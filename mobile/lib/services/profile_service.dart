import 'package:supabase_flutter/supabase_flutter.dart';
import '../data/models/user_profile.dart';
import '../core/utils/app_logger.dart';

/// Service for managing user profiles
class ProfileService {
  final SupabaseClient _client;

  ProfileService({SupabaseClient? client})
      : _client = client ?? Supabase.instance.client;

  /// Get all profiles for an organization with a specific role
  Future<List<UserProfile>> getProfilesByRole(
      String organizationId, String role) async {
    AppLogger.d(
        'ProfileService: Fetching profiles for org $organizationId with role $role');
    try {
      final response = await _client
          .from('profiles')
          .select()
          .eq('organization_id', organizationId)
          .eq('role', role)
          .eq('is_active', true)
          .order('full_name');

      return (response as List)
          .map((json) => UserProfile.fromJson(json))
          .toList();
    } catch (e, stack) {
      AppLogger.e('ProfileService: Error fetching profiles', e, stack);
      rethrow;
    }
  }

  /// Get current user profile
  Future<UserProfile?> getCurrentProfile() async {
    final user = _client.auth.currentUser;
    if (user == null) return null;

    try {
      final response = await _client
          .from('profiles')
          .select()
          .eq('id', user.id)
          .maybeSingle();

      return response != null ? UserProfile.fromJson(response) : null;
    } catch (e) {
      AppLogger.w('ProfileService: Error fetching current profile: $e');
      return null;
    }
  }
}
