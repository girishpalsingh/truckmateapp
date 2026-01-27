import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import '../providers/auth_provider.dart';
import '../../core/utils/user_utils.dart';
import '../themes/app_theme.dart';
import '../../services/trip_service.dart';
import '../../services/load_service.dart';
import '../../data/models/trip.dart';
import '../../data/models/load.dart';
import 'rate_con_analysis_screen.dart';
import 'load_details_screen.dart';
import 'notification_screen.dart';
import 'pdf_viewer_screen.dart';
import '../providers/notification_provider.dart';
import '../widgets/notification_toast.dart';
import '../../../l10n/app_localizations.dart';
import 'rate_con_list_screen.dart';
import 'load_list_screen.dart';

/// Main Dashboard Screen - Action-oriented for drivers
class DashboardScreen extends ConsumerStatefulWidget {
  const DashboardScreen({super.key});

  @override
  ConsumerState<DashboardScreen> createState() => _DashboardScreenState();
}

class _DashboardScreenState extends ConsumerState<DashboardScreen> {
  final TripService _tripService = TripService();
  final LoadService _loadService = LoadService();
  Trip? _activeTrip;
  List<Load> _recentLoads = [];
  TripProfitability? _profitability;
  String? _userRole;
  bool _isLoading = true;

  @override
  void initState() {
    super.initState();
    _loadData();
    // Initialize notification listener via provider
    Future.microtask(() {
      ref.read(notificationProvider.notifier);
    });
  }

  Future<void> _loadData() async {
    try {
      final role = await UserUtils.getUserRole();

      // If driver, load active trip. If owner, maybe load fleet stats (for now just active trip is fine as placeholder or skip).
      Trip? trip;
      if (role == 'driver') {
        trip = await _tripService.getActiveTrip();
      }

      final loads = await _loadService.getLoads(); // Returns List<Load>

      TripProfitability? profit;
      if (trip != null) {
        profit = await _tripService.calculateProfitability(trip.id);
      }
      if (mounted) {
        setState(() {
          _activeTrip = trip;
          _recentLoads = loads;
          _profitability = profit;
          _userRole = role;
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
        title: Text(AppLocalizations.of(context)!.logout),
        content: Text(AppLocalizations.of(context)!.logoutConfirmation),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context, false),
            child: Text(AppLocalizations.of(context)!.cancel),
          ),
          TextButton(
            onPressed: () => Navigator.pop(context, true),
            child: Text(AppLocalizations.of(context)!.logout,
                style: const TextStyle(color: Colors.red)),
          ),
        ],
      ),
    );

    if (confirm == true) {
      await ref.read(authProvider.notifier).signOut();
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
        title: DualLanguageText(
          primaryText: AppLocalizations.of(context)!.appName,
          subtitleText: 'ਟਰੱਕਮੇਟ',
          primaryStyle: const TextStyle(
            color: Colors.white,
            fontSize: 20,
            fontWeight: FontWeight.bold,
          ),
          subtitleStyle: const TextStyle(color: Colors.white70, fontSize: 12),
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
              PopupMenuItem(
                value: 'settings',
                child: Row(
                  children: [
                    const Icon(Icons.settings, color: Colors.grey),
                    const SizedBox(width: 8),
                    Text(AppLocalizations.of(context)!.settings),
                  ],
                ),
              ),
              PopupMenuItem(
                value: 'logout',
                child: Row(
                  children: [
                    const Icon(Icons.logout, color: Colors.red),
                    const SizedBox(width: 8),
                    Text(AppLocalizations.of(context)!.logout,
                        style: const TextStyle(color: Colors.red)),
                  ],
                ),
              ),
            ],
          ),
        ],
      ),
      body: RefreshIndicator(
        onRefresh: _loadData,
        child: SingleChildScrollView(
          physics: const AlwaysScrollableScrollPhysics(),
          padding: const EdgeInsets.all(16),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: [
              // Content based on Role
              if (_userRole == 'driver') ...[
                if (_isLoading)
                  const Center(child: CircularProgressIndicator())
                else if (_activeTrip != null)
                  _buildActiveTripCard()
                else
                  _buildNoTripCard(),
              ] else if (_userRole == 'owner' ||
                  _userRole == 'manager' ||
                  _userRole == 'dispatcher') ...[
                // Owner Dashboard
                _buildOwnerDashboardWidgets(),
              ],

              // Recent Loads List
              if (_recentLoads.isNotEmpty &&
                  (_activeTrip == null ||
                      _activeTrip!.status == 'completed' ||
                      _activeTrip!.status == 'deadhead')) ...[
                const SizedBox(height: 16),
                _buildRecentLoadsList(),
              ],

              const SizedBox(height: 24),

              // Quick Actions
              DualLanguageText(
                primaryText: AppLocalizations.of(context)!.quickActions,
                subtitleText:
                    AppLocalizations.of(context)!.quickActionsSubtitle,
                primaryStyle: const TextStyle(
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
                      icon: Icons.local_shipping,
                      label: 'All Loads',
                      subtitle: 'ਸਾਰੇ ਲੋਡ ਵੇਖੋ', // View all loads in Punjabi
                      color: AppTheme.primaryColor,
                      onTap: () => Navigator.push(
                        context,
                        MaterialPageRoute(
                            builder: (context) => const LoadListScreen()),
                      ),
                    ),
                  ),
                  const SizedBox(width: 12),
                  Expanded(
                    child: _buildActionButton(
                      icon: Icons.document_scanner,
                      label: AppLocalizations.of(context)!.scanDoc,
                      subtitle: AppLocalizations.of(context)!.scanDocSubtitle,
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
                      label: AppLocalizations.of(context)!.logFuel,
                      subtitle: AppLocalizations.of(context)!.logFuelSubtitle,
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
                      label: AppLocalizations.of(context)!.addExpense,
                      subtitle:
                          AppLocalizations.of(context)!.addExpenseSubtitle,
                      color: AppTheme.warningColor,
                      onTap: () => Navigator.pushNamed(context, '/expense'),
                    ),
                  ),
                ],
              ),
              const SizedBox(height: 12),

              // New Tiles: Rate Cons & Loads
              Row(
                children: [
                  Expanded(
                    child: _buildActionButton(
                      icon: Icons.assignment,
                      label: 'Rate Cons',
                      subtitle: 'View Rate Confirmations',
                      color: Colors.blueAccent,
                      onTap: () => Navigator.push(
                        context,
                        MaterialPageRoute(
                            builder: (context) => const RateConListScreen()),
                      ),
                    ),
                  ),
                  const SizedBox(width: 12),
                  Expanded(
                    child: _buildActionButton(
                      icon: Icons.local_shipping,
                      label: 'Loads',
                      subtitle: 'Manage Loads',
                      color: Colors.teal,
                      onTap: () => Navigator.push(
                        context,
                        MaterialPageRoute(
                            builder: (context) => const LoadListScreen()),
                      ),
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
        items: [
          BottomNavigationBarItem(
              icon: const Icon(Icons.home),
              label: AppLocalizations.of(context)!.home),
          BottomNavigationBarItem(
              icon: const Icon(Icons.route),
              label: AppLocalizations.of(context)!.trips),
          BottomNavigationBarItem(
              icon: const Icon(Icons.folder),
              label: AppLocalizations.of(context)!.documents),
          BottomNavigationBarItem(
              icon: const Icon(Icons.person),
              label: AppLocalizations.of(context)!.profile),
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
                DualLanguageText(
                  primaryText: AppLocalizations.of(context)!.activeTrip,
                  subtitleText:
                      AppLocalizations.of(context)!.activeTripSubtitle,
                  primaryStyle: const TextStyle(
                    color: Colors.white,
                    fontSize: 18,
                    fontWeight: FontWeight.bold,
                  ),
                  subtitleStyle:
                      const TextStyle(color: Colors.white70, fontSize: 10),
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
                    '${_activeTrip!.originAddress ?? AppLocalizations.of(context)!.unknown} → ${_activeTrip!.destinationAddress ?? AppLocalizations.of(context)!.unknown}',
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
                  AppLocalizations.of(context)!.miles,
                  '${_activeTrip!.totalMiles ?? 0}',
                  Icons.speed,
                ),
                _buildStatItem(
                  AppLocalizations.of(context)!.rate,
                  '\$${_activeTrip!.rate?.toStringAsFixed(0) ?? "0"}',
                  Icons.attach_money,
                ),
                if (_profitability != null)
                  _buildStatItem(
                    AppLocalizations.of(context)!.profit,
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
                child: DualLanguageText(
                  primaryText: AppLocalizations.of(context)!.viewTripDetails,
                  subtitleText:
                      AppLocalizations.of(context)!.viewTripDetailsSubtitle,
                  alignment: CrossAxisAlignment.center,
                  primaryStyle: const TextStyle(fontWeight: FontWeight.bold),
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

  Widget _buildOwnerDashboardWidgets() {
    return Column(
      children: [
        Row(
          children: [
            _buildStatItem(
                'Available Trucks', 'Checking...', Icons.local_shipping),
          ],
        ),
        // TODO: Implement actual owner stats
        const SizedBox(height: 16),
        Card(
          child: Padding(
            padding: const EdgeInsets.all(16.0),
            child: Column(
              children: [
                const Text('Fleet Overview',
                    style:
                        TextStyle(fontSize: 18, fontWeight: FontWeight.bold)),
                const SizedBox(height: 8),
                const Text('Owner/Manager functionality coming soon.'),
                TextButton(
                  onPressed: () {
                    Navigator.push(
                      context,
                      MaterialPageRoute(
                          builder: (context) => const LoadListScreen()),
                    );
                  },
                  child: const Text('View All Loads'),
                ),
              ],
            ),
          ),
        ),
      ],
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
            DualLanguageText(
              primaryText: AppLocalizations.of(context)!.noActiveTrip,
              subtitleText: AppLocalizations.of(context)!.noActiveTripSubtitle,
              primaryStyle: const TextStyle(
                fontSize: 18,
                fontWeight: FontWeight.bold,
              ),
              alignment: CrossAxisAlignment.center,
            ),
            const SizedBox(height: 8),
            Text(
              AppLocalizations.of(context)!.startNewTripTracking,
              style: TextStyle(color: Colors.grey.shade600),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildRecentLoadsList() {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Padding(
          padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
          child: DualLanguageText(
            primaryText: 'Latest Load',
            subtitleText: 'ਨਵੀਨਤਮ ਲੋਡ',
            primaryStyle: Theme.of(context).textTheme.titleMedium?.copyWith(
                  fontWeight: FontWeight.bold,
                ),
          ),
        ),
        ListView.builder(
          shrinkWrap: true,
          physics: const NeverScrollableScrollPhysics(),
          itemCount: _recentLoads.isEmpty ? 0 : 1, // Only show latest
          itemBuilder: (context, index) {
            final load = _recentLoads[index];

            // Calculate Stop Status
            int totalStops = 0;
            int completedStops = 0;
            if (load.rateConfirmations != null &&
                load.rateConfirmations!.isNotEmpty) {
              final rc = load.rateConfirmations!.first;
              if (rc['rc_stops'] != null) {
                final stops = rc['rc_stops'] as List;
                totalStops = stops.length;
                completedStops =
                    stops.where((s) => s['status'] == 'COMPLETED').length;
              }
            }

            // Determine display status
            String statusText = load.status.toUpperCase();
            String statusPunjabi = '';
            Color statusColor = Colors.grey;

            if (_activeTrip != null && _activeTrip!.loadId == load.id) {
              statusText = 'TRIP STARTED';
              statusPunjabi = 'ਟ੍ਰਿਪ ਸ਼ੁਰੂ ਹੋਇਆ';
              statusColor = Colors.green;
            } else if (load.status.toLowerCase() == 'delivered' ||
                load.status.toLowerCase() == 'completed') {
              statusText = 'TRIP ENDED';
              statusPunjabi = 'ਟ੍ਰਿਪ ਖਤਮ ਹੋਇਆ';
              statusColor = Colors.blue;
            } else if (load.status.toLowerCase() == 'assigned') {
              statusText = 'ASSIGNED';
              statusPunjabi = 'ਸੌਂਪਿਆ ਗਿਆ';
              statusColor = Colors.orange;
            }

            return Card(
              margin: const EdgeInsets.symmetric(horizontal: 16, vertical: 4),
              child: ListTile(
                title: Text('Load #${load.brokerLoadId ?? "Unknown"}'),
                subtitle: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text('${load.brokerName ?? "Unknown Broker"}'),
                    const SizedBox(height: 4),
                    // Status Row
                    Row(
                      children: [
                        Container(
                          padding: const EdgeInsets.symmetric(
                              horizontal: 8, vertical: 2),
                          decoration: BoxDecoration(
                            color: statusColor.withOpacity(0.1),
                            borderRadius: BorderRadius.circular(4),
                            border: Border.all(color: statusColor),
                          ),
                          child: Column(
                            crossAxisAlignment: CrossAxisAlignment.start,
                            children: [
                              Text(statusText,
                                  style: TextStyle(
                                      fontWeight: FontWeight.bold,
                                      fontSize: 12,
                                      color: statusColor)),
                              if (statusPunjabi.isNotEmpty)
                                Text(statusPunjabi,
                                    style: TextStyle(
                                        fontSize: 10,
                                        color: statusColor.withOpacity(0.8))),
                            ],
                          ),
                        ),
                        const SizedBox(width: 8),
                        // Stops Status
                        if (totalStops > 0)
                          Text('Stops: $completedStops/$totalStops',
                              style: const TextStyle(
                                  fontSize: 12, fontWeight: FontWeight.w500)),
                      ],
                    ),
                  ],
                ),
                trailing: Text(
                  '\$${load.primaryRate?.toStringAsFixed(0) ?? "0"}',
                  style: const TextStyle(
                      fontWeight: FontWeight.bold, color: Colors.green),
                ),
                isThreeLine: true,
                onTap: () {
                  Navigator.push(
                    context,
                    MaterialPageRoute(
                      builder: (context) => LoadDetailsScreen(
                          load: load
                              .toJson()), // Temporary mapping if Screen expects Map
                    ),
                  ).then((_) => _loadData());
                },
              ),
            );
          },
        ),
        const SizedBox(height: 16),
      ],
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
          ScaffoldMessenger.of(context).showSnackBar(
            SnackBar(
                content: Text(
                    AppLocalizations.of(context)!.voiceCommandsComingSoon)),
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
              Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  DualLanguageText(
                    primaryText: AppLocalizations.of(context)!.voiceCommand,
                    subtitleText:
                        AppLocalizations.of(context)!.voiceCommandSubtitle,
                    primaryStyle: const TextStyle(
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
              if (notification.data['id'] != null) {
                ref
                    .read(notificationProvider.notifier)
                    .markAsRead(notification.data['id']);
              }

              if (notification.data['type'] == 'rate_con_review') {
                final rateConId = notification.data['rate_confirmation_id'];

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
                  Navigator.push(
                    context,
                    MaterialPageRoute(
                      builder: (context) => const NotificationScreen(),
                    ),
                  );
                }
              } else if (notification.data['type'] == 'dispatch_sheet') {
                final path = notification.data['path'];
                final url = notification.data['url'];
                Navigator.push(
                  context,
                  MaterialPageRoute(
                    builder: (context) => PdfViewerScreen(
                      title: 'Dispatcher Sheet',
                      storagePath: path,
                      url: url,
                    ),
                  ),
                );
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
