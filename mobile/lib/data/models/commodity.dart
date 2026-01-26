class Commodity {
  final String? description;
  final double? weightLbs;
  final int? quantity;
  final String? unitType;
  final bool isHazmat;
  final String? tempReq;

  Commodity({
    this.description,
    this.weightLbs,
    this.quantity,
    this.unitType,
    this.isHazmat = false,
    this.tempReq,
  });

  factory Commodity.fromJson(Map<String, dynamic> json) {
    return Commodity(
      description: json['description'],
      weightLbs: json['weight_lbs'] != null
          ? (json['weight_lbs'] as num).toDouble()
          : null,
      quantity: json['quantity'] as int?,
      unitType: json['unit_type'],
      isHazmat: json['is_hazmat'] ?? false,
      tempReq: json['temp_req'],
    );
  }

  Map<String, dynamic> toJson() {
    return {
      'description': description,
      'weight_lbs': weightLbs,
      'quantity': quantity,
      'unit_type': unitType,
      'is_hazmat': isHazmat,
      'temp_req': tempReq,
    };
  }
}
