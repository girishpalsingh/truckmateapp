/// Model for rate confirmation charges (Line Haul, Fuel, etc.)
class Charge {
  final String id;
  final String rateConfirmationId;
  final String? description;
  final double? amount;
  final DateTime createdAt;

  Charge({
    required this.id,
    required this.rateConfirmationId,
    this.description,
    this.amount,
    required this.createdAt,
  });

  factory Charge.fromJson(Map<String, dynamic> json) {
    return Charge(
      id: json['id'],
      rateConfirmationId: json['rate_confirmation_id'],
      description: json['description'],
      amount:
          json['amount'] != null ? (json['amount'] as num).toDouble() : null,
      createdAt: DateTime.parse(json['created_at']),
    );
  }

  Map<String, dynamic> toJson() {
    return {
      'id': id,
      'rate_confirmation_id': rateConfirmationId,
      'description': description,
      'amount': amount,
      'created_at': createdAt.toIso8601String(),
    };
  }

  String get displayAmount =>
      amount != null ? '\$${amount!.toStringAsFixed(2)}' : 'N/A';
}
