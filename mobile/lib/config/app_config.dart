import 'dart:convert';
import 'package:flutter/services.dart';

/// Application configuration loaded from config file
class AppConfig {
  final SupabaseConfig supabase;
  final PowerSyncConfig powersync;
  final LLMConfig llm;
  final TwilioConfig twilio;
  final ResendConfig resend;
  final DevelopmentConfig development;
  final StorageConfig storage;

  AppConfig({
    required this.supabase,
    required this.powersync,
    required this.llm,
    required this.twilio,
    required this.resend,
    required this.development,
    required this.storage,
  });

  static AppConfig? _instance;
  static AppConfig get instance => _instance!;

  static Future<AppConfig> load() async {
    if (_instance != null) return _instance!;

    try {
      final jsonString = await rootBundle.loadString(
        'assets/config/app_config.json',
      );
      final json = jsonDecode(jsonString) as Map<String, dynamic>;
      _instance = AppConfig._fromJson(json);
    } catch (e) {
      // Use default development config if file not found
      _instance = AppConfig._default();
    }
    return _instance!;
  }

  factory AppConfig._fromJson(Map<String, dynamic> json) {
    return AppConfig(
      supabase: SupabaseConfig.fromJson(json['supabase'] ?? {}),
      powersync: PowerSyncConfig.fromJson(json['powersync'] ?? {}),
      llm: LLMConfig.fromJson(json['llm'] ?? {}),
      twilio: TwilioConfig.fromJson(json['twilio'] ?? {}),
      resend: ResendConfig.fromJson(json['resend'] ?? {}),
      development: DevelopmentConfig.fromJson(json['development'] ?? {}),
      storage: StorageConfig.fromJson(json['storage'] ?? {}),
    );
  }

  factory AppConfig._default() {
    return AppConfig(
      supabase: SupabaseConfig(
        projectUrl: 'https://hgwjghlyaseqrvkvknji.supabase.co',
        anonKey:
            'eyJhbGciOiJIUzI1NiIsInR5cCI6IkpXVCJ9.eyJpc3MiOiJzdXBhYmFzZSIsInJlZiI6Imhnd2pnaGx5YXNlcXJ2a3ZrbmppIiwicm9sZSI6ImFub24iLCJpYXQiOjE3Njg4NTExMDksImV4cCI6MjA4NDQyNzEwOX0.eDO8TLerhKqz9OouhlB-gFWsESEgQEY9h2Ek0ZbzmVM',
      ),
      powersync: PowerSyncConfig(instanceUrl: '', apiKey: ''),
      llm: LLMConfig(defaultProvider: 'gemini', geminiApiKey: ''),
      twilio: TwilioConfig(accountSid: '', authToken: '', phoneNumber: ''),
      resend: ResendConfig(apiKey: '', fromEmail: 'noreply@truckmate.app'),
      development: DevelopmentConfig(
        enabled: true,
        defaultOtp: '123456',
        skipTwilio: true,
        skipEmail: true,
      ),
      storage: StorageConfig(bucketPrefix: 'truckmate', maxFileSizeMb: 50),
    );
  }

  bool get isDevelopment => development.enabled;
}

class SupabaseConfig {
  final String projectUrl;
  final String anonKey;
  final String? serviceRoleKey;

  SupabaseConfig({
    required this.projectUrl,
    required this.anonKey,
    this.serviceRoleKey,
  });

  factory SupabaseConfig.fromJson(Map<String, dynamic> json) {
    return SupabaseConfig(
      projectUrl: json['project_url'] ?? '',
      anonKey: json['anon_key'] ?? '',
      serviceRoleKey: json['service_role_key'],
    );
  }
}

class PowerSyncConfig {
  final String instanceUrl;
  final String apiKey;

  PowerSyncConfig({required this.instanceUrl, required this.apiKey});

  factory PowerSyncConfig.fromJson(Map<String, dynamic> json) {
    return PowerSyncConfig(
      instanceUrl: json['instance_url'] ?? '',
      apiKey: json['api_key'] ?? '',
    );
  }
}

class LLMConfig {
  final String defaultProvider;
  final String? geminiApiKey;
  final String? openaiApiKey;

  LLMConfig({
    required this.defaultProvider,
    this.geminiApiKey,
    this.openaiApiKey,
  });

  factory LLMConfig.fromJson(Map<String, dynamic> json) {
    return LLMConfig(
      defaultProvider: json['default_provider'] ?? 'gemini',
      geminiApiKey: json['gemini']?['api_key'],
      openaiApiKey: json['openai']?['api_key'],
    );
  }
}

class TwilioConfig {
  final String accountSid;
  final String authToken;
  final String phoneNumber;

  TwilioConfig({
    required this.accountSid,
    required this.authToken,
    required this.phoneNumber,
  });

  factory TwilioConfig.fromJson(Map<String, dynamic> json) {
    return TwilioConfig(
      accountSid: json['account_sid'] ?? '',
      authToken: json['auth_token'] ?? '',
      phoneNumber: json['phone_number'] ?? '',
    );
  }
}

class ResendConfig {
  final String apiKey;
  final String fromEmail;

  ResendConfig({required this.apiKey, required this.fromEmail});

  factory ResendConfig.fromJson(Map<String, dynamic> json) {
    return ResendConfig(
      apiKey: json['api_key'] ?? '',
      fromEmail: json['from_email'] ?? 'noreply@truckmate.app',
    );
  }
}

class DevelopmentConfig {
  final bool enabled;
  final String defaultOtp;
  final bool skipTwilio;
  final bool skipEmail;

  DevelopmentConfig({
    required this.enabled,
    required this.defaultOtp,
    required this.skipTwilio,
    required this.skipEmail,
  });

  factory DevelopmentConfig.fromJson(Map<String, dynamic> json) {
    return DevelopmentConfig(
      enabled: json['enabled'] ?? false,
      defaultOtp: json['default_otp'] ?? '123456',
      skipTwilio: json['skip_twilio'] ?? false,
      skipEmail: json['skip_email'] ?? false,
    );
  }
}

class StorageConfig {
  final String bucketPrefix;
  final int maxFileSizeMb;

  StorageConfig({required this.bucketPrefix, required this.maxFileSizeMb});

  factory StorageConfig.fromJson(Map<String, dynamic> json) {
    return StorageConfig(
      bucketPrefix: json['bucket_prefix'] ?? 'truckmate',
      maxFileSizeMb: json['max_file_size_mb'] ?? 50,
    );
  }
}
