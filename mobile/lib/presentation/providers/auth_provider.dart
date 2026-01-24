import 'package:flutter/foundation.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import '../../services/auth_service.dart';
import '../../config/app_config.dart';
import '../../core/utils/user_utils.dart';
import 'package:supabase_flutter/supabase_flutter.dart' as sb;
import 'auth_state.dart';

final authProvider = StateNotifierProvider<AuthNotifier, AuthState>((ref) {
  return AuthNotifier();
});

class AuthNotifier extends StateNotifier<AuthState> {
  final AuthService _authService;

  AuthNotifier({AuthService? authService})
      : _authService = authService ?? AuthService(),
        super(const AuthState()) {
    _initializeAuthListener();
  }

  /// Listens to Supabase Auth state changes (sign-in, sign-out, token refresh)
  void _initializeAuthListener() {
    sb.Supabase.instance.client.auth.onAuthStateChange.listen((data) async {
      final sb.AuthChangeEvent event = data.event;
      final sb.Session? session = data.session;

      debugPrint('🔔 Supabase Auth Event: $event');

      switch (event) {
        case sb.AuthChangeEvent.signedIn:
        case sb.AuthChangeEvent.tokenRefreshed:
          if (session?.user != null) {
            // Ensure internal state is authenticated
            if (state.status != AuthStatus.authenticated) {
              state = state.copyWith(status: AuthStatus.authenticated);
            }
            // Optionally refresh profile here if needed
          }
          break;
        case sb.AuthChangeEvent.signedOut:
        case sb.AuthChangeEvent.userDeleted:
          // Synchronize logout if we weren't already aware
          if (state.status != AuthStatus.unauthenticated) {
            await UserUtils.clearAllUserData();
            state = const AuthState(status: AuthStatus.unauthenticated);
          }
          break;
        default:
          break;
      }
    });
  }

  /// Checks for an existing session using UserUtils.
  Future<void> checkSession() async {
    // Artificial delay for welcome screen animation/splash effect
    await Future.delayed(const Duration(seconds: 2));

    try {
      // Use centralized utility to check login status
      final isLoggedIn = await UserUtils.isLoggedIn();

      if (isLoggedIn) {
        // Load user identity from persistence
        final identity = await UserUtils.getCurrentUserIdentity();
        debugPrint('👤 Session restored for user: ${identity?.userId}');
        state = state.copyWith(status: AuthStatus.authenticated);
      } else {
        state = state.copyWith(status: AuthStatus.unauthenticated);
      }
    } catch (e) {
      debugPrint('❌ Failed to restore session: $e');
      state = state.copyWith(
        status: AuthStatus.unauthenticated,
        errorMessage: 'Failed to restore session',
      );
    }

    // Check dev mode while we're at it
    try {
      final config = await AppConfig.load();
      if (config.isDevelopment) {
        state = state.copyWith(devMode: true);
      }
    } catch (_) {
      // Ignore config load errors
    }
  }

  Future<void> sendOTP(String phoneNumber) async {
    state = state.copyWith(isLoading: true, errorMessage: null);

    final result = await _authService.sendOTP(phoneNumber: phoneNumber);

    if (result.success) {
      state = state.copyWith(
        isLoading: false,
        otpSent: true,
      );
    } else {
      state = state.copyWith(
        isLoading: false,
        errorMessage: result.message,
      );
    }
  }

  Future<void> verifyOTP(String phoneNumber, String otp) async {
    state = state.copyWith(isLoading: true, errorMessage: null);

    final result = await _authService.verifyOTP(
      phoneNumber: phoneNumber,
      otp: otp,
    );

    if (result.success) {
      debugPrint('✅ OTP verification successful: $result');

      // Use centralized utility to save user identity to persistence
      final userId = result.profile?.id ?? result.userId;
      if (userId != null && userId != 'unknown') {
        await UserUtils.saveUserIdentity(
          userId: userId,
          organizationId: result.profile?.organizationId,
          phoneNumber: phoneNumber,
          userName: result.profile?.fullName,
        );
      } else {
        debugPrint('⚠️ No valid user ID received from OTP verification');
      }

      state = state.copyWith(
        isLoading: false,
        status: AuthStatus.authenticated,
        userProfile: result.profile,
      );
    } else {
      state = state.copyWith(
        isLoading: false,
        errorMessage: result.message,
      );
    }
  }

  void changePhoneNumber() {
    state = state.copyWith(
      otpSent: false,
      errorMessage: null,
    );
  }

  /// Sign out the user and clear all data
  /// Uses centralized UserUtils.clearAllUserData() to ensure complete cleanup
  Future<void> signOut() async {
    debugPrint('🚪 Signing out user...');

    // Sign out from auth service (clears Supabase session)
    await _authService.signOut();

    // Clear all user data using centralized utility
    // This clears: SharedPreferences, pending sync queue, and local document storage
    await UserUtils.clearAllUserData();

    // Reset state to unauthenticated with otpSent=false
    // This ensures the login screen shows phone number input, not OTP verification
    state = const AuthState(
      status: AuthStatus.unauthenticated,
      otpSent: false,
    );

    debugPrint('✅ Sign out complete');
  }
}
