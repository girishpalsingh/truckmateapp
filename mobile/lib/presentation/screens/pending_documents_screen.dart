import 'dart:typed_data';
import 'package:flutter/material.dart';
import '../../data/models/pending_document_model.dart';
import '../../services/document_sync_service.dart';
import '../themes/app_theme.dart';
import 'document_viewer_screen.dart';

/// Screen to display all pending and synced documents
class PendingDocumentsScreen extends StatefulWidget {
  const PendingDocumentsScreen({super.key});

  @override
  State<PendingDocumentsScreen> createState() => _PendingDocumentsScreenState();
}

class _PendingDocumentsScreenState extends State<PendingDocumentsScreen> {
  final DocumentSyncService _syncService = DocumentSyncService();
  List<PendingDocument> _documents = [];
  final Set<String> _selectedIds = {};
  bool _isLoading = true;
  bool _isSelectionMode = false;

  @override
  void initState() {
    super.initState();
    _loadDocuments();
  }

  Future<void> _loadDocuments() async {
    setState(() => _isLoading = true);
    try {
      final docs = await _syncService.getPendingDocuments();
      setState(() {
        _documents = docs;
        _isLoading = false;
      });
    } catch (e) {
      debugPrint('Error loading documents: $e');
      setState(() => _isLoading = false);
    }
  }

  void _toggleSelection(String id) {
    setState(() {
      if (_selectedIds.contains(id)) {
        _selectedIds.remove(id);
        if (_selectedIds.isEmpty) {
          _isSelectionMode = false;
        }
      } else {
        _selectedIds.add(id);
      }
    });
  }

  void _enterSelectionMode(String id) {
    setState(() {
      _isSelectionMode = true;
      _selectedIds.add(id);
    });
  }

  void _exitSelectionMode() {
    setState(() {
      _isSelectionMode = false;
      _selectedIds.clear();
    });
  }

  Future<void> _deleteSelected() async {
    // Only allow deleting unsynced documents
    final unsyncedIds = _selectedIds.where((id) {
      final doc = _documents.where((d) => d.id == id).firstOrNull;
      if (doc == null) return true; // Allow deleting documents not in list
      return !_isSynced(doc);
    }).toList();

    if (unsyncedIds.isEmpty) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Only unsynced documents can be deleted')),
      );
      return;
    }

    final confirmed = await showDialog<bool>(
      context: context,
      builder: (context) => AlertDialog(
        title: const Text('Delete Documents'),
        content: Text('Delete ${unsyncedIds.length} unsynced document(s)?'),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context, false),
            child: const Text('Cancel'),
          ),
          TextButton(
            onPressed: () => Navigator.pop(context, true),
            style: TextButton.styleFrom(foregroundColor: Colors.red),
            child: const Text('Delete'),
          ),
        ],
      ),
    );

    if (confirmed == true) {
      final success = await _syncService.deleteDocuments(unsyncedIds);
      _exitSelectionMode();
      if (success) {
        await _loadDocuments();
        if (mounted) {
          ScaffoldMessenger.of(context).showSnackBar(
            SnackBar(
                content: Text('Deleted ${unsyncedIds.length} document(s)')),
          );
        }
      } else {
        if (mounted) {
          ScaffoldMessenger.of(context).showSnackBar(
            const SnackBar(content: Text('Failed to delete some documents')),
          );
        }
        await _loadDocuments();
      }
    }
  }

  bool _isSynced(PendingDocument doc) {
    return doc.syncStatus == DocumentSyncStatus.complete ||
        doc.syncStatus == DocumentSyncStatus.uploaded;
  }

  void _openDocument(PendingDocument doc) {
    Navigator.push(
      context,
      MaterialPageRoute(
        builder: (context) => DocumentViewerScreen(document: doc),
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: _isSelectionMode
            ? Text('${_selectedIds.length} selected')
            : const Text('Documents'),
        leading: _isSelectionMode
            ? IconButton(
                icon: const Icon(Icons.close),
                onPressed: _exitSelectionMode,
              )
            : null,
        actions: [
          if (_isSelectionMode)
            IconButton(
              icon: const Icon(Icons.delete),
              onPressed: _deleteSelected,
            )
          else
            IconButton(
              icon: const Icon(Icons.refresh),
              onPressed: _loadDocuments,
            ),
        ],
      ),
      body: _isLoading
          ? const Center(child: CircularProgressIndicator())
          : _documents.isEmpty
              ? _buildEmptyState()
              : RefreshIndicator(
                  onRefresh: _loadDocuments,
                  child: GridView.builder(
                    padding: const EdgeInsets.all(12),
                    gridDelegate:
                        const SliverGridDelegateWithFixedCrossAxisCount(
                      crossAxisCount: 2,
                      childAspectRatio: 0.8,
                      crossAxisSpacing: 12,
                      mainAxisSpacing: 12,
                    ),
                    itemCount: _documents.length,
                    itemBuilder: (context, index) {
                      final doc = _documents[index];
                      return _DocumentTile(
                        document: doc,
                        isSelected: _selectedIds.contains(doc.id),
                        isSelectionMode: _isSelectionMode,
                        isSynced: _isSynced(doc),
                        syncService: _syncService,
                        onTap: () {
                          if (_isSelectionMode) {
                            _toggleSelection(doc.id);
                          } else {
                            _openDocument(doc);
                          }
                        },
                        onLongPress: () {
                          if (!_isSelectionMode && !_isSynced(doc)) {
                            _enterSelectionMode(doc.id);
                          }
                        },
                      );
                    },
                  ),
                ),
    );
  }

  Widget _buildEmptyState() {
    return Center(
      child: Column(
        mainAxisAlignment: MainAxisAlignment.center,
        children: [
          Icon(
            Icons.folder_open,
            size: 80,
            color: AppTheme.textSubtitle,
          ),
          const SizedBox(height: 16),
          Text(
            'No documents yet',
            style: Theme.of(context).textTheme.titleLarge?.copyWith(
                  color: AppTheme.textSecondary,
                ),
          ),
          const SizedBox(height: 8),
          Text(
            'Scan a document to get started',
            style: Theme.of(context).textTheme.bodyMedium,
          ),
        ],
      ),
    );
  }
}

class _DocumentTile extends StatefulWidget {
  final PendingDocument document;
  final bool isSelected;
  final bool isSelectionMode;
  final bool isSynced;
  final DocumentSyncService syncService;
  final VoidCallback onTap;
  final VoidCallback onLongPress;

  const _DocumentTile({
    required this.document,
    required this.isSelected,
    required this.isSelectionMode,
    required this.isSynced,
    required this.syncService,
    required this.onTap,
    required this.onLongPress,
  });

  @override
  State<_DocumentTile> createState() => _DocumentTileState();
}

class _DocumentTileState extends State<_DocumentTile> {
  Uint8List? _thumbnailBytes;
  bool _isLoadingThumbnail = true;

  @override
  void initState() {
    super.initState();
    _loadThumbnail();
  }

  Future<void> _loadThumbnail() async {
    try {
      final bytes = await widget.syncService.getDocumentBytes(widget.document);
      if (mounted) {
        setState(() {
          _thumbnailBytes = bytes;
          _isLoadingThumbnail = false;
        });
      }
    } catch (e) {
      if (mounted) {
        setState(() => _isLoadingThumbnail = false);
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    final doc = widget.document;
    final isPdf = doc.localPath.toLowerCase().endsWith('.pdf');

    return GestureDetector(
      onTap: widget.onTap,
      onLongPress: widget.onLongPress,
      child: Container(
        decoration: BoxDecoration(
          borderRadius: BorderRadius.circular(12),
          border: widget.isSelected
              ? Border.all(color: AppTheme.primaryColor, width: 3)
              : Border.all(color: Colors.grey.shade300),
          boxShadow: [
            BoxShadow(
              color: Colors.black.withOpacity(0.1),
              blurRadius: 4,
              offset: const Offset(0, 2),
            ),
          ],
        ),
        child: ClipRRect(
          borderRadius: BorderRadius.circular(10),
          child: Stack(
            fit: StackFit.expand,
            children: [
              // Thumbnail
              _buildThumbnail(isPdf),

              // Status indicator
              Positioned(
                right: 8,
                bottom: 8,
                child: _buildStatusIndicator(),
              ),

              // Selection checkbox
              if (widget.isSelectionMode && !widget.isSynced)
                Positioned(
                  left: 8,
                  top: 8,
                  child: Container(
                    decoration: BoxDecoration(
                      color: widget.isSelected
                          ? AppTheme.primaryColor
                          : Colors.white,
                      shape: BoxShape.circle,
                      border: Border.all(
                        color: widget.isSelected
                            ? AppTheme.primaryColor
                            : Colors.grey,
                        width: 2,
                      ),
                    ),
                    child: widget.isSelected
                        ? const Icon(Icons.check, size: 18, color: Colors.white)
                        : const SizedBox(width: 22, height: 22),
                  ),
                ),

              // Document type label
              Positioned(
                left: 0,
                right: 0,
                bottom: 0,
                child: Container(
                  padding:
                      const EdgeInsets.symmetric(horizontal: 8, vertical: 6),
                  decoration: BoxDecoration(
                    gradient: LinearGradient(
                      begin: Alignment.bottomCenter,
                      end: Alignment.topCenter,
                      colors: [
                        Colors.black.withOpacity(0.7),
                        Colors.transparent,
                      ],
                    ),
                  ),
                  child: Text(
                    doc.title ?? doc.documentTypeDisplay,
                    style: const TextStyle(
                      color: Colors.white,
                      fontSize: 12,
                      fontWeight: FontWeight.w500,
                    ),
                    maxLines: 1,
                    overflow: TextOverflow.ellipsis,
                  ),
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }

  Widget _buildThumbnail(bool isPdf) {
    if (_isLoadingThumbnail) {
      return Container(
        color: Colors.grey.shade200,
        child: const Center(child: CircularProgressIndicator(strokeWidth: 2)),
      );
    }

    if (_thumbnailBytes != null && !isPdf) {
      return Image.memory(
        _thumbnailBytes!,
        fit: BoxFit.cover,
      );
    }

    // PDF or no thumbnail available
    return Container(
      color: Colors.grey.shade100,
      child: Center(
        child: Icon(
          isPdf ? Icons.picture_as_pdf : Icons.description,
          size: 48,
          color: isPdf ? Colors.red.shade400 : Colors.grey,
        ),
      ),
    );
  }

  Widget _buildStatusIndicator() {
    final isSynced = widget.isSynced;
    final isProcessing = widget.document.isProcessing;
    final isFailed = widget.document.isFailed;

    IconData icon;
    Color color;

    if (isSynced) {
      icon = Icons.check_circle;
      color = AppTheme.successColor;
    } else if (isFailed) {
      icon = Icons.error;
      color = AppTheme.errorColor;
    } else if (isProcessing) {
      return SizedBox(
        width: 24,
        height: 24,
        child: CircularProgressIndicator(
          strokeWidth: 2,
          color: AppTheme.accentColor,
        ),
      );
    } else {
      icon = Icons.check_circle_outline;
      color = Colors.grey;
    }

    return Container(
      decoration: BoxDecoration(
        color: Colors.white,
        shape: BoxShape.circle,
        boxShadow: [
          BoxShadow(
            color: Colors.black.withOpacity(0.2),
            blurRadius: 4,
          ),
        ],
      ),
      child: Icon(icon, size: 24, color: color),
    );
  }
}
