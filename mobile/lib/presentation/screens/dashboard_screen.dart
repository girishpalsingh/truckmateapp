import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import '../providers/auth_provider.dart';
import '../themes/app_theme.dart';
import '../../services/trip_service.dart';
import '../../services/load_service.dart';
import '../../data/models/trip.dart';
import 'rate_con_analysis_screen.dart';
import 'load_details_screen.dart';
import 'notification_screen.dart';
import 'pdf_viewer_screen.dart';
import '../providers/notification_provider.dart';
import '../widgets/notification_toast.dart';
import '../../../l10n/app_localizations.dart';

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
  Map<String, dynamic>? _latestLoad;
  TripProfitability? _profitability;
  bool _isLoading = true;

  @override
  void initState() {
    super.initState();
    _loadActiveTrip();
    // Initialize notification listener via provider
    Future.microtask(() {
      ref.read(notificationProvider.notifier);
    });
  }

  Future<void> _loadActiveTrip() async {
    try {
      final trip = await _tripService.getActiveTrip();
      final load = await _loadService.getLatestLoad();

      TripProfitability? profit;
      if (trip != null) {
        profit = await _tripService.calculateProfitability(trip.id);
      }
      if (mounted) {
        setState(() {
          _activeTrip = trip;
          _latestLoad = load;
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

              // Latest Pending Load
              if (_latestLoad != null &&
                  (_activeTrip == null ||
                      _activeTrip!.status == 'completed' ||
                      _activeTrip!.status == 'deadhead')) ...[
                const SizedBox(height: 16),
                _buildLatestLoadCard(),
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
                      icon: Icons.play_arrow_rounded,
                      label: AppLocalizations.of(context)!.startTrip,
                      subtitle: AppLocalizations.of(context)!.startTripSubtitle,
                      color: AppTheme.successColor,
                      onTap: () => Navigator.pushNamed(context, '/trip/new'),
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

  Widget _buildLatestLoadCard() {
    return Card(
      elevation: 2,
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
      color: Colors.blue.shade50,
      child: InkWell(
        onTap: () {
          Navigator.push(
            context,
            MaterialPageRoute(
              builder: (context) => LoadDetailsScreen(load: _latestLoad!),
            ),
          );
        },
        borderRadius: BorderRadius.circular(16),
        child: Padding(
          padding: const EdgeInsets.all(16),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Row(
                mainAxisAlignment: MainAxisAlignment.spaceBetween,
                children: [
                  const Row(children: [
                    Icon(Icons.assignment_outlined, color: Colors.blue),
                    SizedBox(width: 8),
                    Text('Latest Load',
                        style: TextStyle(
                            fontWeight: FontWeight.bold, color: Colors.blue)),
                  ]),
                  Container(
                    padding:
                        const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
                    decoration: BoxDecoration(
                        color: Colors.blue.withOpacity(0.2),
                        borderRadius: BorderRadius.circular(8)),
                    child: Text(
                        (_latestLoad!['status'] ?? 'PENDING')
                            .toString()
                            .toUpperCase(),
                        style: TextStyle(
                            fontSize: 10,
                            color: Colors.blue.shade800,
                            fontWeight: FontWeight.bold)),
                  ),
                ],
              ),
              const SizedBox(height: 12),
              Text('${_latestLoad!['broker_name'] ?? "Unknown Broker"}',
                  style: const TextStyle(
                      fontWeight: FontWeight.bold, fontSize: 16)),
              Text('Rate: \$${_latestLoad!['primary_rate'] ?? 0}',
                  style: TextStyle(color: Colors.green.shade700)),
              const SizedBox(height: 8),
              Row(
                mainAxisAlignment: MainAxisAlignment.end,
                children: const [
                  Text('Tap to view details',
                      style: TextStyle(fontSize: 12, color: Colors.grey)),
                  Icon(Icons.chevron_right, size: 16, color: Colors.grey),
                ],
              )
            ],
          ),
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
