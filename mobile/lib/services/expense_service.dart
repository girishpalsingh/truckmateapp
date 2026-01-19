import 'package:supabase_flutter/supabase_flutter.dart';

/// Service for managing expenses
class ExpenseService {
  final SupabaseClient _client;

  ExpenseService({SupabaseClient? client})
    : _client = client ?? Supabase.instance.client;

  /// Create an expense
  Future<Expense> createExpense({
    required String organizationId,
    String? tripId,
    required String category,
    required double amount,
    String currency = 'USD',
    String? vendorName,
    String? jurisdiction,
    double? gallons,
    double? pricePerGallon,
    DateTime? date,
    bool isReimbursable = false,
    String? receiptImagePath,
    String? notes,
  }) async {
    final response = await _client
        .from('expenses')
        .insert({
          'organization_id': organizationId,
          'trip_id': tripId,
          'category': category,
          'amount': amount,
          'currency': currency,
          'vendor_name': vendorName,
          'jurisdiction': jurisdiction,
          'gallons': gallons,
          'price_per_gallon': pricePerGallon,
          'date': (date ?? DateTime.now()).toIso8601String().split('T')[0],
          'is_reimbursable': isReimbursable,
          'receipt_image_path': receiptImagePath,
          'notes': notes,
        })
        .select()
        .single();

    return Expense.fromJson(response);
  }

  /// Get expenses for an organization
  Future<List<Expense>> getExpenses({
    required String organizationId,
    String? tripId,
    String? category,
    String? jurisdiction,
    DateTime? fromDate,
    DateTime? toDate,
    int limit = 100,
  }) async {
    var query = _client
        .from('expenses')
        .select('''
          *,
          trip:trips(origin_address, destination_address)
        ''')
        .eq('organization_id', organizationId);

    if (tripId != null) {
      query = query.eq('trip_id', tripId);
    }
    if (category != null) {
      query = query.eq('category', category);
    }
    if (jurisdiction != null) {
      query = query.eq('jurisdiction', jurisdiction);
    }
    if (fromDate != null) {
      query = query.gte('date', fromDate.toIso8601String().split('T')[0]);
    }
    if (toDate != null) {
      query = query.lte('date', toDate.toIso8601String().split('T')[0]);
    }

    final response = await query.order('date', ascending: false).limit(limit);

    return (response as List).map((json) => Expense.fromJson(json)).toList();
  }

  /// Get expense totals by category
  Future<Map<String, double>> getExpenseTotalsByCategory(
    String organizationId, {
    DateTime? fromDate,
    DateTime? toDate,
  }) async {
    final expenses = await getExpenses(
      organizationId: organizationId,
      fromDate: fromDate,
      toDate: toDate,
    );

    final totals = <String, double>{};
    for (final expense in expenses) {
      totals[expense.category] =
          (totals[expense.category] ?? 0) + expense.amount;
    }
    return totals;
  }

  /// Get fuel summary for IFTA
  Future<List<IFTAFuelSummary>> getIFTAFuelSummary(
    String organizationId, {
    required int year,
    required int quarter,
  }) async {
    // Calculate quarter date range
    final startMonth = (quarter - 1) * 3 + 1;
    final fromDate = DateTime(year, startMonth, 1);
    final toDate = DateTime(year, startMonth + 3, 0);

    final expenses = await getExpenses(
      organizationId: organizationId,
      category: 'fuel',
      fromDate: fromDate,
      toDate: toDate,
    );

    // Group by jurisdiction
    final byJurisdiction = <String, IFTAFuelSummary>{};
    for (final expense in expenses) {
      final state = expense.jurisdiction ?? 'UNKNOWN';
      if (!byJurisdiction.containsKey(state)) {
        byJurisdiction[state] = IFTAFuelSummary(
          jurisdiction: state,
          totalGallons: 0,
          totalAmount: 0,
        );
      }
      byJurisdiction[state] = IFTAFuelSummary(
        jurisdiction: state,
        totalGallons:
            byJurisdiction[state]!.totalGallons + (expense.gallons ?? 0),
        totalAmount: byJurisdiction[state]!.totalAmount + expense.amount,
      );
    }

    return byJurisdiction.values.toList();
  }

  /// Update expense
  Future<Expense> updateExpense(
    String expenseId,
    Map<String, dynamic> updates,
  ) async {
    final response = await _client
        .from('expenses')
        .update(updates)
        .eq('id', expenseId)
        .select()
        .single();

    return Expense.fromJson(response);
  }

  /// Delete expense
  Future<void> deleteExpense(String expenseId) async {
    await _client.from('expenses').delete().eq('id', expenseId);
  }
}

class Expense {
  final String id;
  final String organizationId;
  final String? tripId;
  final String category;
  final double amount;
  final String currency;
  final String? vendorName;
  final String? jurisdiction;
  final double? gallons;
  final double? pricePerGallon;
  final DateTime date;
  final bool isReimbursable;
  final String? receiptImagePath;
  final String? notes;
  final Map<String, dynamic>? trip;

  Expense({
    required this.id,
    required this.organizationId,
    this.tripId,
    required this.category,
    required this.amount,
    this.currency = 'USD',
    this.vendorName,
    this.jurisdiction,
    this.gallons,
    this.pricePerGallon,
    required this.date,
    this.isReimbursable = false,
    this.receiptImagePath,
    this.notes,
    this.trip,
  });

  factory Expense.fromJson(Map<String, dynamic> json) {
    return Expense(
      id: json['id'],
      organizationId: json['organization_id'],
      tripId: json['trip_id'],
      category: json['category'],
      amount: (json['amount'] ?? 0).toDouble(),
      currency: json['currency'] ?? 'USD',
      vendorName: json['vendor_name'],
      jurisdiction: json['jurisdiction'],
      gallons: json['gallons']?.toDouble(),
      pricePerGallon: json['price_per_gallon']?.toDouble(),
      date: DateTime.parse(json['date']),
      isReimbursable: json['is_reimbursable'] ?? false,
      receiptImagePath: json['receipt_image_path'],
      notes: json['notes'],
      trip: json['trip'],
    );
  }

  String get categoryDisplay {
    switch (category) {
      case 'fuel':
        return 'Fuel';
      case 'tolls':
        return 'Tolls';
      case 'scale':
        return 'Scale';
      case 'lumper':
        return 'Lumper';
      case 'repair':
        return 'Repair';
      case 'maintenance':
        return 'Maintenance';
      case 'food':
        return 'Food';
      case 'lodging':
        return 'Lodging';
      case 'fee':
        return 'Fee';
      case 'detention_payout':
        return 'Detention';
      default:
        return 'Other';
    }
  }
}

class IFTAFuelSummary {
  final String jurisdiction;
  final double totalGallons;
  final double totalAmount;

  IFTAFuelSummary({
    required this.jurisdiction,
    required this.totalGallons,
    required this.totalAmount,
  });
}
