import 'dart:io';
import 'dart:typed_data';
import 'package:flutter/material.dart';
import 'package:geolocator/geolocator.dart';
import 'package:image_picker/image_picker.dart';
import '../../services/detention_service.dart';
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

  @override
  void initState() {
    super.initState();
    _fetchLocation();
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
    if (_currentPosition == null || _photoFile == null) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
            content: Text('Please capture location and photo first')),
      );
      return;
    }

    setState(() => _isLoading = true);
    try {
      final bytes = await _photoFile!.readAsBytes();

      await _detentionService.startDetention(
        organizationId: widget.organizationId,
        loadId: widget.loadId,
        stopId: widget.stopId ?? 'unknown', // Fallback or require it
        lat: _currentPosition!.latitude,
        lng: _currentPosition!.longitude,
        photoBytes: bytes,
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

            // Location Section
            Card(
              child: Padding(
                padding: const EdgeInsets.all(16),
                child: Column(
                  children: [
                    const Icon(Icons.location_on, size: 40, color: Colors.blue),
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
                onTap: () => _pickImage(ImageSource.camera),
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
              onPressed:
                  (_isLoading || _currentPosition == null || _photoFile == null)
                      ? null
                      : _submit,
              child: _isLoading
                  ? const CircularProgressIndicator(color: Colors.white)
                  : const Text(
                      'START DETENTION TIMER',
                      style:
                          TextStyle(fontSize: 18, fontWeight: FontWeight.bold),
                    ),
            ),
          ],
        ),
      ),
    );
  }
}
