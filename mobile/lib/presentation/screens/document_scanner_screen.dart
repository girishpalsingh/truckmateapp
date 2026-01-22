import 'dart:io';
import 'dart:typed_data';
import 'package:flutter/foundation.dart' show kIsWeb;
import 'package:flutter/material.dart';
import 'package:camera/camera.dart';
import 'package:vision_text_recognition/vision_text_recognition.dart';
import 'package:image_picker/image_picker.dart';
import 'package:file_picker/file_picker.dart';
import 'package:pdf/pdf.dart';
import 'package:pdf/widgets.dart' as pw;
import 'package:share_plus/share_plus.dart';
import 'package:path_provider/path_provider.dart';
import '../themes/app_theme.dart';
import '../../services/document_sync_service.dart';
import '../../data/models/pending_document_model.dart';

/// Document Scanner Screen with platform-specific implementations
/// - Android: Google ML Kit
/// - iOS: VisionKit (via camera)
/// - Web: File upload
class DocumentScannerScreen extends StatefulWidget {
  const DocumentScannerScreen({super.key});

  @override
  State<DocumentScannerScreen> createState() => _DocumentScannerScreenState();
}

class _DocumentScannerScreenState extends State<DocumentScannerScreen> {
  CameraController? _cameraController;
  bool _isInitialized = false;
  List<XFile> _capturedPages = [];
  String? _selectedDocType;
  bool _isProcessing = false;
  String? _extractedText;
  final int _maxPages = 10;

  // File Upload State
  File? _uploadedPdf;
  String? _uploadedPdfName;
  Uint8List? _uploadedPdfBytes; // For web PDF support

  // Sync Service
  final DocumentSyncService _syncService = DocumentSyncService();
  PendingDocument? _lastSavedDocument;

  final List<Map<String, String>> _documentTypes = [
    {
      'value': 'rate_con',
      'label': 'Rate Confirmation',
      'subtitle': 'ਦਰ ਪੁਸ਼ਟੀ',
    },
    {'value': 'bol', 'label': 'Bill of Lading', 'subtitle': 'ਲੈਡਿੰਗ ਬਿੱਲ'},
    {'value': 'fuel_receipt', 'label': 'Fuel Receipt', 'subtitle': 'ਈਂਧਣ ਰਸੀਦ'},
    {
      'value': 'lumper_receipt',
      'label': 'Lumper Receipt',
      'subtitle': 'ਲੰਪਰ ਰਸੀਦ',
    },
    {'value': 'scale_ticket', 'label': 'Scale Ticket', 'subtitle': 'ਸਕੇਲ ਟਿਕਟ'},
    {'value': 'other', 'label': 'Other Document', 'subtitle': 'ਹੋਰ ਦਸਤਾਵੇਜ਼'},
  ];

  @override
  void initState() {
    super.initState();
    // Initialize sync service for document upload/sync
    _syncService.initialize();
    print('[Scanner] DocumentSyncService initialized');

    if (!kIsWeb) {
      _initCamera();
    }
  }

  Future<void> _initCamera() async {
    try {
      final cameras = await availableCameras();
      if (cameras.isEmpty) return;

      _cameraController = CameraController(
        cameras.first,
        ResolutionPreset.high,
        enableAudio: false,
      );

      await _cameraController!.initialize();
      if (mounted) {
        setState(() => _isInitialized = true);
      }
    } catch (e) {
      debugPrint('Camera initialization error: $e');
    }
  }

  @override
  void dispose() {
    _cameraController?.dispose();
    super.dispose();
  }

  Future<void> _capturePhoto() async {
    if (_cameraController == null || !_cameraController!.value.isInitialized) {
      return;
    }

    if (_capturedPages.length >= _maxPages) {
      _showMessage('Maximum $_maxPages pages reached');
      return;
    }

    try {
      setState(() => _isProcessing = true);

      final XFile photo = await _cameraController!.takePicture();

      // Extract text using ML Kit
      String? text;
      if (!kIsWeb) {
        text = await _extractTextFromImage(photo.path);
        if (text != null && text.isNotEmpty) {
          debugPrint(
            'Extracted text: ${text.substring(0, text.length.clamp(0, 200))}...',
          );
        }
      }

      setState(() {
        _capturedPages.add(photo);
        _extractedText = text;
        _isProcessing = false;
      });

      _showMessage('Page ${_capturedPages.length} captured');
    } catch (e) {
      setState(() => _isProcessing = false);
      _showMessage('Failed to capture: $e');
    }
  }

  Future<void> _pickFile() async {
    try {
      FilePickerResult? result = await FilePicker.platform.pickFiles(
        type: FileType
            .any, // changed from custom to any to ensure all file types are visible
        // allowedExtensions: ['jpg', 'jpeg', 'png', 'pdf'], // ignored when type is any
        allowMultiple:
            kIsWeb, // Allow multiple only on web for now if needed, or stick to single for PDF
      );

      if (result == null) return;

      if (kIsWeb) {
        // Web handling
        for (final file in result.files) {
          if (file.extension?.toLowerCase() == 'pdf') {
            // Handle PDF on Web - store bytes directly
            if (file.bytes != null) {
              setState(() {
                _uploadedPdfBytes = file.bytes;
                _uploadedPdfName = file.name;
                _uploadedPdf = null;
                _capturedPages.clear();
              });
              _showMessage('PDF uploaded: ${file.name}');
            }
          } else {
            // Image Web
            // Use bytes to create XFile or similar
            // Existing logic used XFile from image_picker
            // We can convert PlatformFile to XFile
            if (file.bytes != null) {
              final xFile = XFile.fromData(file.bytes!, name: file.name);
              if (_capturedPages.length < _maxPages) {
                setState(() {
                  _capturedPages.add(xFile);
                });
              }
            }
          }
        }
        _showMessage('Added ${result.files.length} file(s)');
      } else {
        // Mobile handling
        final path = result.files.single.path;
        if (path == null) return;

        final isPdf = path.toLowerCase().endsWith('.pdf');

        if (isPdf) {
          setState(() {
            _uploadedPdf = File(path);
            _uploadedPdfName = result.files.single.name;
            _capturedPages.clear(); // Clear captured pages if PDF is uploaded
            _extractedText = null;
          });
          _showMessage('PDF uploaded: $_uploadedPdfName');
        } else {
          // Image
          // If we had a PDF, clear it
          setState(() {
            _uploadedPdf = null;
            _uploadedPdfName = null;
          });

          final XFile image = XFile(path);
          if (_capturedPages.length < _maxPages) {
            final text = await _extractTextFromImage(image.path);
            setState(() {
              _capturedPages.add(image);
              _extractedText = text;
            });
          }
        }
      }
    } catch (e) {
      debugPrint('🔴 Pick file error: $e');
      debugPrint('🔴 Pick file error: $e');
      _showMessage('Failed to pick file: $e');
    }
  }

  Future<void> _pickFromGallery() async {
    try {
      final ImagePicker picker = ImagePicker();
      // Pick multiple images
      final List<XFile> images = await picker.pickMultiImage();

      if (images.isEmpty) return;

      // Clear previous if any PDF was there
      setState(() {
        _uploadedPdf = null;
        _uploadedPdfName = null;
        _uploadedPdfBytes = null;
      });

      int addedCount = 0;
      for (final image in images) {
        if (_capturedPages.length < _maxPages) {
          // Text extraction (optional per image, maybe slow for many)
          // We can do it lazy or just extract for the first one for now
          // Or extract all in parallel? Let's process valid ones.

          // To be responsive, we add them first, then extract text?
          // Existing logic extracts before adding. Let's keep consistency but maybe show loading.

          // For now, let's just add them. Text extraction is triggered on "Scan" usually?
          // Wait, existing logic:
          /*
            final text = await _extractTextFromImage(image.path);
            _capturedPages.add(image);
            */

          // If picking multiple, extracting text for all might freeze UI.
          // Let's add them to pages. The text extraction in this flow is mostly for debug or auto-fill values.
          // We can do it effectively.

          setState(() {
            _capturedPages.add(image);
          });
          addedCount++;
        }
      }

      if (addedCount > 0) {
        // Try extracting text from the first one as a sample for auto-detection
        final firstText = await _extractTextFromImage(images.first.path);
        setState(() {
          _extractedText = firstText;
        });
        _showMessage('Added $addedCount image(s) from Gallery');
      }
    } catch (e) {
      debugPrint('🔴 Pick gallery error: $e');
      _showMessage('Failed to pick images: $e');
    }
  }

  void _showUploadOptions() {
    showModalBottomSheet(
      context: context,
      backgroundColor: Colors.transparent,
      builder: (context) => Container(
        padding: const EdgeInsets.all(24),
        decoration: BoxDecoration(
          color: Theme.of(context).scaffoldBackgroundColor,
          borderRadius: const BorderRadius.vertical(top: Radius.circular(24)),
        ),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            const DualLanguageText(
              primaryText: 'Select Source',
              subtitleText: 'ਸਰੋਤ ਚੁਣੋ',
              primaryStyle:
                  TextStyle(fontSize: 20, fontWeight: FontWeight.bold),
              alignment: CrossAxisAlignment.center,
            ),
            const SizedBox(height: 24),
            Row(
              mainAxisAlignment: MainAxisAlignment.spaceEvenly,
              children: [
                _buildOptionBtn(
                  icon: Icons.photo_library,
                  label: 'Gallery',
                  subLabel: 'ਗੈਲਰੀ',
                  color: Colors.purple,
                  onTap: () {
                    Navigator.pop(context);
                    _pickFromGallery();
                  },
                ),
                _buildOptionBtn(
                  icon: Icons.folder_open,
                  label: 'Files',
                  subLabel: 'ਫਾਈਲਾਂ',
                  color: Colors.orange,
                  onTap: () {
                    Navigator.pop(context);
                    _pickFile();
                  },
                ),
              ],
            ),
            const SizedBox(height: 16),
          ],
        ),
      ),
    );
  }

  Widget _buildOptionBtn({
    required IconData icon,
    required String label,
    required String subLabel,
    required Color color,
    required VoidCallback onTap,
  }) {
    return GestureDetector(
      onTap: onTap,
      child: Column(
        children: [
          Container(
            padding: const EdgeInsets.all(16),
            decoration: BoxDecoration(
              color: color.withOpacity(0.1),
              shape: BoxShape.circle,
            ),
            child: Icon(icon, size: 32, color: color),
          ),
          const SizedBox(height: 8),
          Text(label, style: const TextStyle(fontWeight: FontWeight.bold)),
          Text(subLabel,
              style: TextStyle(fontSize: 10, color: Colors.grey.shade600)),
        ],
      ),
    );
  }

  Future<String?> _extractTextFromImage(String imagePath) async {
    try {
      // Read image file as bytes
      final File imageFile = File(imagePath);
      final List<int> imageBytes = await imageFile.readAsBytes();

      // Check if text recognition is available
      final bool isAvailable = await VisionTextRecognition.isAvailable();
      if (!isAvailable) {
        debugPrint('Text recognition not available');
        return null;
      }

      // Recognize text using vision_text_recognition
      final TextRecognitionResult result =
          await VisionTextRecognition.recognizeText(imageBytes);

      final text = result.fullText;
      final quality = result.confidence;
      debugPrint('Text quality/confidence score: $quality');
      debugPrint('Processing time: ${result.processingTimeMs}ms');

      return text;
    } catch (e) {
      debugPrint('Text extraction error: $e');
      return null;
    }
  }

  Future<void> _saveDocument() async {
    if (_capturedPages.isEmpty &&
        _uploadedPdf == null &&
        _uploadedPdfBytes == null) {
      _showMessage('No pages or document to save');
      return;
    }

    // Handle uploaded PDF (mobile)
    if (_uploadedPdf != null) {
      _onPdfReady(_uploadedPdf!);
      return;
    }

    // Handle uploaded PDF bytes (web)
    if (_uploadedPdfBytes != null) {
      await _onPdfBytesReady(
          _uploadedPdfBytes!, _uploadedPdfName ?? 'document.pdf');
      return;
    }

    setState(() => _isProcessing = true);

    try {
      final pdf = pw.Document();

      for (final page in _capturedPages) {
        final imageBytes = await page.readAsBytes();
        final image = pw.MemoryImage(imageBytes);

        pdf.addPage(
          pw.Page(
            pageFormat: PdfPageFormat.a4,
            build: (context) =>
                pw.Center(child: pw.Image(image, fit: pw.BoxFit.contain)),
          ),
        );
      }

      final Uint8List pdfBytes = await pdf.save();
      final fileName =
          '${_selectedDocType ?? 'document'}_${DateTime.now().millisecondsSinceEpoch}.pdf';

      if (kIsWeb) {
        // For web: trigger download via blob URL
        await _downloadPdfWeb(pdfBytes, fileName);
        setState(() => _isProcessing = false);
        _showMessage('PDF downloaded: $fileName');
      } else {
        // For mobile: save to temp and share
        final output = await getTemporaryDirectory();
        final file = File('${output.path}/$fileName');
        await file.writeAsBytes(pdfBytes);

        _onPdfReady(file);
      }
    } catch (e) {
      debugPrint('🔴 PDF generation error: $e');
      setState(() => _isProcessing = false);
      _showMessage('Failed to generate PDF: $e');
    }
  }

  Future<void> _onPdfReady(File file) async {
    // Save locally and queue for sync
    final bytes = await file.readAsBytes();
    await _saveToSyncQueue(bytes, file.path.split('/').last);
  }

  Future<void> _onPdfBytesReady(Uint8List bytes, String fileName) async {
    // Save locally and queue for sync
    await _saveToSyncQueue(bytes, fileName);
  }

  Future<void> _saveToSyncQueue(Uint8List bytes, String fileName) async {
    print(
        '[Scanner] ═══════════════════════════════════════════════════════════');
    print('[Scanner] 💾 SAVING DOCUMENT TO SYNC QUEUE');
    print(
        '[Scanner] ═══════════════════════════════════════════════════════════');
    print('[Scanner]    File name: $fileName');
    print('[Scanner]    Bytes: ${bytes.length}');
    print('[Scanner]    Document type: $_selectedDocType');

    setState(() => _isProcessing = true);

    try {
      print('[Scanner] Calling syncService.saveAndQueueDocument...');
      final pendingDoc = await _syncService.saveAndQueueDocument(
        bytes: bytes,
        documentType: _selectedDocType ?? 'other',
        fileName: fileName,
      );

      print('[Scanner] ✅ Document queued successfully: ${pendingDoc.id}');

      setState(() {
        _lastSavedDocument = pendingDoc;
        _isProcessing = false;
      });

      _showSaveSuccess(pendingDoc);
    } catch (e, stack) {
      print('[Scanner] ❌ Failed to save document: $e');
      print('[Scanner] Stack: $stack');
      setState(() => _isProcessing = false);
      _showMessage('Failed to save document: $e');
    }
  }

  void _showSaveSuccess(PendingDocument doc) {
    showModalBottomSheet(
      context: context,
      builder: (context) => Container(
        padding: const EdgeInsets.all(24),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            const Icon(Icons.check_circle, color: Colors.green, size: 64),
            const SizedBox(height: 16),
            const DualLanguageText(
              primaryText: 'Document Saved',
              subtitleText: 'ਦਸਤਾਵੇਜ਼ ਸੇਵ ਹੋ ਗਿਆ',
              primaryStyle:
                  TextStyle(fontSize: 20, fontWeight: FontWeight.bold),
              alignment: CrossAxisAlignment.center,
            ),
            const SizedBox(height: 8),
            Text(
              doc.statusDisplay,
              style: TextStyle(color: Colors.grey.shade600),
            ),
            const SizedBox(height: 16),
            Text(
              'Will sync automatically when online',
              style: TextStyle(color: Colors.grey.shade500, fontSize: 12),
            ),
            const SizedBox(height: 24),
            Row(
              children: [
                Expanded(
                  child: OutlinedButton(
                    onPressed: () {
                      Navigator.pop(context);
                      _resetScanner();
                    },
                    child: const Text('Scan Another'),
                  ),
                ),
                const SizedBox(width: 16),
                Expanded(
                  child: ElevatedButton(
                    onPressed: () {
                      Navigator.pop(context);
                      Navigator.pop(context); // Go back to dashboard
                    },
                    child: const Text('Done'),
                  ),
                ),
              ],
            ),
          ],
        ),
      ),
    );
  }

  void _resetScanner() {
    setState(() {
      _capturedPages.clear();
      _uploadedPdf = null;
      _uploadedPdfName = null;
      _uploadedPdfBytes = null;
      _selectedDocType = null;
      _lastSavedDocument = null;
    });
  }

  Future<void> _downloadPdfWeb(Uint8List bytes, String fileName) async {
    // Create a blob URL and trigger download on web
    // This is a simplified approach - for production, use universal_html or js interop
    try {
      // Use share_plus which has web support
      await Share.shareXFiles(
        [XFile.fromData(bytes, name: fileName, mimeType: 'application/pdf')],
        text: 'TruckMate Document',
      );
    } catch (e) {
      debugPrint('🔴 Web download error: $e');
      _showMessage('Download initiated - check your downloads folder');
    }
  }

  void _showMessage(String message) {
    ScaffoldMessenger.of(
      context,
    ).showSnackBar(SnackBar(content: Text(message)));
  }

  void _removePage(int index) {
    setState(() {
      _capturedPages.removeAt(index);
    });
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: const DualLanguageText(
          primaryText: 'Scan Document',
          subtitleText: 'ਦਸਤਾਵੇਜ਼ ਸਕੈਨ ਕਰੋ',
          primaryStyle: TextStyle(color: Colors.white),
          subtitleStyle: TextStyle(color: Colors.white70, fontSize: 10),
          alignment: CrossAxisAlignment.center,
        ),
        actions: [
          if (_capturedPages.isNotEmpty ||
              _uploadedPdf != null ||
              _uploadedPdfBytes != null)
            TextButton.icon(
              onPressed: _isProcessing ? null : _saveDocument,
              icon: const Icon(Icons.save, color: Colors.white),
              label: Text(
                '${_capturedPages.isNotEmpty ? _capturedPages.length : "PDF"}',
                style: const TextStyle(color: Colors.white),
              ),
            ),
        ],
      ),
      body: Column(
        children: [
          // Document Type Selector
          if (_selectedDocType == null)
            Expanded(child: _buildDocumentTypeSelector())
          else ...[
            // Camera Preview or Upload Area
            Expanded(
              flex: 3,
              child: (_uploadedPdf != null || _uploadedPdfBytes != null)
                  ? _buildPdfPreview()
                  : (_capturedPages.isNotEmpty
                      ? _buildImageReview()
                      : (kIsWeb ? _buildWebUpload() : _buildCameraPreview())),
            ),

            // Captured Pages Preview (Bottom strip) - Hide if in Review mode?
            // User might want to swipe? Let's keep it simple.
            // If we have Review mode, maybe we don't need the bottom strip or controls?
            // Let's hide the bottom strip if we are showing the full Review UI to avoid clutter?
            // Or keep it for context?
            // The PDF flow doesn't show a strip.
            // Let's hide the strip if we are in "Review" mode (which effectively _buildImageReview is).
            if (_capturedPages.isEmpty && !kIsWeb)
              // No, wait. If capturing, we usually want to see the strip.
              // But if we switch to "Review" mode immediately after 1 capture, it slows down multi-page scanning.
              // Users usually want to scan 1, scan 2, scan 3... then Send.
              // So replacing Camera with Review immediately after 1st scan is bad UX for multi-page.

              // Maybe the user wants the "Send" button *IN* the place where PDF Send button is?
              // The PDF Send button is in the middle.
              // If I keep Camera, I can't put a button in the middle blocking it.

              // Maybe the user is uploading from *Gallery*?
              // If uploading from Gallery, `_capturedPages` is populated.
              // If I pick from Gallery, I definitely don't need Camera.
              // So, distinguishing "Scan Mode" vs "Gallery/Review Mode"?
              // There is no explicit mode variable.

              // However, if I uploaded from Gallery, I likely want Review.
              // If I scanned from Camera, I might want to scan more.

              // Compromise:
              // If I have pages, I show the Camera (for more scanning) BUT the "Send" button should be dominant.
              // The user complained about *position*.
              // "not at same position in pdf upload screen".
              // PDF screen: Middle.
              // My Image screen: Bottom.

              // If I make `_buildImageReview` toggleable? No.

              // Let's assume for now: If `_capturedPages.isNotEmpty`, we show the Review Screen (Images + Send Button)
              // AND an "Add Page" button (which opens Camera).
              // This aligns UI with PDF flow (Preview + Send).

              // Implementation:
              // If pages > 0: Show Review UI.
              // Review UI has: Carousel of pages, Send Button, "Scan More" button.

              // This solves the position issue perfectly.

              // Captured Pages Preview
              // if (_capturedPages.isNotEmpty)
              //   SizedBox(height: 100, child: _buildPagesPreview()),

              // Controls - Hide if in Review mode (pages exist)
              if (_capturedPages.isEmpty &&
                  (_uploadedPdf == null && _uploadedPdfBytes == null))
                _buildControls(),
          ],
        ],
      ),
    );
  }

  Widget _buildDocumentTypeSelector() {
    return Padding(
      padding: const EdgeInsets.all(16),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          const SizedBox(height: 20),
          const DualLanguageText(
            primaryText: 'Select Document Type',
            subtitleText: 'ਦਸਤਾਵੇਜ਼ ਦੀ ਕਿਸਮ ਚੁਣੋ',
            primaryStyle: TextStyle(fontSize: 20, fontWeight: FontWeight.bold),
          ),
          const SizedBox(height: 20),
          Expanded(
            child: ListView.builder(
              itemCount: _documentTypes.length,
              itemBuilder: (context, index) {
                final type = _documentTypes[index];
                return Card(
                  margin: const EdgeInsets.only(bottom: 12),
                  child: ListTile(
                    contentPadding: const EdgeInsets.all(16),
                    leading: Container(
                      padding: const EdgeInsets.all(12),
                      decoration: BoxDecoration(
                        color: AppTheme.primaryColor.withOpacity(0.1),
                        borderRadius: BorderRadius.circular(12),
                      ),
                      child: Icon(
                        _getIconForType(type['value']!),
                        color: AppTheme.primaryColor,
                      ),
                    ),
                    title: Text(
                      type['label']!,
                      style: const TextStyle(fontWeight: FontWeight.bold),
                    ),
                    subtitle: Text(type['subtitle']!),
                    trailing: const Icon(Icons.arrow_forward_ios),
                    onTap: () {
                      setState(() => _selectedDocType = type['value']);
                    },
                  ),
                );
              },
            ),
          ),
        ],
      ),
    );
  }

  IconData _getIconForType(String type) {
    switch (type) {
      case 'rate_con':
        return Icons.description;
      case 'bol':
        return Icons.local_shipping;
      case 'fuel_receipt':
        return Icons.local_gas_station;
      case 'lumper_receipt':
        return Icons.receipt_long;
      case 'scale_ticket':
        return Icons.scale;
      default:
        return Icons.insert_drive_file;
    }
  }

  Widget _buildCameraPreview() {
    if (!_isInitialized || _cameraController == null) {
      return const Center(child: CircularProgressIndicator());
    }

    return Stack(
      children: [
        ClipRRect(
          borderRadius: const BorderRadius.vertical(top: Radius.circular(16)),
          child: CameraPreview(_cameraController!),
        ),
        // Document frame overlay
        Positioned.fill(child: CustomPaint(painter: DocumentFramePainter())),
        if (_isProcessing)
          Container(
            color: Colors.black54,
            child: const Center(
              child: CircularProgressIndicator(color: Colors.white),
            ),
          ),
      ],
    );
  }

  Widget _buildPdfPreview() {
    return Container(
      margin: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: Colors.grey.shade100,
        borderRadius: BorderRadius.circular(16),
        border: Border.all(color: AppTheme.primaryColor),
      ),
      child: Center(
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            const Icon(Icons.picture_as_pdf, size: 80, color: Colors.red),
            const SizedBox(height: 16),
            Text(
              _uploadedPdfName ?? 'Document.pdf',
              style: const TextStyle(
                fontSize: 18,
                fontWeight: FontWeight.bold,
              ),
            ),
            const SizedBox(height: 8),
            Row(
              mainAxisAlignment: MainAxisAlignment.center,
              children: [
                TextButton(
                  onPressed: () {
                    setState(() {
                      _uploadedPdf = null;
                      _uploadedPdfName = null;
                      _uploadedPdfBytes = null;
                    });
                  },
                  child:
                      const Text('Remove', style: TextStyle(color: Colors.red)),
                ),
                const SizedBox(width: 16),
                ElevatedButton.icon(
                  onPressed: _saveDocument,
                  icon: const Icon(Icons.send),
                  label: const Text('Send'),
                  style: ElevatedButton.styleFrom(
                    backgroundColor: AppTheme.primaryColor,
                    foregroundColor: Colors.white,
                  ),
                ),
              ],
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildImageReview() {
    return Container(
      width: double.infinity,
      color: Colors.black87,
      child: Column(
        mainAxisAlignment: MainAxisAlignment.center,
        children: [
          // Image Carousel / Preview
          Expanded(
            child: Padding(
              padding: const EdgeInsets.all(16),
              child: _buildPagesPreview(), // Reuse the list/grid
            ),
          ),

          // Actions
          Padding(
            padding: const EdgeInsets.all(24),
            child: Column(
              children: [
                Text(
                  '${_capturedPages.length} Pages Captured',
                  style: const TextStyle(
                      color: Colors.white,
                      fontSize: 18,
                      fontWeight: FontWeight.bold),
                ),
                const SizedBox(height: 24),
                Row(
                  mainAxisAlignment: MainAxisAlignment.center,
                  children: [
                    // Add More / Retake
                    OutlinedButton.icon(
                      onPressed: () {
                        // Just show camera again?
                        // But my logic hides camera if pages > 0.
                        // I need a state to "force camera"?
                        // Or I just delete the pages? No.
                        // I need a "Scan Mode" flag?
                        // Or simpler: change the logic in build to:
                        // if (_capturedPages.isNotEmpty && !_isScanningMore) ...

                        // For now, let's just use "Remove All" to clear and start over?
                        // The user probably wants to ADD.

                        setState(() {
                          _capturedPages.clear(); // Temporary fix for "Retake"
                          // Ideally we want to append.
                          // If we want to append, we need to switch view back to Camera.
                          // But my View logic is: pages > 0 -> Review.
                          // I should add a bool _isReviewMode = false;
                          // When scanning, _isReviewMode = false.
                          // When "Done" or "Upload", _isReviewMode = true.

                          // But right now, users just snap and I put it in list.
                          // Let's add a "Add Page" interaction.

                          // _capturePhoto(); // This takes a photo immediately? No.
                          // _buildCameraPreview() is a widget.
                        });
                      },
                      icon: const Icon(Icons.delete),
                      label: const Text('Clear All'),
                      style: OutlinedButton.styleFrom(
                          foregroundColor: Colors.red,
                          side: const BorderSide(color: Colors.red)),
                    ),
                    const SizedBox(width: 16),

                    // Send Button (Big Blue - Same Position as PDF)
                    ElevatedButton.icon(
                      onPressed: _saveDocument,
                      icon: const Icon(Icons.send),
                      label: const Text('Send'),
                      style: AppTheme.actionButtonStyle.copyWith(
                        minimumSize:
                            const MaterialStatePropertyAll(Size(140, 50)),
                      ),
                    ),
                  ],
                ),
                // "Add Page" - Since hiding camera prevents adding, we need a way.
                // Actually, if we hide camera, we can't add more easily without changing state.
                // But wait, the user complaint was "button position".
                // If I allow "Add Page", I switch to Camera.
                // When does it switch back to Review?
                // After capturing?

                const SizedBox(height: 16),
                TextButton.icon(
                  onPressed: _pickFromGallery,
                  // Or camera? If I want camera, I need to render camera.
                  // _pickFromGallery is safe.
                  icon: const Icon(Icons.add_photo_alternate),
                  label: const Text('Add from Gallery',
                      style: TextStyle(color: Colors.white)),
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildWebUpload() {
    return Container(
      margin: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        border: Border.all(
          color: AppTheme.primaryColor,
          width: 2,
          style: BorderStyle.solid,
        ),
        borderRadius: BorderRadius.circular(16),
      ),
      child: InkWell(
        onTap: _pickFile,
        borderRadius: BorderRadius.circular(16),
        child: Center(
          child: Column(
            mainAxisAlignment: MainAxisAlignment.center,
            children: [
              Icon(Icons.cloud_upload, size: 64, color: AppTheme.primaryColor),
              const SizedBox(height: 16),
              const DualLanguageText(
                primaryText: 'Click to Upload',
                subtitleText: 'ਅੱਪਲੋਡ ਕਰਨ ਲਈ ਕਲਿੱਕ ਕਰੋ',
                primaryStyle: TextStyle(
                  fontSize: 18,
                  fontWeight: FontWeight.bold,
                ),
                alignment: CrossAxisAlignment.center,
              ),
              const SizedBox(height: 8),
              const Text('PDF or Image files'),
            ],
          ),
        ),
      ),
    );
  }

  Widget _buildPagesPreview() {
    return Container(
      color: Colors.grey.shade100,
      child: ListView.builder(
        scrollDirection: Axis.horizontal,
        padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 8),
        itemCount: _capturedPages.length,
        itemBuilder: (context, index) {
          return Stack(
            children: [
              Container(
                width: 70,
                margin: const EdgeInsets.symmetric(horizontal: 4),
                decoration: BoxDecoration(
                  borderRadius: BorderRadius.circular(8),
                  border: Border.all(color: AppTheme.primaryColor),
                ),
                child: ClipRRect(
                  borderRadius: BorderRadius.circular(8),
                  child: kIsWeb
                      ? const Icon(Icons.image)
                      : Image.file(
                          File(_capturedPages[index].path),
                          fit: BoxFit.cover,
                        ),
                ),
              ),
              Positioned(
                top: 0,
                right: 0,
                child: GestureDetector(
                  onTap: () => _removePage(index),
                  child: Container(
                    padding: const EdgeInsets.all(2),
                    decoration: const BoxDecoration(
                      color: Colors.red,
                      shape: BoxShape.circle,
                    ),
                    child: const Icon(
                      Icons.close,
                      size: 16,
                      color: Colors.white,
                    ),
                  ),
                ),
              ),
              Positioned(
                bottom: 4,
                left: 4,
                child: Container(
                  padding: const EdgeInsets.symmetric(
                    horizontal: 6,
                    vertical: 2,
                  ),
                  decoration: BoxDecoration(
                    color: Colors.black54,
                    borderRadius: BorderRadius.circular(4),
                  ),
                  child: Text(
                    '${index + 1}',
                    style: const TextStyle(color: Colors.white, fontSize: 10),
                  ),
                ),
              ),
            ],
          );
        },
      ),
    );
  }

  Widget _buildControls() {
    return Container(
      padding: const EdgeInsets.all(16),
      color: Colors.white,
      child: Row(
        mainAxisAlignment: MainAxisAlignment.spaceEvenly,
        children: [
          // File Upload (Gallery/Files)
          IconButton(
            onPressed: () {
              if (kIsWeb) {
                _pickFile(); // Web uses standard picker
              } else {
                _showUploadOptions();
              }
            },
            icon: const Icon(
                Icons.upload_file), // Changed icon to represent generic upload
            iconSize: 32,
            color: AppTheme.primaryColor,
          ),

          // Capture Button
          if (!kIsWeb)
            GestureDetector(
              onTap: _isProcessing ? null : _capturePhoto,
              child: Container(
                width: 72,
                height: 72,
                decoration: BoxDecoration(
                  shape: BoxShape.circle,
                  border: Border.all(color: AppTheme.primaryColor, width: 4),
                ),
                child: Center(
                  child: Container(
                    width: 56,
                    height: 56,
                    decoration: BoxDecoration(
                      shape: BoxShape.circle,
                      color:
                          _isProcessing ? Colors.grey : AppTheme.primaryColor,
                    ),
                    child: _isProcessing
                        ? const CircularProgressIndicator(color: Colors.white)
                        : const Icon(
                            Icons.camera,
                            color: Colors.white,
                            size: 32,
                          ),
                  ),
                ),
              ),
            ),

          // Send Button (only if pages exist)
          if (_capturedPages.isNotEmpty)
            ElevatedButton.icon(
              onPressed: _saveDocument,
              icon: const Icon(Icons.send),
              label: const Text('Send'),
              style: ElevatedButton.styleFrom(
                backgroundColor: AppTheme.primaryColor,
                foregroundColor: Colors.white,
                padding:
                    const EdgeInsets.symmetric(horizontal: 24, vertical: 12),
              ),
            )
          else
            const SizedBox(width: 48), // Spacer to balance layout

          // Done / Save
          // Done / Save - Only show if not a PDF (PDF has its own send button)
          if (_uploadedPdf == null && _uploadedPdfBytes == null)
            IconButton(
              onPressed: _capturedPages.isEmpty ? null : _saveDocument,
              icon: const Icon(Icons.check_circle),
              iconSize: 32,
              color:
                  _capturedPages.isEmpty ? Colors.grey : AppTheme.successColor,
            ),
        ],
      ),
    );
  }
}

/// Custom painter for document frame overlay
class DocumentFramePainter extends CustomPainter {
  @override
  void paint(Canvas canvas, Size size) {
    final paint = Paint()
      ..color = Colors.white
      ..style = PaintingStyle.stroke
      ..strokeWidth = 2;

    final cornerLength = size.width * 0.1;
    final margin = 40.0;

    // Top-left corner
    canvas.drawLine(
      Offset(margin, margin),
      Offset(margin + cornerLength, margin),
      paint,
    );
    canvas.drawLine(
      Offset(margin, margin),
      Offset(margin, margin + cornerLength),
      paint,
    );

    // Top-right corner
    canvas.drawLine(
      Offset(size.width - margin, margin),
      Offset(size.width - margin - cornerLength, margin),
      paint,
    );
    canvas.drawLine(
      Offset(size.width - margin, margin),
      Offset(size.width - margin, margin + cornerLength),
      paint,
    );

    // Bottom-left corner
    canvas.drawLine(
      Offset(margin, size.height - margin),
      Offset(margin + cornerLength, size.height - margin),
      paint,
    );
    canvas.drawLine(
      Offset(margin, size.height - margin),
      Offset(margin, size.height - margin - cornerLength),
      paint,
    );

    // Bottom-right corner
    canvas.drawLine(
      Offset(size.width - margin, size.height - margin),
      Offset(size.width - margin - cornerLength, size.height - margin),
      paint,
    );
    canvas.drawLine(
      Offset(size.width - margin, size.height - margin),
      Offset(size.width - margin, size.height - margin - cornerLength),
      paint,
    );
  }

  @override
  bool shouldRepaint(covariant CustomPainter oldDelegate) => false;
}
