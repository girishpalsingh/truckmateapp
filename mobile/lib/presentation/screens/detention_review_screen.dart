import 'package:flutter/material.dart';
import '../../services/detention_service.dart';
import '../../core/utils/app_logger.dart';

/// Screen for reviewing and approving detention invoice details before generation
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

  // Financial details controllers
  late TextEditingController _rateController;
  late TextEditingController _hoursController;
  late TextEditingController _payableController;

  // Reference info controllers
  late TextEditingController _bolController;
  late TextEditingController _poController;
  late TextEditingController _facilityNameController;
  late TextEditingController _facilityAddressController;
  late TextEditingController _emailController;

  bool _isLoading = false;
  bool _sendEmail = false;
  double _totalDue = 0.0;

  @override
  void initState() {
    super.initState();
    // Initialize controllers from initial data
    _rateController = TextEditingController(
        text: (widget.initialData['rate_per_hour'] ?? 75.0).toString());
    _hoursController = TextEditingController(
        text: (widget.initialData['total_hours'] ?? 0.0).toStringAsFixed(2));
    _payableController = TextEditingController(
        text: (widget.initialData['payable_hours'] ?? 0.0).toStringAsFixed(2));
    _bolController =
        TextEditingController(text: widget.initialData['bol_number'] ?? '');
    _poController =
        TextEditingController(text: widget.initialData['po_number'] ?? '');
    _facilityNameController =
        TextEditingController(text: widget.initialData['facility_name'] ?? '');
    _facilityAddressController = TextEditingController(
        text: widget.initialData['facility_address'] ?? '');
    _emailController =
        TextEditingController(text: widget.initialData['broker_email'] ?? '');

    _calculateTotal();
  }

  @override
  void dispose() {
    _rateController.dispose();
    _hoursController.dispose();
    _payableController.dispose();
    _bolController.dispose();
    _poController.dispose();
    _facilityNameController.dispose();
    _facilityAddressController.dispose();
    _emailController.dispose();
    super.dispose();
  }

  /// Recalculate total due based on rate and payable hours
  void _calculateTotal() {
    final rate = double.tryParse(_rateController.text) ?? 0.0;
    final payable = double.tryParse(_payableController.text) ?? 0.0;
    setState(() {
      _totalDue = rate * payable;
    });
  }

  /// Submit invoice to backend
  Future<void> _submitInvoice() async {
    if (!_formKey.currentState!.validate()) return;

    // Validate email if sending
    if (_sendEmail && _emailController.text.isEmpty) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
            content: Text('Please enter email address to send invoice')),
      );
      return;
    }

    setState(() => _isLoading = true);
    try {
      final invoiceDetails = {
        'rate_per_hour': double.parse(_rateController.text),
        'total_hours': double.parse(_hoursController.text),
        'payable_hours': double.parse(_payableController.text),
        'total_due': _totalDue,
        'bol_number': _bolController.text,
        'po_number': _poController.text,
        'facility_name': _facilityNameController.text,
        'facility_address': _facilityAddressController.text,
        'broker_email': _emailController.text,
        'currency': 'USD',
      };

      final invoice = await _detentionService.createInvoice(
        detentionRecordId: widget.detentionRecordId,
        invoiceDetails: invoiceDetails,
        sendEmail: _sendEmail,
      );

      if (mounted) {
        final message = _sendEmail
            ? 'Invoice created and sent to ${_emailController.text}'
            : 'Invoice created successfully!';
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text(message)),
        );
        // Return PDF URL for viewing
        Navigator.pop(context, invoice.pdfUrl);
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

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: const Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text('Review Detention Invoice', style: TextStyle(fontSize: 16)),
            Text('ਡਿਟੈਂਸ਼ਨ ਇਨਵੌਇਸ ਦੀ ਸਮੀਖਿਆ ਕਰੋ',
                style: TextStyle(fontSize: 10, fontWeight: FontWeight.normal)),
          ],
        ),
      ),
      body: SingleChildScrollView(
        padding: const EdgeInsets.all(24),
        child: Form(
          key: _formKey,
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: [
              // Section: Facility Info
              _buildSectionHeader('Facility Information'),
              const SizedBox(height: 12),
              TextFormField(
                controller: _facilityNameController,
                decoration: const InputDecoration(
                  labelText: 'Facility Name',
                  prefixIcon: Icon(Icons.business),
                ),
              ),
              const SizedBox(height: 12),
              TextFormField(
                controller: _facilityAddressController,
                decoration: const InputDecoration(
                  labelText: 'Facility Address',
                  prefixIcon: Icon(Icons.location_on),
                ),
                validator: (val) =>
                    val == null || val.isEmpty ? 'Required' : null,
                maxLines: 2,
              ),

              const Divider(height: 32),

              // Section: Reference Numbers
              _buildSectionHeader('Reference Numbers'),
              const SizedBox(height: 12),
              Row(
                children: [
                  Expanded(
                    child: TextFormField(
                      controller: _bolController,
                      decoration: const InputDecoration(
                        labelText: 'BOL #',
                        prefixIcon: Icon(Icons.receipt),
                      ),
                    ),
                  ),
                  const SizedBox(width: 16),
                  Expanded(
                    child: TextFormField(
                      controller: _poController,
                      decoration: const InputDecoration(
                        labelText: 'PO #',
                        prefixIcon: Icon(Icons.tag),
                      ),
                    ),
                  ),
                ],
              ),

              const Divider(height: 32),

              // Section: Billing
              _buildSectionHeader('Billing Details'),
              const SizedBox(height: 12),
              Row(
                children: [
                  Expanded(
                    child: TextFormField(
                      controller: _hoursController,
                      decoration: const InputDecoration(
                        labelText: 'Total Hours',
                        suffixText: 'hrs',
                      ),
                      keyboardType: TextInputType.number,
                      readOnly: true, // Calculated from detention record
                    ),
                  ),
                  const SizedBox(width: 16),
                  Expanded(
                    child: TextFormField(
                      controller: _payableController,
                      decoration: const InputDecoration(
                        labelText: 'Payable Hours',
                        suffixText: 'hrs',
                        helperText: 'After free time',
                      ),
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
                decoration: const InputDecoration(
                  labelText: 'Rate per Hour',
                  prefixText: '\$ ',
                  prefixIcon: Icon(Icons.attach_money),
                ),
                keyboardType: TextInputType.number,
                onChanged: (_) => _calculateTotal(),
                validator: (val) => val == null || double.tryParse(val) == null
                    ? 'Invalid'
                    : null,
              ),

              const SizedBox(height: 24),

              // Total Due Box
              Container(
                padding: const EdgeInsets.all(20),
                decoration: BoxDecoration(
                  gradient: LinearGradient(
                    colors: [Colors.green.shade400, Colors.green.shade600],
                  ),
                  borderRadius: BorderRadius.circular(12),
                ),
                child: Row(
                  mainAxisAlignment: MainAxisAlignment.spaceBetween,
                  children: [
                    const Text('Total Due:',
                        style: TextStyle(
                            fontSize: 18,
                            fontWeight: FontWeight.bold,
                            color: Colors.white)),
                    Text('\$${_totalDue.toStringAsFixed(2)}',
                        style: const TextStyle(
                            fontSize: 18,
                            fontWeight: FontWeight.bold,
                            color: Colors.white)),
                  ],
                ),
              ),

              const Divider(height: 32),

              // Section: Email
              _buildSectionHeader('Send Invoice'),
              const SizedBox(height: 12),
              TextFormField(
                controller: _emailController,
                decoration: const InputDecoration(
                  labelText: 'Broker Email',
                  prefixIcon: Icon(Icons.email),
                  hintText: 'email@example.com',
                ),
                keyboardType: TextInputType.emailAddress,
              ),
              const SizedBox(height: 8),
              SwitchListTile(
                title: const Text('Send invoice via email'),
                subtitle: const Text('Email will be sent after PDF generation'),
                value: _sendEmail,
                onChanged: (val) => setState(() => _sendEmail = val),
                contentPadding: EdgeInsets.zero,
              ),

              const SizedBox(height: 32),

              // Submit Button
              ElevatedButton(
                style: ElevatedButton.styleFrom(
                  minimumSize: const Size(double.infinity, 56),
                  backgroundColor: Colors.blue,
                  foregroundColor: Colors.white,
                ),
                onPressed: _isLoading ? null : _submitInvoice,
                child: _isLoading
                    ? const CircularProgressIndicator(color: Colors.white)
                    : Row(
                        mainAxisAlignment: MainAxisAlignment.center,
                        children: [
                          const Icon(Icons.check_circle),
                          const SizedBox(width: 8),
                          Text(
                            _sendEmail
                                ? 'APPROVE & SEND INVOICE'
                                : 'APPROVE & GENERATE INVOICE',
                            style: const TextStyle(
                                fontWeight: FontWeight.bold,
                                color: Colors.white),
                          ),
                        ],
                      ),
              ),
            ],
          ),
        ),
      ),
    );
  }

  /// Helper to build section headers
  Widget _buildSectionHeader(String title) {
    return Text(
      title,
      style: const TextStyle(fontSize: 16, fontWeight: FontWeight.bold),
    );
  }
}
