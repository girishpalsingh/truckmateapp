/// Model for reference numbers (PO, BOL, SO, etc.)
class ReferenceNumber {
  final String id;
  final String rateConfirmationId;
  final String? refType;
  final String? refValue;
  final DateTime? createdAt;

  ReferenceNumber({
    required this.id,
    required this.rateConfirmationId,
    this.refType,
    this.refValue,
    this.createdAt,
  });

  factory ReferenceNumber.fromJson(Map<String, dynamic> json) {
    return ReferenceNumber(
      id: json['ref_id']?.toString() ?? '',
      rateConfirmationId: json['rate_confirmation_id'],
      refType: json['ref_type'],
      refValue: json['ref_value'],
      createdAt: json['created_at'] != null
          ? DateTime.parse(json['created_at'])
          : null,
    );
  }

  Map<String, dynamic> toJson() {
    return {
      'id': id,
      'rate_confirmation_id': rateConfirmationId,
      'ref_type': refType,
      'ref_value': refValue,
      'created_at': createdAt?.toIso8601String(),
    };
  }
}
