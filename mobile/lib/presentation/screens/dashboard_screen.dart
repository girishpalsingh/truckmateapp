import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import '../providers/auth_provider.dart';
import '../../core/utils/user_utils.dart';
import '../themes/app_theme.dart';
import '../../services/load_service.dart';
import '../../data/models/load.dart';
import 'rate_con_analysis_screen.dart';
import 'load_details_screen.dart';
import 'notification_screen.dart';
import 'pdf_viewer_screen.dart';
import '../providers/notification_provider.dart';
import '../widgets/notification_toast.dart';
import '../../../l10n/app_localizations.dart';

import 'load_list_screen.dart';
import '../../services/detention_service.dart';
import '../../data/models/detention_record.dart';
import '../widgets/journey_timeline.dart';
import '../../data/models/stop.dart';
import '../widgets/glass_container.dart'; // Import GlassContainer

/// Main Dashboard Screen - Action-oriented for drivers
class DashboardScreen extends ConsumerStatefulWidget {
  const DashboardScreen({super.key});

  @override
  ConsumerState<DashboardScreen> createState() => _DashboardScreenState();
}

class _DashboardScreenState extends ConsumerState<DashboardScreen> {
  final LoadService _loadService = LoadService();
  final DetentionService _detentionService = DetentionService();
  List<Load> _recentLoads = [];
  List<DetentionRecord> _activeDetentions = [];
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
      final loads = await _loadService.getLoads(); // Returns List<Load>

      final orgId = await UserUtils.getUserOrganization() ?? '';

      final activeDetentions = orgId.isNotEmpty
          ? await _detentionService.getAllActiveDetentions(orgId)
          : <DetentionRecord>[];

      if (mounted) {
        setState(() {
          _recentLoads = loads;
          _activeDetentions = activeDetentions;
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
      body: Stack(
        children: [
          // Background Gradient Mesh
          Container(
            decoration: const BoxDecoration(
              gradient: LinearGradient(
                begin: Alignment.topLeft,
                end: Alignment.bottomRight,
                colors: [
                  Color(0xFFE0E7FF), // Light Indigo
                  Colors.white,
                  Color(0xFFE0F2FE), // Light Sky
                ],
                stops: [0.0, 0.5, 1.0],
              ),
            ),
          ),
          // Content
          _isLoading
              ? const Center(child: CircularProgressIndicator())
              : RefreshIndicator(
                  onRefresh: _loadData,
                  child: SingleChildScrollView(
                    physics: const AlwaysScrollableScrollPhysics(),
                    padding: const EdgeInsets.all(16),
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.stretch,
                      children: [
                        // Active Detention Alert
                        if (_activeDetentions.isNotEmpty) ...[
                          ..._activeDetentions
                              .map((d) => _buildActiveDetentionCard(d))
                              .toList(),
                          const SizedBox(height: 16),
                        ],

                        // Latest Load Journey Card
                        if (_recentLoads.isNotEmpty)
                          _buildJourneyCard(_recentLoads.first)
                        else
                          GlassContainer(
                            color: Colors.white,
                            padding: const EdgeInsets.all(24.0),
                            child: Center(
                              child: Column(
                                children: [
                                  Icon(Icons.local_shipping_outlined,
                                      size: 48, color: Colors.grey.shade400),
                                  const SizedBox(height: 16),
                                  Text(
                                    AppLocalizations.of(context)!.noActiveTrip,
                                    style: TextStyle(
                                        color: Colors.grey.shade600,
                                        fontSize: 16),
                                  ),
                                ],
                              ),
                            ),
                          ),

                        const SizedBox(height: 24),

                        // Quick Actions
                        DualLanguageText(
                          primaryText:
                              AppLocalizations.of(context)!.quickActions,
                          subtitleText: AppLocalizations.of(context)!
                              .quickActionsSubtitle,
                          primaryStyle: const TextStyle(
                            fontSize: 18,
                            fontWeight: FontWeight.bold,
                          ),
                        ),
                        const SizedBox(height: 16),

                        // Action Buttons Grid
                        _buildQuickActionsGrid(),

                        const SizedBox(height: 24),

                        // Voice Command Button
                        _buildVoiceCommandButton(),

                        // Bottom Padding
                        const SizedBox(height: 40),
                      ],
                    ),
                  ),
                ),
        ],
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

  Widget _buildJourneyCard(Load load) {
    // If we have an active trip, use its details if simpler, or just use load data
    // Load has rateConfirmations which has stops
    List<Stop> stops = [];
    String origin = 'Unknown';
    String destination = 'Unknown';

    if (load.rateConfirmations != null && load.rateConfirmations!.isNotEmpty) {
      final rc = load.rateConfirmations!.first;
      if (rc['rc_stops'] != null) {
        stops = (rc['rc_stops'] as List).map((s) => Stop.fromJson(s)).toList();
        if (stops.isNotEmpty) {
          origin = stops.first.address?.split(',').firstOrNull ?? 'Start';
          destination = stops.last.address?.split(',').firstOrNull ?? 'End';
        }
      }
    }

    return GlassContainer(
      color: Colors.white,
      padding: EdgeInsets.zero,
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Container(
            padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
            decoration: const BoxDecoration(
              gradient: AppTheme.primaryGradient,
              borderRadius: BorderRadius.vertical(top: Radius.circular(20)),
            ),
            child: Row(
              mainAxisAlignment: MainAxisAlignment.spaceBetween,
              children: [
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        'LATEST LOAD #${load.brokerLoadId ?? load.id.substring(0, 4)}',
                        style: const TextStyle(
                          color: Colors.white,
                          fontWeight: FontWeight.bold,
                          fontSize: 14,
                        ),
                      ),
                      Text(
                        load.brokerName ?? 'Unknown Broker',
                        style: const TextStyle(
                          color: Colors.white70,
                          fontSize: 12,
                        ),
                      ),
                    ],
                  ),
                ),
                Container(
                  padding:
                      const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
                  decoration: BoxDecoration(
                    color: Colors.white.withOpacity(0.2),
                    borderRadius: BorderRadius.circular(12),
                    border: Border.all(color: Colors.white.withOpacity(0.3)),
                  ),
                  child: Text(
                    load.status.toUpperCase(),
                    style: const TextStyle(
                      color: Colors.white,
                      fontSize: 10,
                      fontWeight: FontWeight.bold,
                    ),
                  ),
                ),
              ],
            ),
          ),
          Padding(
            padding: const EdgeInsets.all(0),
            child: JourneyTimeline(
              stops: stops,
              origin: origin,
              destination: destination,
            ),
          ),
          Padding(
            padding: const EdgeInsets.all(8.0),
            child: SizedBox(
              width: double.infinity,
              child: TextButton(
                onPressed: () {
                  Navigator.push(
                    context,
                    MaterialPageRoute(
                      builder: (context) =>
                          LoadDetailsScreen(load: load.toJson()),
                    ),
                  ).then((_) => _loadData());
                },
                child: Row(
                  mainAxisAlignment: MainAxisAlignment.center,
                  children: [
                    const Text('View Trip Details',
                        style: TextStyle(
                            color: AppTheme.primaryColor,
                            fontWeight: FontWeight.bold)),
                    const SizedBox(width: 8),
                    const Icon(Icons.arrow_forward_ios,
                        size: 14, color: AppTheme.primaryColor),
                  ],
                ),
              ),
            ),
          ),
        ],
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
    return GlassContainer(
      color: Colors.white.withOpacity(0.7),
      gradient: LinearGradient(
        begin: Alignment.topLeft,
        end: Alignment.bottomRight,
        colors: [
          Colors.white.withOpacity(0.9),
          Colors.white.withOpacity(0.5),
        ],
      ),
      onTap: onTap,
      child: Padding(
        padding: const EdgeInsets.all(20),
        child: Column(
          children: [
            Container(
              padding: const EdgeInsets.all(12),
              decoration: BoxDecoration(
                color: color.withOpacity(0.1),
                shape: BoxShape.circle,
              ),
              child: Icon(icon, size: 32, color: color),
            ),
            const SizedBox(height: 12),
            Text(
              label,
              style: TextStyle(
                fontWeight: FontWeight.bold,
                color: AppTheme.textPrimary,
                fontSize: 15,
              ),
            ),
            const SizedBox(height: 4),
            Text(
              subtitle,
              style: TextStyle(fontSize: 11, color: AppTheme.textSecondary),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildQuickActionsGrid() {
    return Column(
      children: [
        Row(
          children: [
            Expanded(
              child: _buildActionButton(
                icon: Icons.upload_file,
                label: AppLocalizations.of(context)!.uploadRateCon,
                subtitle: AppLocalizations.of(context)!.uploadRateConSubtitle,
                color: Colors.blueAccent,
                onTap: () => Navigator.pushNamed(
                  context,
                  '/scan',
                  arguments: {'type': 'rate_con'},
                ),
              ),
            ),
            const SizedBox(width: 12),
            Expanded(
              child: _buildActionButton(
                icon: Icons.history,
                label: AppLocalizations.of(context)!.showOldLoads,
                subtitle: AppLocalizations.of(context)!.showOldLoadsSubtitle,
                color: Colors.orangeAccent,
                onTap: () => Navigator.push(
                  context,
                  MaterialPageRoute(
                    builder: (context) => const LoadListScreen(),
                  ),
                ),
              ),
            ),
          ],
        ),
        const SizedBox(height: 12),
        Row(
          children: [
            Expanded(
              child: _buildActionButton(
                icon: Icons.search,
                label: AppLocalizations.of(context)!.searchDocuments,
                subtitle: AppLocalizations.of(context)!.searchDocumentsSubtitle,
                color: Colors.teal,
                onTap: () => Navigator.pushNamed(context, '/documents'),
              ),
            ),
            const SizedBox(width: 12),
            Expanded(
              child: _buildActionButton(
                icon: Icons.attach_money,
                label: AppLocalizations.of(context)!.expenses,
                subtitle: AppLocalizations.of(context)!.expensesSubtitle,
                color: Colors.redAccent,
                onTap: () => Navigator.pushNamed(context, '/expense'),
              ),
            ),
          ],
        ),
      ],
    );
  }

  Widget _buildActiveDetentionCard(DetentionRecord record) {
    return GlassContainer(
      color: Colors.red.shade50.withOpacity(0.9),
      border: Border.all(color: Colors.red.shade200),
      child: ListTile(
        leading: Container(
          padding: const EdgeInsets.all(8),
          decoration: BoxDecoration(
            color: Colors.red.withOpacity(0.1),
            shape: BoxShape.circle,
          ),
          child: const Icon(Icons.timer, color: Colors.red, size: 24),
        ),
        title: const Text('DETENTION ACTIVE',
            style: TextStyle(fontWeight: FontWeight.bold, color: Colors.red)),
        subtitle: Text(
            'Started: ${record.startTime.toLocal().toString().split('.')[0]}'),
        trailing: ElevatedButton(
          style: ElevatedButton.styleFrom(
            backgroundColor: Colors.red,
            foregroundColor: Colors.white,
            shape:
                RoundedRectangleBorder(borderRadius: BorderRadius.circular(20)),
          ),
          onPressed: () {
            try {
              final load =
                  _recentLoads.firstWhere((l) => l.id == record.loadId);
              Navigator.push(
                context,
                MaterialPageRoute(
                    builder: (_) => LoadDetailsScreen(load: load.toJson())),
              ).then((_) => _loadData());
            } catch (e) {
              ScaffoldMessenger.of(context).showSnackBar(
                const SnackBar(
                    content:
                        Text('Go to Loads list to manage this detention.')),
              );
            }
          },
          child: const Text('VIEW'),
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
