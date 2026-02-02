import 'package:flutter/material.dart';
import '../../services/detention_service.dart';
import '../../core/utils/app_logger.dart';

class DetentionReviewScreen extends StatefulWidget {
  final String detentionRecordId;
  final Map<String, dynamic> initialData;

  const DetentionReviewScreen({
    super.key,
    required this.detentionRecordId,
    required this.initialData,
  });

  @override
  State<DetentionReviewScreen> createState() => _DetentionReviewScreenState();
}

class _DetentionReviewScreenState extends State<DetentionReviewScreen> {
  final DetentionService _detentionService = DetentionService();
  final _formKey = GlobalKey<FormState>();

  late TextEditingController _rateController;
  late TextEditingController _hoursController;
  late TextEditingController _payableController;
  late TextEditingController _bolController;
  late TextEditingController _facilityController;

  bool _isLoading = false;
  double _totalDue = 0.0;

  @override
  void initState() {
    super.initState();
    _rateController = TextEditingController(
        text: widget.initialData['rate_per_hour'].toString());
    _hoursController = TextEditingController(
        text: widget.initialData['total_hours'].toStringAsFixed(2));
    _payableController = TextEditingController(
        text: widget.initialData['payable_hours'].toStringAsFixed(2));
    _bolController =
        TextEditingController(text: widget.initialData['bol_number'] ?? '');
    _facilityController = TextEditingController(
        text: widget.initialData['facility_address'] ?? '');

    _calculateTotal();
  }

  void _calculateTotal() {
    final rate = double.tryParse(_rateController.text) ?? 0.0;
    final payable = double.tryParse(_payableController.text) ?? 0.0;
    setState(() {
      _totalDue = rate * payable;
    });
  }

  Future<void> _submitInvoice() async {
    if (!_formKey.currentState!.validate()) return;

    setState(() => _isLoading = true);
    try {
      final invoiceDetails = {
        'rate_per_hour': double.parse(_rateController.text),
        'total_hours': double.parse(_hoursController.text),
        'payable_hours': double.parse(_payableController.text),
        'total_due': _totalDue,
        'bol_number': _bolController.text,
        'facility_address': _facilityController.text,
        'currency': 'USD',
      };

      final invoice = await _detentionService.createInvoice(
        detentionRecordId: widget.detentionRecordId,
        invoiceDetails: invoiceDetails,
      );

      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(content: Text('Invoice created successfully!')),
        );
        Navigator.pop(context, invoice.pdfUrl); // Return with PDF URL if needed
      }
    } catch (e, stack) {
      if (mounted) {
        AppLogger.e('Error creating invoice', e, stack);
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('Error creating invoice: $e')),
        );
        setState(() => _isLoading = false);
      }
    }
  }

  // Helper to re-calculate payable hours when logic changes (e.g. rate or free time? No simple calc here)

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(title: const Text('Review Detention Invoice')),
      body: SingleChildScrollView(
        padding: const EdgeInsets.all(24),
        child: Form(
          key: _formKey,
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: [
              const Text(
                'Verify Invoice Details',
                style: TextStyle(fontSize: 18, fontWeight: FontWeight.bold),
              ),
              const SizedBox(height: 24),
              TextFormField(
                controller: _facilityController,
                decoration:
                    const InputDecoration(labelText: 'Facility Address'),
                validator: (val) =>
                    val == null || val.isEmpty ? 'Required' : null,
              ),
              const SizedBox(height: 16),
              TextFormField(
                controller: _bolController,
                decoration: const InputDecoration(labelText: 'BOL Number'),
              ),
              const Divider(height: 48),
              Row(
                children: [
                  Expanded(
                    child: TextFormField(
                      controller: _hoursController,
                      decoration:
                          const InputDecoration(labelText: 'Total Hours'),
                      keyboardType: TextInputType.number,
                      readOnly:
                          true, // Typically read-only but could be editable
                    ),
                  ),
                  const SizedBox(width: 16),
                  Expanded(
                    child: TextFormField(
                      controller: _payableController,
                      decoration:
                          const InputDecoration(labelText: 'Payable Hours'),
                      keyboardType: TextInputType.number,
                      onChanged: (_) => _calculateTotal(),
                      validator: (val) =>
                          val == null || double.tryParse(val) == null
                              ? 'Invalid'
                              : null,
                    ),
                  ),
                ],
              ),
              const SizedBox(height: 16),
              TextFormField(
                controller: _rateController,
                decoration:
                    const InputDecoration(labelText: 'Rate per Hour (\$)'),
                keyboardType: TextInputType.number,
                onChanged: (_) => _calculateTotal(),
                validator: (val) => val == null || double.tryParse(val) == null
                    ? 'Invalid'
                    : null,
              ),
              const SizedBox(height: 32),
              Container(
                padding: const EdgeInsets.all(16),
                decoration: BoxDecoration(
                  color: Colors.green.shade50,
                  border: Border.all(color: Colors.green),
                  borderRadius: BorderRadius.circular(8),
                ),
                child: Row(
                  mainAxisAlignment: MainAxisAlignment.spaceBetween,
                  children: [
                    const Text('Total Due:',
                        style: TextStyle(
                            fontSize: 18, fontWeight: FontWeight.bold)),
                    Text('\$${_totalDue.toStringAsFixed(2)}',
                        style: const TextStyle(
                            fontSize: 24,
                            fontWeight: FontWeight.bold,
                            color: Colors.green)),
                  ],
                ),
              ),
              const SizedBox(height: 48),
              ElevatedButton(
                style: ElevatedButton.styleFrom(
                  minimumSize: const Size(double.infinity, 56),
                  backgroundColor: Colors.blue,
                  foregroundColor: Colors.white,
                ),
                onPressed: _isLoading ? null : _submitInvoice,
                child: _isLoading
                    ? const CircularProgressIndicator(color: Colors.white)
                    : const Text('APPROVE & GENERATE INVOICE',
                        style: TextStyle(fontWeight: FontWeight.bold)),
              ),
            ],
          ),
        ),
      ),
    );
  }
}
