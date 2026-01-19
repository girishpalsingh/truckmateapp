import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import '../themes/app_theme.dart';
import '../../services/trip_service.dart';

/// New Trip Screen
class NewTripScreen extends ConsumerStatefulWidget {
  const NewTripScreen({super.key});

  @override
  ConsumerState<NewTripScreen> createState() => _NewTripScreenState();
}

class _NewTripScreenState extends ConsumerState<NewTripScreen> {
  final _formKey = GlobalKey<FormState>();
  final _originController = TextEditingController();
  final _destinationController = TextEditingController();
  final _odometerController = TextEditingController();
  final TripService _tripService = TripService();
  bool _isLoading = false;

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
      await _tripService.createTrip(
        organizationId: '11111111-1111-1111-1111-111111111111',
        originAddress: _originController.text,
        destinationAddress: _destinationController.text,
        odometerStart: int.parse(_odometerController.text),
      );
      if (mounted) Navigator.pushReplacementNamed(context, '/dashboard');
    } catch (e) {
      if (mounted) setState(() => _isLoading = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(title: const Text('Start New Trip')),
      body: SingleChildScrollView(
        padding: const EdgeInsets.all(16),
        child: Form(
          key: _formKey,
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: [
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
    if (mounted)
      setState(() {
        _trip = trip;
        _isLoading = false;
      });
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
          ],
        ),
      ),
    );
  }
}
