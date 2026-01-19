import 'dart:typed_data';
import 'package:supabase_flutter/supabase_flutter.dart';

/// Service for managing documents
class DocumentService {
  final SupabaseClient _client;

  DocumentService({SupabaseClient? client})
      : _client = client ?? Supabase.instance.client;

  /// Upload a document image to storage
  Future<String> uploadDocument({
    required String organizationId,
    required String tripId,
    required String documentType,
    required Uint8List imageBytes,
    required String fileName,
  }) async {
    final path =
        '$organizationId/$tripId/${DateTime.now().millisecondsSinceEpoch}_$fileName';

    await _client.storage.from('documents').uploadBinary(
          path,
          imageBytes,
          fileOptions: const FileOptions(contentType: 'image/jpeg'),
        );

    return path;
  }

  /// Create a document record
  Future<Document> createDocument({
    required String organizationId,
    required String tripId,
    String? loadId,
    required String type,
    required String imageUrl,
    String? localTextExtraction,
    int pageCount = 1,
  }) async {
    final response = await _client
        .from('documents')
        .insert({
          'organization_id': organizationId,
          'trip_id': tripId,
          'load_id': loadId,
          'type': type,
          'image_url': imageUrl,
          'local_text_extraction': localTextExtraction,
          'page_count': pageCount,
          'status': 'pending_review',
        })
        .select()
        .single();

    return Document.fromJson(response);
  }

  /// Process document with LLM
  Future<DocumentProcessResult> processDocument({
    required String documentId,
    required String documentType,
    required String imageUrl,
    String? localExtraction,
  }) async {
    final response = await _client.functions.invoke(
      'process-document',
      body: {
        'document_id': documentId,
        'document_type': documentType,
        'image_url': imageUrl,
        'local_extraction': localExtraction,
      },
    );

    if (response.status != 200) {
      return DocumentProcessResult(
        success: false,
        error: response.data?['error'] ?? 'Processing failed',
      );
    }

    return DocumentProcessResult(
      success: true,
      documentId: documentId,
      extractedData: response.data?['extracted_data'],
      confidence: (response.data?['confidence'] ?? 0).toDouble(),
    );
  }

  /// Get documents for a trip
  Future<List<Document>> getTripDocuments(String tripId) async {
    final response = await _client
        .from('documents')
        .select('*')
        .eq('trip_id', tripId)
        .order('created_at', ascending: false);

    return (response as List).map((json) => Document.fromJson(json)).toList();
  }

  /// Update document status
  Future<void> updateDocumentStatus(
    String documentId,
    String status, {
    String? reviewerId,
  }) async {
    await _client.from('documents').update({
      'status': status,
      'reviewed_by': reviewerId,
      'reviewed_at': DateTime.now().toIso8601String(),
    }).eq('id', documentId);
  }
}

class Document {
  final String id;
  final String organizationId;
  final String? tripId;
  final String? loadId;
  final String type;
  final String imageUrl;
  final String? thumbnailUrl;
  final int pageCount;
  final Map<String, dynamic>? aiData;
  final double? aiConfidence;
  final List<dynamic>? dangerousClauses;
  final String status;
  final DateTime? createdAt;

  Document({
    required this.id,
    required this.organizationId,
    this.tripId,
    this.loadId,
    required this.type,
    required this.imageUrl,
    this.thumbnailUrl,
    this.pageCount = 1,
    this.aiData,
    this.aiConfidence,
    this.dangerousClauses,
    required this.status,
    this.createdAt,
  });

  factory Document.fromJson(Map<String, dynamic> json) {
    return Document(
      id: json['id'],
      organizationId: json['organization_id'],
      tripId: json['trip_id'],
      loadId: json['load_id'],
      type: json['type'],
      imageUrl: json['image_url'],
      thumbnailUrl: json['thumbnail_url'],
      pageCount: json['page_count'] ?? 1,
      aiData: json['ai_data'],
      aiConfidence: json['ai_confidence']?.toDouble(),
      dangerousClauses: json['dangerous_clauses'],
      status: json['status'],
      createdAt: json['created_at'] != null
          ? DateTime.parse(json['created_at'])
          : null,
    );
  }

  bool get isPending => status == 'pending_review';
  bool get isApproved => status == 'approved';
  bool get isRejected => status == 'rejected';

  String get typeDisplay {
    switch (type) {
      case 'rate_con':
        return 'Rate Confirmation';
      case 'bol':
        return 'Bill of Lading';
      case 'fuel_receipt':
        return 'Fuel Receipt';
      case 'lumper_receipt':
        return 'Lumper Receipt';
      case 'scale_ticket':
        return 'Scale Ticket';
      case 'detention_evidence':
        return 'Detention Evidence';
      default:
        return 'Document';
    }
  }
}

class DocumentProcessResult {
  final bool success;
  final String? documentId;
  final Map<String, dynamic>? extractedData;
  final double confidence;
  final String? error;

  DocumentProcessResult({
    required this.success,
    this.documentId,
    this.extractedData,
    this.confidence = 0,
    this.error,
  });
}
