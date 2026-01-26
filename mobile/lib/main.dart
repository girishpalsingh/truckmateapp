import 'dart:async';
import 'package:flutter/foundation.dart';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_localizations/flutter_localizations.dart';
import 'l10n/app_localizations.dart';
import 'package:supabase_flutter/supabase_flutter.dart';
import 'core/utils/app_logger.dart';
import 'core/utils/navigation_logger.dart';
import 'core/utils/provider_logger.dart';

import 'config/app_config.dart';
import 'presentation/themes/app_theme.dart';
import 'presentation/screens/welcome_screen.dart';
import 'presentation/screens/login_screen.dart';
import 'presentation/screens/dashboard_screen.dart';
import 'presentation/screens/trip_screens.dart';
import 'presentation/screens/document_scanner_screen.dart';
import 'presentation/screens/expense_screen.dart';
import 'presentation/screens/pending_documents_screen.dart';
import 'services/push_notification_service.dart';
import 'services/device_service.dart';
import 'services/tracking_service.dart';
import 'package:firebase_core/firebase_core.dart';
import 'firebase_options.dart'; // Uncomment after running 'flutterfire configure'

void main() async {
  // Catch Flutter framework errors
  FlutterError.onError = (FlutterErrorDetails details) {
    FlutterError.presentError(details);
    // Use print() for web console visibility
    AppLogger.e('FLUTTER FRAMEWORK ERROR', details.exception, details.stack);
  };

  // Catch async errors not handled by Flutter
  runZonedGuarded(() async {
    WidgetsFlutterBinding.ensureInitialized();

    // Lock orientation to portrait for driver usability
    await SystemChrome.setPreferredOrientations([
      DeviceOrientation.portraitUp,
      DeviceOrientation.portraitDown,
    ]);

    // Load configuration
    final config = await AppConfig.load();
    AppLogger.i('Config loaded: dev mode = ${config.isDevelopment}');

    // Initialize Supabase
    await Supabase.initialize(
      url: config.supabase.projectUrl,
      anonKey: config.supabase.anonKey,
    );
    AppLogger.i('Supabase initialized');

    // Initialize Firebase
    try {
      await Firebase.initializeApp(
        options: DefaultFirebaseOptions.currentPlatform,
      );
      AppLogger.i('Firebase initialized');

      // Initialize Push Notifications
      await PushNotificationService().initialize();
    } catch (e) {
      AppLogger.w(
          'Firebase initialization failed (expected if config missing)', e);
    }
    // print('ℹ️ Firebase skipped (Run `flutterfire configure` to enable)');

    // Initialize Device and Tracking services monitoring
    Supabase.instance.client.auth.onAuthStateChange.listen((data) async {
      final event = data.event;
      if (event == AuthChangeEvent.signedIn ||
          event == AuthChangeEvent.initialSession) {
        try {
          final deviceService = DeviceService(Supabase.instance.client);
          await deviceService.registerDevice();

          final trackingService =
              TrackingService(Supabase.instance.client, deviceService);
          await trackingService.restoreTracking();
        } catch (e) {
          AppLogger.e('Error initializing tracking services', e);
        }
      }
    });

    // Initialize PowerSync for offline support
    // await PowerSyncService.initialize();

    runApp(ProviderScope(
      observers: [ProviderLogger()],
      child: const TruckMateApp(),
    ));
  }, (error, stackTrace) {
    AppLogger.e('UNCAUGHT ASYNC ERROR', error, stackTrace);
  });
}

class TruckMateApp extends StatelessWidget {
  const TruckMateApp({super.key});

  @override
  Widget build(BuildContext context) {
    return MaterialApp(
      title: 'TruckMate',
      navigatorKey: navigatorKey,
      debugShowCheckedModeBanner: false,
      theme: AppTheme.lightTheme,
      navigatorObservers: [NavigationLogger()],
      localizationsDelegates: const [
        AppLocalizations.delegate, // Add this
        GlobalMaterialLocalizations.delegate,
        GlobalWidgetsLocalizations.delegate,
        GlobalCupertinoLocalizations.delegate,
      ],
      supportedLocales: AppLocalizations
          .supportedLocales, // Use auto-generated supported locales
      initialRoute: '/',
      routes: {
        '/': (context) => const WelcomeScreen(),
        '/login': (context) => const LoginScreen(),
        '/dashboard': (context) => const DashboardScreen(),
        '/trip/new': (context) => const NewTripScreen(),
        '/trip/active': (context) => const ActiveTripScreen(),
        '/trips': (context) => const TripListScreen(),
        '/scan': (context) => const DocumentScannerScreen(),
        '/expense': (context) => const ExpenseScreen(),
        '/documents': (context) => const PendingDocumentsScreen(),
      },
    );
  }
}

/// Global Supabase client access
final supabase = Supabase.instance.client;

/// Global Navigator Key for navigation from services
final GlobalKey<NavigatorState> navigatorKey = GlobalKey<NavigatorState>();
