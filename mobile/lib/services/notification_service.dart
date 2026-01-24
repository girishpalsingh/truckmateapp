import 'package:supabase_flutter/supabase_flutter.dart';
import '../data/models/app_notification.dart';
import '../core/utils/app_logger.dart';

class NotificationService {
  final SupabaseClient _client;

  NotificationService({SupabaseClient? client})
      : _client = client ?? Supabase.instance.client;

  /// Fetch notifications for the current user/organization
  Future<List<AppNotification>> fetchNotifications() async {
    AppLogger.d('NotificationService: Fetching notifications');
    try {
      final response = await _client
          .from('notifications')
          .select()
          .order('created_at', ascending: false)
          .limit(50);

      return (response as List)
          .map((json) => AppNotification.fromJson(json))
          .toList();
    } catch (e, stack) {
      AppLogger.e(
          'NotificationService: Error fetching notifications', e, stack);
      rethrow;
    }
  }

  /// Mark a single notification as read
  Future<void> markAsRead(String notificationId) async {
    // AppLogger.d('NotificationService: Marking $notificationId as read');
    try {
      await _client
          .from('notifications')
          .update({'is_read': true}).eq('id', notificationId);
    } catch (e, stack) {
      AppLogger.e(
          'NotificationService: Error marking notification read', e, stack);
      // Suppress error for UI smoothness
    }
  }

  /// Mark all notifications as read for the current user context
  /// Note: The RLS policy generally handles "for current user",
  /// but explicitly we might want to target unread ones.
  Future<void> markAllAsRead() async {
    AppLogger.i('NotificationService: Marking ALL as read');
    try {
      // We update all unread notifications visible to this user
      await _client
          .from('notifications')
          .update({'is_read': true}).eq('is_read', false);
    } catch (e, stack) {
      AppLogger.e('NotificationService: Error marking all read', e, stack);
      rethrow;
    }
  }
}
