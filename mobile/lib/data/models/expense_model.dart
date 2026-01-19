class ExpenseModel {
  final String id;
  final String organizationId;
  final String? tripId;
  final String category;
  final double amount;
  final String currency;
  final String? vendorName;
  final String? jurisdiction;
  final double? gallons;
  final DateTime date;
  final bool isReimbursable;

  ExpenseModel({
    required this.id,
    required this.organizationId,
    this.tripId,
    required this.category,
    required this.amount,
    this.currency = 'USD',
    this.vendorName,
    this.jurisdiction,
    this.gallons,
    required this.date,
    this.isReimbursable = false,
  });

  factory ExpenseModel.fromJson(Map<String, dynamic> json) {
    return ExpenseModel(
      id: json['id'],
      organizationId: json['organization_id'],
      tripId: json['trip_id'],
      category: json['category'],
      amount: (json['amount'] ?? 0).toDouble(),
      currency: json['currency'] ?? 'USD',
      vendorName: json['vendor_name'],
      jurisdiction: json['jurisdiction'],
      gallons: json['gallons']?.toDouble(),
      date: DateTime.parse(json['date']),
      isReimbursable: json['is_reimbursable'] ?? false,
    );
  }

  Map<String, dynamic> toJson() => {
    'organization_id': organizationId,
    'trip_id': tripId,
    'category': category,
    'amount': amount,
    'currency': currency,
    'vendor_name': vendorName,
    'jurisdiction': jurisdiction,
    'gallons': gallons,
    'date': date.toIso8601String().split('T')[0],
    'is_reimbursable': isReimbursable,
  };
}
