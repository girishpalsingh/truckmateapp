import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:intl/intl.dart';
import '../providers/notification_provider.dart';
import '../../data/models/app_notification.dart';
import 'rate_con_review_screen.dart';

class NotificationScreen extends ConsumerStatefulWidget {
  const NotificationScreen({super.key});

  @override
  ConsumerState<NotificationScreen> createState() => _NotificationScreenState();
}

class _NotificationScreenState extends ConsumerState<NotificationScreen> {
  @override
  void initState() {
    super.initState();
    // Refresh notifications when entering the screen
    Future.microtask(() {
      ref.read(notificationProvider.notifier).fetchNotifications();
    });
  }

  void _handleNotificationTap(AppNotification notification) {
    // Mark as read immediately
    if (!notification.isRead) {
      ref.read(notificationProvider.notifier).markAsRead(notification.id);
    }

    // Navigate to notification destination
    if (notification.data != null) {
      final type = notification.data!['type'];
      if (type == 'rate_con_review') {
        final rateConId = notification.data!['rate_con_id'];
        if (rateConId != null) {
          Navigator.push(
            context,
            MaterialPageRoute(
              builder: (context) => RateConReviewScreen(rateConId: rateConId),
            ),
          );
        }
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    final state = ref.watch(notificationProvider);

    return Scaffold(
      appBar: AppBar(
        title: const Text('Notifications'),
        actions: [
          if (state.notifications.isNotEmpty)
            IconButton(
              icon: const Icon(Icons.done_all),
              tooltip: 'Mark all as read',
              onPressed: () {
                ref.read(notificationProvider.notifier).markAllAsRead();
              },
            ),
        ],
      ),
      body: state.isLoading && state.notifications.isEmpty
          ? const Center(child: CircularProgressIndicator())
          : state.notifications.isEmpty
              ? _buildEmptyState()
              : ListView.builder(
                  itemCount: state.notifications.length,
                  itemBuilder: (context, index) {
                    final notification = state.notifications[index];
                    return _buildNotificationItem(notification);
                  },
                ),
    );
  }

  Widget _buildEmptyState() {
    return Center(
      child: Column(
        mainAxisAlignment: MainAxisAlignment.center,
        children: [
          Icon(Icons.notifications_off_outlined,
              size: 64, color: Colors.grey.shade400),
          const SizedBox(height: 16),
          Text(
            'No notifications yet',
            style: TextStyle(color: Colors.grey.shade600, fontSize: 16),
          ),
        ],
      ),
    );
  }

  Widget _buildNotificationItem(AppNotification notification) {
    final isRead = notification.isRead;
    final theme = Theme.of(context);

    // Determine icon based on type (crudely for now)
    IconData icon = Icons.notifications;
    if (notification.data?['type'] == 'rate_con_review') {
      icon = Icons.description;
    }

    return Dismissible(
      key: Key(notification.id),
      background: Container(
        color: Colors.red,
        alignment: Alignment.centerRight,
        padding: const EdgeInsets.only(right: 20),
        child: const Icon(Icons.delete, color: Colors.white),
      ),
      direction: DismissDirection.endToStart,
      onDismissed: (direction) {
        // TODO: Implement delete notification functionality
        // ref.read(notificationProvider.notifier).delete(notification.id);
        // For now just visually removing it might be confusing if checks refresh.
        // Assuming delete is not strictly "Dismissible" in requirements, maybe just leave it read.
      },
      confirmDismiss: (direction) async {
        // Optional: disable delete for now or implement delete in service
        return false;
      },
      child: ListTile(
        onTap: () => _handleNotificationTap(notification),
        tileColor: isRead ? null : theme.colorScheme.primary.withOpacity(0.05),
        leading: CircleAvatar(
          backgroundColor: isRead
              ? Colors.grey.shade200
              : theme.colorScheme.primary.withOpacity(0.1),
          child: Icon(
            icon,
            color: isRead ? Colors.grey : theme.colorScheme.primary,
          ),
        ),
        title: Text(
          notification.title,
          style: TextStyle(
            fontWeight: isRead ? FontWeight.normal : FontWeight.bold,
          ),
        ),
        subtitle: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            if (notification.body != null)
              Text(
                notification.body!,
                maxLines: 2,
                overflow: TextOverflow.ellipsis,
              ),
            const SizedBox(height: 4),
            Text(
              DateFormat.yMMMd()
                  .add_jm()
                  .format(notification.createdAt.toLocal()),
              style: TextStyle(fontSize: 12, color: Colors.grey.shade600),
            ),
          ],
        ),
        trailing: !isRead
            ? Container(
                width: 10,
                height: 10,
                decoration: BoxDecoration(
                  color: theme.colorScheme.primary,
                  shape: BoxShape.circle,
                ),
              )
            : null,
      ),
    );
  }
}
