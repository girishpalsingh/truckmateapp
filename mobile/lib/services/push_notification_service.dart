import 'package:firebase_core/firebase_core.dart';
import 'package:firebase_messaging/firebase_messaging.dart';
import 'package:supabase_flutter/supabase_flutter.dart';
import 'package:flutter/foundation.dart';

class PushNotificationService {
  final SupabaseClient _supabase;

  PushNotificationService({SupabaseClient? supabase})
      : _supabase = supabase ?? Supabase.instance.client;

  Future<void> initialize() async {
    // 1. Request Permission
    FirebaseMessaging messaging = FirebaseMessaging.instance;

    NotificationSettings settings = await messaging.requestPermission(
      alert: true,
      announcement: false,
      badge: true,
      carPlay: false,
      criticalAlert: false,
      provisional: false,
      sound: true,
    );

    if (settings.authorizationStatus == AuthorizationStatus.authorized) {
      print('[FCM] User granted permission');

      // 2. Get Token
      String? token;

      try {
        if (defaultTargetPlatform == TargetPlatform.iOS) {
          // On iOS, waiting for APNS token is sometimes required
          String? apnsToken = await messaging.getAPNSToken();
          if (apnsToken == null) {
            print('[FCM] APNS token not ready, waiting 3s...');
            await Future.delayed(const Duration(seconds: 3));
            apnsToken = await messaging.getAPNSToken();
          }
          if (apnsToken == null) {
            print('[FCM] APNS token still null. FCM token might fail.');
          }
        }

        token = await messaging.getToken();
      } catch (e) {
        print('[FCM] Error getting token: $e');
      }

      if (token != null) {
        print('[FCM] Token: $token');
        await _saveTokenToDatabase(token);
      }

      // 3. Listen for token refresh
      messaging.onTokenRefresh.listen((newToken) {
        _saveTokenToDatabase(newToken);
      });

      // 4. Handle foreground messages
      FirebaseMessaging.onMessage.listen((RemoteMessage message) {
        print('[FCM] Got a message whilst in the foreground!');
        print('[FCM] Message data: ${message.data}');

        if (message.notification != null) {
          print(
              '[FCM] Message also contained a notification: ${message.notification}');
          // Note: Foreground messages don't show a system alert by default on Android.
          // We rely on our `dashboard_screen.dart` Realtime listener for in-app UI.
          // But we could show a local notification here if we wanted duplication or if Realtime fails.
        }
      });
    } else {
      print('[FCM] User declined or has not accepted permission');
    }
  }

  Future<void> _saveTokenToDatabase(String token) async {
    final userId = _supabase.auth.currentUser?.id;
    if (userId == null) return;

    try {
      await _supabase
          .from('profiles')
          .update({'fcm_token': token}).eq('id', userId);
      print('[FCM] Token saved to profile');
    } catch (e) {
      print('[FCM] Error saving token: $e');
    }
  }
}
