import 'package:supabase_flutter/supabase_flutter.dart';
import '../config/app_config.dart';

/// Authentication service for OTP-based login
class AuthService {
  final SupabaseClient _client;
  final AppConfig _config;

  AuthService({SupabaseClient? client, AppConfig? config})
      : _client = client ?? Supabase.instance.client,
        _config = config ?? AppConfig.instance;

  /// Send OTP to phone number and email
  Future<OTPSendResult> sendOTP({
    required String phoneNumber,
    String? email,
  }) async {
    try {
      // In development mode, skip actual sending
      if (_config.isDevelopment) {
        return OTPSendResult(
          success: true,
          message:
              'Development mode: Use OTP ${_config.development.defaultOtp}',
          devMode: true,
        );
      }

      final response = await _client.functions.invoke(
        'auth-otp',
        body: {'action': 'send', 'phone_number': phoneNumber, 'email': email},
      );

      if (response.status != 200) {
        return OTPSendResult(
          success: false,
          message: 'Failed to send OTP',
          error: response.data?['error'],
        );
      }

      return OTPSendResult(
        success: true,
        message: 'OTP sent successfully',
        devMode: response.data?['dev_mode'] ?? false,
      );
    } catch (e) {
      return OTPSendResult(
        success: false,
        message: 'Failed to send OTP',
        error: e.toString(),
      );
    }
  }

  /// Verify OTP and log in
  Future<OTPVerifyResult> verifyOTP({
    required String phoneNumber,
    required String otp,
  }) async {
    try {
      // In development mode, check against default OTP
      if (_config.isDevelopment && otp == _config.development.defaultOtp) {
        // For dev mode, create a mock session
        return OTPVerifyResult(
          success: true,
          userExists: true,
          message: 'Development login successful',
          profile: UserProfile(
            id: 'dev-user-id',
            fullName: 'Dev Driver',
            phoneNumber: phoneNumber,
            role: 'driver',
            organizationId: '11111111-1111-1111-1111-111111111111',
          ),
        );
      }

      final response = await _client.functions.invoke(
        'auth-otp',
        body: {'action': 'verify', 'phone_number': phoneNumber, 'otp': otp},
      );

      if (response.status != 200) {
        return OTPVerifyResult(
          success: false,
          message: response.data?['error'] ?? 'Invalid OTP',
        );
      }

      final data = response.data;

      if (data['user_exists'] == true) {
        return OTPVerifyResult(
          success: true,
          userExists: true,
          message: 'Login successful',
          profile: UserProfile.fromJson(data['profile']),
        );
      } else {
        return OTPVerifyResult(
          success: true,
          userExists: false,
          message: 'Please complete registration',
        );
      }
    } catch (e) {
      return OTPVerifyResult(
        success: false,
        message: 'Verification failed: ${e.toString()}',
      );
    }
  }

  /// Check if user is logged in
  bool get isLoggedIn => _client.auth.currentSession != null;

  /// Get current user
  User? get currentUser => _client.auth.currentUser;

  /// Sign out
  Future<void> signOut() async {
    await _client.auth.signOut();
  }
}

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

class OTPVerifyResult {
  final bool success;
  final bool userExists;
  final String message;
  final UserProfile? profile;

  OTPVerifyResult({
    required this.success,
    this.userExists = false,
    required this.message,
    this.profile,
  });
}

class UserProfile {
  final String id;
  final String fullName;
  final String phoneNumber;
  final String? email;
  final String role;
  final String? organizationId;

  UserProfile({
    required this.id,
    required this.fullName,
    required this.phoneNumber,
    this.email,
    required this.role,
    this.organizationId,
  });

  factory UserProfile.fromJson(Map<String, dynamic> json) {
    return UserProfile(
      id: json['id'],
      fullName: json['full_name'] ?? '',
      phoneNumber: json['phone_number'] ?? '',
      email: json['email_address'],
      role: json['role'] ?? 'driver',
      organizationId: json['organization_id'],
    );
  }
}
