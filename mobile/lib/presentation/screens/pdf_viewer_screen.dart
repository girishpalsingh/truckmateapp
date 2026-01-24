import 'package:flutter/material.dart';
import 'package:syncfusion_flutter_pdfviewer/pdfviewer.dart';
import 'package:supabase_flutter/supabase_flutter.dart';
import '../../core/utils/app_logger.dart';

class PdfViewerScreen extends StatefulWidget {
  final String title;
  final String? storagePath;
  final String? url;

  const PdfViewerScreen({
    super.key,
    required this.title,
    this.storagePath,
    this.url,
  });

  @override
  State<PdfViewerScreen> createState() => _PdfViewerScreenState();
}

class _PdfViewerScreenState extends State<PdfViewerScreen> {
  final SupabaseClient _supabase = Supabase.instance.client;
  String? _resolvedUrl;
  bool _isLoading = true;
  String? _error;

  @override
  void initState() {
    super.initState();
    _resolveUrl();
  }

  Future<void> _resolveUrl() async {
    try {
      if (widget.url != null &&
          !widget.url!.contains('kong:8000') &&
          widget.url!.startsWith('http')) {
        AppLogger.i('Using direct signed URL from server');
        if (mounted) {
          setState(() {
            _resolvedUrl = widget.url;
            _isLoading = false;
          });
        }
        return;
      }

      if (widget.storagePath != null) {
        AppLogger.i('Resolving signed URL for: ${widget.storagePath}');
        // Generate a signed URL from the client side to ensure it uses the correct base URL for local/prod
        final signedUrl = await _supabase.storage
            .from('documents')
            .createSignedUrl(widget.storagePath!, 3600);

        if (mounted) {
          setState(() {
            _resolvedUrl = signedUrl;
            _isLoading = false;
          });
        }
      } else if (widget.url != null) {
        // Fallback to widget.url if path is missing
        if (mounted) {
          setState(() {
            _resolvedUrl = widget.url;
            _isLoading = false;
          });
        }
      } else {
        throw Exception('No storage path or URL provided');
      }
    } catch (e) {
      AppLogger.e('Error resolving PDF URL', e);
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
    return Scaffold(
      appBar: AppBar(
        title: Text(widget.title),
        actions: [
          if (_resolvedUrl != null)
            IconButton(
              icon: const Icon(Icons.refresh),
              onPressed: _resolveUrl,
            ),
        ],
      ),
      body: _isLoading
          ? const Center(child: CircularProgressIndicator())
          : _error != null
              ? _buildErrorState()
              : _resolvedUrl != null
                  ? SfPdfViewer.network(_resolvedUrl!)
                  : const Center(child: Text('No PDF to display')),
    );
  }

  Widget _buildErrorState() {
    return Center(
      child: Padding(
        padding: const EdgeInsets.all(24.0),
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            const Icon(Icons.error_outline, size: 64, color: Colors.red),
            const SizedBox(height: 16),
            const Text(
              'Could not load PDF',
              style: TextStyle(fontSize: 18, fontWeight: FontWeight.bold),
            ),
            const SizedBox(height: 8),
            Text(
              _error!,
              textAlign: TextAlign.center,
              style: TextStyle(color: Colors.grey.shade600),
            ),
            const SizedBox(height: 24),
            ElevatedButton(
              onPressed: _resolveUrl,
              child: const Text('Try Again'),
            ),
          ],
        ),
      ),
    );
  }
}
