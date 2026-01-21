import 'dart:typed_data';
import 'package:flutter/material.dart';
import '../../data/models/pending_document_model.dart';
import '../../services/document_sync_service.dart';
import '../themes/app_theme.dart';

/// Full-screen document viewer
class DocumentViewerScreen extends StatefulWidget {
  final PendingDocument document;

  const DocumentViewerScreen({super.key, required this.document});

  @override
  State<DocumentViewerScreen> createState() => _DocumentViewerScreenState();
}

class _DocumentViewerScreenState extends State<DocumentViewerScreen> {
  final DocumentSyncService _syncService = DocumentSyncService();
  Uint8List? _documentBytes;
  bool _isLoading = true;
  String? _error;

  @override
  void initState() {
    super.initState();
    _loadDocument();
  }

  Future<void> _loadDocument() async {
    try {
      final bytes = await _syncService.getDocumentBytes(widget.document);
      if (mounted) {
        setState(() {
          _documentBytes = bytes;
          _isLoading = false;
        });
      }
    } catch (e) {
      if (mounted) {
        setState(() {
          _error = e.toString();
          _isLoading = false;
        });
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    final doc = widget.document;
    final isPdf = doc.localPath.toLowerCase().endsWith('.pdf');

    return Scaffold(
      backgroundColor: Colors.black,
      appBar: AppBar(
        backgroundColor: Colors.black,
        foregroundColor: Colors.white,
        title: Text(doc.documentTypeDisplay),
        actions: [
          IconButton(
            icon: const Icon(Icons.info_outline),
            onPressed: _showDocumentInfo,
          ),
        ],
      ),
      body: _buildBody(isPdf),
    );
  }

  Widget _buildBody(bool isPdf) {
    if (_isLoading) {
      return const Center(
        child: CircularProgressIndicator(color: Colors.white),
      );
    }

    if (_error != null) {
      return Center(
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            const Icon(Icons.error_outline, size: 64, color: Colors.red),
            const SizedBox(height: 16),
            Text(
              'Failed to load document',
              style: Theme.of(context).textTheme.titleLarge?.copyWith(
                    color: Colors.white,
                  ),
            ),
            const SizedBox(height: 8),
            Text(
              _error!,
              style: const TextStyle(color: Colors.grey),
              textAlign: TextAlign.center,
            ),
            const SizedBox(height: 24),
            ElevatedButton(
              onPressed: () {
                setState(() {
                  _isLoading = true;
                  _error = null;
                });
                _loadDocument();
              },
              child: const Text('Retry'),
            ),
          ],
        ),
      );
    }

    if (_documentBytes == null) {
      return const Center(
        child: Text(
          'Document not available',
          style: TextStyle(color: Colors.white),
        ),
      );
    }

    if (isPdf) {
      // For PDF files, show a placeholder (PDF viewing requires additional packages)
      return Center(
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            Icon(Icons.picture_as_pdf, size: 80, color: Colors.red.shade400),
            const SizedBox(height: 16),
            const Text(
              'PDF Document',
              style: TextStyle(color: Colors.white, fontSize: 18),
            ),
            const SizedBox(height: 8),
            Text(
              '${(_documentBytes!.length / 1024).toStringAsFixed(1)} KB',
              style: const TextStyle(color: Colors.grey),
            ),
          ],
        ),
      );
    }

    // Image viewer with pinch-to-zoom
    return InteractiveViewer(
      minScale: 0.5,
      maxScale: 4.0,
      child: Center(
        child: Image.memory(
          _documentBytes!,
          fit: BoxFit.contain,
        ),
      ),
    );
  }

  void _showDocumentInfo() {
    final doc = widget.document;

    showModalBottomSheet(
      context: context,
      backgroundColor: Colors.grey.shade900,
      shape: const RoundedRectangleBorder(
        borderRadius: BorderRadius.vertical(top: Radius.circular(16)),
      ),
      builder: (context) => Padding(
        padding: const EdgeInsets.all(20),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Center(
              child: Container(
                width: 40,
                height: 4,
                decoration: BoxDecoration(
                  color: Colors.grey.shade600,
                  borderRadius: BorderRadius.circular(2),
                ),
              ),
            ),
            const SizedBox(height: 20),
            Text(
              'Document Details',
              style: Theme.of(context).textTheme.titleLarge?.copyWith(
                    color: Colors.white,
                  ),
            ),
            const SizedBox(height: 16),
            _buildInfoRow('Type', doc.documentTypeDisplay),
            _buildInfoRow('Status', doc.statusDisplay),
            _buildInfoRow('Created', _formatDate(doc.createdAt)),
            if (doc.syncedAt != null)
              _buildInfoRow('Synced', _formatDate(doc.syncedAt!)),
            if (doc.tripId != null &&
                doc.tripId != '00000000-0000-0000-0000-000000000000')
              _buildInfoRow('Trip ID', doc.tripId!.substring(0, 8) + '...'),
            if (doc.confidence != null)
              _buildInfoRow('Confidence',
                  '${(doc.confidence! * 100).toStringAsFixed(0)}%'),
            if (doc.errorMessage != null)
              _buildInfoRow('Error', doc.errorMessage!, isError: true),
            const SizedBox(height: 20),
          ],
        ),
      ),
    );
  }

  Widget _buildInfoRow(String label, String value, {bool isError = false}) {
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 6),
      child: Row(
        mainAxisAlignment: MainAxisAlignment.spaceBetween,
        children: [
          Text(
            label,
            style: const TextStyle(color: Colors.grey),
          ),
          Flexible(
            child: Text(
              value,
              style: TextStyle(
                color: isError ? AppTheme.errorColor : Colors.white,
              ),
              textAlign: TextAlign.end,
            ),
          ),
        ],
      ),
    );
  }

  String _formatDate(DateTime date) {
    return '${date.day}/${date.month}/${date.year} ${date.hour}:${date.minute.toString().padLeft(2, '0')}';
  }
}
