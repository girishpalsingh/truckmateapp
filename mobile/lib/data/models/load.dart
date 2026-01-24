class Load {
  final String id;
  final String organizationId;
  final String? rateConfirmationId;
  final String? brokerName;
  final String? brokerLoadId;
  final double? primaryRate;
  final double? fuelSurcharge;
  final String status;
  final DateTime? createdAt;
  final Map<String, dynamic>? rateConfirmation;

  Load({
    required this.id,
    required this.organizationId,
    this.rateConfirmationId,
    this.brokerName,
    this.brokerLoadId,
    this.primaryRate,
    this.fuelSurcharge,
    required this.status,
    this.createdAt,
    this.rateConfirmation,
  });

  factory Load.fromJson(Map<String, dynamic> json) {
    return Load(
      id: json['id'],
      organizationId: json['organization_id'],
      rateConfirmationId: json['rate_confirmation_id'],
      brokerName: json['broker_name'],
      brokerLoadId: json['broker_load_id'],
      primaryRate: (json['primary_rate'] as num?)?.toDouble(),
      fuelSurcharge: (json['fuel_surcharge'] as num?)?.toDouble(),
      status: json['status'] ?? 'assigned',
      createdAt: json['created_at'] != null
          ? DateTime.parse(json['created_at'])
          : null,
      rateConfirmation:
          json['rate_confirmations'], // Note plural in Query usually
    );
  }
}
