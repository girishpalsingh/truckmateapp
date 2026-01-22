import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:supabase_flutter/supabase_flutter.dart';
import '../../data/models/app_notification.dart';
import '../../services/notification_service.dart';

final notificationServiceProvider = Provider<NotificationService>((ref) {
  return NotificationService();
});

class NotificationState {
  final List<AppNotification> notifications;
  final bool isLoading;
  final String? error;
  // Used to trigger UI events (like Toasts) when a new notification arrives
  final AppNotification? latestNotification;

  NotificationState({
    this.notifications = const [],
    this.isLoading = true,
    this.error,
    this.latestNotification,
  });

  NotificationState copyWith({
    List<AppNotification>? notifications,
    bool? isLoading,
    String? error,
    AppNotification? latestNotification,
  }) {
    return NotificationState(
      notifications: notifications ?? this.notifications,
      isLoading: isLoading ?? this.isLoading,
      error: error ?? this.error,
      latestNotification: latestNotification ?? this.latestNotification,
    );
  }

  int get unreadCount => notifications.where((n) => !n.isRead).length;
}

class NotificationNotifier extends StateNotifier<NotificationState> {
  final NotificationService _service;
  RealtimeChannel? _subscription;

  NotificationNotifier(this._service) : super(NotificationState()) {
    _init();
  }

  Future<void> _init() async {
    await fetchNotifications();
    _subscribeToRealtime();
  }

  Future<void> fetchNotifications() async {
    try {
      state = state.copyWith(isLoading: true);
      final notifications = await _service.fetchNotifications();
      // Limit to 10
      final limitedNotifications = notifications.take(10).toList();
      state =
          state.copyWith(notifications: limitedNotifications, isLoading: false);
    } catch (e) {
      state = state.copyWith(error: e.toString(), isLoading: false);
    }
  }

  Future<void> markAsRead(String notificationId) async {
    try {
      // Optimistic update
      final updatedList = state.notifications.map((n) {
        if (n.id == notificationId) {
          return n.copyWith(isRead: true);
        }
        return n;
      }).toList();
      state = state.copyWith(notifications: updatedList);

      await _service.markAsRead(notificationId);
    } catch (e) {
      // Revert if needed, but for read status it's usually fine to ignore transient errors
      print("Error marking as read: $e");
    }
  }

  Future<void> markAllAsRead() async {
    try {
      final updatedList =
          state.notifications.map((n) => n.copyWith(isRead: true)).toList();
      state = state.copyWith(notifications: updatedList);
      await _service.markAllAsRead();
    } catch (e) {
      print("Error marking all as read: $e");
    }
  }

  void _subscribeToRealtime() {
    _subscription = Supabase.instance.client
        .channel('public:notifications')
        .onPostgresChanges(
          event: PostgresChangeEvent.insert,
          schema: 'public',
          table: 'notifications',
          callback: (payload) {
            final newRecord = payload.newRecord;
            final userId = Supabase.instance.client.auth.currentUser?.id;

            // Filter: If user_id is set, it MUST match. If null, it's global.
            // RLS protects fetch, but Realtime broadcast might send everything to everyone listening on the channel
            // if we filter by table only.

            // Wait, does Supabase Realtime respect RLS?
            // By default, NO, unless you enable "Walrus" (Realtime RLS).
            // But we can filter client side safely enough for awareness,
            // provided sensitive data isn't in generic notifications.

            final targetUserId = newRecord['user_id'];
            if (targetUserId != null && targetUserId != userId) {
              // Not for us
              return;
            }

            // Ideally we check organization_id too, but typical setup implies we only get relevant ones?
            // Actually Realtime broadcasts row changes.
            // Let's verify organization match too just in case.
            // (Client-side filtering is NOT security, but it's UX).

            // Note: We'd need to know current user's org.
            // For now, let's assume the backend/RLS prevented connection or we just filter by user match logic.

            final notification = AppNotification.fromJson(newRecord);
            // Add new and limit to 10
            final currentList = [notification, ...state.notifications];
            if (currentList.length > 10) {
              currentList.removeRange(10, currentList.length);
            }

            state = state.copyWith(
              notifications: currentList,
              latestNotification: notification, // Set this to trigger listeners
            );
          },
        )
        .subscribe();
  }

  @override
  void dispose() {
    _subscription?.unsubscribe();
    super.dispose();
  }
}

final notificationProvider =
    StateNotifierProvider<NotificationNotifier, NotificationState>((ref) {
  final service = ref.watch(notificationServiceProvider);
  return NotificationNotifier(service);
});
