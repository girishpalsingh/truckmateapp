import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:url_launcher/url_launcher.dart';
import '../../data/models/rate_con_model.dart';
import '../../data/models/stop.dart';
import '../../data/models/risk_clause.dart';
import '../../services/rate_con_service.dart';
import '../themes/app_theme.dart';
import '../widgets/rate_con_action_buttons.dart';
import 'trip_screens.dart';
import 'rate_con_clauses_screen.dart';

class RateConReviewScreen extends ConsumerStatefulWidget {
  final String rateConId;

  const RateConReviewScreen({super.key, required this.rateConId});

  @override
  ConsumerState<RateConReviewScreen> createState() =>
      _RateConReviewScreenState();
}

class _RateConReviewScreenState extends ConsumerState<RateConReviewScreen> {
  final RateConService _service = RateConService();
  bool _isLoading = true;
  RateCon? _rateCon;
  String? _error;
  final Map<String, dynamic> _pendingEdits = {};

  @override
  void initState() {
    super.initState();
    _fetchRateCon();
  }

  Future<void> _fetchRateCon() async {
    try {
      final rateCon = await _service.getRateCon(widget.rateConId);
      if (mounted) {
        setState(() {
          _rateCon = rateCon;
          _isLoading = false;
        });
      }
    } catch (e) {
      if (mounted) {
        setState(() {
          _error = e.toString();
          _isLoading = false;
        });
      }
    }
  }

  Future<void> _viewOriginalDocument() async {
    if (_rateCon?.documentId == null) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('No document linked')),
      );
      return;
    }

    try {
      final url = await _service.getDocumentUrl(_rateCon!.documentId!);
      if (url != null) {
        await launchUrl(Uri.parse(url), mode: LaunchMode.externalApplication);
      } else {
        if (mounted) {
          ScaffoldMessenger.of(context).showSnackBar(
            const SnackBar(content: Text('Could not load document')),
          );
        }
      }
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('Error: $e')),
        );
      }
    }
  }

  Future<void> _handleAccept() async {
    if (_rateCon == null) return;

    print('DEBUG: Handling Accept Button Press');
    final createTrip = await showCreateTripDialog(context);
    print('DEBUG: Dialog Result: $createTrip');

    if (createTrip == null) return;

    setState(() => _isLoading = true);

    try {
      print('DEBUG: Calling approveRateCon...');
      final newLoadId =
          await _service.approveRateCon(widget.rateConId, _pendingEdits);
      print('DEBUG: Rate Con Approved. New Load ID: $newLoadId');

      if (!mounted) return;

      if (createTrip) {
        // Get first pickup and last delivery stops for trip creation
        final pickupStop = _rateCon!.stops
            .where((s) => s.stopType == StopType.pickup)
            .firstOrNull;
        final deliveryStop = _rateCon!.stops
            .where((s) => s.stopType == StopType.delivery)
            .lastOrNull;

        Navigator.pushReplacement(
          context,
          MaterialPageRoute(
            builder: (context) => CreateTripScreen(
              originAddress: pickupStop?.address,
              destinationAddress: deliveryStop?.address,
              loadId: newLoadId,
            ),
          ),
        );
      } else {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(
            content: Text('Rate Confirmation Accepted'),
            backgroundColor: Colors.green,
          ),
        );
        Navigator.of(context).popUntil((route) => route.isFirst);
      }
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('Error: $e'), backgroundColor: Colors.red),
        );
        setState(() => _isLoading = false);
      }
    }
  }

  Future<void> _handleReject() async {
    final confirmed = await showDialog<bool>(
      context: context,
      builder: (context) => AlertDialog(
        title: const DualLanguageText(
          primaryText: 'Send Back Rate Con?',
          subtitleText: 'ਰੇਟ ਕੋਨ ਵਾਪਸ ਭੇਜੋ?',
          primaryStyle: TextStyle(fontWeight: FontWeight.bold, fontSize: 20),
        ),
        content: const DualLanguageText(
          primaryText:
              'Are you sure you want to reject this rate confirmation?',
          subtitleText: 'ਕੀ ਤੁਸੀਂ ਇਸ ਰੇਟ ਕਨਫਰਮੇਸ਼ਨ ਨੂੰ ਰੱਦ ਕਰਨਾ ਚਾਹੁੰਦੇ ਹੋ?',
          primaryStyle: TextStyle(fontSize: 16),
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context, false),
            child: const Text('Cancel'),
          ),
          FilledButton(
            onPressed: () => Navigator.pop(context, true),
            style: FilledButton.styleFrom(backgroundColor: Colors.red),
            child: const Text('Reject'),
          ),
        ],
      ),
    );

    if (confirmed != true) return;

    setState(() => _isLoading = true);

    try {
      await _service.rejectRateCon(widget.rateConId);

      if (!mounted) return;

      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
          content: Text('Rate Confirmation Rejected'),
          backgroundColor: Colors.orange,
        ),
      );
      Navigator.of(context).popUntil((route) => route.isFirst);
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('Error: $e'), backgroundColor: Colors.red),
        );
        setState(() => _isLoading = false);
      }
    }
  }

  void _editField(String label, String key, String? currentValue) {
    final controller = TextEditingController(text: currentValue);
    showDialog(
      context: context,
      builder: (context) => AlertDialog(
        title: Text('Edit $label'),
        content: TextField(
          controller: controller,
          decoration: InputDecoration(labelText: label),
          autofocus: true,
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context),
            child: const Text('Cancel'),
          ),
          FilledButton(
            onPressed: () {
              setState(() {
                _pendingEdits[key] = controller.text;
              });
              Navigator.pop(context);
            },
            child: const Text('Save'),
          ),
        ],
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: const DualLanguageText(
          primaryText: 'Review Rate Confirmation',
          subtitleText: 'ਰੇਟ ਕਨਫਰਮੇਸ਼ਨ ਦੀ ਸਮੀਖਿਆ',
          primaryStyle: TextStyle(color: Colors.white),
          subtitleStyle: TextStyle(color: Colors.white70, fontSize: 10),
        ),
        actions: [
          if (_rateCon?.documentId != null)
            IconButton(
              icon: const Icon(Icons.picture_as_pdf),
              onPressed: _viewOriginalDocument,
              tooltip: 'View Original PDF',
            ),
        ],
      ),
      body: _isLoading
          ? const Center(child: CircularProgressIndicator())
          : _error != null
              ? Center(child: Text('Error: $_error'))
              : _rateCon == null
                  ? const Center(child: Text('Rate Confirmation not found'))
                  : Column(
                      children: [
                        Expanded(
                          child: SingleChildScrollView(
                            padding: const EdgeInsets.all(16.0),
                            child: Column(
                              crossAxisAlignment: CrossAxisAlignment.start,
                              children: [
                                // Status Banner and Traffic Light
                                _buildHeaderCard(),
                                const SizedBox(height: 16),

                                // Reference Numbers
                                if (_rateCon!.referenceNumbers.isNotEmpty)
                                  _buildReferenceNumbersSection(),

                                // Broker Details
                                _buildBrokerSection(),

                                // Carrier Details
                                _buildCarrierSection(),

                                // Stops (Pickup/Delivery)
                                if (_rateCon!.stops.isNotEmpty)
                                  _buildStopsSection(),

                                // Financials
                                _buildFinancialsSection(),

                                // Commodity
                                _buildCommoditySection(),

                                // Risk Clauses Button
                                if (_rateCon!.riskClauses.isNotEmpty)
                                  _buildRiskClausesButton(),

                                const SizedBox(
                                    height: 80), // Space for action buttons
                              ],
                            ),
                          ),
                        ),
                        if (_rateCon!.status != 'approved' &&
                            _rateCon!.status != 'rejected')
                          RateConActionButtons(
                            onAccept: _handleAccept,
                            onReject: _handleReject,
                            isLoading: _isLoading,
                          )
                        else if (_rateCon!.status == 'approved')
                          Padding(
                            padding: const EdgeInsets.all(16.0),
                            child: SizedBox(
                              width: double.infinity,
                              child: ElevatedButton.icon(
                                onPressed: () {
                                  Navigator.push(
                                    context,
                                    MaterialPageRoute(
                                      builder: (context) => CreateTripScreen(
                                        // We'll try to get addresses from stops if available
                                        originAddress: _rateCon!.stops
                                            .where((s) =>
                                                s.stopType == StopType.pickup)
                                            .firstOrNull
                                            ?.address,
                                        destinationAddress: _rateCon!.stops
                                            .where((s) =>
                                                s.stopType == StopType.delivery)
                                            .lastOrNull
                                            ?.address,
                                        loadId: widget.rateConId,
                                      ),
                                    ),
                                  );
                                },
                                icon: const Icon(Icons.add_road),
                                label: const Text('Create Trip'),
                                style: ElevatedButton.styleFrom(
                                  padding:
                                      const EdgeInsets.symmetric(vertical: 16),
                                ),
                              ),
                            ),
                          ),
                      ],
                    ),
    );
  }

  Widget _buildHeaderCard() {
    final status = _rateCon!.status;
    Color statusColor = Colors.orange;
    String statusText = 'Under Review';

    if (status == 'approved') {
      statusColor = Colors.green;
      statusText = 'APPROVED';
    } else if (status == 'rejected') {
      statusColor = Colors.red;
      statusText = 'REJECTED';
    }

    return Card(
      elevation: 2,
      child: Padding(
        padding: const EdgeInsets.all(16),
        child: Column(
          children: [
            Row(
              mainAxisAlignment: MainAxisAlignment.spaceBetween,
              children: [
                Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      'Rate Con #${_rateCon!.rateConId}',
                      style: Theme.of(context).textTheme.titleLarge?.copyWith(
                            fontWeight: FontWeight.bold,
                          ),
                    ),
                    const SizedBox(height: 4),
                    Container(
                      padding: const EdgeInsets.symmetric(
                          horizontal: 8, vertical: 4),
                      decoration: BoxDecoration(
                        color: statusColor.withOpacity(0.1),
                        borderRadius: BorderRadius.circular(4),
                      ),
                      child: Text(
                        statusText,
                        style: TextStyle(
                          color: statusColor,
                          fontWeight: FontWeight.bold,
                          fontSize: 12,
                        ),
                      ),
                    ),
                  ],
                ),
                // Traffic Light
                Container(
                  padding: const EdgeInsets.all(12),
                  decoration: BoxDecoration(
                    shape: BoxShape.circle,
                    color: _getTrafficLightColor().withOpacity(0.2),
                  ),
                  child: Text(
                    _rateCon!.trafficLightEmoji,
                    style: const TextStyle(fontSize: 32),
                  ),
                ),
              ],
            ),
          ],
        ),
      ),
    );
  }

  Color _getTrafficLightColor() {
    switch (_rateCon!.overallTrafficLight) {
      case RateConTrafficLight.red:
        return Colors.red;
      case RateConTrafficLight.yellow:
        return Colors.orange;
      case RateConTrafficLight.green:
        return Colors.green;
      case RateConTrafficLight.unknown:
        return Colors.grey;
    }
  }

  Widget _buildReferenceNumbersSection() {
    return _buildSection(
      title: 'Reference Numbers',
      titlePunjabi: 'ਹਵਾਲਾ ਨੰਬਰ',
      child: Wrap(
        spacing: 8,
        runSpacing: 8,
        children: _rateCon!.referenceNumbers.map((ref) {
          return Chip(
            label: Text('${ref.refType}: ${ref.refValue}'),
            backgroundColor:
                Theme.of(context).colorScheme.surfaceContainerHighest,
          );
        }).toList(),
      ),
    );
  }

  Widget _buildBrokerSection() {
    return _buildSection(
      title: 'Broker Details',
      titlePunjabi: 'ਬ੍ਰੋਕਰ ਵੇਰਵੇ',
      child: Column(
        children: [
          _buildEditableRow('Name', 'broker_name', _rateCon!.brokerName),
          _buildEditableRow(
              'MC Number', 'broker_mc_number', _rateCon!.brokerMcNumber),
          _buildEditableRow(
              'Address', 'broker_address', _rateCon!.brokerAddress),
          _buildEditableRow('Phone', 'broker_phone', _rateCon!.brokerPhone),
          _buildEditableRow('Email', 'broker_email', _rateCon!.brokerEmail),
        ],
      ),
    );
  }

  Widget _buildCarrierSection() {
    return _buildSection(
      title: 'Carrier Details',
      titlePunjabi: 'ਕੈਰੀਅਰ ਵੇਰਵੇ',
      child: Column(
        children: [
          _buildEditableRow('Name', 'carrier_name', _rateCon!.carrierName),
          _buildEditableRow(
              'DOT Number', 'carrier_dot_number', _rateCon!.carrierDotNumber),
          _buildEditableRow(
              'Address', 'carrier_address', _rateCon!.carrierAddress),
          _buildEditableRow('Phone', 'carrier_phone', _rateCon!.carrierPhone),
          _buildEditableRow('Email', 'carrier_email', _rateCon!.carrierEmail),
          _buildEditableRow('Equipment', 'carrier_equipment_type',
              _rateCon!.carrierEquipmentType),
          _buildEditableRow('Equip #', 'carrier_equipment_number',
              _rateCon!.carrierEquipmentNumber),
        ],
      ),
    );
  }

  Widget _buildStopsSection() {
    // Sort stops by sequence number
    final sortedStops = List<Stop>.from(_rateCon!.stops)
      ..sort((a, b) => a.sequenceNumber.compareTo(b.sequenceNumber));

    return _buildSection(
      title: 'Stops',
      titlePunjabi: 'ਸਟਾਪ',
      child: Column(
        children: sortedStops.map((stop) => _buildStopCard(stop)).toList(),
      ),
    );
  }

  Widget _buildStopCard(Stop stop) {
    final isPickup = stop.stopType == StopType.pickup;
    final color = isPickup ? Colors.blue : Colors.green;

    return Card(
      margin: const EdgeInsets.only(bottom: 8),
      child: ExpansionTile(
        leading: Icon(
          isPickup ? Icons.upload : Icons.download,
          color: color,
        ),
        title: Text(
          '${stop.displayType} #${stop.sequenceNumber}',
          style: TextStyle(fontWeight: FontWeight.bold, color: color),
        ),
        subtitle: Text(
          stop.address ?? 'Address not specified',
          maxLines: 1,
          overflow: TextOverflow.ellipsis,
        ),
        children: [
          Padding(
            padding: const EdgeInsets.all(16),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                if (stop.address != null)
                  _buildSimpleRow('Address', stop.address!),
                _buildSimpleRow('Schedule', stop.displaySchedule),
                if (stop.contactPerson != null)
                  _buildSimpleRow('Contact', stop.contactPerson!),
                if (stop.phone != null) _buildSimpleRow('Phone', stop.phone!),
                if (stop.email != null) _buildSimpleRow('Email', stop.email!),
                if (stop.specialInstructions != null)
                  Container(
                    margin: const EdgeInsets.only(top: 8),
                    padding: const EdgeInsets.all(12),
                    decoration: BoxDecoration(
                      color: Colors.amber.withOpacity(0.1),
                      borderRadius: BorderRadius.circular(8),
                      border: Border.all(color: Colors.amber.withOpacity(0.3)),
                    ),
                    child: Row(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        const Icon(Icons.warning_amber,
                            color: Colors.amber, size: 20),
                        const SizedBox(width: 8),
                        Expanded(
                          child: Text(
                            stop.specialInstructions!,
                            style: const TextStyle(fontSize: 13),
                          ),
                        ),
                      ],
                    ),
                  ),
              ],
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildFinancialsSection() {
    return _buildSection(
      title: 'Financials',
      titlePunjabi: 'ਵਿੱਤੀ ਵੇਰਵੇ',
      child: Column(
        children: [
          // Total Rate - Prominent
          Container(
            padding: const EdgeInsets.all(16),
            margin: const EdgeInsets.only(bottom: 12),
            decoration: BoxDecoration(
              gradient: LinearGradient(
                colors: [
                  Theme.of(context).colorScheme.primary.withOpacity(0.1),
                  Theme.of(context).colorScheme.primary.withOpacity(0.05),
                ],
              ),
              borderRadius: BorderRadius.circular(12),
            ),
            child: Row(
              mainAxisAlignment: MainAxisAlignment.spaceBetween,
              children: [
                const Text(
                  'Total Rate',
                  style: TextStyle(fontSize: 16, fontWeight: FontWeight.w500),
                ),
                Text(
                  _rateCon!.displayTotalRate,
                  style: TextStyle(
                    fontSize: 24,
                    fontWeight: FontWeight.bold,
                    color: Theme.of(context).colorScheme.primary,
                  ),
                ),
              ],
            ),
          ),

          // Charges breakdown
          if (_rateCon!.charges.isNotEmpty) ...[
            const Divider(),
            ...(_rateCon!.charges.map((charge) => Padding(
                  padding: const EdgeInsets.symmetric(vertical: 4),
                  child: Row(
                    mainAxisAlignment: MainAxisAlignment.spaceBetween,
                    children: [
                      Text(charge.description ?? 'Charge'),
                      Text(charge.displayAmount),
                    ],
                  ),
                ))),
          ],

          const SizedBox(height: 8),
          _buildEditableRow(
              'Payment Terms', 'payment_terms', _rateCon!.paymentTerms),
        ],
      ),
    );
  }

  Widget _buildCommoditySection() {
    return _buildSection(
      title: 'Commodity',
      titlePunjabi: 'ਸਮਾਨ',
      child: Column(
        children: [
          _buildEditableRow('Name', 'commodity_name', _rateCon!.commodityName),
          _buildSimpleRow(
              'Weight',
              _rateCon!.commodityWeight != null
                  ? '${_rateCon!.commodityWeight} ${_rateCon!.commodityUnit ?? 'lbs'}'
                  : 'N/A'),
          _buildSimpleRow(
              'Pallets', _rateCon!.palletCount?.toString() ?? 'N/A'),
        ],
      ),
    );
  }

  Widget _buildRiskClausesButton() {
    final redCount = _rateCon!.riskClauses
        .where((c) => c.trafficLight == TrafficLight.red)
        .length;
    final yellowCount = _rateCon!.riskClauses
        .where((c) => c.trafficLight == TrafficLight.yellow)
        .length;

    return _buildSection(
      title: 'Risk Analysis',
      titlePunjabi: 'ਜੋਖਮ ਵਿਸ਼ਲੇਸ਼ਣ',
      child: InkWell(
        onTap: () {
          Navigator.push(
            context,
            MaterialPageRoute(
              builder: (context) => RateConClausesScreen(
                rateConId: _rateCon!.id,
                clauses: _rateCon!.riskClauses,
              ),
            ),
          );
        },
        child: Container(
          padding: const EdgeInsets.all(16),
          decoration: BoxDecoration(
            color: Colors.red.withOpacity(0.05),
            borderRadius: BorderRadius.circular(12),
            border: Border.all(color: Colors.red.withOpacity(0.2)),
          ),
          child: Row(
            children: [
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      '${_rateCon!.riskClauses.length} Clauses Found',
                      style: const TextStyle(
                        fontWeight: FontWeight.bold,
                        fontSize: 16,
                      ),
                    ),
                    const SizedBox(height: 4),
                    Row(
                      children: [
                        if (redCount > 0) ...[
                          const Text('🔴'),
                          Text(' $redCount '),
                        ],
                        if (yellowCount > 0) ...[
                          const Text('🟡'),
                          Text(' $yellowCount'),
                        ],
                      ],
                    ),
                  ],
                ),
              ),
              const Icon(Icons.arrow_forward_ios, size: 16),
            ],
          ),
        ),
      ),
    );
  }

  Widget _buildSection({
    required String title,
    required String titlePunjabi,
    required Widget child,
  }) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Padding(
          padding: const EdgeInsets.symmetric(vertical: 12),
          child: DualLanguageText(
            primaryText: title,
            subtitleText: titlePunjabi,
            primaryStyle: TextStyle(
              fontSize: 18,
              fontWeight: FontWeight.bold,
              color: Theme.of(context).colorScheme.primary,
            ),
            subtitleStyle: const TextStyle(fontSize: 12, color: Colors.grey),
          ),
        ),
        child,
        const SizedBox(height: 8),
      ],
    );
  }

  Widget _buildSimpleRow(String label, String value) {
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 6),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          SizedBox(
            width: 100,
            child: Text(
              label,
              style: TextStyle(
                fontWeight: FontWeight.w500,
                color: Colors.grey[600],
              ),
            ),
          ),
          Expanded(
            child: Text(value, style: const TextStyle(fontSize: 15)),
          ),
        ],
      ),
    );
  }

  Widget _buildEditableRow(String label, String key, String? value) {
    final isEdited = _pendingEdits.containsKey(key);
    final displayValue = _pendingEdits[key] ?? value ?? 'Tap to add';
    final hasValue = (value != null && value.isNotEmpty) || isEdited;

    return InkWell(
      onLongPress: () => _editField(label, key, _pendingEdits[key] ?? value),
      child: Padding(
        padding: const EdgeInsets.symmetric(vertical: 6),
        child: Row(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            SizedBox(
              width: 100,
              child: Text(
                label,
                style: TextStyle(
                  fontWeight: FontWeight.w500,
                  color: Colors.grey[600],
                ),
              ),
            ),
            Expanded(
              child: Text(
                displayValue,
                style: TextStyle(
                  fontSize: 15,
                  color: hasValue ? null : Colors.grey,
                  fontStyle: hasValue ? FontStyle.normal : FontStyle.italic,
                  fontWeight: isEdited ? FontWeight.bold : FontWeight.normal,
                ),
              ),
            ),
            if (isEdited)
              const Padding(
                padding: EdgeInsets.only(left: 8),
                child: Icon(Icons.edit, size: 14, color: Colors.blue),
              ),
          ],
        ),
      ),
    );
  }
}
