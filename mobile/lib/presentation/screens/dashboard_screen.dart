import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import '../providers/auth_provider.dart';
import '../themes/app_theme.dart';
import '../../services/trip_service.dart';
import 'rate_con_analysis_screen.dart';
import 'notification_screen.dart';
import '../../services/notification_service.dart';
import '../providers/notification_provider.dart';
import '../widgets/notification_toast.dart';

/// Main Dashboard Screen - Action-oriented for drivers
class DashboardScreen extends ConsumerStatefulWidget {
  const DashboardScreen({super.key});

  @override
  ConsumerState<DashboardScreen> createState() => _DashboardScreenState();
}

class _DashboardScreenState extends ConsumerState<DashboardScreen> {
  final TripService _tripService = TripService();
  Trip? _activeTrip;
  TripProfitability? _profitability;
  bool _isLoading = true;

  @override
  void initState() {
    super.initState();
    _loadActiveTrip();
    // Initialize notification listener via provider
    // We defer slightly to ensure context is ready
    Future.microtask(() {
      ref.read(notificationProvider.notifier); // Just reading instantiates it
    });
  }

  // NOTE: Original direct Supabase listener removed.
  // The global NotificationProvider now handles listening and state updates.
  // We can listen to state changes here if we want to show a toast/dialog,
  // or just rely on the badge and occasional check.
  // For the requested functionality: "bell icon with notification list and unread badge",
  // the badge is UI state, the list is the screen.
  // The "showDialog" behavior might still be desired?
  // User asked "bell icon with list... will supabase broadcast to all users?"
  // Let's keep the alert dialog logic but drive it from the provider state change?
  // Actually, UI alerts might be annoying if notification center exists.
  // Let's assume the Badge is primary, but we'll keep a listener for NEW urgent items if needed later.
  // For now, removing the direct subscription avoids duplicate logic.

  Future<void> _loadActiveTrip() async {
    try {
      final trip = await _tripService.getActiveTrip();
      TripProfitability? profit;
      if (trip != null) {
        profit = await _tripService.calculateProfitability(trip.id);
      }
      if (mounted) {
        setState(() {
          _activeTrip = trip;
          _profitability = profit;
          _isLoading = false;
        });
      }
    } catch (e) {
      if (mounted) {
        setState(() => _isLoading = false);
      }
    }
  }

  Future<void> _logout() async {
    final confirm = await showDialog<bool>(
      context: context,
      builder: (context) => AlertDialog(
        title: const Text('Logout'),
        content: const Text('Are you sure you want to logout?'),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context, false),
            child: const Text('Cancel'),
          ),
          TextButton(
            onPressed: () => Navigator.pop(context, true),
            child: const Text('Logout', style: TextStyle(color: Colors.red)),
          ),
        ],
      ),
    );

    if (confirm == true) {
      await ref.read(authProvider.notifier).signOut();
      print('[Dashboard] Session cleared via authProvider, logging out');

      if (mounted) {
        Navigator.pushReplacementNamed(context, '/login');
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    // Watch notifications for badge count
    final notificationState = ref.watch(notificationProvider);
    final unreadCount = notificationState.unreadCount;

    // Listen for NEW notifications to show Toast
    ref.listen(notificationProvider, (previous, next) {
      if (previous?.latestNotification != next.latestNotification &&
          next.latestNotification != null) {
        _showNotificationToast(next.latestNotification!);
      }
    });

    return Scaffold(
      appBar: AppBar(
        title: const DualLanguageText(
          primaryText: 'TruckMate',
          subtitleText: 'ਟਰੱਕਮੇਟ',
          primaryStyle: TextStyle(
            color: Colors.white,
            fontSize: 20,
            fontWeight: FontWeight.bold,
          ),
          subtitleStyle: TextStyle(color: Colors.white70, fontSize: 12),
          alignment: CrossAxisAlignment.center,
        ),
        actions: [
          // Notification Bell
          Stack(
            children: [
              IconButton(
                icon: const Icon(Icons.notifications),
                onPressed: () {
                  Navigator.push(
                    context,
                    MaterialPageRoute(
                        builder: (context) => const NotificationScreen()),
                  );
                },
              ),
              if (unreadCount > 0)
                Positioned(
                  right: 8,
                  top: 8,
                  child: Container(
                    padding: const EdgeInsets.all(2),
                    decoration: BoxDecoration(
                      color: Colors.red,
                      borderRadius: BorderRadius.circular(10),
                    ),
                    constraints: const BoxConstraints(
                      minWidth: 16,
                      minHeight: 16,
                    ),
                    child: Text(
                      '$unreadCount',
                      style: const TextStyle(
                        color: Colors.white,
                        fontSize: 10,
                        fontWeight: FontWeight.bold,
                      ),
                      textAlign: TextAlign.center,
                    ),
                  ),
                ),
            ],
          ),
          PopupMenuButton<String>(
            icon: const Icon(Icons.more_vert),
            onSelected: (value) {
              if (value == 'logout') {
                _logout();
              }
            },
            itemBuilder: (context) => [
              const PopupMenuItem(
                value: 'settings',
                child: Row(
                  children: [
                    Icon(Icons.settings, color: Colors.grey),
                    SizedBox(width: 8),
                    Text('Settings'),
                  ],
                ),
              ),
              const PopupMenuItem(
                value: 'logout',
                child: Row(
                  children: [
                    Icon(Icons.logout, color: Colors.red),
                    SizedBox(width: 8),
                    Text('Logout', style: TextStyle(color: Colors.red)),
                  ],
                ),
              ),
            ],
          ),
        ],
      ),
      body: RefreshIndicator(
        onRefresh: _loadActiveTrip,
        child: SingleChildScrollView(
          physics: const AlwaysScrollableScrollPhysics(),
          padding: const EdgeInsets.all(16),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: [
              // Active Trip Card
              if (_isLoading)
                const Center(child: CircularProgressIndicator())
              else if (_activeTrip != null)
                _buildActiveTripCard()
              else
                _buildNoTripCard(),

              const SizedBox(height: 24),

              // Quick Actions
              const DualLanguageText(
                primaryText: 'Quick Actions',
                subtitleText: 'ਤੇਜ਼ ਕਾਰਵਾਈਆਂ',
                primaryStyle: TextStyle(
                  fontSize: 18,
                  fontWeight: FontWeight.bold,
                ),
              ),
              const SizedBox(height: 16),

              // Action Buttons Grid
              Row(
                children: [
                  Expanded(
                    child: _buildActionButton(
                      icon: Icons.play_arrow_rounded,
                      label: 'Start Trip',
                      subtitle: 'ਯਾਤਰਾ ਸ਼ੁਰੂ',
                      color: AppTheme.successColor,
                      onTap: () => Navigator.pushNamed(context, '/trip/new'),
                    ),
                  ),
                  const SizedBox(width: 12),
                  Expanded(
                    child: _buildActionButton(
                      icon: Icons.document_scanner,
                      label: 'Scan Doc',
                      subtitle: 'ਦਸਤਾਵੇਜ਼ ਸਕੈਨ',
                      color: AppTheme.primaryColor,
                      onTap: () => Navigator.pushNamed(context, '/scan'),
                    ),
                  ),
                ],
              ),
              const SizedBox(height: 12),
              Row(
                children: [
                  Expanded(
                    child: _buildActionButton(
                      icon: Icons.local_gas_station,
                      label: 'Log Fuel',
                      subtitle: 'ਈਂਧਣ ਲੌਗ',
                      color: AppTheme.accentColor,
                      onTap: () => Navigator.pushNamed(
                        context,
                        '/expense',
                        arguments: 'fuel',
                      ),
                    ),
                  ),
                  const SizedBox(width: 12),
                  Expanded(
                    child: _buildActionButton(
                      icon: Icons.receipt_long,
                      label: 'Add Expense',
                      subtitle: 'ਖਰਚਾ ਜੋੜੋ',
                      color: AppTheme.warningColor,
                      onTap: () => Navigator.pushNamed(context, '/expense'),
                    ),
                  ),
                ],
              ),

              const SizedBox(height: 24),

              // Voice Command Button
              _buildVoiceCommandButton(),
            ],
          ),
        ),
      ),
      bottomNavigationBar: BottomNavigationBar(
        currentIndex: 0,
        onTap: (index) {
          switch (index) {
            case 0:
              // Already on home
              break;
            case 1:
              Navigator.pushNamed(context, '/trips');
              break;
            case 2:
              Navigator.pushNamed(context, '/documents');
              break;
            case 3:
              Navigator.pushNamed(context, '/profile');
              break;
          }
        },
        items: const [
          BottomNavigationBarItem(icon: Icon(Icons.home), label: 'Home'),
          BottomNavigationBarItem(icon: Icon(Icons.route), label: 'Trips'),
          BottomNavigationBarItem(icon: Icon(Icons.folder), label: 'Documents'),
          BottomNavigationBarItem(icon: Icon(Icons.person), label: 'Profile'),
        ],
      ),
    );
  }

  Widget _buildActiveTripCard() {
    return Card(
      elevation: 4,
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(20)),
      child: Container(
        padding: const EdgeInsets.all(20),
        decoration: BoxDecoration(
          borderRadius: BorderRadius.circular(20),
          gradient: LinearGradient(
            begin: Alignment.topLeft,
            end: Alignment.bottomRight,
            colors: [
              AppTheme.primaryColor,
              AppTheme.primaryColor.withOpacity(0.8),
            ],
          ),
        ),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(
              mainAxisAlignment: MainAxisAlignment.spaceBetween,
              children: [
                const DualLanguageText(
                  primaryText: 'Active Trip',
                  subtitleText: 'ਸਰਗਰਮ ਯਾਤਰਾ',
                  primaryStyle: TextStyle(
                    color: Colors.white,
                    fontSize: 18,
                    fontWeight: FontWeight.bold,
                  ),
                  subtitleStyle: TextStyle(color: Colors.white70, fontSize: 10),
                ),
                Container(
                  padding: const EdgeInsets.symmetric(
                    horizontal: 12,
                    vertical: 6,
                  ),
                  decoration: BoxDecoration(
                    color: Colors.white.withOpacity(0.2),
                    borderRadius: BorderRadius.circular(20),
                  ),
                  child: Text(
                    _activeTrip!.status.toUpperCase(),
                    style: const TextStyle(
                      color: Colors.white,
                      fontWeight: FontWeight.bold,
                      fontSize: 12,
                    ),
                  ),
                ),
              ],
            ),
            const SizedBox(height: 16),

            // Route
            Row(
              children: [
                const Icon(Icons.location_on, color: Colors.white70, size: 20),
                const SizedBox(width: 8),
                Expanded(
                  child: Text(
                    '${_activeTrip!.originAddress ?? "Unknown"} → ${_activeTrip!.destinationAddress ?? "Unknown"}',
                    style: const TextStyle(color: Colors.white, fontSize: 14),
                    maxLines: 2,
                    overflow: TextOverflow.ellipsis,
                  ),
                ),
              ],
            ),
            const SizedBox(height: 16),

            // Stats Row
            Row(
              children: [
                _buildStatItem(
                  'Miles',
                  '${_activeTrip!.totalMiles ?? 0}',
                  Icons.speed,
                ),
                _buildStatItem(
                  'Rate',
                  '\$${_activeTrip!.rate?.toStringAsFixed(0) ?? "0"}',
                  Icons.attach_money,
                ),
                if (_profitability != null)
                  _buildStatItem(
                    'Profit',
                    '\$${_profitability!.netProfit.toStringAsFixed(0)}',
                    Icons.trending_up,
                    isPositive: _profitability!.netProfit >= 0,
                  ),
              ],
            ),
            const SizedBox(height: 16),

            // End Trip Button
            SizedBox(
              width: double.infinity,
              child: ElevatedButton(
                onPressed: () => Navigator.pushNamed(context, '/trip/active'),
                style: ElevatedButton.styleFrom(
                  backgroundColor: Colors.white,
                  foregroundColor: AppTheme.primaryColor,
                  padding: const EdgeInsets.symmetric(vertical: 14),
                  shape: RoundedRectangleBorder(
                    borderRadius: BorderRadius.circular(12),
                  ),
                ),
                child: const DualLanguageText(
                  primaryText: 'View Trip Details',
                  subtitleText: 'ਯਾਤਰਾ ਦੇ ਵੇਰਵੇ ਵੇਖੋ',
                  alignment: CrossAxisAlignment.center,
                  primaryStyle: TextStyle(fontWeight: FontWeight.bold),
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildStatItem(
    String label,
    String value,
    IconData icon, {
    bool isPositive = true,
  }) {
    return Expanded(
      child: Column(
        children: [
          Icon(icon, color: Colors.white70, size: 20),
          const SizedBox(height: 4),
          Text(
            value,
            style: TextStyle(
              color: isPositive ? Colors.white : Colors.red.shade200,
              fontSize: 18,
              fontWeight: FontWeight.bold,
            ),
          ),
          Text(
            label,
            style: const TextStyle(color: Colors.white70, fontSize: 12),
          ),
        ],
      ),
    );
  }

  Widget _buildNoTripCard() {
    return Card(
      elevation: 2,
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(20)),
      child: Padding(
        padding: const EdgeInsets.all(24),
        child: Column(
          children: [
            Icon(
              Icons.local_shipping_outlined,
              size: 64,
              color: Colors.grey.shade400,
            ),
            const SizedBox(height: 16),
            const DualLanguageText(
              primaryText: 'No Active Trip',
              subtitleText: 'ਕੋਈ ਸਰਗਰਮ ਯਾਤਰਾ ਨਹੀਂ',
              primaryStyle: TextStyle(
                fontSize: 18,
                fontWeight: FontWeight.bold,
              ),
              alignment: CrossAxisAlignment.center,
            ),
            const SizedBox(height: 8),
            Text(
              'Start a new trip to begin tracking',
              style: TextStyle(color: Colors.grey.shade600),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildActionButton({
    required IconData icon,
    required String label,
    required String subtitle,
    required Color color,
    required VoidCallback onTap,
  }) {
    return Material(
      color: Colors.transparent,
      child: InkWell(
        onTap: onTap,
        borderRadius: BorderRadius.circular(16),
        child: Container(
          padding: const EdgeInsets.all(20),
          decoration: BoxDecoration(
            color: color.withOpacity(0.1),
            borderRadius: BorderRadius.circular(16),
            border: Border.all(color: color.withOpacity(0.3)),
          ),
          child: Column(
            children: [
              Icon(icon, size: 36, color: color),
              const SizedBox(height: 8),
              Text(
                label,
                style: TextStyle(fontWeight: FontWeight.bold, color: color),
              ),
              Text(
                subtitle,
                style: TextStyle(fontSize: 10, color: color.withOpacity(0.7)),
              ),
            ],
          ),
        ),
      ),
    );
  }

  Widget _buildVoiceCommandButton() {
    return Material(
      color: Colors.transparent,
      child: InkWell(
        onTap: () {
          // TODO: Implement voice commands
          ScaffoldMessenger.of(context).showSnackBar(
            const SnackBar(content: Text('Voice commands coming soon!')),
          );
        },
        borderRadius: BorderRadius.circular(16),
        child: Container(
          padding: const EdgeInsets.all(20),
          decoration: BoxDecoration(
            gradient: LinearGradient(
              colors: [
                AppTheme.secondaryColor.withOpacity(0.1),
                AppTheme.primaryColor.withOpacity(0.1),
              ],
            ),
            borderRadius: BorderRadius.circular(16),
            border: Border.all(color: AppTheme.primaryColor.withOpacity(0.3)),
          ),
          child: Row(
            mainAxisAlignment: MainAxisAlignment.center,
            children: [
              Icon(Icons.mic, size: 32, color: AppTheme.primaryColor),
              const SizedBox(width: 12),
              const Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  DualLanguageText(
                    primaryText: 'Voice Command',
                    subtitleText: 'ਆਵਾਜ਼ ਕਮਾਂਡ',
                    primaryStyle: TextStyle(
                      fontWeight: FontWeight.bold,
                      fontSize: 16,
                    ),
                  ),
                ],
              ),
            ],
          ),
        ),
      ),
    );
  }

  void _showNotificationToast(dynamic notification) {
    late OverlayEntry overlayEntry;

    // Auto-dismiss timer
    Future.delayed(const Duration(seconds: 15), () {
      if (overlayEntry.mounted) {
        overlayEntry.remove();
      }
    });

    overlayEntry = OverlayEntry(
      builder: (context) => Positioned(
        top: MediaQuery.of(context).padding.top + 10,
        left: 0,
        right: 0,
        child: Material(
          color: Colors.transparent,
          child: NotificationToast(
            title: notification.title ?? 'New Notification',
            body: notification.body ?? 'You have a new update.',
            onViewTap: () {
              overlayEntry.remove();
              // Mark as read if ID is available
              if (notification.data['id'] != null) {
                // Use the provider notifier to update state + backend
                ref
                    .read(notificationProvider.notifier)
                    .markAsRead(notification.data['id']);
              }

              // Navigate based on type
              if (notification.data['type'] == 'rate_con_review') {
                // Try both old and new key names for backwards compatibility
                final rateConId = notification.data['rate_confirmation_id'] ??
                    notification.data['rate_con_id'];
                if (rateConId != null) {
                  Navigator.push(
                    context,
                    MaterialPageRoute(
                      builder: (context) => RateConAnalysisScreen(
                        rateConId: rateConId.toString(),
                      ),
                    ),
                  );
                } else {
                  // Fallback to notification screen if no rate con ID
                  Navigator.push(
                    context,
                    MaterialPageRoute(
                      builder: (context) => const NotificationScreen(),
                    ),
                  );
                }
              } else {
                Navigator.push(
                  context,
                  MaterialPageRoute(
                    builder: (context) => const NotificationScreen(),
                  ),
                );
              }
            },
            onDismiss: () {
              overlayEntry.remove();
            },
          ),
        ),
      ),
    );

    Overlay.of(context).insert(overlayEntry);
  }
}
