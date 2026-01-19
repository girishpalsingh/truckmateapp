import 'dart:async';
import 'package:flutter/foundation.dart';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_localizations/flutter_localizations.dart';
import 'package:supabase_flutter/supabase_flutter.dart';

import 'config/app_config.dart';
import 'presentation/themes/app_theme.dart';
import 'presentation/screens/welcome_screen.dart';
import 'presentation/screens/login_screen.dart';
import 'presentation/screens/dashboard_screen.dart';
import 'presentation/screens/trip_screens.dart';
import 'presentation/screens/document_scanner_screen.dart';
import 'presentation/screens/expense_screen.dart';

void main() async {
  // Catch Flutter framework errors
  FlutterError.onError = (FlutterErrorDetails details) {
    FlutterError.presentError(details);
    debugPrint('🔴 Flutter Error: ${details.exception}');
    debugPrint('Stack trace:\n${details.stack}');
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
    debugPrint('✅ Config loaded: dev mode = ${config.isDevelopment}');

    // Initialize Supabase
    await Supabase.initialize(
      url: config.supabase.projectUrl,
      anonKey: config.supabase.anonKey,
    );
    debugPrint('✅ Supabase initialized');

    // Initialize PowerSync for offline support
    // await PowerSyncService.initialize();

    runApp(const ProviderScope(child: TruckMateApp()));
  }, (error, stackTrace) {
    debugPrint('🔴 Uncaught Error: $error');
    debugPrint('Stack trace:\n$stackTrace');
  });
}

class TruckMateApp extends StatelessWidget {
  const TruckMateApp({super.key});

  @override
  Widget build(BuildContext context) {
    return MaterialApp(
      title: 'TruckMate',
      debugShowCheckedModeBanner: false,
      theme: AppTheme.lightTheme,
      localizationsDelegates: const [
        GlobalMaterialLocalizations.delegate,
        GlobalWidgetsLocalizations.delegate,
        GlobalCupertinoLocalizations.delegate,
      ],
      supportedLocales: const [
        Locale('en'), // English
        Locale('pa'), // Punjabi
      ],
      initialRoute: '/',
      routes: {
        '/': (context) => const WelcomeScreen(),
        '/login': (context) => const LoginScreen(),
        '/dashboard': (context) => const DashboardScreen(),
        '/trip/new': (context) => const NewTripScreen(),
        '/trip/active': (context) => const ActiveTripScreen(),
        '/scan': (context) => const DocumentScannerScreen(),
        '/expense': (context) => const ExpenseScreen(),
      },
    );
  }
}

/// Global Supabase client access
final supabase = Supabase.instance.client;
