import 'package:flutter/material.dart';
import '../../services/load_service.dart';
import '../../services/profile_service.dart';
import '../../services/truck_service.dart';
import '../../core/utils/app_logger.dart';
import '../../data/models/user_profile.dart';
import '../../data/models/truck.dart';
import '../../services/rate_con_service.dart';
import 'rate_con_review_screen.dart';
import 'package:url_launcher/url_launcher.dart';

class LoadDetailsScreen extends StatefulWidget {
  final Map<String, dynamic> load;

  const LoadDetailsScreen({super.key, required this.load});

  @override
  State<LoadDetailsScreen> createState() => _LoadDetailsScreenState();
}

class _LoadDetailsScreenState extends State<LoadDetailsScreen> {
  final LoadService _loadService = LoadService();
  final ProfileService _profileService = ProfileService();
  final TruckService _truckService = TruckService();
  final RateConService _rateConService = RateConService();

  bool _isLoading = false;
  Map<String, dynamic>? _assignment;
  List<dynamic> _stops = [];

  @override
  void initState() {
    super.initState();
    _parseStops();
    _fetchAssignment();
  }

  void _parseStops() {
    final rc = widget.load['rate_confirmations'];
    if (rc != null && rc['rc_stops'] != null) {
      if (mounted) {
        setState(() {
          _stops = (rc['rc_stops'] as List<dynamic>);
          _stops.sort((a, b) =>
              (a['stop_sequence'] ?? 0).compareTo(b['stop_sequence'] ?? 0));
        });
      }
    }
  }

  Future<void> _fetchAssignment() async {
    setState(() => _isLoading = true);
    try {
      final assignment = await _loadService.getAssignment(widget.load['id']);
      if (mounted) {
        setState(() {
          _assignment = assignment;
          _isLoading = false;
        });
      }
    } catch (e, stack) {
      if (mounted) {
        setState(() => _isLoading = false);
        AppLogger.e('Error fetching assignment', e, stack);
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('Error fetching assignment: $e')),
        );
      }
    }
  }

  Future<void> _showAssignDialog() async {
    // Fetch drivers and trucks
    // Ideally use a specialized widget or separate screen for selection
    // implementing a simple dialog here for MVP

    UserProfile? selectedDriver;
    Truck? selectedTruck;

    // Fetch lists
    List<UserProfile> drivers = [];
    List<Truck> trucks = [];

    try {
      final orgId = widget.load['organization_id'];
      drivers = await _profileService.getProfilesByRole(orgId, 'driver');
      trucks = await _truckService.getTrucks(orgId);
    } catch (e, stack) {
      AppLogger.e('Error loading resources', e, stack);
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text('Error loading resources: $e')),
      );
      return;
    }

    if (!mounted) return;

    await showDialog(
      context: context,
      builder: (context) => StatefulBuilder(
        builder: (context, setState) => AlertDialog(
          title: const Text('Assign Driver & Truck'),
          content: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              DropdownButtonFormField<UserProfile>(
                decoration: const InputDecoration(labelText: 'Driver'),
                items: drivers.map((d) {
                  return DropdownMenuItem(
                    value: d,
                    child: Text(d.fullName),
                  );
                }).toList(),
                onChanged: (val) => setState(() => selectedDriver = val),
              ),
              const SizedBox(height: 16),
              DropdownButtonFormField<Truck>(
                decoration: const InputDecoration(labelText: 'Truck'),
                items: trucks.map((t) {
                  return DropdownMenuItem(
                    value: t,
                    child: Text('${t.truckNumber} ${t.make}'),
                  );
                }).toList(),
                onChanged: (val) => setState(() => selectedTruck = val),
              ),
            ],
          ),
          actions: [
            TextButton(
              onPressed: () => Navigator.pop(context),
              child: const Text('Cancel'),
            ),
            ElevatedButton(
              onPressed: (selectedDriver != null && selectedTruck != null)
                  ? () {
                      Navigator.pop(context);
                      _performAssignment(selectedDriver!, selectedTruck!);
                    }
                  : null,
              child: const Text('Assign'),
            ),
          ],
        ),
      ),
    );
  }

  Future<void> _performAssignment(UserProfile driver, Truck truck) async {
    setState(() => _isLoading = true);
    try {
      await _loadService.assignLoad(
        loadId: widget.load['id'],
        organizationId: widget.load['organization_id'],
        driverId: driver.id,
        truckId: truck.id,
      );
      await _fetchAssignment();
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Assignment successful')),
      );
    } catch (e, stack) {
      if (mounted) {
        setState(() => _isLoading = false);
        AppLogger.e('Error assigning', e, stack);
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('Error assigning: $e')),
        );
      }
    }
  }

  Future<void> _createDispatchSheet() async {
    setState(() => _isLoading = true);
    try {
      await _loadService.generateDispatchSheet(widget.load['id']);
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Dispatch sheet generated and sent.')),
      );
      setState(() => _isLoading = false);
    } catch (e, stack) {
      if (mounted) {
        setState(() => _isLoading = false);
        AppLogger.e('Error creating dispatch sheet', e, stack);
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('Error creating dispatch sheet: $e')),
        );
      }
    }
  }

  void _startTrip() {
    // Navigate to trip creation/start screen, passing assignment details
    // For now showing SnackBar as placeholder for "Start Trip" logic integration
    ScaffoldMessenger.of(context).showSnackBar(
      const SnackBar(content: Text('Starting Trip... (Logic pending)')),
    );
    // Typically:
    // Navigator.pushNamed(context, '/trip/new', arguments: { 'load': widget.load, 'assignment': _assignment });
  }

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final rate = (widget.load['primary_rate'] ?? 0).toString();

    return DefaultTabController(
      length: 2,
      child: Scaffold(
        appBar: AppBar(
          title: const Text('Load Details'),
          bottom: const TabBar(
            tabs: [
              Tab(text: 'Details'),
              Tab(text: 'Documents'),
            ],
          ),
        ),
        body: _isLoading && _assignment == null
            ? const Center(child: CircularProgressIndicator())
            : TabBarView(
                children: [
                  _buildDetailsTab(theme, rate),
                  _buildDocumentsTab(),
                ],
              ),
      ),
    );
  }

  Widget _buildDetailsTab(ThemeData theme, String rate) {
    return SingleChildScrollView(
      padding: const EdgeInsets.all(16),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          // Info Card
          Card(
            elevation: 2,
            child: Padding(
              padding: const EdgeInsets.all(16),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text('Load #${widget.load['broker_load_id'] ?? "Unknown"}',
                      style: theme.textTheme.titleLarge),
                  const SizedBox(height: 8),
                  Text('Broker: ${widget.load['broker_name']}'),
                  Text('Rate: \$$rate',
                      style: const TextStyle(
                          color: Colors.green, fontWeight: FontWeight.bold)),
                  const SizedBox(height: 8),
                  Text(
                      'Status: ${(widget.load['status'] ?? "Created").toUpperCase()}'),
                ],
              ),
            ),
          ),
          const SizedBox(height: 16),

          // Assignment Section
          Text('Assignment',
              style: theme.textTheme.titleMedium
                  ?.copyWith(fontWeight: FontWeight.bold)),
          const SizedBox(height: 8),
          if (_assignment != null)
            Card(
              color: Colors.blue.shade50,
              child: ListTile(
                leading: const Icon(Icons.check_circle,
                    color: Colors.green, size: 32),
                title: Text(
                    _assignment!['driver']['full_name'] ?? 'Unknown Driver'),
                subtitle: Text(
                    'Truck: ${_assignment!['truck']['truck_number'] ?? "N/A"}'),
                trailing: IconButton(
                    icon: const Icon(Icons.edit), onPressed: _showAssignDialog),
              ),
            )
          else
            Card(
              child: Padding(
                padding: const EdgeInsets.all(16),
                child: Column(
                  children: [
                    const Text('No Driver Assigned',
                        style: TextStyle(color: Colors.grey)),
                    const SizedBox(height: 8),
                    ElevatedButton(
                      onPressed: _showAssignDialog,
                      child: const Text('Assign Driver/Truck'),
                    ),
                  ],
                ),
              ),
            ),

          const SizedBox(height: 24),

          // Actions
          if (_assignment != null) ...[
            ElevatedButton.icon(
              onPressed: _startTrip,
              icon: const Icon(Icons.play_arrow),
              label: const Text('Start Trip'),
              style: ElevatedButton.styleFrom(
                  backgroundColor: Colors.green,
                  foregroundColor: Colors.white,
                  padding: const EdgeInsets.symmetric(vertical: 16)),
            ),
            const SizedBox(height: 12),
            OutlinedButton.icon(
              onPressed: _createDispatchSheet,
              icon: const Icon(Icons.file_copy),
              label: const Text('Create Dispatch Sheet'),
              style: OutlinedButton.styleFrom(
                  padding: const EdgeInsets.symmetric(vertical: 16)),
            )
          ],

          const SizedBox(height: 24),

          const SizedBox(height: 24),

          // Rate Con Summary Link
          if (widget.load['rate_confirmations'] != null)
            _buildRateConSummaryCard(widget.load['rate_confirmations']),

          const SizedBox(height: 24),

          // Stops List
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
              return Card(
                margin: const EdgeInsets.only(bottom: 12),
                child: ListTile(
                  leading: CircleAvatar(
                    backgroundColor: theme.colorScheme.primary.withOpacity(0.1),
                    child: Text('${index + 1}',
                        style: TextStyle(color: theme.colorScheme.primary)),
                  ),
                  title: Text(stop['facility_address'] ?? "Unknown Address",
                      style: const TextStyle(fontWeight: FontWeight.bold)),
                  subtitle: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(stop['stop_type']?.toUpperCase() ?? "STOP"),
                      if (stop['special_instructions'] != null &&
                          stop['special_instructions'].isNotEmpty)
                        Text('Notes: ${stop['special_instructions']}',
                            style:
                                const TextStyle(fontStyle: FontStyle.italic)),
                    ],
                  ),
                  isThreeLine: true,
                ),
              );
            },
          ),

          // Commodities
          if (_stops.isNotEmpty)
            _buildCommoditiesSection(_stops
                .expand((s) => (s['rc_commodities'] as List<dynamic>?) ?? [])
                .toList()),
        ],
      ),
    );
  }

  Widget _buildRateConSummaryCard(Map<String, dynamic> rc) {
    return Card(
      child: ListTile(
        leading: const Icon(Icons.description, color: Colors.blue),
        title: const Text('View Rate Confirmation Details'),
        subtitle: Text('Status: ${rc['status'].toString().toUpperCase()}'),
        trailing: const Icon(Icons.arrow_forward_ios, size: 16),
        onTap: () {
          // Navigate to distinct Rate Con Review/Detail Screen
          Navigator.push(
            context,
            MaterialPageRoute(
              builder: (context) =>
                  RateConReviewScreen(rateConId: rc['rate_con_id']),
            ),
          );
        },
      ),
    );
  }

  Widget _buildDocumentsTab() {
    final rc = widget.load['rate_confirmations'];
    if (rc == null) return const Center(child: Text('No documents available'));

    return ListView(
      padding: const EdgeInsets.all(16),
      children: [
        if (rc != null)
          Card(
            child: ListTile(
              leading: const Icon(Icons.picture_as_pdf, color: Colors.red),
              title: const Text('Original Rate Confirmation PDF'),
              trailing: const Icon(Icons.download),
              onTap: () => _openDocument(rc['document_id']),
            ),
          ),
        // Placeholder for other docs like BOL
        // const Card(child: ListTile(leading: Icon(Icons.insert_drive_file), title: Text('Bill of Lading (Coming Soon)'))),
      ],
    );
  }

  Future<void> _openDocument(String? documentId) async {
    if (documentId == null) {
      ScaffoldMessenger.of(context)
          .showSnackBar(const SnackBar(content: Text('No document ID linked')));
      return;
    }

    try {
      final url = await _rateConService.getDocumentUrl(documentId);
      if (url != null) {
        if (await canLaunchUrl(Uri.parse(url))) {
          await launchUrl(Uri.parse(url), mode: LaunchMode.externalApplication);
        } else {
          if (mounted)
            ScaffoldMessenger.of(context).showSnackBar(
                const SnackBar(content: Text('Could not launch document URL')));
        }
      } else {
        if (mounted)
          ScaffoldMessenger.of(context).showSnackBar(
              const SnackBar(content: Text('Could not generate document URL')));
      }
    } catch (e, stack) {
      AppLogger.e('Error opening document', e, stack);
      if (mounted)
        ScaffoldMessenger.of(context).showSnackBar(
            SnackBar(content: Text('Error opening document: $e')));
    }
  }

  Widget _buildCommoditiesSection(List<dynamic> commodities) {
    if (commodities.isEmpty) return const SizedBox.shrink();

    final theme = Theme.of(context);
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        const SizedBox(height: 24),
        Text('Commodities',
            style: theme.textTheme.titleMedium
                ?.copyWith(fontWeight: FontWeight.bold)),
        const SizedBox(height: 8),
        ...commodities.map((c) {
          final weight =
              c['weight_lbs'] != null ? '${c['weight_lbs']} lbs' : 'N/A';
          final count = c['quantity'] != null ? 'Qty: ${c['quantity']}' : '';
          return Card(
            margin: const EdgeInsets.only(bottom: 8),
            child: ListTile(
              title: Text(c['description'] ?? 'Unknown Commodity',
                  style: const TextStyle(fontWeight: FontWeight.bold)),
              subtitle: Text('$weight ${count.isNotEmpty ? '• $count' : ''}'),
            ),
          );
        }).toList(),
      ],
    );
  }
}
