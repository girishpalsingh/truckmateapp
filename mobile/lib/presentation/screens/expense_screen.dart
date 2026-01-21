import 'package:flutter/material.dart';
import '../themes/app_theme.dart';
import '../../services/expense_service.dart';
import '../../core/utils/user_utils.dart';

class ExpenseScreen extends StatefulWidget {
  const ExpenseScreen({super.key});

  @override
  State<ExpenseScreen> createState() => _ExpenseScreenState();
}

class _ExpenseScreenState extends State<ExpenseScreen> {
  final _formKey = GlobalKey<FormState>();
  final _amountController = TextEditingController();
  final _vendorController = TextEditingController();
  final _gallonsController = TextEditingController();
  String _category = 'fuel';
  String _jurisdiction = 'CA';
  bool _isLoading = false;

  final List<String> _categories = [
    'fuel',
    'tolls',
    'food',
    'lodging',
    'repair',
    'other',
  ];
  final List<String> _states = [
    'CA',
    'TX',
    'AZ',
    'NV',
    'OR',
    'WA',
    'ID',
    'UT',
    'CO',
    'NM',
  ];

  Future<void> _saveExpense() async {
    if (!_formKey.currentState!.validate()) return;
    setState(() => _isLoading = true);

    try {
      // Get organization ID from persistence using centralized utility
      final organizationId = await UserUtils.getUserOrganization();
      if (organizationId == null) {
        if (mounted) {
          ScaffoldMessenger.of(context).showSnackBar(
            const SnackBar(
              content: Text('No organization found. Please log in again.'),
              backgroundColor: Colors.red,
            ),
          );
          setState(() => _isLoading = false);
        }
        return;
      }

      await ExpenseService().createExpense(
        organizationId: organizationId,
        category: _category,
        amount: double.parse(_amountController.text),
        vendorName: _vendorController.text,
        jurisdiction: _jurisdiction,
        gallons: _category == 'fuel'
            ? double.tryParse(_gallonsController.text)
            : null,
      );
      if (mounted) Navigator.pop(context);
    } catch (e) {
      if (mounted) setState(() => _isLoading = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(title: const Text('Add Expense')),
      body: SingleChildScrollView(
        padding: const EdgeInsets.all(16),
        child: Form(
          key: _formKey,
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: [
              DropdownButtonFormField<String>(
                value: _category,
                decoration: const InputDecoration(labelText: 'Category'),
                items: _categories
                    .map(
                      (c) => DropdownMenuItem(
                        value: c,
                        child: Text(c.toUpperCase()),
                      ),
                    )
                    .toList(),
                onChanged: (v) => setState(() => _category = v!),
              ),
              const SizedBox(height: 16),
              TextFormField(
                controller: _amountController,
                keyboardType: TextInputType.number,
                decoration: const InputDecoration(
                  labelText: 'Amount',
                  prefixText: '\$',
                ),
                validator: (v) => double.tryParse(v ?? '') == null
                    ? 'Enter valid amount'
                    : null,
              ),
              const SizedBox(height: 16),
              TextFormField(
                controller: _vendorController,
                decoration: const InputDecoration(labelText: 'Vendor Name'),
              ),
              const SizedBox(height: 16),
              DropdownButtonFormField<String>(
                value: _jurisdiction,
                decoration: const InputDecoration(labelText: 'State (IFTA)'),
                items: _states
                    .map((s) => DropdownMenuItem(value: s, child: Text(s)))
                    .toList(),
                onChanged: (v) => setState(() => _jurisdiction = v!),
              ),
              if (_category == 'fuel') ...[
                const SizedBox(height: 16),
                TextFormField(
                  controller: _gallonsController,
                  keyboardType: TextInputType.number,
                  decoration: const InputDecoration(labelText: 'Gallons'),
                ),
              ],
              const SizedBox(height: 16),
              OutlinedButton.icon(
                onPressed: () => Navigator.pushNamed(context, '/scan'),
                icon: const Icon(Icons.camera_alt),
                label: const Text('Scan Receipt'),
              ),
              const SizedBox(height: 32),
              ElevatedButton(
                onPressed: _isLoading ? null : _saveExpense,
                style: AppTheme.actionButtonStyle,
                child: _isLoading
                    ? const CircularProgressIndicator()
                    : const Text('Save Expense'),
              ),
            ],
          ),
        ),
      ),
    );
  }
}
