import 'package:firebase_core/firebase_core.dart';
import 'package:firebase_messaging/firebase_messaging.dart';
import 'package:supabase_flutter/supabase_flutter.dart';
import 'package:flutter/foundation.dart';
import 'package:flutter/material.dart';
import '../core/utils/app_logger.dart';
import '../main.dart'; // To access navigatorKey
import '../presentation/screens/pdf_viewer_screen.dart';
import '../presentation/screens/rate_con_analysis_screen.dart';
import '../presentation/screens/notification_screen.dart';

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
      AppLogger.i('[FCM] User granted permission');

      // 2. Get Token
      String? token;

      try {
        if (defaultTargetPlatform == TargetPlatform.iOS) {
          // On iOS, waiting for APNS token is sometimes required
          String? apnsToken = await messaging.getAPNSToken();
          if (apnsToken == null) {
            AppLogger.d('[FCM] APNS token not ready, waiting 3s...');
            await Future.delayed(const Duration(seconds: 3));
            apnsToken = await messaging.getAPNSToken();
          }
          if (apnsToken == null) {
            AppLogger.w('[FCM] APNS token still null. FCM token might fail.');
          }
        }

        token = await messaging.getToken();
      } catch (e) {
        AppLogger.e('[FCM] Error getting token: $e');
      }

      if (token != null) {
        AppLogger.i('[FCM] Token: $token');
        await _saveTokenToDatabase(token);
      }

      // 3. Listen for token refresh
      messaging.onTokenRefresh.listen((newToken) {
        _saveTokenToDatabase(newToken);
      });

      // 4. Handle foreground messages
      FirebaseMessaging.onMessage.listen((RemoteMessage message) {
        AppLogger.d('[FCM] Got a message whilst in the foreground!');
        AppLogger.d('[FCM] Message data: ${message.data}');
      });

      // 5. Handle background clicks
      FirebaseMessaging.onMessageOpenedApp.listen((RemoteMessage message) {
        AppLogger.d('[FCM] User tapped notification while in background');
        _handleNotificationRouting(message.data);
      });

      // 6. Check for initial message (when app was terminated)
      RemoteMessage? initialMessage =
          await FirebaseMessaging.instance.getInitialMessage();
      if (initialMessage != null) {
        AppLogger.d('[FCM] App opened from terminated state via notification');
        _handleNotificationRouting(initialMessage.data);
      }
    } else {
      AppLogger.w('[FCM] User declined or has not accepted permission');
    }
  }

  Future<void> _saveTokenToDatabase(String token) async {
    final userId = _supabase.auth.currentUser?.id;
    if (userId == null) return;

    try {
      await _supabase
          .from('profiles')
          .update({'fcm_token': token}).eq('id', userId);
      AppLogger.i('[FCM] Token saved to profile');
    } catch (e) {
      AppLogger.e('[FCM] Error saving token: $e');
    }
  }

  void _handleNotificationRouting(Map<String, dynamic> data) {
    AppLogger.d('[FCM] Routing notification: ${data['type']}');

    final type = data['type'];
    final context = navigatorKey.currentContext;

    if (context == null) {
      AppLogger.w('[FCM] Navigator context is null, cannot route');
      return;
    }

    if (type == 'rate_con_review') {
      final rateConId = data['rate_confirmation_id'];
      if (rateConId != null) {
        Navigator.push(
          context,
          MaterialPageRoute(
            builder: (context) =>
                RateConAnalysisScreen(rateConId: rateConId.toString()),
          ),
        );
      }
    } else if (type == 'dispatch_sheet') {
      Navigator.push(
        context,
        MaterialPageRoute(
          builder: (context) => PdfViewerScreen(
            title: 'Dispatcher Sheet',
            storagePath: data['path'],
            url: data['url'],
          ),
        ),
      );
    } else {
      Navigator.push(
        context,
        MaterialPageRoute(
          builder: (context) => const NotificationScreen(),
        ),
      );
    }
  }
}
