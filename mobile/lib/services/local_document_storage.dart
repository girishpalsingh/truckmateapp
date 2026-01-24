import 'dart:io';
import 'dart:typed_data';
import 'package:flutter/foundation.dart';
import 'package:path_provider/path_provider.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:uuid/uuid.dart';
import 'dart:convert';
import '../core/utils/app_logger.dart';

/// Service for local document storage with caching
/// Keeps last 20 documents locally for faster access
/// Supports both mobile (File-based) and web (SharedPreferences-based) storage
class LocalDocumentStorage {
  static const int maxCachedFiles = 20;
  static const String _documentsFolder = 'truckmate_documents';
  static const String _webDocumentsKey = 'web_documents_cache';
  static const String _webDocumentsListKey = 'web_documents_list';

  /// Get the documents directory path (mobile only)
  Future<Directory> get _documentsDir async {
    final appDir = await getApplicationDocumentsDirectory();
    final docsDir = Directory('${appDir.path}/$_documentsFolder');
    if (!await docsDir.exists()) {
      await docsDir.create(recursive: true);
    }
    return docsDir;
  }

  /// Save document bytes to local storage
  /// Returns the local file path (or virtual path on web)
  Future<String> saveDocument({
    required Uint8List bytes,
    required String documentType,
    required String originalFileName,
  }) async {
    final uuid = const Uuid().v4();
    final extension = _getExtension(originalFileName);
    final fileName = '${documentType}_${uuid}$extension';

    if (kIsWeb) {
      // Web: Store in SharedPreferences as base64
      return await _saveDocumentWeb(bytes, fileName);
    } else {
      // Mobile: Store as file
      return await _saveDocumentMobile(bytes, fileName);
    }
  }

  Future<String> _saveDocumentWeb(Uint8List bytes, String fileName) async {
    final prefs = await SharedPreferences.getInstance();

    // Store the bytes as base64
    final base64Data = base64Encode(bytes);
    await prefs.setString('$_webDocumentsKey:$fileName', base64Data);

    // Update the list of cached documents
    final docsList = prefs.getStringList(_webDocumentsListKey) ?? [];
    docsList.insert(0, fileName); // Add to front (newest first)

    // Cleanup old entries
    if (docsList.length > maxCachedFiles) {
      final toRemove = docsList.sublist(maxCachedFiles);
      for (final oldFile in toRemove) {
        await prefs.remove('$_webDocumentsKey:$oldFile');
      }
      docsList.removeRange(maxCachedFiles, docsList.length);
    }

    await prefs.setStringList(_webDocumentsListKey, docsList);

    AppLogger.d('📁 [Web] Document saved: $fileName');
    return 'web://$fileName'; // Virtual path for web
  }

  Future<String> _saveDocumentMobile(Uint8List bytes, String fileName) async {
    final dir = await _documentsDir;
    final filePath = '${dir.path}/$fileName';

    final file = File(filePath);
    await file.writeAsBytes(bytes);

    AppLogger.d('📁 Document saved locally: $filePath');

    // Cleanup old files beyond cache limit
    await _cleanupOldFiles();

    // Return only the filename to ensure persistence across iOS sandbox rotations
    return fileName;
  }

  /// Get document bytes from local storage
  Future<Uint8List?> getLocalDocumentBytes(String localPath) async {
    if (kIsWeb || localPath.startsWith('web://')) {
      return await _getDocumentBytesWeb(localPath);
    } else {
      return await _getDocumentBytesMobile(localPath);
    }
  }

  Future<Uint8List?> _getDocumentBytesWeb(String virtualPath) async {
    final fileName = virtualPath.replaceFirst('web://', '');
    final prefs = await SharedPreferences.getInstance();
    final base64Data = prefs.getString('$_webDocumentsKey:$fileName');

    if (base64Data != null) {
      return base64Decode(base64Data);
    }
    return null;
  }

  Future<Uint8List?> _getDocumentBytesMobile(String localPath) async {
    final file = await _resolveLocalFile(localPath);
    if (await file.exists()) {
      return await file.readAsBytes();
    }
    return null;
  }

  /// Get document from local storage (mobile only)
  Future<File?> getLocalDocument(String localPath) async {
    if (kIsWeb) return null;

    final file = await _resolveLocalFile(localPath);
    if (await file.exists()) {
      return file;
    }
    return null;
  }

  /// Check if document exists locally
  Future<bool> existsLocally(String localPath) async {
    if (kIsWeb || localPath.startsWith('web://')) {
      final fileName = localPath.replaceFirst('web://', '');
      final prefs = await SharedPreferences.getInstance();
      return prefs.containsKey('$_webDocumentsKey:$fileName');
    } else {
      final file = await _resolveLocalFile(localPath);
      return await file.exists();
    }
  }

  /// Helper to resolve absolute or relative paths
  Future<File> _resolveLocalFile(String path) async {
    // If it's already an absolute path and exists, use it (for backward compatibility)
    if (path.startsWith('/') && await File(path).exists()) {
      return File(path);
    }

    // Otherwise, assume it's a filename relative to our doc dir
    // Or if it was an absolute path from a previous install (on iOS), extract filename
    String fileName = path;
    if (path.contains('/')) {
      fileName = path.split('/').last;
    }

    final dir = await _documentsDir;
    return File('${dir.path}/$fileName');
  }

  /// Get all locally cached documents (mobile only)
  Future<List<FileSystemEntity>> getCachedDocuments() async {
    if (kIsWeb) return [];

    final dir = await _documentsDir;
    if (!await dir.exists()) return [];

    final files = await dir.list().toList();
    // Sort by modification time (newest first)
    files.sort((a, b) {
      final aStat = a.statSync();
      final bStat = b.statSync();
      return bStat.modified.compareTo(aStat.modified);
    });

    return files;
  }

  /// Cleanup old files, keeping only the last [maxCachedFiles]
  Future<void> _cleanupOldFiles() async {
    if (kIsWeb) return; // Web cleanup is handled in _saveDocumentWeb

    try {
      final files = await getCachedDocuments();

      if (files.length > maxCachedFiles) {
        // Delete files beyond the cache limit
        for (int i = maxCachedFiles; i < files.length; i++) {
          final file = files[i];
          if (file is File) {
            await file.delete();
            AppLogger.d('🗑️ Cleaned up old document: ${file.path}');
          }
        }
      }
    } catch (e, stack) {
      AppLogger.w('⚠️ Error cleaning up old files', e, stack);
    }
  }

  /// Get file extension from filename
  String _getExtension(String fileName) {
    final lastDot = fileName.lastIndexOf('.');
    if (lastDot != -1) {
      return fileName.substring(lastDot);
    }
    return '.pdf'; // Default to PDF
  }

  /// Delete a single document from local storage
  Future<bool> deleteDocument(String localPath) async {
    try {
      if (kIsWeb || localPath.startsWith('web://')) {
        final fileName = localPath.replaceFirst('web://', '');
        final prefs = await SharedPreferences.getInstance();
        await prefs.remove('$_webDocumentsKey:$fileName');

        // Update the documents list
        final docsList = prefs.getStringList(_webDocumentsListKey) ?? [];
        docsList.remove(fileName);
        await prefs.setStringList(_webDocumentsListKey, docsList);

        AppLogger.d('🗑️ [Web] Document deleted: $fileName');
        return true;
      } else {
        final file = File(localPath);
        if (await file.exists()) {
          await file.delete();
          AppLogger.d('🗑️ Document deleted: $localPath');
          return true;
        }
        return false;
      }
    } catch (e, stack) {
      AppLogger.e('Error deleting document', e, stack);
      return false;
    }
  }

  /// Clear all cached documents (for testing/debugging)
  Future<void> clearCache() async {
    if (kIsWeb) {
      final prefs = await SharedPreferences.getInstance();
      final docsList = prefs.getStringList(_webDocumentsListKey) ?? [];
      for (final fileName in docsList) {
        await prefs.remove('$_webDocumentsKey:$fileName');
      }
      await prefs.remove(_webDocumentsListKey);
      AppLogger.d('🗑️ [Web] Document cache cleared');
    } else {
      final dir = await _documentsDir;
      if (await dir.exists()) {
        await dir.delete(recursive: true);
        AppLogger.d('🗑️ Document cache cleared');
      }
    }
  }

  /// Get cache size in bytes
  Future<int> getCacheSize() async {
    if (kIsWeb) {
      final prefs = await SharedPreferences.getInstance();
      final docsList = prefs.getStringList(_webDocumentsListKey) ?? [];
      int totalSize = 0;
      for (final fileName in docsList) {
        final base64Data = prefs.getString('$_webDocumentsKey:$fileName');
        if (base64Data != null) {
          totalSize += base64Data.length;
        }
      }
      return totalSize;
    }

    final files = await getCachedDocuments();
    int totalSize = 0;
    for (final file in files) {
      if (file is File) {
        totalSize += await file.length();
      }
    }
    return totalSize;
  }

  /// Format cache size for display
  Future<String> getFormattedCacheSize() async {
    final bytes = await getCacheSize();
    if (bytes < 1024) return '$bytes B';
    if (bytes < 1024 * 1024) return '${(bytes / 1024).toStringAsFixed(1)} KB';
    return '${(bytes / (1024 * 1024)).toStringAsFixed(1)} MB';
  }
}
