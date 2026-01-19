class TripModel {
  final String id;
  final String organizationId;
  final String? loadId;
  final String? truckId;
  final String? driverId;
  final String? originAddress;
  final String? destinationAddress;
  final int? odometerStart;
  final int? odometerEnd;
  final String status;
  final DateTime? createdAt;

  TripModel({
    required this.id,
    required this.organizationId,
    this.loadId,
    this.truckId,
    this.driverId,
    this.originAddress,
    this.destinationAddress,
    this.odometerStart,
    this.odometerEnd,
    required this.status,
    this.createdAt,
  });

  factory TripModel.fromJson(Map<String, dynamic> json) {
    return TripModel(
      id: json['id'],
      organizationId: json['organization_id'],
      loadId: json['load_id'],
      truckId: json['truck_id'],
      driverId: json['driver_id'],
      originAddress: json['origin_address'],
      destinationAddress: json['destination_address'],
      odometerStart: json['odometer_start'],
      odometerEnd: json['odometer_end'],
      status: json['status'] ?? 'active',
      createdAt: json['created_at'] != null
          ? DateTime.parse(json['created_at'])
          : null,
    );
  }

  Map<String, dynamic> toJson() => {
    'id': id,
    'organization_id': organizationId,
    'load_id': loadId,
    'truck_id': truckId,
    'driver_id': driverId,
    'origin_address': originAddress,
    'destination_address': destinationAddress,
    'odometer_start': odometerStart,
    'odometer_end': odometerEnd,
    'status': status,
  };
}
