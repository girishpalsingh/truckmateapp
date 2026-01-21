import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import '../providers/auth_provider.dart';
import '../themes/app_theme.dart';
import '../../services/trip_service.dart';

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
  }

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
      // Use authProvider to properly sign out (clears Supabase session AND SharedPreferences)
      await ref.read(authProvider.notifier).signOut();
      print('[Dashboard] Session cleared via authProvider, logging out');

      if (mounted) {
        Navigator.pushReplacementNamed(context, '/login');
      }
    }
  }

  @override
  Widget build(BuildContext context) {
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
}
