import 'dart:io';
import 'dart:typed_data';
import 'dart:ui' as ui;
import 'package:flutter/material.dart';
import 'package:geolocator/geolocator.dart';
import 'package:image_picker/image_picker.dart';
import '../../services/detention_service.dart';
import '../../data/models/detention_record.dart';
import '../../core/utils/app_logger.dart';

class DetentionEntryScreen extends StatefulWidget {
  final String loadId; // loadId
  final String?
      stopId; // stopId (nullable if just load level, but schema likes stop_id)
  final String organizationId;
  final String facilityAddress;

  const DetentionEntryScreen({
    super.key,
    required this.loadId,
    required this.organizationId,
    this.stopId,
    required this.facilityAddress,
  });

  @override
  State<DetentionEntryScreen> createState() => _DetentionEntryScreenState();
}

class _DetentionEntryScreenState extends State<DetentionEntryScreen> {
  final DetentionService _detentionService = DetentionService();
  final ImagePicker _picker = ImagePicker();

  bool _isLoading = false;
  Position? _currentPosition;
  String? _locationError;
  XFile? _photoFile;
  Uint8List? _mockPhotoBytes; // For simulator testing

  // Existing detention check
  DetentionRecord? _existingDetention;
  bool _checkingExisting = true;

  @override
  void initState() {
    super.initState();
    _checkExistingDetention();
    _fetchLocation();
    _generateMockPhoto(); // Auto-generate mock photo for simulator
  }

  /// Check if detention already exists for this stop
  Future<void> _checkExistingDetention() async {
    if (widget.stopId == null) {
      setState(() => _checkingExisting = false);
      return;
    }

    try {
      final existing =
          await _detentionService.getExistingDetentionForStop(widget.stopId!);
      if (mounted) {
        setState(() {
          _existingDetention = existing;
          _checkingExisting = false;
        });
      }
    } catch (e) {
      AppLogger.e('Error checking existing detention', e);
      if (mounted) {
        setState(() => _checkingExisting = false);
      }
    }
  }

  /// Delete existing detention to allow starting a new one
  Future<void> _deleteExistingDetention() async {
    if (_existingDetention == null) return;

    final confirmed = await showDialog<bool>(
      context: context,
      builder: (context) => AlertDialog(
        title: const Text('Delete Existing Detention?'),
        content: Text(
          'A detention record already exists for this stop '
          '(started ${_formatDateTime(_existingDetention!.startTime)}). '
          'Delete it to start a new one?',
        ),
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
      setState(() => _isLoading = true);
      try {
        await _detentionService.deleteDetention(_existingDetention!.id);
        if (mounted) {
          setState(() {
            _existingDetention = null;
            _isLoading = false;
          });
          ScaffoldMessenger.of(context).showSnackBar(
            const SnackBar(content: Text('Previous detention deleted')),
          );
        }
      } catch (e) {
        AppLogger.e('Error deleting detention', e);
        if (mounted) {
          setState(() => _isLoading = false);
          ScaffoldMessenger.of(context).showSnackBar(
            SnackBar(content: Text('Error deleting: $e')),
          );
        }
      }
    }
  }

  String _formatDateTime(DateTime dt) {
    return '${dt.month}/${dt.day} ${dt.hour}:${dt.minute.toString().padLeft(2, '0')}';
  }

  /// Generate a simple mock photo for simulator testing
  Future<void> _generateMockPhoto() async {
    try {
      // Create a simple colored image programmatically using Canvas
      final recorder = ui.PictureRecorder();
      final canvas = Canvas(recorder);
      final paint = Paint()..color = Colors.blueGrey;

      // Draw background
      canvas.drawRect(const Rect.fromLTWH(0, 0, 400, 300), paint);

      // Draw "MOCK" text indicator
      final textPainter = TextPainter(
        text: const TextSpan(
          text: 'MOCK DETENTION PHOTO',
          style: TextStyle(
            color: Colors.white,
            fontSize: 24,
            fontWeight: FontWeight.bold,
          ),
        ),
        textDirection: TextDirection.ltr,
      );
      textPainter.layout();
      textPainter.paint(canvas, const Offset(60, 130));

      // Convert to image bytes
      final picture = recorder.endRecording();
      final img = await picture.toImage(400, 300);
      final byteData = await img.toByteData(format: ui.ImageByteFormat.png);

      if (byteData != null) {
        setState(() {
          _mockPhotoBytes = byteData.buffer.asUint8List();
        });
        AppLogger.d('Mock photo generated for simulator testing');
      }
    } catch (e) {
      AppLogger.e('Failed to generate mock photo', e);
    }
  }

  Future<void> _fetchLocation() async {
    setState(() => _isLoading = true);
    try {
      bool serviceEnabled = await Geolocator.isLocationServiceEnabled();
      if (!serviceEnabled) {
        throw Exception('Location services are disabled.');
      }

      LocationPermission permission = await Geolocator.checkPermission();
      if (permission == LocationPermission.denied) {
        permission = await Geolocator.requestPermission();
        if (permission == LocationPermission.denied) {
          throw Exception('Location permissions are denied');
        }
      }

      if (permission == LocationPermission.deniedForever) {
        throw Exception(
            'Location permissions are permanently denied, we cannot request permissions.');
      }

      final pos = await Geolocator.getCurrentPosition();
      setState(() {
        _currentPosition = pos;
        _locationError = null;
        _isLoading = false;
      });
    } catch (e) {
      setState(() {
        _locationError = e.toString();
        _isLoading = false;
      });
    }
  }

  Future<void> _pickImage(ImageSource source) async {
    try {
      final XFile? photo = await _picker.pickImage(
        source: source,
        imageQuality: 50, // Optimize size
      );
      if (photo != null) {
        setState(() {
          _photoFile = photo;
        });
      }
    } catch (e) {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text('Error picking image: $e')),
      );
    }
  }

  Future<void> _submit() async {
    // Only location is required for testing on simulator
    if (_currentPosition == null) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
            content: Text('Please wait for location to be captured')),
      );
      return;
    }

    setState(() => _isLoading = true);
    try {
      // Use real photo if captured, otherwise use mock photo for simulator
      Uint8List? bytes;
      if (_photoFile != null) {
        bytes = await _photoFile!.readAsBytes();
      } else if (_mockPhotoBytes != null) {
        // Use auto-generated mock photo for simulator testing
        bytes = _mockPhotoBytes;
        AppLogger.d('Using mock photo for detention (simulator mode)');
      }

      await _detentionService.startDetention(
        organizationId: widget.organizationId,
        loadId: widget.loadId,
        stopId: widget.stopId ?? 'unknown', // Fallback or require it
        lat: _currentPosition!.latitude,
        lng: _currentPosition!.longitude,
        photoBytes: bytes, // Uses mock photo if no real photo captured
      );

      if (mounted) {
        Navigator.pop(context, true); // Return true to indicate success
      }
    } catch (e, stack) {
      AppLogger.e('Error starting detention', e, stack);
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('Error starting detention: $e')),
        );
        setState(() => _isLoading = false);
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(title: const Text('Start Detention')),
      body: SingleChildScrollView(
        padding: const EdgeInsets.all(24),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            const Text(
              'Confirm Arrival & Start Timer',
              style: TextStyle(fontSize: 20, fontWeight: FontWeight.bold),
              textAlign: TextAlign.center,
            ),
            const SizedBox(height: 8),
            Text(
              'for ${widget.facilityAddress}',
              textAlign: TextAlign.center,
              style: const TextStyle(color: Colors.grey),
            ),
            const SizedBox(height: 32),

            // Show loading while checking for existing detention
            if (_checkingExisting)
              const Center(child: CircularProgressIndicator())

            // Show existing detention warning if one exists
            else if (_existingDetention != null) ...[
              Card(
                color: Colors.orange.shade50,
                child: Padding(
                  padding: const EdgeInsets.all(16),
                  child: Column(
                    children: [
                      const Icon(Icons.warning, size: 40, color: Colors.orange),
                      const SizedBox(height: 8),
                      const Text(
                        'Detention Already Exists',
                        style: TextStyle(
                          fontSize: 18,
                          fontWeight: FontWeight.bold,
                          color: Colors.orange,
                        ),
                      ),
                      const SizedBox(height: 8),
                      Text(
                        'Started: ${_formatDateTime(_existingDetention!.startTime)}',
                        style: const TextStyle(fontSize: 14),
                      ),
                      if (_existingDetention!.endTime != null)
                        Text(
                          'Ended: ${_formatDateTime(_existingDetention!.endTime!)}',
                          style: const TextStyle(fontSize: 14),
                        ),
                      const SizedBox(height: 16),
                      ElevatedButton.icon(
                        onPressed: _isLoading ? null : _deleteExistingDetention,
                        icon: const Icon(Icons.delete),
                        label: const Text('Delete & Start New'),
                        style: ElevatedButton.styleFrom(
                          backgroundColor: Colors.red,
                          foregroundColor: Colors.white,
                        ),
                      ),
                    ],
                  ),
                ),
              ),
            ]

            // Show normal entry form if no existing detention
            else ...[
              // Location Section
              Card(
                child: Padding(
                  padding: const EdgeInsets.all(16),
                  child: Column(
                    children: [
                      const Icon(Icons.location_on,
                          size: 40, color: Colors.blue),
                      const SizedBox(height: 8),
                      if (_isLoading && _currentPosition == null)
                        const CircularProgressIndicator()
                      else if (_locationError != null)
                        Text('Error: $_locationError',
                            style: const TextStyle(color: Colors.red))
                      else if (_currentPosition != null)
                        Text(
                          'Lat: ${_currentPosition!.latitude.toStringAsFixed(5)}\nLng: ${_currentPosition!.longitude.toStringAsFixed(5)}',
                          textAlign: TextAlign.center,
                          style: const TextStyle(fontSize: 16),
                        ),
                      TextButton.icon(
                        onPressed: _fetchLocation,
                        icon: const Icon(Icons.refresh),
                        label: const Text('Update Location'),
                      )
                    ],
                  ),
                ),
              ),
              const SizedBox(height: 16),

              // Photo Section
              Card(
                child: InkWell(
                  onTap: () {
                    // On simulator, use mock photo instead of camera
                    if (_mockPhotoBytes != null && _photoFile == null) {
                      setState(() {
                        // Mark that we're using the mock photo (already generated)
                      });
                      ScaffoldMessenger.of(context).showSnackBar(
                        const SnackBar(
                            content: Text('Mock photo attached for testing')),
                      );
                    } else {
                      // Try camera for real devices
                      _pickImage(ImageSource.camera);
                    }
                  },
                  child: Padding(
                    padding: const EdgeInsets.all(16),
                    child: Column(
                      children: [
                        const Icon(Icons.camera_alt,
                            size: 40, color: Colors.blue),
                        const SizedBox(height: 8),
                        if (_photoFile != null) ...[
                          Image.file(File(_photoFile!.path), height: 150),
                          const SizedBox(height: 8),
                          TextButton(
                              onPressed: () => _pickImage(ImageSource.gallery),
                              child: const Text('Change Photo')),
                        ] else if (_mockPhotoBytes != null) ...[
                          // Show mock photo preview
                          Image.memory(_mockPhotoBytes!, height: 150),
                          const SizedBox(height: 8),
                          const Text('Mock Photo (Simulator)',
                              style: TextStyle(
                                  color: Colors.green,
                                  fontWeight: FontWeight.bold)),
                          const Text('Tap to attach for testing',
                              style: TextStyle(color: Colors.grey)),
                        ] else ...[
                          const Text('Tap to Take Photo of Arrival/Site',
                              style: TextStyle(
                                  fontSize: 16, fontWeight: FontWeight.bold)),
                          const Text('(Required for evidence)',
                              style: TextStyle(color: Colors.grey)),
                        ]
                      ],
                    ),
                  ),
                ),
              ),
              const SizedBox(height: 32),

              ElevatedButton(
                style: ElevatedButton.styleFrom(
                  minimumSize: const Size(double.infinity, 56),
                  backgroundColor: Colors.redAccent,
                  foregroundColor: Colors.white,
                ),
                // Photo is optional, only location is required
                onPressed:
                    (_isLoading || _currentPosition == null) ? null : _submit,
                child: _isLoading
                    ? const CircularProgressIndicator(color: Colors.white)
                    : const Text(
                        'START DETENTION TIMER',
                        style: TextStyle(
                            fontSize: 18, fontWeight: FontWeight.bold),
                      ),
              ),
            ],
          ],
        ),
      ),
    );
  }
}
