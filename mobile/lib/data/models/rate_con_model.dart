class RateCon {
  final String id;
  final String organizationId;
  final String? brokerName;
  final String? brokerMcNumber;
  final String? loadId;
  final String? carrierName;
  final String? carrierMcNumber;
  final String? pickupAddress;
  final DateTime? pickupDate;
  final String?
      pickupTime; // keeping as String for now to match flexible schema or TimeOfDay later
  final String? deliveryAddress;
  final DateTime? deliveryDate;
  final String? deliveryTime;
  final double? rateAmount;
  final String? commodity;
  final double? weight;
  final double? detentionLimit;
  final double? detentionAmountPerHour;
  final double? fineAmount;
  final String? fineDescription;
  final Map<String, dynamic>? contacts;
  final String? notes;
  final String? instructions;
  final String status; // 'under_review', 'processing', 'approved'
  final String? overallTrafficLight; // 'RED', 'YELLOW', 'GREEN'
  final DateTime createdAt;
  final DateTime updatedAt;

  RateCon({
    required this.id,
    required this.organizationId,
    this.brokerName,
    this.brokerMcNumber,
    this.loadId,
    this.carrierName,
    this.carrierMcNumber,
    this.pickupAddress,
    this.pickupDate,
    this.pickupTime,
    this.deliveryAddress,
    this.deliveryDate,
    this.deliveryTime,
    this.rateAmount,
    this.commodity,
    this.weight,
    this.detentionLimit,
    this.detentionAmountPerHour,
    this.fineAmount,
    this.fineDescription,
    this.contacts,
    this.notes,
    this.instructions,
    required this.status,
    this.overallTrafficLight,
    required this.createdAt,
    required this.updatedAt,
  });

  factory RateCon.fromJson(Map<String, dynamic> json) {
    return RateCon(
      id: json['id'],
      organizationId: json['organization_id'],
      brokerName: json['broker_name'],
      brokerMcNumber: json['broker_mc_number'],
      loadId: json['load_id'],
      carrierName: json['carrier_name'],
      carrierMcNumber: json['carrier_mc_number'],
      pickupAddress: json['pickup_address'],
      pickupDate: json['pickup_date'] != null
          ? DateTime.tryParse(json['pickup_date'])
          : null,
      pickupTime: json['pickup_time']
          ?.toString(), // Handle potential time type mismatch safely
      deliveryAddress: json['delivery_address'],
      deliveryDate: json['delivery_date'] != null
          ? DateTime.tryParse(json['delivery_date'])
          : null,
      deliveryTime: json['delivery_time']?.toString(),
      rateAmount: json['rate_amount'] != null
          ? (json['rate_amount'] as num).toDouble()
          : null,
      commodity: json['commodity'],
      weight:
          json['weight'] != null ? (json['weight'] as num).toDouble() : null,
      detentionLimit: json['detention_limit'] != null
          ? (json['detention_limit'] as num).toDouble()
          : null,
      detentionAmountPerHour: json['detention_amount_per_hour'] != null
          ? (json['detention_amount_per_hour'] as num).toDouble()
          : null,
      fineAmount: json['fine_amount'] != null
          ? (json['fine_amount'] as num).toDouble()
          : null,
      fineDescription: json['fine_description'],
      contacts: json['contacts'],
      notes: json['notes'],
      instructions: json['instructions'],
      status: json['status'] ?? 'under_review',
      overallTrafficLight: json['overall_traffic_light'],
      createdAt: DateTime.parse(json['created_at']),
      updatedAt: DateTime.parse(json['updated_at']),
    );
  }

  Map<String, dynamic> toJson() {
    return {
      'id': id,
      'organization_id': organizationId,
      'broker_name': brokerName,
      'broker_mc_number': brokerMcNumber,
      'load_id': loadId,
      'carrier_name': carrierName,
      'carrier_mc_number': carrierMcNumber,
      'pickup_address': pickupAddress,
      'pickup_date': pickupDate?.toIso8601String(),
      'pickup_time': pickupTime,
      'delivery_address': deliveryAddress,
      'delivery_date': deliveryDate?.toIso8601String(),
      'delivery_time': deliveryTime,
      'rate_amount': rateAmount,
      'commodity': commodity,
      'weight': weight,
      'detention_limit': detentionLimit,
      'detention_amount_per_hour': detentionAmountPerHour,
      'fine_amount': fineAmount,
      'fine_description': fineDescription,
      'contacts': contacts,
      'notes': notes,
      'instructions': instructions,
      'status': status,
      'overall_traffic_light': overallTrafficLight,
      'created_at': createdAt.toIso8601String(),
      'updated_at': updatedAt.toIso8601String(),
    };
  }

  RateCon copyWith({
    String? id,
    String? organizationId,
    String? brokerName,
    String? brokerMcNumber,
    String? loadId,
    String? carrierName,
    String? carrierMcNumber,
    String? pickupAddress,
    DateTime? pickupDate,
    String? pickupTime,
    String? deliveryAddress,
    DateTime? deliveryDate,
    String? deliveryTime,
    double? rateAmount,
    String? commodity,
    double? weight,
    double? detentionLimit,
    double? detentionAmountPerHour,
    double? fineAmount,
    String? fineDescription,
    Map<String, dynamic>? contacts,
    String? notes,
    String? instructions,
    String? status,
    DateTime? createdAt,
    DateTime? updatedAt,
  }) {
    return RateCon(
      id: id ?? this.id,
      organizationId: organizationId ?? this.organizationId,
      brokerName: brokerName ?? this.brokerName,
      brokerMcNumber: brokerMcNumber ?? this.brokerMcNumber,
      loadId: loadId ?? this.loadId,
      carrierName: carrierName ?? this.carrierName,
      carrierMcNumber: carrierMcNumber ?? this.carrierMcNumber,
      pickupAddress: pickupAddress ?? this.pickupAddress,
      pickupDate: pickupDate ?? this.pickupDate,
      pickupTime: pickupTime ?? this.pickupTime,
      deliveryAddress: deliveryAddress ?? this.deliveryAddress,
      deliveryDate: deliveryDate ?? this.deliveryDate,
      deliveryTime: deliveryTime ?? this.deliveryTime,
      rateAmount: rateAmount ?? this.rateAmount,
      commodity: commodity ?? this.commodity,
      weight: weight ?? this.weight,
      detentionLimit: detentionLimit ?? this.detentionLimit,
      detentionAmountPerHour:
          detentionAmountPerHour ?? this.detentionAmountPerHour,
      fineAmount: fineAmount ?? this.fineAmount,
      fineDescription: fineDescription ?? this.fineDescription,
      contacts: contacts ?? this.contacts,
      notes: notes ?? this.notes,
      instructions: instructions ?? this.instructions,
      status: status ?? this.status,
      createdAt: createdAt ?? this.createdAt,
      updatedAt: updatedAt ?? this.updatedAt,
    );
  }
}
