import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:shared_preferences/shared_preferences.dart';
import '../../services/auth_service.dart';
import '../../config/app_config.dart';
import 'auth_state.dart';

final authProvider = StateNotifierProvider<AuthNotifier, AuthState>((ref) {
  return AuthNotifier();
});

class AuthNotifier extends StateNotifier<AuthState> {
  final AuthService _authService;

  AuthNotifier({AuthService? authService})
      : _authService = authService ?? AuthService(),
        super(const AuthState());

  /// Checks for an existing session in SharedPreferences.
  Future<void> checkSession() async {
    // Artificial delay for welcome screen animation/splash effect
    await Future.delayed(const Duration(seconds: 2));

    try {
      final prefs = await SharedPreferences.getInstance();
      final isLoggedIn = prefs.getBool('is_logged_in') ?? false;
      final userId = prefs.getString('user_id');

      if (isLoggedIn && userId != null) {
        // Ideally we would also load the profile from prefs or fetch it
        state = state.copyWith(status: AuthStatus.authenticated);
      } else {
        state = state.copyWith(status: AuthStatus.unauthenticated);
      }
    } catch (e) {
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
      // Persist session
      final prefs = await SharedPreferences.getInstance();
      await prefs.setBool('is_logged_in', true);
      await prefs.setString(
          'user_id', result.profile?.id ?? result.userId ?? 'unknown');
      await prefs.setString('user_phone', phoneNumber);

      if (result.profile != null) {
        await prefs.setString('user_name', result.profile!.fullName);
        if (result.profile!.organizationId != null) {
          await prefs.setString(
              'organization_id', result.profile!.organizationId!);
        }
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

  Future<void> signOut() async {
    await _authService.signOut();
    final prefs = await SharedPreferences.getInstance();
    await prefs.clear();

    // We might want to keep some prefs like theme mode?
    // For now, clearing all is what was implied, but safer to just clear auth keys.
    // However, existing code didn't specify, so let's stick to simple clear or just specific keys.
    // Re-reading login logic: it sets specific keys. Let's just update state for now.

    state = const AuthState(status: AuthStatus.unauthenticated);
  }
}
