import 'package:flutter/foundation.dart';
import 'package:shared_preferences/shared_preferences.dart';

/// Utility class for user-related operations
class UserUtils {
  /// Get the current user's organization ID from SharedPreferences
  static Future<String?> getUserOrganization() async {
    try {
      final prefs = await SharedPreferences.getInstance();
      final localOrgId = prefs.getString('organization_id');

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
}
