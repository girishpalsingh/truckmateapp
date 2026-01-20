import 'dart:convert';
import 'package:supabase_flutter/supabase_flutter.dart';
import '../config/app_config.dart';
import '../data/models/user_profile.dart';

class AuthService {
  final SupabaseClient _client;
  final AppConfig _config;

  AuthService({SupabaseClient? client, AppConfig? config})
      : _client = client ?? Supabase.instance.client,
        _config = config ?? AppConfig.instance;

  /// Sends an OTP via the Edge Function
  Future<OTPSendResult> sendOTP({required String phoneNumber}) async {
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
          print('Error decoding response data: $e');
        }
      }

      if (response.status != 200) {
        return OTPSendResult(
          success: false,
          message: 'Failed to send OTP',
          error: responseData is Map
              ? responseData['error']
              : responseData.toString(),
        );
      }

      final data = responseData as Map<String, dynamic>;

      return OTPSendResult(
        success: true,
        message: 'OTP sent successfully',
        devMode: data['dev'] == true || data['dev_mode'] == true,
      );
    } catch (e) {
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
          print('Error decoding verify response data: $e');
        }
      }

      if (response.status != 200) {
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
      if (sessionData != null && sessionData['refresh_token'] != null) {
        // We use setSession with the refresh_token.
        // This handles the JWT acquisition and background refreshing for you.
        await _client.auth.setSession(sessionData['refresh_token']);
      } else {
        throw 'No session data returned from server';
      }

      // Profile mapping
      final profileData = data['profile'] as Map<String, dynamic>?;
      final userId = data['user']?['id'] ?? data['profile']?['id'];

      return OTPVerifyResult(
        success: true,
        userExists: profileData != null,
        message: profileData != null
            ? 'Login successful'
            : 'Please complete registration',
        userId: userId,
        profile: profileData != null ? UserProfile.fromJson(profileData) : null,
      );
    } catch (e) {
      return OTPVerifyResult(
        success: false,
        message: 'Verification failed: ${e.toString()}',
      );
    }
  }

  bool get isLoggedIn => _client.auth.currentSession != null;
  User? get currentUser => _client.auth.currentUser;

  Future<void> signOut() async => await _client.auth.signOut();
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
}
