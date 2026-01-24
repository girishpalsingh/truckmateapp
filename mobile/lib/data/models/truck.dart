/// Model for truck data
class Truck {
  final String id;
  final String organizationId;
  final String truckNumber;
  final String? make;
  final String? model;
  final int? year;
  final String? vin;
  final String? licensePlate;
  final int currentOdometer;
  final DateTime createdAt;
  final DateTime updatedAt;

  Truck({
    required this.id,
    required this.organizationId,
    required this.truckNumber,
    this.make,
    this.model,
    this.year,
    this.vin,
    this.licensePlate,
    this.currentOdometer = 0,
    required this.createdAt,
    required this.updatedAt,
  });

  factory Truck.fromJson(Map<String, dynamic> json) {
    return Truck(
      id: json['id'],
      organizationId: json['organization_id'],
      truckNumber: json['truck_number'],
      make: json['make'],
      model: json['model'],
      year: json['year'],
      vin: json['vin'],
      licensePlate: json['license_plate'],
      currentOdometer: json['current_odometer'] ?? 0,
      createdAt: DateTime.parse(json['created_at']),
      updatedAt: DateTime.parse(json['updated_at']),
    );
  }

  Map<String, dynamic> toJson() {
    return {
      'id': id,
      'organization_id': organizationId,
      'truck_number': truckNumber,
      'make': make,
      'model': model,
      'year': year,
      'vin': vin,
      'license_plate': licensePlate,
      'current_odometer': currentOdometer,
      'created_at': createdAt.toIso8601String(),
      'updated_at': updatedAt.toIso8601String(),
    };
  }

  @override
  String toString() => 'Truck(number: $truckNumber, $make $model)';
}
