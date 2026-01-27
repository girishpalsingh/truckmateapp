import 'dart:convert';
import 'package:supabase_flutter/supabase_flutter.dart';
import '../config/app_config.dart';
import '../data/models/user_profile.dart';
import '../core/utils/app_logger.dart';

class AuthService {
  final SupabaseClient _client;
  final AppConfig _config;

  AuthService({SupabaseClient? client, AppConfig? config})
      : _client = client ?? Supabase.instance.client,
        _config = config ?? AppConfig.instance;

  /// Sends an OTP via the Edge Function
  Future<OTPSendResult> sendOTP({required String phoneNumber}) async {
    AppLogger.i('AuthService: Sending OTP to $phoneNumber');
    try {
      final response = await _client.functions.invoke(
        'auth-otp',
        body: {'action': 'send', 'phone_number': phoneNumber},
      );

      dynamic responseData = response.data;
      if (responseData is String) {
        try {
          responseData = jsonDecode(responseData);
        } catch (e) {
          // If decoding fails, we'll keep it as string or handle it later
          AppLogger.w('AuthService: Error decoding response data: $e');
        }
      }

      if (response.status != 200) {
        AppLogger.w(
            'AuthService: Failed to send OTP. Status: ${response.status}');
        return OTPSendResult(
          success: false,
          message: 'Failed to send OTP',
          error: responseData is Map
              ? responseData['error']
              : responseData.toString(),
        );
      }

      final data = responseData as Map<String, dynamic>;
      AppLogger.i('AuthService: OTP sent successfully');

      return OTPSendResult(
        success: true,
        message: 'OTP sent successfully',
        devMode: data['dev'] == true || data['dev_mode'] == true,
      );
    } catch (e, stackTrace) {
      AppLogger.e('AuthService: Exception sending OTP', e, stackTrace);
      return OTPSendResult(
        success: false,
        message: 'Something went wrong: $e',
        error: e.toString(),
      );
    }
  }

  /// Verifies the OTP and establishes the Supabase Session
  Future<OTPVerifyResult> verifyOTP({
    required String phoneNumber,
    required String otp,
  }) async {
    AppLogger.i('AuthService: Verifying OTP for $phoneNumber');
    try {
      final response = await _client.functions.invoke(
        'auth-otp',
        body: {'action': 'verify', 'phone_number': phoneNumber, 'otp': otp},
      );

      dynamic responseData = response.data;
      if (responseData is String) {
        try {
          responseData = jsonDecode(responseData);
        } catch (e) {
          AppLogger.w('AuthService: Error decoding verify response data: $e');
        }
      }

      if (response.status != 200) {
        AppLogger.w(
            'AuthService: Invalid OTP or server error. Status: ${response.status}');
        return OTPVerifyResult(
          success: false,
          message: responseData is Map
              ? responseData['error'] ?? 'Invalid OTP'
              : 'Invalid OTP',
        );
      }

      final data = responseData;
      // Ensure data is accessable as Map if possible, though dynamic usually works.

      final sessionData = data['session'];

      // --- CRITICAL STEP: ESTABLISH AUTH CONTEXT ---
      if (sessionData != null && sessionData['access_token'] != null) {
        // Use setSession with the access_token.
        // Note: For long-term persistence and auto-refresh, the Supabase SDK
        // will use the refresh_token if it's included in the session recovery.
        // In supabase_flutter 2.x, passing the access_token to setSession is common,
        // but restoring from a full session object or refresh token is better.
        await _client.auth.setSession(sessionData['access_token']);

        // If you want robust auto-refreshing from the refresh token immediately:
        if (sessionData['refresh_token'] != null) {
          try {
            await _client.auth.recoverSession(sessionData['refresh_token']);
          } catch (e) {
            AppLogger.w(
                'AuthService: Non-critical error during session recovery: $e');
          }
        }
      } else {
        throw 'No session data returned from server';
      }

      // Profile mapping
      final profileData = data['profile'] as Map<String, dynamic>?;
      final userId = data['user']?['id'] ?? data['profile']?['id'];

      AppLogger.i(
          'AuthService: Login successful. User Exists: ${profileData != null}');
      return OTPVerifyResult(
        success: true,
        userExists: profileData != null,
        message: profileData != null
            ? 'Login successful'
            : 'Please complete registration',
        userId: userId,
        profile: profileData != null ? UserProfile.fromJson(profileData) : null,
      );
    } catch (e, stackTrace) {
      AppLogger.e('AuthService: Verification failed', e, stackTrace);
      return OTPVerifyResult(
        success: false,
        message: 'Verification failed: ${e.toString()}',
      );
    }
  }

  bool get isLoggedIn => _client.auth.currentSession != null;
  User? get currentUser => _client.auth.currentUser;

  /// Fetch the current user's profile from the database
  Future<UserProfile?> getCurrentProfile() async {
    final user = _client.auth.currentUser;
    if (user == null) return null;

    try {
      final response = await _client
          .from('profiles')
          .select()
          .eq('id', user.id)
          .maybeSingle();

      if (response == null) return null;
      return UserProfile.fromJson(response);
    } catch (e) {
      AppLogger.e('AuthService: Failed to fetch current profile', e);
      return null;
    }
  }

  Future<void> signOut() async {
    AppLogger.i('AuthService: Signing out');
    await _client.auth.signOut();
  }
}

// ... (OTPSendResult and OTPVerifyResult classes remain the same)
/// Result object for the [AuthService.sendOTP] operation.
class OTPSendResult {
  final bool success;
  final String message;
  final String? error;
  final bool devMode;

  OTPSendResult({
    required this.success,
    required this.message,
    this.error,
    this.devMode = false,
  });
}

/// Result object for the [AuthService.verifyOTP] operation.
class OTPVerifyResult {
  final bool success;

  /// True if the user has a profile in the database, false if they are a new user.
  final bool userExists;
  final String message;
  final String? userId;
  final UserProfile? profile;

  OTPVerifyResult({
    required this.success,
    this.userExists = false,
    required this.message,
    this.userId,
    this.profile,
  });
  @override
  String toString() {
    return 'OTPVerifyResult(success: $success, userExists: $userExists, message: $message, userId: $userId, profile: $profile)';
  }
}
