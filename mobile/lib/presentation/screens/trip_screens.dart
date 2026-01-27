import 'package:flutter/material.dart';
import '../../core/utils/app_logger.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import '../../services/trip_service.dart';
import '../../services/truck_service.dart';
import '../../services/profile_service.dart';
import '../../services/tracking_service.dart';
import '../../data/models/truck.dart';
import '../../data/models/user_profile.dart';
import '../../data/models/trip.dart';
import '../../core/utils/user_utils.dart';
import 'package:url_launcher/url_launcher.dart';
import 'detention_timer_screen.dart';
import '../themes/app_theme.dart';

/// Alias for NewTripScreen when creating from rate con
typedef CreateTripScreen = NewTripScreen;

/// New Trip Screen
class NewTripScreen extends ConsumerStatefulWidget {
  final String? originAddress;
  final String? destinationAddress;
  final String? loadId;
  final String? brokerName;
  final double? rate;

  const NewTripScreen({
    super.key,
    this.originAddress,
    this.destinationAddress,
    this.loadId,
    this.brokerName,
    this.rate,
  });

  @override
  ConsumerState<NewTripScreen> createState() => _NewTripScreenState();
}

class _NewTripScreenState extends ConsumerState<NewTripScreen> {
  final _formKey = GlobalKey<FormState>();
  late final TextEditingController _originController;
  late final TextEditingController _destinationController;
  final _odometerController = TextEditingController();
  final TripService _tripService = TripService();
  final TruckService _truckService = TruckService();
  final ProfileService _profileService = ProfileService();

  bool _isLoading = false;
  List<Truck> _trucks = [];
  List<UserProfile> _drivers = [];
  Truck? _selectedTruck;
  UserProfile? _selectedDriver;
  bool _isDataLoading = true;

  @override
  void initState() {
    super.initState();
    _originController = TextEditingController(text: widget.originAddress);
    _destinationController =
        TextEditingController(text: widget.destinationAddress);
    _loadInitialData();
  }

  Future<void> _loadInitialData() async {
    try {
      final orgId = await UserUtils.getUserOrganization();
      final currentUserId = await UserUtils.getUserId();

      if (orgId != null) {
        final results = await Future.wait([
          _truckService.getTrucks(orgId),
          _profileService.getProfilesByRole(orgId, 'driver'),
        ]);

        if (mounted) {
          setState(() {
            _trucks = results[0] as List<Truck>;
            _drivers = results[1] as List<UserProfile>;

            // Pre-select current driver
            if (currentUserId != null) {
              _selectedDriver = _drivers.firstWhere(
                (d) => d.id == currentUserId,
                orElse: () => _drivers.first,
              );
            } else if (_drivers.isNotEmpty) {
              _selectedDriver = _drivers.first;
            }

            // Optional: Try to match truck if we had equipment info (could pass it in widget)
            if (_trucks.isNotEmpty) {
              _selectedTruck = _trucks.first;
            }

            _isDataLoading = false;
          });
        }
      } else {
        if (mounted) setState(() => _isDataLoading = false);
      }
    } catch (e) {
      debugPrint('Error loading initial data: $e');
      if (mounted) setState(() => _isDataLoading = false);
    }
  }

  @override
  void dispose() {
    _originController.dispose();
    _destinationController.dispose();
    _odometerController.dispose();
    super.dispose();
  }

  Future<void> _startTrip() async {
    if (!_formKey.currentState!.validate()) return;
    setState(() => _isLoading = true);

    try {
      // Get organization ID and user ID from persistence using centralized utility
      final organizationId = await UserUtils.getUserOrganization();
      final userId = await UserUtils.getUserId();

      if (organizationId == null || userId == null) {
        if (mounted) {
          ScaffoldMessenger.of(context).showSnackBar(
            const SnackBar(
              content: Text('Session expired. Please log in again.'),
              backgroundColor: Colors.red,
            ),
          );
          setState(() => _isLoading = false);
        }
        return;
      }

      final trip = await _tripService.createTrip(
        organizationId: organizationId,
        loadId: widget.loadId,
        truckId: _selectedTruck?.id,
        driverId: _selectedDriver?.id ?? userId,
        originAddress: _originController.text,
        destinationAddress: _destinationController.text,
        odometerStart: int.tryParse(_odometerController.text) ?? 0,
      );

      // Start tracking
      ref.read(trackingServiceProvider).startTracking(trip.id);

      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(
            content: Text('Trip started successfully!'),
            backgroundColor: Colors.green,
          ),
        );
        // Navigate to active trip screen or dashboard
        Navigator.pushReplacementNamed(context, '/dashboard');
      }
    } catch (e) {
      debugPrint('Error creating trip: $e');
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text('Failed to start trip: $e'),
            backgroundColor: Colors.red,
          ),
        );
        setState(() => _isLoading = false);
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    final hasPrefilledData =
        widget.originAddress != null || widget.destinationAddress != null;

    return Scaffold(
      appBar: AppBar(
        title: Text(
            hasPrefilledData ? 'Create Trip from Rate Con' : 'Start New Trip'),
      ),
      body: _isDataLoading
          ? const Center(child: CircularProgressIndicator())
          : SingleChildScrollView(
              padding: const EdgeInsets.all(16),
              child: Form(
                key: _formKey,
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.stretch,
                  children: [
                    if (widget.loadId != null) ...[
                      _buildLoadInfoCard(),
                      const SizedBox(height: 16),
                    ],
                    if (hasPrefilledData) ...[
                      Container(
                        padding: const EdgeInsets.all(12),
                        margin: const EdgeInsets.only(bottom: 16),
                        decoration: BoxDecoration(
                          color: Colors.green.withOpacity(0.1),
                          borderRadius: BorderRadius.circular(8),
                          border:
                              Border.all(color: Colors.green.withOpacity(0.3)),
                        ),
                        child: Row(
                          children: [
                            const Icon(Icons.check_circle, color: Colors.green),
                            const SizedBox(width: 8),
                            const Expanded(
                              child: Text(
                                'Pre-filled from Rate Confirmation',
                                style: TextStyle(color: Colors.green),
                              ),
                            ),
                          ],
                        ),
                      ),
                    ],

                    // Truck Selector
                    DropdownButtonFormField<Truck>(
                      value: _selectedTruck,
                      decoration: const InputDecoration(
                        labelText: 'Select Truck',
                        prefixIcon: Icon(Icons.local_shipping),
                      ),
                      items: _trucks.map((truck) {
                        return DropdownMenuItem(
                          value: truck,
                          child: Text(truck.truckNumber),
                        );
                      }).toList(),
                      onChanged: (val) => setState(() => _selectedTruck = val),
                      validator: (val) => val == null ? 'Required' : null,
                    ),
                    const SizedBox(height: 16),

                    // Driver Selector
                    DropdownButtonFormField<UserProfile>(
                      value: _selectedDriver,
                      decoration: const InputDecoration(
                        labelText: 'Select Driver',
                        prefixIcon: Icon(Icons.person),
                      ),
                      items: _drivers.map((driver) {
                        return DropdownMenuItem(
                          value: driver,
                          child: Text(driver.fullName),
                        );
                      }).toList(),
                      onChanged: (val) => setState(() => _selectedDriver = val),
                      validator: (val) => val == null ? 'Required' : null,
                    ),
                    const SizedBox(height: 16),

                    TextFormField(
                      controller: _originController,
                      decoration: const InputDecoration(
                        labelText: 'Origin',
                        prefixIcon: Icon(Icons.location_on),
                      ),
                      validator: (v) => v?.isEmpty ?? true ? 'Required' : null,
                    ),
                    const SizedBox(height: 16),
                    TextFormField(
                      controller: _destinationController,
                      decoration: const InputDecoration(
                        labelText: 'Destination',
                        prefixIcon: Icon(Icons.flag),
                      ),
                    ),
                    const SizedBox(height: 16),
                    TextFormField(
                      controller: _odometerController,
                      keyboardType: TextInputType.number,
                      decoration: const InputDecoration(
                        labelText: 'Odometer (Optional)',
                        prefixIcon: Icon(Icons.speed),
                      ),
                    ),
                    const SizedBox(height: 32),
                    ElevatedButton(
                      onPressed: _isLoading ? null : _startTrip,
                      style: AppTheme.successButtonStyle,
                      child: _isLoading
                          ? const CircularProgressIndicator()
                          : const Text('Start Trip'),
                    ),
                  ],
                ),
              ),
            ),
    );
  }

  Widget _buildLoadInfoCard() {
    return Card(
      child: Padding(
        padding: const EdgeInsets.all(12),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(
              children: [
                const Icon(Icons.assignment, size: 16, color: Colors.blue),
                const SizedBox(width: 8),
                Text(
                  'Load Details',
                  style: TextStyle(
                    fontWeight: FontWeight.bold,
                    color: Colors.blue.shade700,
                  ),
                ),
              ],
            ),
            const Divider(),
            if (widget.brokerName != null)
              _buildInfoRow('Broker', widget.brokerName!),
            if (widget.rate != null)
              _buildInfoRow('Rate', '\$${widget.rate!.toStringAsFixed(2)}'),
          ],
        ),
      ),
    );
  }

  Widget _buildInfoRow(String label, String value) {
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 2),
      child: Row(
        mainAxisAlignment: MainAxisAlignment.spaceBetween,
        children: [
          Text(label, style: const TextStyle(color: Colors.grey)),
          Text(value, style: const TextStyle(fontWeight: FontWeight.w500)),
        ],
      ),
    );
  }
}

/// Active Trip Screen
class ActiveTripScreen extends ConsumerStatefulWidget {
  const ActiveTripScreen({super.key});

  @override
  ConsumerState<ActiveTripScreen> createState() => _ActiveTripScreenState();
}

class _ActiveTripScreenState extends ConsumerState<ActiveTripScreen> {
  Trip? _trip;
  bool _isLoading = true;
  List<dynamic> _stops = [];
  Map<String, dynamic>? _currentStop;

  @override
  void initState() {
    super.initState();
    _loadTrip();
  }

  Future<void> _loadTrip() async {
    final trip = await TripService().getActiveTrip();
    if (mounted) {
      setState(() {
        _trip = trip;
        _isLoading = false;

        // Parse stops
        if (trip?.load != null && trip!.load!['rate_confirmations'] != null) {
          final rc = trip.load!['rate_confirmations'];
          if (rc['rc_stops'] != null) {
            _stops = List.from(rc['rc_stops']);
            _stops.sort((a, b) => (a['sequence_number'] ?? 0)
                .compareTo(b['sequence_number'] ?? 0));

            // Find current stop (first pending or arrived)
            _currentStop = _stops.firstWhere(
              (s) => s['status'] != 'COMPLETED' && s['status'] != 'SKIPPED',
              orElse: () => null,
            );
          }
        }
      });
    }
  }

  Future<void> _updateStopStatus(String status) async {
    if (_currentStop == null) return;

    setState(() => _isLoading = true);
    try {
      final now = DateTime.now();
      await TripService().updateStopStatus(
        stopId: _currentStop!['id'],
        status: status,
        actualArrival: status == 'ARRIVED' ? now : null,
        actualDeparture: status == 'COMPLETED' ? now : null,
      );

      // Reload trip to refresh state
      await _loadTrip();

      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text('Stop marked as $status')),
      );
    } catch (e) {
      AppLogger.e('Error updating stop', e);
      if (mounted) {
        setState(() => _isLoading = false);
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('Error: $e')),
        );
      }
    }
  }

  void _showArrivalDialog() {
    showDialog(
      context: context,
      builder: (context) => AlertDialog(
        title: const Text('Arrived at Stop'),
        content: const Text('Confirm arrival at this location?'),
        actions: [
          TextButton(
              onPressed: () => Navigator.pop(context),
              child: const Text('Cancel')),
          ElevatedButton(
            onPressed: () {
              Navigator.pop(context);
              _updateStopStatus('ARRIVED');
            },
            child: const Text('Confirm Arrival'),
          ),
        ],
      ),
    );
  }

  void _showDepartureDialog() {
    showDialog(
      context: context,
      builder: (context) => AlertDialog(
        title: const Text('Depart / Complete Stop'),
        content: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            const Text(
                'Would you like to start detention timer or upload documents?'),
            const SizedBox(height: 12),
            if (_currentStop?['stop_type'] == 'Delivery')
              OutlinedButton.icon(
                icon: const Icon(Icons.timer),
                label: const Text('Start Detention Timer'),
                onPressed: () {
                  Navigator.pop(context);
                  Navigator.push(
                    context,
                    MaterialPageRoute(
                      builder: (context) => DetentionTimerScreen(
                        arrivalTime: DateTime.parse(
                            _currentStop!['actual_arrival'] ??
                                DateTime.now().toIso8601String()),
                        stopAddress: _currentStop!['address'] ?? 'Current Stop',
                      ),
                    ),
                  );
                },
              ),
            const SizedBox(height: 8),
            OutlinedButton.icon(
              icon: const Icon(Icons.upload_file),
              label: const Text('Upload BOL / POD'),
              onPressed: () {
                Navigator.pop(context);
                Navigator.pushNamed(
                    context, '/scan'); // Or specific BOL upload flow
              },
            ),
          ],
        ),
        actions: [
          TextButton(
              onPressed: () => Navigator.pop(context),
              child: const Text('Cancel')),
          ElevatedButton(
            style: AppTheme.successButtonStyle,
            onPressed: () {
              Navigator.pop(context);
              _updateStopStatus('COMPLETED');
            },
            child: const Text('Mark Completed'),
          ),
        ],
      ),
    );
  }

  Future<void> _endTrip() async {
    final odometerController = TextEditingController();

    final shouldEnd = await showDialog<bool>(
      context: context,
      builder: (context) => AlertDialog(
        title: const Text('End Trip'),
        content: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            const Text('Enter ending odometer reading:'),
            TextField(
              controller: odometerController,
              keyboardType: TextInputType.number,
              decoration: const InputDecoration(labelText: 'Odometer'),
            ),
          ],
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context, false),
            child: const Text('Cancel'),
          ),
          ElevatedButton(
            onPressed: () => Navigator.pop(context, true),
            style: AppTheme.successButtonStyle,
            child: const Text('End Trip'),
          ),
        ],
      ),
    );

    if (shouldEnd == true && odometerController.text.isNotEmpty) {
      setState(() => _isLoading = true);
      try {
        await TripService()
            .endTrip(_trip!.id, int.tryParse(odometerController.text) ?? 0);

        // Stop tracking
        await ref.read(trackingServiceProvider).stopTracking();

        if (mounted) {
          ScaffoldMessenger.of(context).showSnackBar(
            const SnackBar(content: Text('Trip ended successfully')),
          );
          Navigator.pushReplacementNamed(context, '/dashboard');
        }
      } catch (e) {
        debugPrint('Error ending trip: $e');
        if (mounted) {
          ScaffoldMessenger.of(context).showSnackBar(
            SnackBar(content: Text('Error: $e'), backgroundColor: Colors.red),
          );
          setState(() => _isLoading = false);
        }
      }
    }
  }

  Future<void> _createDispatcherSheet() async {
    if (_trip?.loadId == null) return;

    // Show loading indicator
    setState(() => _isLoading = true);

    try {
      final response =
          await TripService().generateDispatcherSheet(tripId: _trip!.id);
      final url = response['url'] as String;
      debugPrint('Dispatcher Sheet URL: $url');

      final uri = Uri.parse(url);
      if (await canLaunchUrl(uri)) {
        await launchUrl(uri, mode: LaunchMode.externalApplication);
      } else {
        if (mounted) {
          ScaffoldMessenger.of(context).showSnackBar(
            SnackBar(content: Text('Could not launch URL: $url')),
          );
        }
      }
    } catch (e) {
      debugPrint('Error creating dispatcher sheet: $e');
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('Error: $e'), backgroundColor: Colors.red),
        );
      }
    } finally {
      if (mounted) setState(() => _isLoading = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    if (_isLoading)
      return const Scaffold(body: Center(child: CircularProgressIndicator()));
    if (_trip == null)
      return Scaffold(
        appBar: AppBar(),
        body: const Center(child: Text('No active trip')),
      );

    return Scaffold(
      appBar: AppBar(title: const Text('Active Trip')),
      body: Padding(
        padding: const EdgeInsets.all(16),
        child: Column(
          children: [
            Card(
              child: Padding(
                padding: const EdgeInsets.all(16),
                child: Column(
                  children: [
                    if (_currentStop != null) ...[
                      Row(
                        children: [
                          const Icon(Icons.navigation, color: Colors.blue),
                          const SizedBox(width: 8),
                          Text('Next Destination:',
                              style: Theme.of(context).textTheme.labelLarge),
                        ],
                      ),
                      const SizedBox(height: 8),
                      Text(
                        _currentStop!['address'] ?? 'Unknown Address',
                        style: const TextStyle(
                            fontSize: 18, fontWeight: FontWeight.bold),
                        textAlign: TextAlign.center,
                      ),
                      Text(
                        _currentStop!['stop_type']?.toUpperCase() ?? 'STOP',
                        style: const TextStyle(color: Colors.grey),
                      ),
                      const SizedBox(height: 16),
                      if (_currentStop!['status'] == 'PENDING' ||
                          _currentStop!['status'] == null)
                        SizedBox(
                          width: double.infinity,
                          child: ElevatedButton.icon(
                            icon: const Icon(Icons.location_on),
                            label: const Text('Tap to Arrive'),
                            style: ElevatedButton.styleFrom(
                                backgroundColor: Colors.blue,
                                foregroundColor: Colors.white),
                            onPressed: _showArrivalDialog,
                          ),
                        )
                      else if (_currentStop!['status'] == 'ARRIVED')
                        SizedBox(
                          width: double.infinity,
                          child: ElevatedButton.icon(
                            icon: const Icon(Icons.check),
                            label: const Text('Complete Stop'),
                            style: ElevatedButton.styleFrom(
                                backgroundColor: Colors.green,
                                foregroundColor: Colors.white),
                            onPressed: _showDepartureDialog,
                          ),
                        ),
                    ] else ...[
                      const Text('All stops completed!',
                          style: TextStyle(color: Colors.green, fontSize: 18)),
                      const SizedBox(height: 8),
                      const Text('You can now end the trip.'),
                    ]
                  ],
                ),
              ),
            ),
            const SizedBox(height: 16),
            Row(
              children: [
                Expanded(
                  child: OutlinedButton.icon(
                    onPressed: () => Navigator.pushNamed(context, '/scan'),
                    icon: const Icon(Icons.document_scanner),
                    label: const Text('Scan'),
                  ),
                ),
                const SizedBox(width: 12),
                Expanded(
                  child: OutlinedButton.icon(
                    onPressed: () => Navigator.pushNamed(context, '/expense'),
                    icon: const Icon(Icons.receipt),
                    label: const Text('Expense'),
                  ),
                ),
              ],
            ),
            if (_trip?.loadId != null) ...[
              const SizedBox(height: 12),
              SizedBox(
                width: double.infinity,
                child: OutlinedButton.icon(
                  onPressed: _createDispatcherSheet,
                  icon: const Icon(Icons.description),
                  label: const Text('Create Dispatcher Sheet'),
                ),
              ),
              const SizedBox(height: 24),
              SizedBox(
                width: double.infinity,
                child: ElevatedButton.icon(
                  onPressed: _endTrip,
                  icon: const Icon(Icons.stop_circle),
                  label: const Text('End Trip'),
                  style: ElevatedButton.styleFrom(
                    backgroundColor: Colors.red,
                    foregroundColor: Colors.white,
                  ),
                ),
              ),
            ],
          ],
        ),
      ),
    );
  }
}

/// Trip List Screen
class TripListScreen extends ConsumerStatefulWidget {
  const TripListScreen({super.key});

  @override
  ConsumerState<TripListScreen> createState() => _TripListScreenState();
}

class _TripListScreenState extends ConsumerState<TripListScreen> {
  final TripService _tripService = TripService();
  List<Trip>? _trips;
  bool _isLoading = true;

  @override
  void initState() {
    super.initState();
    _loadTrips();
  }

  Future<void> _loadTrips() async {
    try {
      final userId = await UserUtils.getUserId();
      final trips = await _tripService.getTrips(driverId: userId);
      if (mounted) {
        setState(() {
          _trips = trips;
          _isLoading = false;
        });
      }
    } catch (e) {
      debugPrint('Error loading trips: $e');
      if (mounted) {
        setState(() => _isLoading = false);
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(title: const Text('Trips')),
      body: _isLoading
          ? const Center(child: CircularProgressIndicator())
          : _trips == null || _trips!.isEmpty
              ? const Center(child: Text('No trips found'))
              : ListView.builder(
                  itemCount: _trips!.length,
                  itemBuilder: (context, index) {
                    final trip = _trips![index];
                    return Card(
                      margin: const EdgeInsets.symmetric(
                          horizontal: 16, vertical: 8),
                      child: ListTile(
                        title: Text(
                          '${trip.originAddress ?? "Unknown"} → ${trip.destinationAddress ?? "Unknown"}',
                          style: const TextStyle(fontWeight: FontWeight.bold),
                        ),
                        subtitle: Text(
                          'Date: ${trip.createdAt?.toLocal().toString().split(' ')[0] ?? "N/A"}\nStatus: ${trip.status}',
                        ),
                        leading: Icon(
                          trip.status == 'active'
                              ? Icons.local_shipping
                              : Icons.check_circle,
                          color: trip.status == 'active'
                              ? Colors.green
                              : Colors.grey,
                        ),
                        trailing: const Icon(Icons.chevron_right),
                        onTap: () {
                          Navigator.push(
                            context,
                            MaterialPageRoute(
                              builder: (context) =>
                                  TripDetailScreen(trip: trip),
                            ),
                          );
                        },
                      ),
                    );
                  },
                ),
    );
  }
}

/// Trip Detail Screen
class TripDetailScreen extends ConsumerStatefulWidget {
  final Trip trip;
  const TripDetailScreen({super.key, required this.trip});

  @override
  ConsumerState<TripDetailScreen> createState() => _TripDetailScreenState();
}

class _TripDetailScreenState extends ConsumerState<TripDetailScreen> {
  bool _isLoading = false;

  Future<void> _createDispatcherSheet() async {
    if (widget.trip.loadId == null) return;

    setState(() => _isLoading = true);

    try {
      final response =
          await TripService().generateDispatcherSheet(tripId: widget.trip.id);
      final url = response['url'] as String;
      debugPrint('Dispatcher Sheet URL: $url');

      final uri = Uri.parse(url);
      if (await canLaunchUrl(uri)) {
        await launchUrl(uri, mode: LaunchMode.externalApplication);
      } else {
        if (mounted) {
          ScaffoldMessenger.of(context).showSnackBar(
            SnackBar(content: Text('Could not launch URL: $url')),
          );
        }
      }
    } catch (e) {
      debugPrint('Error creating dispatcher sheet: $e');
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('Error: $e'), backgroundColor: Colors.red),
        );
      }
    } finally {
      if (mounted) setState(() => _isLoading = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(title: const Text('Trip Details')),
      body: SingleChildScrollView(
        padding: const EdgeInsets.all(16),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            Card(
              child: Padding(
                padding: const EdgeInsets.all(16.0),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text('Origin',
                        style: Theme.of(context).textTheme.labelSmall),
                    Text(widget.trip.originAddress ?? 'Unknown',
                        style: const TextStyle(fontSize: 16)),
                    const SizedBox(height: 12),
                    Text('Destination',
                        style: Theme.of(context).textTheme.labelSmall),
                    Text(widget.trip.destinationAddress ?? 'Unknown',
                        style: const TextStyle(fontSize: 16)),
                    const SizedBox(height: 12),
                    Text('Status: ${widget.trip.status}',
                        style: const TextStyle(fontWeight: FontWeight.bold)),
                    if (widget.trip.loadId != null) ...[
                      const SizedBox(height: 8),
                      Text('Load ID: ${widget.trip.loadId}'),
                    ]
                  ],
                ),
              ),
            ),
            const SizedBox(height: 24),
            if (widget.trip.loadId != null)
              SizedBox(
                width: double.infinity,
                child: OutlinedButton.icon(
                  onPressed: _isLoading ? null : _createDispatcherSheet,
                  icon: _isLoading
                      ? const SizedBox(
                          width: 20,
                          height: 20,
                          child: CircularProgressIndicator(strokeWidth: 2))
                      : const Icon(Icons.description),
                  label: Text(
                      _isLoading ? 'Generating...' : 'Create Dispatcher Sheet'),
                ),
              ),
          ],
        ),
      ),
    );
  }
}
