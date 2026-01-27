import 'package:flutter/material.dart';
import '../../services/load_service.dart';
import '../../services/profile_service.dart';
import '../../services/truck_service.dart';
import '../../core/utils/app_logger.dart';
import '../../data/models/user_profile.dart';
import '../../data/models/truck.dart';
import '../../data/models/trailer.dart';
import '../../services/rate_con_service.dart';

import 'rate_con_review_screen.dart';
import 'package:url_launcher/url_launcher.dart';
import 'trip_screens.dart';
import '../../services/trip_service.dart';
import '../../presentation/themes/app_theme.dart'; // For DualLanguageText
import 'package:geolocator/geolocator.dart'; // Add geolocator
import '../../l10n/app_localizations.dart'; // Correct localization import

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

  bool _isTripActiveForLoad = false;
  final TripService _tripService = TripService();

  Map<String, dynamic>? _getRateCon() {
    final rc = widget.load['rate_confirmations'];
    if (rc is List && rc.isNotEmpty) {
      return rc.first as Map<String, dynamic>;
    } else if (rc is Map<String, dynamic>) {
      return rc;
    }
    return null;
  }

  @override
  void initState() {
    super.initState();
    _parseStops();
    _fetchAssignment();
    _checkActiveTrip();
  }

  Future<void> _checkActiveTrip() async {
    try {
      final trip = await _tripService.getTripByLoadId(widget.load['id']);
      if (trip != null) {
        if (mounted) {
          setState(() {
            _isTripActiveForLoad = true;
          });
          // Also fetch stops from the trip if available, as they might have updated statuses
          if (trip.load != null && trip.load!['rate_confirmations'] != null) {
            final rc = trip.load!['rate_confirmations'];
            if (rc['rc_stops'] != null) {
              _stops = List.from(rc['rc_stops']);
              _stops.sort((a, b) => (a['sequence_number'] ?? 0)
                  .compareTo(b['sequence_number'] ?? 0));
            }
          }
          _calculateCurrentStop();
        }
      }
    } catch (e) {
      AppLogger.w('Failed to check active trip status', e);
    }
  }

  void _parseStops() {
    final rc = _getRateCon();
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

  Map<String, dynamic>? _currentStop;

  void _calculateCurrentStop() {
    if (!_isTripActiveForLoad || _stops.isEmpty) return;

    // Debug logging
    AppLogger.d('DEBUG: _stops content: $_stops');
    for (var s in _stops) {
      AppLogger.d('DEBUG: Stop ID: ${s['id']}, Type: ${s['stop_type']}');
    }

    // Find first stop that is not completed or skipped
    final stop = _stops.firstWhere(
      (s) => s['status'] != 'COMPLETED' && s['status'] != 'SKIPPED',
      orElse: () => null,
    );
    if (mounted) {
      setState(() {
        _currentStop = stop;
      });
    }
  }

  Future<void> _updateStopStatus(String status) async {
    if (_currentStop == null) return;
    if (_currentStop!['id'] == null) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Error: Stop ID is missing')),
      );
      return;
    }

    setState(() => _isLoading = true);
    try {
      final now = DateTime.now();
      await _tripService.updateStopStatus(
        stopId: _currentStop!['id'],
        status: status,
        actualArrival: status == 'ARRIVED' ? now : null,
        actualDeparture: status == 'COMPLETED' ? now : null,
      );

      // Refresh trip status
      await _checkActiveTrip();
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text('Stop updated to $status')),
      );
      setState(() => _isLoading = false);
    } catch (e) {
      if (mounted) {
        setState(() => _isLoading = false);
        AppLogger.e('Error updating stop', e);
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('Error updating stop: $e')),
        );
      }
    }
  }

  Future<void> _handleArrivalRequest() async {
    bool serviceEnabled;
    LocationPermission permission;

    // Test if location services are enabled.
    serviceEnabled = await Geolocator.isLocationServiceEnabled();
    if (!serviceEnabled) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
            const SnackBar(content: Text('Location services are disabled.')));
      }
      return;
    }

    permission = await Geolocator.checkPermission();
    if (permission == LocationPermission.denied) {
      permission = await Geolocator.requestPermission();
      if (permission == LocationPermission.denied) {
        if (mounted) {
          ScaffoldMessenger.of(context).showSnackBar(SnackBar(
              content: Text(
                  AppLocalizations.of(context)!.locationPermissionDenied)));
        }
        return;
      }
    }

    if (permission == LocationPermission.deniedForever) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(const SnackBar(
            content: Text(
                'Location permissions are permanently denied, we cannot request permissions.')));
      }
      return;
    }

    // When we reach here, permissions are granted and we can
    // continue accessing the position of the device.
    setState(() => _isLoading = true);
    try {
      final position = await Geolocator.getCurrentPosition();
      setState(() => _isLoading = false);
      if (mounted) {
        _showArrivalDialog(position);
      }
    } catch (e) {
      setState(() => _isLoading = false);
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
            SnackBar(content: Text('Error getting location: $e')));
      }
    }
  }

  void _showArrivalDialog(Position position) {
    if (_currentStop == null) return;
    final l10n = AppLocalizations.of(context)!;
    final destinationName =
        _currentStop!['facility_address'] ?? "Unknown Location";

    showDialog(
      context: context,
      builder: (context) => AlertDialog(
        title: const Text('Arrived at Stop'),
        content: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text(l10n.confirmReachedDestination(destinationName)),
            const SizedBox(height: 8),
            Text(l10n.currentLocation(position.latitude.toStringAsFixed(4),
                position.longitude.toStringAsFixed(4))),
          ],
        ),
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
        title: const Text('Complete Stop'),
        content: const Text('Mark this stop as completed?'),
        actions: [
          TextButton(
              onPressed: () => Navigator.pop(context),
              child: const Text('Cancel')),
          ElevatedButton(
            style: ElevatedButton.styleFrom(
                backgroundColor: Colors.green, foregroundColor: Colors.white),
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
    List<UserProfile> drivers = [];
    List<Truck> trucks = [];
    List<Trailer> trailers = [];

    Truck? selectedTruck;
    Trailer? selectedTrailer;

    try {
      final orgId = widget.load['organization_id'];
      drivers = await _profileService.getProfilesByRole(orgId, 'driver',
          availabilityStatus: 'AVAILABLE');
      trucks =
          await _truckService.getTrucks(orgId, availabilityStatus: 'AVAILABLE');
      trailers = await _truckService.getTrailers(orgId,
          availabilityStatus: 'AVAILABLE');
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
              const SizedBox(height: 16),
              DropdownButtonFormField<Trailer>(
                decoration: const InputDecoration(labelText: 'Trailer'),
                items: trailers.map((t) {
                  return DropdownMenuItem(
                    value: t,
                    child: Text('${t.trailerNumber} ${t.trailerType ?? ""}'),
                  );
                }).toList(),
                onChanged: (val) => setState(() => selectedTrailer = val),
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
                      _performAssignment(
                          selectedDriver!, selectedTruck!, selectedTrailer);
                    }
                  : null,
              child: const Text('Assign'),
            ),
          ],
        ),
      ),
    );
  }

  Future<void> _performAssignment(
      UserProfile driver, Truck truck, Trailer? trailer) async {
    setState(() => _isLoading = true);
    try {
      await _loadService.assignLoad(
        loadId: widget.load['id'],
        organizationId: widget.load['organization_id'],
        driverId: driver.id,
        truckId: truck.id,
        trailerId: trailer?.id,
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

  Future<void> _createInvoice() async {
    setState(() => _isLoading = true);
    try {
      await _loadService.generateInvoice(widget.load['id']);
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Invoice generated and sent.')),
      );
      setState(() => _isLoading = false);
    } catch (e, stack) {
      if (mounted) {
        setState(() => _isLoading = false);
        AppLogger.e('Error creating invoice', e, stack);
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('Error creating invoice: $e')),
        );
      }
    }
  }

  void _startTrip() {
    if (_assignment == null) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Please assign a driver and truck first')),
      );
      return;
    }

    // Parse stops to find origin and destination
    String? origin;
    String? destination;

    if (_stops.isNotEmpty) {
      // Assuming sorted by sequence
      origin = _stops.first['facility_address'];
      destination = _stops.last['facility_address'];
    }

    Navigator.push(
      context,
      MaterialPageRoute(
        builder: (context) => CreateTripScreen(
          loadId: widget.load['id'],
          originAddress: origin,
          destinationAddress: destination,
          brokerName: widget.load['broker_name'],
          rate: (widget.load['primary_rate'] as num?)?.toDouble(),
        ),
      ),
    );
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
                      style: ElevatedButton.styleFrom(
                          padding: const EdgeInsets.symmetric(
                              horizontal: 24, vertical: 12)),
                      child: const DualLanguageText(
                        primaryText: 'Assign Driver/Truck',
                        subtitleText: 'ਡਰਾਈਵਰ/ਟਰੱਕ ਨਿਰਧਾਰਤ ਕਰੋ',
                        alignment: CrossAxisAlignment.center,
                        primaryStyle: TextStyle(fontWeight: FontWeight.bold),
                      ),
                    ),
                  ],
                ),
              ),
            ),

          const SizedBox(height: 24),

          // Actions
          if (_assignment != null) ...[
            if (_isTripActiveForLoad && _currentStop != null)
              if (_currentStop!['status'] == 'ARRIVED')
                ElevatedButton(
                  onPressed: _showDepartureDialog,
                  style: ElevatedButton.styleFrom(
                      backgroundColor: Colors.green,
                      foregroundColor: Colors.white,
                      padding: const EdgeInsets.symmetric(vertical: 16)),
                  child: const DualLanguageText(
                    primaryText: 'Complete Stop',
                    subtitleText: 'ਸਟਾਪ ਪੂਰਾ ਕਰੋ',
                    primaryStyle: TextStyle(
                        fontSize: 16,
                        fontWeight: FontWeight.bold,
                        color: Colors.white),
                    subtitleStyle:
                        TextStyle(fontSize: 12, color: Colors.white70),
                    alignment: CrossAxisAlignment.center,
                  ),
                )
              else
                ElevatedButton(
                  onPressed: _handleArrivalRequest,
                  style: ElevatedButton.styleFrom(
                      backgroundColor: AppTheme.accentColor,
                      foregroundColor: Colors.white,
                      padding: const EdgeInsets.symmetric(vertical: 16)),
                  child: DualLanguageText(
                    primaryText: AppLocalizations.of(context)!
                        .confirmReachedDestination(
                            _currentStop!['facility_address'] ?? ""),
                    subtitleText: AppLocalizations.of(context)!
                        .confirmReachedDestinationSubtitle(
                            _currentStop!['facility_address'] ?? ""),
                    primaryStyle: const TextStyle(
                        fontSize: 16,
                        fontWeight: FontWeight.bold,
                        color: Colors.white),
                    subtitleStyle:
                        const TextStyle(fontSize: 12, color: Colors.white70),
                    alignment: CrossAxisAlignment.center,
                    textAlign: TextAlign.center,
                  ),
                )
            else if (_isTripActiveForLoad)
              // Trip active but no stops or all done?
              ElevatedButton(
                onPressed: () => Navigator.pushNamed(context, '/trip/active'),
                style: ElevatedButton.styleFrom(
                    backgroundColor: Colors.blueGrey,
                    foregroundColor: Colors.white,
                    padding: const EdgeInsets.symmetric(vertical: 16)),
                child: const DualLanguageText(
                  primaryText: 'Trip Active - View Details',
                  subtitleText: 'ਟ੍ਰਿਪ ਐਕਟਿਵ - ਵੇਰਵੇ ਵੇਖੋ',
                  primaryStyle: TextStyle(
                      fontSize: 16,
                      fontWeight: FontWeight.bold,
                      color: Colors.white),
                  subtitleStyle: TextStyle(fontSize: 12, color: Colors.white70),
                  alignment: CrossAxisAlignment.center,
                ),
              )
            else
              ElevatedButton(
                onPressed: _startTrip,
                style: ElevatedButton.styleFrom(
                    backgroundColor: Colors.green,
                    foregroundColor: Colors.white,
                    padding: const EdgeInsets.symmetric(vertical: 16)),
                child: const DualLanguageText(
                  primaryText: 'Start Trip',
                  subtitleText: 'ਯਾਤਰਾ ਸ਼ੁਰੂ ਕਰੋ',
                  primaryStyle: TextStyle(
                      fontSize: 16,
                      fontWeight: FontWeight.bold,
                      color: Colors.white),
                  subtitleStyle: TextStyle(fontSize: 12, color: Colors.white70),
                  alignment: CrossAxisAlignment.center,
                ),
              ),
            const SizedBox(height: 12),
            OutlinedButton(
              onPressed: _createDispatchSheet,
              style: OutlinedButton.styleFrom(
                  padding: const EdgeInsets.symmetric(vertical: 12)),
              child: Row(
                mainAxisAlignment: MainAxisAlignment.center,
                children: [
                  const Icon(Icons.file_copy),
                  const SizedBox(width: 8),
                  const DualLanguageText(
                    primaryText: 'Create Dispatch Sheet',
                    subtitleText: 'ਡਿਸਪੈਚ ਸ਼ੀਟ ਬਣਾਓ',
                    alignment: CrossAxisAlignment.center,
                    primaryStyle: TextStyle(fontWeight: FontWeight.bold),
                  ),
                ],
              ),
            ),
            const SizedBox(height: 12),
            OutlinedButton(
              onPressed: _createInvoice,
              style: OutlinedButton.styleFrom(
                  padding: const EdgeInsets.symmetric(vertical: 12)),
              child: Row(
                mainAxisAlignment: MainAxisAlignment.center,
                children: [
                  const Icon(Icons.receipt),
                  const SizedBox(width: 8),
                  const DualLanguageText(
                    primaryText: 'Create Invoice',
                    subtitleText: 'ਇਨਵੌਇਸ ਬਣਾਓ',
                    alignment: CrossAxisAlignment.center,
                    primaryStyle: TextStyle(fontWeight: FontWeight.bold),
                  ),
                ],
              ),
            )
          ],

          const SizedBox(height: 24),

          const SizedBox(height: 24),

          // Rate Con Summary Link
          if (_getRateCon() != null) _buildRateConSummaryCard(_getRateCon()!),

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
    final rc = _getRateCon();
    if (rc == null) return const Center(child: Text('No documents available'));

    return ListView(
      padding: const EdgeInsets.all(16),
      children: [
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
