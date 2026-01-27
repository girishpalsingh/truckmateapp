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
import 'package:intl/intl.dart'; // Add time formatting
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
  String? _dispatchDocumentId; // New state variable
  String? _activeTripId; // active trip id
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
            _activeTripId = trip.id;
          });
          // Also fetch stops from the trip if available, as they might have updated statuses
          if (trip.load != null && trip.load!['rate_confirmations'] != null) {
            final rcRaw = trip.load!['rate_confirmations'];
            // Handle List vs Map (Supabase returns List for one-to-many)
            final rc = (rcRaw is List && rcRaw.isNotEmpty)
                ? rcRaw.first
                : (rcRaw is Map ? rcRaw : null);

            if (rc != null && rc['rc_stops'] != null) {
              _stops = List.from(rc['rc_stops']);
              _stops.sort((a, b) =>
                  (a['stop_sequence'] ?? 0).compareTo(b['stop_sequence'] ?? 0));
            }
          }
          _dispatchDocumentId = trip.dispatchDocumentId; // capture doc ID
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
    print('Current stop: ${_currentStop}');
    // Check for stop_id (int) or id (string)
    final stopId =
        _currentStop!['stop_id']?.toString() ?? _currentStop!['id']?.toString();

    if (stopId == null) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(content: Text('Error: Stop ID is missing')),
        );
      }
      return;
    }

    setState(() => _isLoading = true);
    try {
      final now = DateTime.now();
      await _tripService.updateStopStatus(
        stopId: stopId,
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
    final rc = _getRateCon();

    // DEBUG LOGGING
    AppLogger.i('DEBUG: _createDispatchSheet called');
    if (rc != null) {
      AppLogger.i('DEBUG: Rate Con found: ${rc['id']} (rc_id: ${rc['rc_id']})');
      AppLogger.i('DEBUG: Rate Con keys: ${rc.keys.toList()}');
    } else {
      AppLogger.e('DEBUG: Rate Con is NULL');
    }

    if (rc == null || rc['id'] == null) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Error: No Rate Confirmation linked')),
      );
      return;
    }

    setState(() => _isLoading = true);
    try {
      AppLogger.i('DEBUG: Calling generateDispatchSheet with ID: ${rc['id']}');

      // Pass the Rate Confirmation UUID directly to bypass load relation issues
      final result = await _loadService.generateDispatchSheet(rc['id'],
          tripId: _activeTripId);
      AppLogger.i('DEBUG: Dispatch Sheet Result: $result');

      final newDocId = result['document_id'] as String?;
      final newUrl = result['url'] as String?;

      if (mounted) {
        setState(() {
          _isLoading = false;
          if (newDocId != null) {
            _dispatchDocumentId = newDocId;
          }
        });

        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(content: Text('Dispatch sheet generated.')),
        );

        if (newUrl != null) {
          // Open immediately
          if (await canLaunchUrl(Uri.parse(newUrl))) {
            await launchUrl(Uri.parse(newUrl),
                mode: LaunchMode.externalApplication);
          }
        }
      }

      await _checkActiveTrip(); // Refresh background state
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
      // Invoice generation requires a TRIP ID, not a Load ID.
      // 1. Find the active trip for this load
      final trip = await _tripService.getTripByLoadId(widget.load['id']);

      if (trip == null) {
        throw Exception(
            'No active trip found for this load. Cannot generate invoice.');
      }

      await _loadService.generateInvoice(trip.id);
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
            if (_dispatchDocumentId != null)
              OutlinedButton(
                onPressed: () => _openDocument(_dispatchDocumentId),
                style: OutlinedButton.styleFrom(
                    padding: const EdgeInsets.symmetric(vertical: 12)),
                child: Row(
                  mainAxisAlignment: MainAxisAlignment.center,
                  children: [
                    const Icon(Icons.visibility),
                    const SizedBox(width: 8),
                    const DualLanguageText(
                      primaryText: 'View Dispatch Sheet',
                      subtitleText: 'ਡਿਸਪੈਚ ਸ਼ੀਟ ਵੇਖੋ',
                      alignment: CrossAxisAlignment.center,
                      primaryStyle: TextStyle(fontWeight: FontWeight.bold),
                    ),
                  ],
                ),
              )
            else
              OutlinedButton(
                onPressed: _isLoading ? null : _createDispatchSheet,
                style: OutlinedButton.styleFrom(
                    padding: const EdgeInsets.symmetric(vertical: 12)),
                child: Row(
                  mainAxisAlignment: MainAxisAlignment.center,
                  children: [
                    if (_isLoading)
                      const SizedBox(
                          width: 20,
                          height: 20,
                          child: CircularProgressIndicator(strokeWidth: 2))
                    else
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

          // Stops Timeline
          Text('Stops',
              style: theme.textTheme.titleMedium
                  ?.copyWith(fontWeight: FontWeight.bold)),
          const SizedBox(height: 8),
          _buildStopsTimeline(theme),
          const SizedBox(height: 8),

          // Commodities
          if (_stops.isNotEmpty)
            _buildCommoditiesSection(_stops
                .expand((s) => (s['rc_commodities'] as List<dynamic>?) ?? [])
                .toList()),
        ],
      ),
    );
  }

  Widget _buildStopsTimeline(ThemeData theme) {
    if (_stops.isEmpty) return const Text('No stops found.');

    return ListView.builder(
      shrinkWrap: true,
      physics: const NeverScrollableScrollPhysics(),
      itemCount: _stops.length,
      itemBuilder: (context, index) {
        final stop = _stops[index];
        final isLast = index == _stops.length - 1;
        final status = stop['status'] ?? 'PENDING';
        final isCompleted = status == 'COMPLETED';
        final isArrived = status == 'ARRIVED';

        // Define colors based on status
        Color dotColor;
        Color lineColor;
        if (isCompleted) {
          dotColor = Colors.green;
          lineColor = Colors.green;
        } else if (isArrived) {
          dotColor = Colors.blue;
          lineColor = Colors.grey.shade300;
        } else {
          dotColor = Colors.grey;
          lineColor = Colors.grey.shade300;
        }

        return IntrinsicHeight(
          child: Row(
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: [
              // Timeline Line and Dot
              Column(
                children: [
                  Container(
                    width: 20,
                    height: 20,
                    decoration: BoxDecoration(
                        color: dotColor,
                        shape: BoxShape.circle,
                        border: Border.all(color: Colors.white, width: 2),
                        boxShadow: [
                          BoxShadow(
                            color: dotColor.withOpacity(0.4),
                            blurRadius: 4,
                            spreadRadius: 1,
                          )
                        ]),
                    child: isCompleted
                        ? const Icon(Icons.check, size: 12, color: Colors.white)
                        : Text(
                            '${index + 1}',
                            style: const TextStyle(
                                color: Colors.white,
                                fontSize: 10,
                                fontWeight: FontWeight.bold),
                            textAlign: TextAlign.center,
                          ),
                  ),
                  if (!isLast)
                    Expanded(
                      child: Container(
                        width: 2,
                        color: lineColor,
                        margin: const EdgeInsets.symmetric(vertical: 4),
                      ),
                    ),
                ],
              ),
              const SizedBox(width: 12),
              // Content
              Expanded(
                child: Padding(
                  padding: const EdgeInsets.only(bottom: 24.0),
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Row(
                        children: [
                          Expanded(
                            child: Text(
                              stop['facility_address'] ?? "Unknown Address",
                              style: TextStyle(
                                fontWeight: FontWeight.bold,
                                fontSize: 16,
                                decoration: isCompleted
                                    ? TextDecoration.lineThrough
                                    : null,
                                color:
                                    isCompleted ? Colors.grey : Colors.black87,
                              ),
                            ),
                          ),
                          if (isCompleted)
                            Container(
                              padding: const EdgeInsets.symmetric(
                                  horizontal: 8, vertical: 2),
                              decoration: BoxDecoration(
                                color: Colors.green.withOpacity(0.1),
                                borderRadius: BorderRadius.circular(4),
                              ),
                              child: const Text(
                                'COMPLETED',
                                style: TextStyle(
                                    fontSize: 10,
                                    fontWeight: FontWeight.bold,
                                    color: Colors.green),
                              ),
                            ),
                        ],
                      ),
                      const SizedBox(height: 4),
                      Text(
                        stop['stop_type']?.toUpperCase() ?? "STOP",
                        style: TextStyle(
                            color: isCompleted
                                ? Colors.grey
                                : theme.colorScheme.primary,
                            fontWeight: FontWeight.w600,
                            fontSize: 12),
                      ),
                      if (stop['scheduled_arrival'] != null)
                        Padding(
                          padding: const EdgeInsets.only(top: 2),
                          child: Text(
                            DateFormat('MMM d, h:mm a').format(
                                DateTime.parse(stop['scheduled_arrival'])
                                    .toLocal()),
                            style: TextStyle(
                                fontSize: 12,
                                fontWeight: FontWeight.w500,
                                color:
                                    isCompleted ? Colors.grey : Colors.black87),
                          ),
                        ),
                      if (stop['special_instructions'] != null &&
                          stop['special_instructions'].isNotEmpty)
                        Padding(
                          padding: const EdgeInsets.only(top: 4),
                          child: Text(
                            'Notes: ${stop['special_instructions']}',
                            style: TextStyle(
                                fontStyle: FontStyle.italic,
                                color: Colors.grey.shade600,
                                fontSize: 12),
                          ),
                        ),
                    ],
                  ),
                ),
              ),
            ],
          ),
        );
      },
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
          final rateConId = rc['id'];
          if (rateConId == null) {
            if (mounted) {
              ScaffoldMessenger.of(context).showSnackBar(
                const SnackBar(
                    content: Text('Error: Rate Confirmation ID is missing')),
              );
            }
            return;
          }
          // Navigate to distinct Rate Con Review/Detail Screen
          Navigator.push(
            context,
            MaterialPageRoute(
              builder: (context) => RateConReviewScreen(rateConId: rateConId),
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
        if (_dispatchDocumentId != null)
          Card(
            child: ListTile(
              leading: const Icon(Icons.assignment, color: Colors.blue),
              title: const Text('Dispatch Sheet'),
              subtitle: const Text('Generated for Driver'),
              trailing: const Icon(Icons.visibility),
              onTap: () => _openDocument(_dispatchDocumentId),
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
