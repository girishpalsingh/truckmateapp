import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:supabase_flutter/supabase_flutter.dart';
import 'package:intl/intl.dart';

// Simple model for Rate Con (can be moved to models later)
class RateCon {
  final String id;
  final String? brokerName;
  final String? loadId;
  final double? rateAmount;
  final String? pickupAddress;
  final DateTime? pickupDate;
  final String? deliveryAddress;
  final DateTime? deliveryDate;
  // Add other fields as needed for display

  RateCon({
    required this.id,
    this.brokerName,
    this.loadId,
    this.rateAmount,
    this.pickupAddress,
    this.pickupDate,
    this.deliveryAddress,
    this.deliveryDate,
  });

  factory RateCon.fromJson(Map<String, dynamic> json) {
    return RateCon(
      id: json['id'],
      brokerName: json['broker_name'],
      loadId: json['load_id'],
      rateAmount: json['rate_amount'] != null
          ? (json['rate_amount'] as num).toDouble()
          : null,
      pickupAddress: json['pickup_address'],
      pickupDate: json['pickup_date'] != null
          ? DateTime.tryParse(json['pickup_date'])
          : null,
      deliveryAddress: json['delivery_address'],
      deliveryDate: json['delivery_date'] != null
          ? DateTime.tryParse(json['delivery_date'])
          : null,
    );
  }
}

class RateConReviewScreen extends ConsumerStatefulWidget {
  final String rateConId;

  const RateConReviewScreen({super.key, required this.rateConId});

  @override
  ConsumerState<RateConReviewScreen> createState() =>
      _RateConReviewScreenState();
}

class _RateConReviewScreenState extends ConsumerState<RateConReviewScreen> {
  bool _isLoading = true;
  RateCon? _rateCon;
  String? _error;

  @override
  void initState() {
    super.initState();
    _fetchRateCon();
  }

  Future<void> _fetchRateCon() async {
    try {
      final response = await Supabase.instance.client
          .from('rate_cons')
          .select()
          .eq('id', widget.rateConId)
          .single();

      if (mounted) {
        setState(() {
          _rateCon = RateCon.fromJson(response);
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

  Future<void> _acceptRateCon() async {
    // Logic to accept - maybe update status column if we added one?
    // For now just pop.
    if (!mounted) return;
    ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Rate Confirmation Accepted')));
    Navigator.of(context).pop();
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
                  : SingleChildScrollView(
                      padding: const EdgeInsets.all(16.0),
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          _buildDetailRow('Broker', _rateCon!.brokerName),
                          _buildDetailRow('Load ID', _rateCon!.loadId),
                          const Divider(),
                          _buildDetailRow(
                              'Rate',
                              _rateCon!.rateAmount != null
                                  ? '\$${_rateCon!.rateAmount}'
                                  : null),
                          const Divider(),
                          _buildDetailRow('Pickup', _rateCon!.pickupAddress),
                          _buildDetailRow(
                              'Date',
                              _rateCon!.pickupDate != null
                                  ? DateFormat.yMMMd()
                                      .format(_rateCon!.pickupDate!)
                                  : null),
                          const SizedBox(height: 16),
                          _buildDetailRow(
                              'Delivery', _rateCon!.deliveryAddress),
                          _buildDetailRow(
                              'Date',
                              _rateCon!.deliveryDate != null
                                  ? DateFormat.yMMMd()
                                      .format(_rateCon!.deliveryDate!)
                                  : null),
                          const SizedBox(height: 32),
                          Row(
                            children: [
                              Expanded(
                                child: OutlinedButton(
                                  onPressed: () {
                                    // Edit logic (future task)
                                  },
                                  child: const Text('Edit'),
                                ),
                              ),
                              const SizedBox(width: 16),
                              Expanded(
                                child: FilledButton(
                                  onPressed: _acceptRateCon,
                                  child: const Text('Accept'),
                                ),
                              ),
                            ],
                          ),
                        ],
                      ),
                    ),
    );
  }

  Widget _buildDetailRow(String label, String? value) {
    if (value == null || value.isEmpty) return const SizedBox.shrink();
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
            child: Text(value, style: const TextStyle(fontSize: 16)),
          ),
        ],
      ),
    );
  }
}
