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
  final Map<String, dynamic>? activeAssignment;

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
    this.activeAssignment,
  });

  factory Load.fromJson(Map<String, dynamic> json) {
    Map<String, dynamic>? assignment;
    if (json['dispatch_assignments'] != null) {
      final assignments = json['dispatch_assignments'] as List;
      if (assignments.isNotEmpty) {
        // Try to find ACTIVE, else take first
        assignment = assignments.firstWhere(
          (element) => element['status'] == 'ACTIVE',
          orElse: () => assignments.first,
        );
      }
    }

    return Load(
      id: json['load_id'] ?? json['id'], // Handle both if transition
      organizationId: json['organization_id'],
      rateConfirmationId: json['active_rate_con_id'] != null
          ? json['active_rate_con_id'].toString()
          : null,
      brokerName: json['broker_name'],
      brokerLoadId: json['broker_load_id'],
      primaryRate: (json['primary_rate'] as num?)?.toDouble(),
      fuelSurcharge: (json['fuel_surcharge'] as num?)?.toDouble(),
      status: json['status'] ?? 'created',
      createdAt: json['created_at'] != null
          ? DateTime.parse(json['created_at'])
          : null,
      rateConfirmation: json['rate_confirmations'],
      activeAssignment: assignment,
    );
  }

  Map<String, dynamic> toJson() {
    return {
      'id': id,
      'organization_id': organizationId,
      'rate_confirmation_id': rateConfirmationId,
      'broker_name': brokerName,
      'broker_load_id': brokerLoadId,
      'primary_rate': primaryRate,
      'fuel_surcharge': fuelSurcharge,
      'status': status,
      'created_at': createdAt?.toIso8601String(),
      'rate_confirmations': rateConfirmation,
    };
  }
}
