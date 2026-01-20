import 'dart:async';
import 'dart:convert';
import 'dart:io';
import 'dart:typed_data';
import 'package:flutter/foundation.dart' show debugPrint;
import 'package:connectivity_plus/connectivity_plus.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:supabase_flutter/supabase_flutter.dart';
import 'package:uuid/uuid.dart';

import '../data/models/pending_document_model.dart';
import 'local_document_storage.dart';
import '../core/utils/user_utils.dart';

/// Service for syncing documents with server and handling LLM processing
class DocumentSyncService {
  static const String _pendingDocsKey = 'pending_documents';
  static const int maxRetries = 3;

  final LocalDocumentStorage _localStorage = LocalDocumentStorage();
  final SupabaseClient _supabase;

  StreamSubscription<ConnectivityResult>? _connectivitySubscription;
  bool _isSyncing = false;

  // Cached user organization ID
  String? _userOrganizationId;

  // Stream controller for sync status updates
  final _statusController = StreamController<PendingDocument>.broadcast();
  Stream<PendingDocument> get statusUpdates => _statusController.stream;

  DocumentSyncService({SupabaseClient? supabase})
      : _supabase = supabase ?? Supabase.instance.client;

  /// Get the current user's organization ID from their profile
  Future<String?> _getUserOrganization() async {
    if (_userOrganizationId != null) return _userOrganizationId;

    _userOrganizationId = await UserUtils.getUserOrganization();
    return _userOrganizationId;
  }

  /// Initialize sync service and start listening for connectivity
  Future<void> initialize() async {
    // Listen for connectivity changes
    _connectivitySubscription =
        Connectivity().onConnectivityChanged.listen(_onConnectivityChanged);

    // Check if online and sync pending documents
    final hasInternet = await _hasInternetConnection();
    _log('📡 Initial internet check: $hasInternet');
    if (hasInternet) {
      syncPendingDocuments();
    }
  }

  void dispose() {
    _connectivitySubscription?.cancel();
    _statusController.close();
  }

  Future<void> _onConnectivityChanged(ConnectivityResult result) async {
    _log('📶 Connectivity changed: $result');
    // Always check for actual internet access, as ConnectivityResult can be unreliable
    // (especially on iOS Simulator where it may report 'none' despite having internet)
    if (await _hasInternetConnection()) {
      _log('📶 Online (Confirmed) - starting document sync');
      syncPendingDocuments();
    }
  }

  /// Check for actual internet connection by resolving a domain
  Future<bool> _hasInternetConnection() async {
    try {
      final result = await InternetAddress.lookup('google.com');
      return result.isNotEmpty && result[0].rawAddress.isNotEmpty;
    } on SocketException catch (_) {
      return false;
    }
  }

  /// Log helper that works on web
  void _log(String message) {
    // Use print for web console visibility
    print('[DocumentSync] $message');
  }

  /// Save document locally and queue for sync
  Future<PendingDocument> saveAndQueueDocument({
    required Uint8List bytes,
    required String documentType,
    required String fileName,
    String? tripId,
    String? loadId,
    String? organizationId,
  }) async {
    // Save to local storage
    final localPath = await _localStorage.saveDocument(
      bytes: bytes,
      documentType: documentType,
      originalFileName: fileName,
    );

    // Create pending document record
    final pendingDoc = PendingDocument(
      id: const Uuid().v4(),
      localPath: localPath,
      documentType: documentType,
      tripId: tripId,
      loadId: loadId,
      organizationId: organizationId,
      syncStatus: DocumentSyncStatus.pending,
      createdAt: DateTime.now(),
    );

    // Save to pending queue
    await _addToPendingQueue(pendingDoc);

    _log('📋 Document queued for sync: ${pendingDoc.id}');
    _log('   Type: ${pendingDoc.documentType}');
    _log('   Local path: ${pendingDoc.localPath}');

    // Try to sync immediately if online
    // Try to sync immediately if online
    final hasInternet = await _hasInternetConnection();
    _log('📡 Current internet status: $hasInternet');
    if (hasInternet) {
      _log('🚀 Online - triggering immediate sync...');
      syncPendingDocuments();
    } else {
      _log('📴 Offline - document will sync when online');
    }

    return pendingDoc;
  }

  /// Get all pending documents
  Future<List<PendingDocument>> getPendingDocuments() async {
    final prefs = await SharedPreferences.getInstance();
    final jsonList = prefs.getStringList(_pendingDocsKey) ?? [];

    return jsonList
        .map((json) => PendingDocument.fromJson(jsonDecode(json)))
        .toList();
  }

  /// Sync all pending documents
  Future<void> syncPendingDocuments() async {
    if (_isSyncing) {
      _log('⏳ Sync already in progress, skipping...');
      return;
    }

    _isSyncing = true;
    _log('═══════════════════════════════════════════════════════════');
    _log('🔄 STARTING DOCUMENT SYNC...');
    _log('═══════════════════════════════════════════════════════════');

    try {
      final pendingDocs = await getPendingDocuments();
      final toSync = pendingDocs
          .where((d) =>
              d.syncStatus == DocumentSyncStatus.pending ||
              (d.syncStatus == DocumentSyncStatus.failed &&
                  d.retryCount < maxRetries))
          .toList();

      _log('📤 Found ${toSync.length} documents to sync');

      for (int i = 0; i < toSync.length; i++) {
        _log('───────────────────────────────────────────────────────────');
        _log('📄 Syncing document ${i + 1}/${toSync.length}: ${toSync[i].id}');
        await _syncDocument(toSync[i]);
      }

      _log('═══════════════════════════════════════════════════════════');
      _log('✅ SYNC COMPLETE');
      _log('═══════════════════════════════════════════════════════════');
    } catch (e) {
      _log('❌ Sync error: $e');
    } finally {
      _isSyncing = false;
    }
  }

  /// Sync a single document
  Future<void> _syncDocument(PendingDocument doc) async {
    try {
      // Update status to uploading
      var updatedDoc = doc.copyWith(syncStatus: DocumentSyncStatus.uploading);
      await _updatePendingDocument(updatedDoc);
      _statusController.add(updatedDoc);

      // Read document bytes from local storage (works on both web and mobile)
      final bytes = await _localStorage.getLocalDocumentBytes(doc.localPath);
      if (bytes == null) {
        throw Exception('Local document not found: ${doc.localPath}');
      }
      _log('📄 Loaded ${bytes.length} bytes from local storage');

      // Determine content type
      final isImage = doc.localPath.toLowerCase().endsWith('.jpg') ||
          doc.localPath.toLowerCase().endsWith('.jpeg') ||
          doc.localPath.toLowerCase().endsWith('.png');
      final contentType = isImage ? 'image/jpeg' : 'application/pdf';

      // Get organization ID from document or user profile
      String? orgId = doc.organizationId;
      if (orgId == null || orgId.isEmpty) {
        orgId = await _getUserOrganization();
        if (orgId == null) {
          throw Exception(
              'User has no organization assigned. Cannot upload document.');
        }
      }

      final tripId = doc.tripId ?? 'unassigned';
      final remotePath =
          '$orgId/$tripId/${DateTime.now().millisecondsSinceEpoch}_${doc.id}${_getExtension(doc.localPath)}';

      _log('☁️ Uploading to Supabase Storage...');
      _log('   Path: $remotePath');

      await _supabase.storage.from('documents').uploadBinary(
            remotePath,
            bytes,
            fileOptions: FileOptions(contentType: contentType),
          );

      _log('☁️ ✅ Upload complete!');

      // Create document record in database
      _log('📝 Creating document record in database...');
      final dbResponse = await _supabase
          .from('documents')
          .insert({
            'organization_id': orgId,
            'trip_id': tripId,
            'load_id': doc.loadId,
            'type': doc.documentType,
            'image_url': remotePath,
            'page_count': 1,
            'status': 'pending_review',
          })
          .select()
          .single();

      final remoteDocId = dbResponse['id'] as String;
      _log('📝 ✅ Document record created: $remoteDocId');

      // Update status to uploaded
      updatedDoc = updatedDoc.copyWith(
        syncStatus: DocumentSyncStatus.uploaded,
        remoteUrl: remotePath,
        remoteDocumentId: remoteDocId,
        syncedAt: DateTime.now(),
      );
      await _updatePendingDocument(updatedDoc);
      _statusController.add(updatedDoc);

      // Trigger LLM processing
      _log('🤖 TRIGGERING LLM PROCESSING...');
      await _processWithLLM(updatedDoc);
    } catch (e) {
      _log('❌ Failed to sync document ${doc.id}: $e');

      final failedDoc = doc.copyWith(
        syncStatus: DocumentSyncStatus.failed,
        errorMessage: e.toString(),
        retryCount: doc.retryCount + 1,
      );
      await _updatePendingDocument(failedDoc);
      _statusController.add(failedDoc);
    }
  }

  /// Process document with LLM via Edge Function
  Future<void> _processWithLLM(PendingDocument doc) async {
    try {
      var updatedDoc = doc.copyWith(syncStatus: DocumentSyncStatus.processing);
      await _updatePendingDocument(updatedDoc);
      _statusController.add(updatedDoc);

      _log('───────────────────────────────────────────────────────────');
      _log('🤖 LLM PROCESSING: ${doc.documentType}');
      _log('───────────────────────────────────────────────────────────');
      _log('   Document ID: ${doc.remoteDocumentId}');
      _log('   Image URL: ${doc.remoteUrl}');
      _log('   Calling process-document Edge Function...');

      // Call the process-document Edge Function
      final response = await _supabase.functions.invoke(
        'process-document',
        body: {
          'document_id': doc.remoteDocumentId,
          'document_type': doc.documentType,
          'image_url': doc.remoteUrl,
        },
      );

      _log('🤖 Edge Function response status: ${response.status}');

      if (response.status == 200 && response.data != null) {
        final extractedData =
            response.data['extracted_data'] as Map<String, dynamic>?;
        final confidence = (response.data['confidence'] as num?)?.toDouble();
        final dangerousClauses =
            extractedData?['dangerous_clauses'] as List<dynamic>?;

        updatedDoc = updatedDoc.copyWith(
          syncStatus: DocumentSyncStatus.complete,
          llmResponse: extractedData,
          confidence: confidence,
          dangerousClauses: dangerousClauses,
        );

        _log('🤖 ✅ LLM processing complete!');
        _log('   Confidence: $confidence');
        _log('   Dangerous clauses: ${dangerousClauses?.length ?? 0}');
      } else {
        throw Exception(response.data?['error'] ?? 'Unknown processing error');
      }

      await _updatePendingDocument(updatedDoc);
      _statusController.add(updatedDoc);
    } catch (e) {
      _log('❌ LLM processing failed: $e');

      // Mark as complete but with error (upload succeeded)
      final failedDoc = doc.copyWith(
        syncStatus: DocumentSyncStatus.complete,
        errorMessage: 'LLM processing failed: $e',
      );
      await _updatePendingDocument(failedDoc);
      _statusController.add(failedDoc);
    }
  }

  /// Add document to pending queue
  Future<void> _addToPendingQueue(PendingDocument doc) async {
    final prefs = await SharedPreferences.getInstance();
    final jsonList = prefs.getStringList(_pendingDocsKey) ?? [];
    jsonList.add(jsonEncode(doc.toJson()));
    await prefs.setStringList(_pendingDocsKey, jsonList);
  }

  /// Update document in pending queue
  Future<void> _updatePendingDocument(PendingDocument doc) async {
    final prefs = await SharedPreferences.getInstance();
    final jsonList = prefs.getStringList(_pendingDocsKey) ?? [];

    final updatedList = jsonList.map((json) {
      final existing = PendingDocument.fromJson(jsonDecode(json));
      if (existing.id == doc.id) {
        return jsonEncode(doc.toJson());
      }
      return json;
    }).toList();

    await prefs.setStringList(_pendingDocsKey, updatedList);
  }

  /// Get document by ID
  Future<PendingDocument?> getDocumentById(String id) async {
    final docs = await getPendingDocuments();
    try {
      return docs.firstWhere((d) => d.id == id);
    } catch (_) {
      return null;
    }
  }

  /// Get document bytes - from local cache or fetch from server
  Future<Uint8List?> getDocumentBytes(PendingDocument doc) async {
    // Try local first
    final localBytes = await _localStorage.getLocalDocumentBytes(doc.localPath);
    if (localBytes != null) {
      debugPrint('📁 Loaded from local cache: ${doc.id}');
      return localBytes;
    }

    // Fetch from server if we have remote URL
    if (doc.remoteUrl != null) {
      debugPrint('☁️ Fetching from server: ${doc.remoteUrl}');
      final response =
          await _supabase.storage.from('documents').download(doc.remoteUrl!);
      return response;
    }

    return null;
  }

  String _getExtension(String path) {
    final lastDot = path.lastIndexOf('.');
    if (lastDot != -1) {
      return path.substring(lastDot);
    }
    return '.pdf';
  }

  /// Clear all pending documents (for debugging)
  Future<void> clearPendingQueue() async {
    final prefs = await SharedPreferences.getInstance();
    await prefs.remove(_pendingDocsKey);
    debugPrint('🗑️ Pending queue cleared');
  }
}
