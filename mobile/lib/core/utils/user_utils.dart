import 'package:flutter/foundation.dart';
import 'package:shared_preferences/shared_preferences.dart';
import '../../services/document_sync_service.dart';
import '../../services/local_document_storage.dart';

/// Model class representing the current user's identity
class UserIdentity {
  final String userId;
  final String? organizationId;
  final String? phoneNumber;
  final String? userName;

  const UserIdentity({
    required this.userId,
    this.organizationId,
    this.phoneNumber,
    this.userName,
  });

  bool get hasOrganization =>
      organizationId != null && organizationId!.isNotEmpty;

  @override
  String toString() =>
      'UserIdentity(userId: $userId, organizationId: $organizationId, phoneNumber: $phoneNumber, userName: $userName)';
}

/// Utility class for user-related operations
///
/// This is the SINGLE SOURCE OF TRUTH for reading user identity from persistence.
/// All code should use these utility functions instead of directly accessing SharedPreferences.
class UserUtils {
  // SharedPreferences keys
  static const String _keyUserId = 'user_id';
  static const String _keyOrganizationId = 'organization_id';
  static const String _keyPhoneNumber = 'user_phone';
  static const String _keyUserName = 'user_name';
  static const String _keyIsLoggedIn = 'is_logged_in';

  /// Get the current user's ID from SharedPreferences
  static Future<String?> getUserId() async {
    try {
      final prefs = await SharedPreferences.getInstance();
      final userId = prefs.getString(_keyUserId);

      if (userId != null && userId.isNotEmpty && userId != 'unknown') {
        debugPrint('👤 User ID (from preferences): $userId');
        return userId;
      }

      debugPrint('⚠️ No valid user ID found in preferences');
      return null;
    } catch (e) {
      debugPrint('❌ Failed to get user ID: $e');
      return null;
    }
  }

  /// Get the current user's organization ID from SharedPreferences
  static Future<String?> getUserOrganization() async {
    try {
      final prefs = await SharedPreferences.getInstance();
      final localOrgId = prefs.getString(_keyOrganizationId);

      if (localOrgId != null && localOrgId.isNotEmpty) {
        debugPrint('👤 User organization (from preferences): $localOrgId');
        return localOrgId;
      }

      debugPrint('⚠️ User has no organization assigned');
      return null;
    } catch (e) {
      debugPrint('❌ Failed to get user organization: $e');
      return null;
    }
  }

  /// Get the complete user identity from SharedPreferences
  /// Returns null if the user is not logged in (no valid user ID)
  static Future<UserIdentity?> getCurrentUserIdentity() async {
    try {
      final prefs = await SharedPreferences.getInstance();
      final userId = prefs.getString(_keyUserId);

      if (userId == null || userId.isEmpty || userId == 'unknown') {
        debugPrint('⚠️ No valid user identity in preferences');
        return null;
      }

      final identity = UserIdentity(
        userId: userId,
        organizationId: prefs.getString(_keyOrganizationId),
        phoneNumber: prefs.getString(_keyPhoneNumber),
        userName: prefs.getString(_keyUserName),
      );

      debugPrint('👤 Current user identity: $identity');
      return identity;
    } catch (e) {
      debugPrint('❌ Failed to get user identity: $e');
      return null;
    }
  }

  /// Check if a user is currently logged in
  static Future<bool> isLoggedIn() async {
    try {
      final prefs = await SharedPreferences.getInstance();
      final isLoggedIn = prefs.getBool(_keyIsLoggedIn) ?? false;
      final userId = prefs.getString(_keyUserId);
      return isLoggedIn &&
          userId != null &&
          userId.isNotEmpty &&
          userId != 'unknown';
    } catch (e) {
      debugPrint('❌ Failed to check login status: $e');
      return false;
    }
  }

  /// Save user identity to SharedPreferences after successful authentication
  static Future<void> saveUserIdentity({
    required String userId,
    String? organizationId,
    String? phoneNumber,
    String? userName,
  }) async {
    try {
      final prefs = await SharedPreferences.getInstance();

      await prefs.setBool(_keyIsLoggedIn, true);
      await prefs.setString(_keyUserId, userId);

      if (organizationId != null && organizationId.isNotEmpty) {
        await prefs.setString(_keyOrganizationId, organizationId);
      }
      if (phoneNumber != null && phoneNumber.isNotEmpty) {
        await prefs.setString(_keyPhoneNumber, phoneNumber);
      }
      if (userName != null && userName.isNotEmpty) {
        await prefs.setString(_keyUserName, userName);
      }

      debugPrint('✅ User identity saved to preferences');
      debugPrint('   User ID: $userId');
      debugPrint('   Organization ID: $organizationId');
    } catch (e) {
      debugPrint('❌ Failed to save user identity: $e');
      rethrow;
    }
  }

  /// Clear all user data from persistence on sign out
  /// This includes SharedPreferences AND offline documents
  static Future<void> clearAllUserData() async {
    try {
      debugPrint('🗑️ Clearing all user data...');

      // Clear pending document sync queue
      await DocumentSyncService().clearPendingQueue();
      debugPrint('   ✅ Pending sync queue cleared');

      // Clear local document storage
      await LocalDocumentStorage().clearCache();
      debugPrint('   ✅ Local document storage cleared');

      // Clear SharedPreferences
      final prefs = await SharedPreferences.getInstance();
      await prefs.clear();
      debugPrint('   ✅ SharedPreferences cleared');

      debugPrint('✅ All user data cleared successfully');
    } catch (e) {
      debugPrint('❌ Failed to clear user data: $e');
      rethrow;
    }
  }
}
