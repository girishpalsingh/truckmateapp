import 'dart:async';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:geolocator/geolocator.dart';
import 'package:supabase_flutter/supabase_flutter.dart';
import '../config/app_config.dart';
import 'device_service.dart';

final trackingServiceProvider = Provider<TrackingService>((ref) {
  final deviceService = ref.read(deviceServiceProvider);
  return TrackingService(Supabase.instance.client, deviceService);
});

class TrackingService {
  final SupabaseClient _supabase;
  final DeviceService _deviceService;
  StreamSubscription<Position>? _positionStreamSubscription;
  String? _currentTripId;
  String? _currentDriverId;

  TrackingService(this._supabase, this._deviceService);

  bool get isTracking => _positionStreamSubscription != null;

  Future<void> restoreTracking() async {
    try {
      final user = _supabase.auth.currentUser;
      if (user == null) return;

      // Find active trip for user
      final response = await _supabase
          .from('trips')
          .select('id')
          .eq('driver_id', user.id)
          .eq('status', 'active')
          .maybeSingle();

      if (response != null) {
        final tripId = response['id'] as String;
        print("Restoring tracking for trip: $tripId");
        await startTracking(tripId);
      }
    } catch (e) {
      print("Error restoring tracking: $e");
    }
  }

  Future<void> startTracking(String tripId) async {
    if (isTracking && _currentTripId == tripId)
      return; // Already tracking this trip

    final config = AppConfig.instance.locationTracking;
    if (!config.enabled) return;

    _currentTripId = tripId;
    final user = _supabase.auth.currentUser;
    _currentDriverId = user?.id;

    if (_currentDriverId == null) {
      print("Cannot start tracking: No user logged in");
      return;
    }

    final permission = await Geolocator.checkPermission();
    if (permission == LocationPermission.denied) {
      final requested = await Geolocator.requestPermission();
      if (requested == LocationPermission.denied ||
          requested == LocationPermission.deniedForever) {
        print("Location permission denied");
        return;
      }
    }

    // Configure location settings
    final locationSettings = LocationSettings(
      accuracy: LocationAccuracy.high,
      distanceFilter: config.distanceFilterMeters, // Update on distance change
    );

    // Stop existing stream if any (e.g. different trip?)
    await stopTracking();
    _currentTripId = tripId; // Restore tripId cleared by stopTracking

    _positionStreamSubscription =
        Geolocator.getPositionStream(locationSettings: locationSettings).listen(
            (Position position) {
      _handlePositionUpdate(position);
    }, onError: (e) {
      print("Location stream error: $e");
    });

    print("Started tracking trip: $tripId");
  }

  Future<void> stopTracking() async {
    await _positionStreamSubscription?.cancel();
    _positionStreamSubscription = null;
    _currentTripId = null;
    print("Stopped tracking");
  }

  Future<void> _handlePositionUpdate(Position position) async {
    if (_currentTripId == null || _currentDriverId == null) return;

    // Check time interval manually if needed, or rely on Geolocator.
    // If we want exact seconds interval, Geolocator on Android has `intervalDuration`.
    // But `distanceFilter` is usually better for battery and utility.
    // We will stick to `distanceFilter` from config.

    final deviceId = await _deviceService.getRegisteredDeviceId();
    if (deviceId == null) {
      print("Device ID not found, skipping location upload");
      return;
    }

    // Fetch organization_id (cached or from profile)
    // For efficiency, we can query it once on startTracking.
    // Ideally we pass it or store it.
    // Just query it from profile or let RLS handle (but Insert needs it according to schema).
    // Let's assume we need to provide it.
    // We can cache it in member variable.

    final orgId = await _getOrganizationId();
    if (orgId == null) return;

    try {
      // Direct Database Insert
      // location column expects PostGIS geography.
      // Supabase Dart client doesn't support automatic conversion to geography well in `insert`.
      // We must send a string.
      // Format: 'SRID=4326;POINT(lon lat)'
      final locationString =
          'SRID=4326;POINT(${position.longitude} ${position.latitude})';

      await _supabase.from('driver_locations').insert({
        'trip_id': _currentTripId,
        'driver_id': _currentDriverId,
        'organization_id': orgId,
        'device_id': deviceId,
        'location': locationString,
        'speed': position.speed,
        'heading': position.heading,
        'accuracy': position.accuracy,
        'altitude': position.altitude,
        'timestamp': position.timestamp.toIso8601String(),
      });

      print("Location uploaded: ${position.latitude}, ${position.longitude}");
    } catch (e) {
      print("Error uploading location: $e");
    }
  }

  String? _cachedOrgId;
  Future<String?> _getOrganizationId() async {
    if (_cachedOrgId != null) return _cachedOrgId;
    if (_currentDriverId == null) return null;

    try {
      final data = await _supabase
          .from('profiles')
          .select('organization_id')
          .eq('id', _currentDriverId!)
          .single();
      _cachedOrgId = data['organization_id'];
      return _cachedOrgId;
    } catch (e) {
      print("Error fetching org id: $e");
      return null;
    }
  }
}
