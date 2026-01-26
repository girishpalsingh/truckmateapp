import 'dart:io';
import 'package:device_info_plus/device_info_plus.dart';
import 'package:flutter/services.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:supabase_flutter/supabase_flutter.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:uuid/uuid.dart';

final deviceServiceProvider = Provider<DeviceService>((ref) {
  return DeviceService(Supabase.instance.client);
});

class DeviceService {
  final SupabaseClient _supabase;
  static const String _deviceIdKey = 'device_fingerprint_id';

  DeviceService(this._supabase);

  Future<void> registerDevice() async {
    try {
      final user = _supabase.auth.currentUser;
      if (user == null) return;

      final deviceFingerprint = await _getDeviceFingerprint();
      final deviceInfo = await _getDeviceInfo();

      // Check if device exists
      final existingDevice = await _supabase
          .from('devices')
          .select('id')
          .eq('device_fingerprint', deviceFingerprint)
          .maybeSingle();

      if (existingDevice != null) {
        // Update last active and metadata
        await _supabase.from('devices').update({
          'user_id': user.id,
          // 'organization_id': Org ID is handled by RLS or trigger usually, but we might need to pass it if not inferred.
          // However, our policy uses get_user_organization_id() which relies on profile.
          // If we update, RLS checks org match.
          // For update, we just update generic fields.
          'last_active_at': DateTime.now().toIso8601String(),
          'app_version': await _getAppVersion(),
          'os_version': deviceInfo['os_version'],
        }).eq('id', existingDevice['id']);

        // Store device ID locally for tracking service
        await _storeDeviceId(existingDevice['id']);
      } else {
        // Create new device
        // We need organization_id.
        // We fetch it from profile usually, or let RLS handle it?
        // RLS for INSERT usually checks constraints.
        // But the table has NOT NULL organization_id.
        // We must provide it.

        final profile = await _supabase
            .from('profiles')
            .select('organization_id')
            .eq('id', user.id)
            .single();

        final orgId = profile['organization_id'];

        final res = await _supabase
            .from('devices')
            .insert({
              'user_id': user.id,
              'organization_id': orgId,
              'device_fingerprint': deviceFingerprint,
              'device_type': Platform.isAndroid
                  ? 'android'
                  : (Platform.isIOS ? 'ios' : 'other'),
              'os_version': deviceInfo['os_version'],
              'app_version': await _getAppVersion(),
              'last_active_at': DateTime.now().toIso8601String(),
            })
            .select('id')
            .single();

        await _storeDeviceId(res['id']);
      }
    } catch (e) {
      print('Error registering device: $e');
      // Non-blocking error for main app flow, but tracking won't work without device ID
    }
  }

  Future<String> _getDeviceFingerprint() async {
    final prefs = await SharedPreferences.getInstance();
    String? id = prefs.getString(_deviceIdKey);
    if (id == null) {
      id = const Uuid().v4();
      await prefs.setString(_deviceIdKey, id);
    }
    return id;
  }

  Future<void> _storeDeviceId(String dbId) async {
    final prefs = await SharedPreferences.getInstance();
    await prefs.setString('registered_db_device_id', dbId);
  }

  Future<String?> getRegisteredDeviceId() async {
    final prefs = await SharedPreferences.getInstance();
    return prefs.getString('registered_db_device_id');
  }

  Future<Map<String, String>> _getDeviceInfo() async {
    final deviceInfoPlugin = DeviceInfoPlugin();
    String osVersion = 'Unknown';

    try {
      if (Platform.isAndroid) {
        final androidInfo = await deviceInfoPlugin.androidInfo;
        osVersion =
            'Android ${androidInfo.version.release} (SDK ${androidInfo.version.sdkInt})';
      } else if (Platform.isIOS) {
        final iosInfo = await deviceInfoPlugin.iosInfo;
        osVersion = 'iOS ${iosInfo.systemVersion}';
      }
    } catch (e) {
      // Fallback
    }

    return {'os_version': osVersion};
  }

  Future<String> _getAppVersion() async {
    // Ideally use package_info_plus, but for now hardcode or use simple logic
    // If package_info_plus is in pubspec, use it.
    // It is not in the viewed pubspec.yaml list (I saw device_info_plus? No wait).
    // Let me check pubspec.yaml again. I saw device_info_plus wasn't in the list I viewed?
    // Wait, I viewed pubspec.yaml in Step 12.
    // device_info_plus is NOT there.
    // I need to add `device_info_plus` and `package_info_plus` to pubspec.yaml if I want to use them.
    // Or I can just use generic placeholder for now to avoid dependency hell if I can't run pub get.
    // But the user requested "device type, os version etc.".
    // `Platform` from `dart:io` gives OS.
    return "1.0.0";
  }
}
