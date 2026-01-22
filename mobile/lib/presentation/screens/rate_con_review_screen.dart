import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:intl/intl.dart';
import '../../data/models/rate_con_model.dart';
import '../../services/rate_con_service.dart';

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

  Future<void> _approveRateCon() async {
    if (_rateCon == null) return;

    setState(() => _isLoading = true);
    try {
      await _service.approveRateCon(widget.rateConId, _pendingEdits);
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
            const SnackBar(content: Text('Rate Confirmation Approved')));
        Navigator.of(context).pop();
      }
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context)
            .showSnackBar(SnackBar(content: Text('Error: $e')));
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
        title: const Text('Review Rate Confirmation'),
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
                                if (_rateCon!.status == 'approved')
                                  Container(
                                    width: double.infinity,
                                    padding: const EdgeInsets.all(8),
                                    margin: const EdgeInsets.only(bottom: 16),
                                    color: Colors.green.withOpacity(0.1),
                                    child: const Text(
                                      'APPROVED',
                                      textAlign: TextAlign.center,
                                      style: TextStyle(
                                          color: Colors.green,
                                          fontWeight: FontWeight.bold),
                                    ),
                                  ),
                                _buildSectionHeader('Load Details'),
                                _buildDetailRow(
                                    'Load ID',
                                    'load_id',
                                    _getDisplayValue(
                                        'load_id', _rateCon!.loadId)),
                                _buildDetailRow(
                                    'Broker',
                                    'broker_name',
                                    _getDisplayValue(
                                        'broker_name', _rateCon!.brokerName)),
                                _buildDetailRow(
                                    'MC Number',
                                    'broker_mc_number',
                                    _getDisplayValue('broker_mc_number',
                                        _rateCon!.brokerMcNumber)),
                                const Divider(),
                                _buildSectionHeader('Rate'),
                                _buildDetailRow(
                                    'Amount',
                                    'rate_amount',
                                    _getDisplayValue('rate_amount',
                                        _rateCon!.rateAmount?.toString())),
                                _buildDetailRow(
                                    'Commodity',
                                    'commodity',
                                    _getDisplayValue(
                                        'commodity', _rateCon!.commodity)),
                                _buildDetailRow(
                                    'Weight',
                                    'weight',
                                    _getDisplayValue('weight',
                                        _rateCon!.weight?.toString())),
                                const Divider(),
                                _buildSectionHeader('Pickup'),
                                _buildDetailRow(
                                    'Address',
                                    'pickup_address',
                                    _getDisplayValue('pickup_address',
                                        _rateCon!.pickupAddress)),
                                _buildSimpleRow(
                                    'Date',
                                    _rateCon!.pickupDate != null
                                        ? DateFormat.yMMMd()
                                            .format(_rateCon!.pickupDate!)
                                        : 'N/A'),
                                const SizedBox(height: 16),
                                _buildSectionHeader('Delivery'),
                                _buildDetailRow(
                                    'Address',
                                    'delivery_address',
                                    _getDisplayValue('delivery_address',
                                        _rateCon!.deliveryAddress)),
                                _buildSimpleRow(
                                    'Date',
                                    _rateCon!.deliveryDate != null
                                        ? DateFormat.yMMMd()
                                            .format(_rateCon!.deliveryDate!)
                                        : 'N/A'),
                                const SizedBox(height: 16),
                                _buildSectionHeader('Notes'),
                                _buildDetailRow('Notes', 'notes',
                                    _getDisplayValue('notes', _rateCon!.notes)),
                              ],
                            ),
                          ),
                        ),
                        if (_rateCon!.status != 'approved')
                          Padding(
                            padding: const EdgeInsets.all(16.0),
                            child: SizedBox(
                              width: double.infinity,
                              height: 50,
                              child: FilledButton(
                                onPressed: _approveRateCon,
                                child: const Text('Approve & Submit'),
                              ),
                            ),
                          ),
                      ],
                    ),
    );
  }

  String? _getDisplayValue(String key, String? originalValue) {
    if (_pendingEdits.containsKey(key)) {
      return _pendingEdits[key];
    }
    return originalValue;
  }

  Widget _buildSectionHeader(String title) {
    return Padding(
      padding: const EdgeInsets.only(bottom: 8.0),
      child: Text(
        title,
        style: TextStyle(
            fontSize: 18,
            fontWeight: FontWeight.bold,
            color: Theme.of(context).colorScheme.primary),
      ),
    );
  }

  // Non-editable row for simple display
  Widget _buildSimpleRow(String label, String? value) {
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 8.0),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          SizedBox(
            width: 100,
            child: Text(
              label,
              style: const TextStyle(
                  fontWeight: FontWeight.bold, color: Colors.grey),
            ),
          ),
          Expanded(
            child: Text(
              value ?? 'N/A',
              style: const TextStyle(fontSize: 16),
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildDetailRow(String label, String key, String? value) {
    final isEdited = _pendingEdits.containsKey(key);
    final displayValue = value == null || value.isEmpty ? 'Tap to add' : value;
    final isPlaceholder = value == null || value.isEmpty;

    return InkWell(
      onLongPress: () => _editField(label, key, value),
      child: Padding(
        padding: const EdgeInsets.symmetric(vertical: 8.0),
        child: Row(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            SizedBox(
              width: 100,
              child: Text(
                label,
                style: const TextStyle(
                    fontWeight: FontWeight.bold, color: Colors.grey),
              ),
            ),
            Expanded(
              child: Text(
                displayValue,
                style: TextStyle(
                    fontSize: 16,
                    color: isPlaceholder
                        ? Colors.grey
                        : (isEdited ? Colors.blue : null),
                    fontStyle: isPlaceholder || isEdited
                        ? FontStyle.italic
                        : FontStyle.normal,
                    fontWeight: isEdited ? FontWeight.bold : FontWeight.normal),
              ),
            ),
            if (isEdited)
              const Padding(
                padding: EdgeInsets.only(left: 8.0),
                child: Icon(Icons.edit, size: 16, color: Colors.blue),
              ),
          ],
        ),
      ),
    );
  }
}
