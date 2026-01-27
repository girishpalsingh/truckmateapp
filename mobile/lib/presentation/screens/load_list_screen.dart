import 'package:flutter/material.dart';
import '../../services/load_service.dart';
import '../../data/models/load.dart';

import 'load_details_screen.dart';
import '../themes/app_theme.dart';
import 'package:intl/intl.dart';

class LoadListScreen extends StatefulWidget {
  const LoadListScreen({super.key});

  @override
  State<LoadListScreen> createState() => _LoadListScreenState();
}

class _LoadListScreenState extends State<LoadListScreen> {
  final LoadService _service = LoadService();
  List<Load>? _loads;
  bool _isLoading = true;

  @override
  void initState() {
    super.initState();
    _loadLoads();
  }

  Future<void> _loadLoads() async {
    try {
      final loads = await _service.getLoads();
      if (mounted) {
        setState(() {
          _loads = loads;
          _isLoading = false;
        });
      }
    } catch (e) {
      if (mounted) {
        setState(() => _isLoading = false);
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('Error loading loads: $e')),
        );
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: const DualLanguageText(
          primaryText: 'Loads',
          subtitleText: 'ਲੋਡ',
          primaryStyle: TextStyle(color: Colors.white),
        ),
      ),
      body: _isLoading
          ? const Center(child: CircularProgressIndicator())
          : _loads == null || _loads!.isEmpty
              ? const Center(child: Text('No loads found'))
              : ListView.builder(
                  padding: const EdgeInsets.all(16),
                  itemCount: _loads!.length,
                  itemBuilder: (context, index) {
                    final load = _loads![index];
                    final dateStr = load.createdAt != null
                        ? DateFormat('MMM d, yyyy').format(load.createdAt!)
                        : 'Unknown Date';

                    String? driverName;
                    String? truckNumber;

                    if (load.activeAssignment != null) {
                      final assign = load.activeAssignment!;
                      if (assign['driver'] != null) {
                        driverName = assign['driver']['full_name'];
                      }
                      if (assign['truck'] != null) {
                        truckNumber = assign['truck']['truck_number'];
                      }
                    }

                    return Card(
                      margin: const EdgeInsets.only(bottom: 8),
                      child: Padding(
                        padding: const EdgeInsets.all(8.0),
                        child: ListTile(
                          contentPadding: EdgeInsets.zero,
                          leading: Column(
                            mainAxisAlignment: MainAxisAlignment.center,
                            children: [_buildStatusIcon(load.status)],
                          ),
                          title: Text('Load #${load.brokerLoadId ?? "Unknown"}',
                              style:
                                  const TextStyle(fontWeight: FontWeight.bold)),
                          subtitle: Column(
                            crossAxisAlignment: CrossAxisAlignment.start,
                            children: [
                              Text(load.brokerName ?? "Unknown Broker"),
                              const SizedBox(height: 4),
                              Text('Created: $dateStr',
                                  style: const TextStyle(fontSize: 12)),
                              if (driverName != null) ...[
                                const SizedBox(height: 4),
                                Row(
                                  children: [
                                    const Icon(Icons.person,
                                        size: 14, color: Colors.grey),
                                    const SizedBox(width: 4),
                                    Text(driverName,
                                        style: const TextStyle(
                                            fontWeight: FontWeight.bold,
                                            fontSize: 12)),
                                  ],
                                ),
                              ],
                              if (truckNumber != null) ...[
                                const SizedBox(height: 2),
                                Row(
                                  children: [
                                    const Icon(Icons.local_shipping,
                                        size: 14, color: Colors.grey),
                                    const SizedBox(width: 4),
                                    Text('Truck $truckNumber',
                                        style: const TextStyle(fontSize: 12)),
                                  ],
                                ),
                              ],
                            ],
                          ),
                          trailing: Column(
                            mainAxisAlignment: MainAxisAlignment.center,
                            crossAxisAlignment: CrossAxisAlignment.end,
                            children: [
                              Text(
                                '\$${load.primaryRate?.toStringAsFixed(0) ?? "0"}',
                                style: const TextStyle(
                                    fontWeight: FontWeight.bold,
                                    color: Colors.green,
                                    fontSize: 16),
                              ),
                              const SizedBox(height: 4),
                              Container(
                                padding: const EdgeInsets.symmetric(
                                    horizontal: 8, vertical: 2),
                                decoration: BoxDecoration(
                                  color: _getStatusColor(load.status)
                                      .withOpacity(0.1),
                                  borderRadius: BorderRadius.circular(4),
                                ),
                                child: Text(
                                  load.status.toUpperCase(),
                                  style: TextStyle(
                                      color: _getStatusColor(load.status),
                                      fontSize: 10,
                                      fontWeight: FontWeight.bold),
                                ),
                              ),
                            ],
                          ),
                          onTap: () {
                            Navigator.push(
                              context,
                              MaterialPageRoute(
                                builder: (context) =>
                                    LoadDetailsScreen(load: load.toJson()),
                              ),
                            ).then((_) => _loadLoads());
                          },
                        ),
                      ),
                    );
                  },
                ),
    );
  }

  Widget _buildStatusIcon(String status) {
    IconData icon;
    Color color;

    switch (status.toLowerCase()) {
      case 'completed':
        icon = Icons.check_circle;
        color = Colors.green;
        break;
      case 'assigned':
        icon = Icons.assignment_ind;
        color = Colors.blue;
        break;
      case 'created':
        icon = Icons.new_releases;
        color = Colors.orange;
        break;
      default:
        icon = Icons.help_outline;
        color = Colors.grey;
    }

    return Icon(icon, color: color, size: 32);
  }

  Color _getStatusColor(String status) {
    switch (status.toLowerCase()) {
      case 'completed':
        return Colors.green;
      case 'assigned':
        return Colors.blue;
      case 'created':
        return Colors.orange;
      default:
        return Colors.grey;
    }
  }
}
