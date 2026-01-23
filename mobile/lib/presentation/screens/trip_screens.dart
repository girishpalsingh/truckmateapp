import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import '../themes/app_theme.dart';
import '../../services/trip_service.dart';
import '../../core/utils/user_utils.dart';
import 'package:url_launcher/url_launcher.dart';

/// Alias for NewTripScreen when creating from rate con
typedef CreateTripScreen = NewTripScreen;

/// New Trip Screen
class NewTripScreen extends ConsumerStatefulWidget {
  final String? originAddress;
  final String? destinationAddress;
  final String? loadId;

  const NewTripScreen({
    super.key,
    this.originAddress,
    this.destinationAddress,
    this.loadId,
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
  bool _isLoading = false;

  @override
  void initState() {
    super.initState();
    _originController = TextEditingController(text: widget.originAddress);
    _destinationController =
        TextEditingController(text: widget.destinationAddress);
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

      await _tripService.createTrip(
        organizationId: organizationId,
        loadId: widget.loadId,
        driverId: userId, // Required for RLS policy
        originAddress: _originController.text,
        destinationAddress: _destinationController.text,
        odometerStart: int.parse(_odometerController.text),
      );

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
      body: SingleChildScrollView(
        padding: const EdgeInsets.all(16),
        child: Form(
          key: _formKey,
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: [
              if (hasPrefilledData) ...[
                Container(
                  padding: const EdgeInsets.all(12),
                  margin: const EdgeInsets.only(bottom: 16),
                  decoration: BoxDecoration(
                    color: Colors.green.withOpacity(0.1),
                    borderRadius: BorderRadius.circular(8),
                    border: Border.all(color: Colors.green.withOpacity(0.3)),
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
                  labelText: 'Odometer',
                  prefixIcon: Icon(Icons.speed),
                ),
                validator: (v) =>
                    int.tryParse(v ?? '') == null ? 'Enter valid number' : null,
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
      });
    }
  }

  Future<void> _createDispatcherSheet() async {
    if (_trip?.loadId == null) return;

    // Show loading indicator
    setState(() => _isLoading = true);

    try {
      final url = await TripService().generateDispatcherSheet(_trip!.loadId!);
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
              child: ListTile(
                title: Text(
                  '${_trip!.originAddress} → ${_trip!.destinationAddress}',
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
      final url =
          await TripService().generateDispatcherSheet(widget.trip.loadId!);
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
