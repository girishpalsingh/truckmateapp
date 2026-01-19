import 'dart:io';
import 'dart:typed_data';
import 'package:flutter/foundation.dart' show kIsWeb;
import 'package:flutter/material.dart';
import 'package:camera/camera.dart';
import 'package:vision_text_recognition/vision_text_recognition.dart';
import 'package:image_picker/image_picker.dart';
import 'package:pdf/pdf.dart';
import 'package:pdf/widgets.dart' as pw;
import 'package:share_plus/share_plus.dart';
import 'package:path_provider/path_provider.dart';
import '../themes/app_theme.dart';

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

  Future<void> _pickFromGallery() async {
    try {
      final picker = ImagePicker();
      // Use pickMultiImage for web to allow multiple file selection
      if (kIsWeb) {
        final List<XFile> images = await picker.pickMultiImage();
        if (images.isNotEmpty && _capturedPages.length < _maxPages) {
          setState(() {
            for (final img in images) {
              if (_capturedPages.length < _maxPages) {
                _capturedPages.add(img);
              }
            }
          });
          _showMessage('Added ${images.length} file(s)');
        }
      } else {
        final XFile? image =
            await picker.pickImage(source: ImageSource.gallery);
        if (image != null && _capturedPages.length < _maxPages) {
          final text = await _extractTextFromImage(image.path);
          setState(() {
            _capturedPages.add(image);
            _extractedText = text;
          });
        }
      }
    } catch (e) {
      debugPrint('🔴 Pick from gallery error: $e');
      _showMessage('Failed to pick file: $e');
    }
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

  Future<void> _generatePDF() async {
    if (_capturedPages.isEmpty) {
      _showMessage('No pages to save');
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

        setState(() => _isProcessing = false);

        await Share.shareXFiles([
          XFile(file.path),
        ], text: 'TruckMate Document: $_selectedDocType');
      }
    } catch (e) {
      debugPrint('🔴 PDF generation error: $e');
      setState(() => _isProcessing = false);
      _showMessage('Failed to generate PDF: $e');
    }
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
          if (_capturedPages.isNotEmpty)
            TextButton.icon(
              onPressed: _isProcessing ? null : _generatePDF,
              icon: const Icon(Icons.save, color: Colors.white),
              label: Text(
                '${_capturedPages.length}',
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
              child: kIsWeb ? _buildWebUpload() : _buildCameraPreview(),
            ),

            // Captured Pages Preview
            if (_capturedPages.isNotEmpty)
              SizedBox(height: 100, child: _buildPagesPreview()),

            // Controls
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
        onTap: _pickFromGallery,
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
          // Gallery
          IconButton(
            onPressed: _pickFromGallery,
            icon: const Icon(Icons.photo_library),
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
                            size: 28,
                          ),
                  ),
                ),
              ),
            ),

          // Done / Save
          IconButton(
            onPressed: _capturedPages.isEmpty ? null : _generatePDF,
            icon: const Icon(Icons.check_circle),
            iconSize: 32,
            color: _capturedPages.isEmpty ? Colors.grey : AppTheme.successColor,
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
