import 'package:supabase_flutter/supabase_flutter.dart';
import '../data/models/app_notification.dart';

class NotificationService {
  final SupabaseClient _client;

  NotificationService({SupabaseClient? client})
      : _client = client ?? Supabase.instance.client;

  /// Fetch notifications for the current user/organization
  Future<List<AppNotification>> fetchNotifications() async {
    final response = await _client
        .from('notifications')
        .select()
        .order('created_at', ascending: false)
        .limit(50);

    return (response as List)
        .map((json) => AppNotification.fromJson(json))
        .toList();
  }

  /// Mark a single notification as read
  Future<void> markAsRead(String notificationId) async {
    await _client
        .from('notifications')
        .update({'is_read': true}).eq('id', notificationId);
  }

  /// Mark all notifications as read for the current user context
  /// Note: The RLS policy generally handles "for current user",
  /// but explicitly we might want to target unread ones.
  Future<void> markAllAsRead() async {
    // We update all unread notifications visible to this user
    await _client
        .from('notifications')
        .update({'is_read': true}).eq('is_read', false);
  }
}
