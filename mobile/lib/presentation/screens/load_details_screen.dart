import 'package:flutter/material.dart';
import '../../services/load_service.dart';
import 'trip_screens.dart'; // For NewTripScreen arguments if needed

class LoadDetailsScreen extends StatefulWidget {
  final Map<String, dynamic> load;

  const LoadDetailsScreen({super.key, required this.load});

  @override
  State<LoadDetailsScreen> createState() => _LoadDetailsScreenState();
}

class _LoadDetailsScreenState extends State<LoadDetailsScreen> {
  bool _isLoading = false;
  List<dynamic> _stops = [];

  @override
  void initState() {
    super.initState();
    // Stops should be loaded via the rate confirmation link usually
    // load['rate_confirmations']['stops']
    _parseStops();
  }

  void _parseStops() {
    // If the load was fetched with rate_confirmations(*, stops(*))
    final rc = widget.load['rate_confirmations'];
    if (rc != null && rc['stops'] != null) {
      setState(() {
        _stops = rc['stops'] as List<dynamic>;
        _stops.sort((a, b) =>
            (a['sequence_number'] ?? 0).compareTo(b['sequence_number'] ?? 0));
      });
    }
  }

  void _navigateToAddTrip() {
    // Identify origin/dest from stops
    String? origin;
    String? dest;

    if (_stops.isNotEmpty) {
      origin = _stops.first['address'];
      dest = _stops.last['address'];
    }

    Navigator.push(
      context,
      MaterialPageRoute(
        builder: (context) => NewTripScreen(
          loadId: widget.load['id'],
          brokerName: widget.load['broker_name'],
          rate: (widget.load['primary_rate'] as num?)?.toDouble(),
          originAddress: origin,
          destinationAddress: dest,
        ),
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final rate = (widget.load['primary_rate'] ?? 0).toString();

    return Scaffold(
      appBar: AppBar(title: const Text('Load Details')),
      body: SingleChildScrollView(
        padding: const EdgeInsets.all(16),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            // Header Card
            Card(
              elevation: 2,
              shape: RoundedRectangleBorder(
                  borderRadius: BorderRadius.circular(12)),
              child: Padding(
                padding: const EdgeInsets.all(16),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text('Load #${widget.load['broker_load_id'] ?? "Unknown"}',
                        style: theme.textTheme.titleLarge
                            ?.copyWith(fontWeight: FontWeight.bold)),
                    const SizedBox(height: 8),
                    Text('Broker: ${widget.load['broker_name'] ?? "Unknown"}',
                        style: theme.textTheme.bodyLarge),
                    const SizedBox(height: 8),
                    Text('Rate: \$$rate',
                        style: theme.textTheme.titleMedium?.copyWith(
                            color: Colors.green, fontWeight: FontWeight.bold)),
                    const SizedBox(height: 8),
                    Container(
                      padding: const EdgeInsets.symmetric(
                          horizontal: 8, vertical: 4),
                      decoration: BoxDecoration(
                        color: Colors.blue.shade100,
                        borderRadius: BorderRadius.circular(4),
                      ),
                      child: Text(
                        (widget.load['status'] ?? 'Assigned').toUpperCase(),
                        style: TextStyle(
                            fontSize: 12,
                            color: Colors.blue.shade800,
                            fontWeight: FontWeight.bold),
                      ),
                    ),
                  ],
                ),
              ),
            ),
            const SizedBox(height: 20),

            // Stops
            Text('Stops',
                style: theme.textTheme.titleMedium
                    ?.copyWith(fontWeight: FontWeight.bold)),
            const SizedBox(height: 8),
            ListView.builder(
              shrinkWrap: true,
              physics: const NeverScrollableScrollPhysics(),
              itemCount: _stops.length,
              itemBuilder: (context, index) {
                final stop = _stops[index];
                return ListTile(
                  leading: CircleAvatar(
                    backgroundColor: index == 0
                        ? Colors.green
                        : (index == _stops.length - 1
                            ? Colors.red
                            : Colors.grey),
                    radius: 12,
                    child: Text('${index + 1}',
                        style:
                            const TextStyle(fontSize: 12, color: Colors.white)),
                  ),
                  title: Text(stop['address'] ?? 'Unknown Address'),
                  subtitle: Text(stop['stop_type'] ?? 'Stop'),
                );
              },
            ),

            const SizedBox(height: 32),

            // Action Button
            ElevatedButton.icon(
              onPressed: _navigateToAddTrip,
              icon: const Icon(Icons.directions_bus),
              label: const Text('Add Trip'),
              style: ElevatedButton.styleFrom(
                padding: const EdgeInsets.symmetric(vertical: 16),
                backgroundColor: theme.primaryColor,
                foregroundColor: Colors.white,
              ),
            ),
          ],
        ),
      ),
    );
  }
}
