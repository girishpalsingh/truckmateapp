class Trip {
  final String id;
  final String organizationId;
  final String? loadId;
  final String? truckId;
  final String? driverId;
  final String? originAddress;
  final String? destinationAddress;
  final int? odometerStart;
  final int? odometerEnd;
  final int? totalMiles;
  final String status;
  final DateTime? createdAt;
  final Map<String, dynamic>? load;
  final Map<String, dynamic>? truck;
  final Map<String, dynamic>? driver;
  final String? dispatchDocumentId; // New field

  Trip({
    required this.id,
    required this.organizationId,
    this.loadId,
    this.truckId,
    this.driverId,
    this.originAddress,
    this.destinationAddress,
    this.odometerStart,
    this.odometerEnd,
    this.totalMiles,
    required this.status,
    this.createdAt,
    this.load,
    this.truck,
    this.driver,
    this.dispatchDocumentId,
  });

  factory Trip.fromJson(Map<String, dynamic> json) {
    return Trip(
      id: json['id'],
      organizationId: json['organization_id'],
      loadId: json['load_id'],
      truckId: json['truck_id'],
      driverId: json['driver_id'],
      originAddress: json['origin_address'],
      destinationAddress: json['destination_address'],
      odometerStart: json['odometer_start'],
      odometerEnd: json['odometer_end'],
      totalMiles: json['total_miles'],
      status: json['status'],
      createdAt: json['created_at'] != null
          ? DateTime.parse(json['created_at'])
          : null,
      load: json['load'],
      truck: json['truck'],
      driver: json['driver'],
      dispatchDocumentId: json['dispatch_document_id'],
    );
  }

  bool get isActive => status == 'active';
  bool get isCompleted => status == 'completed';
  bool get isDeadhead => status == 'deadhead';

  double? get rate => load?['primary_rate']?.toDouble();
  String? get truckNumber => truck?['truck_number'];
  String? get driverName => driver?['full_name'];
}

class TripProfitability {
  final double revenue;
  final double expenses;
  final double detentionRevenue;
  final double netProfit;
  final double profitMargin;

  TripProfitability({
    required this.revenue,
    required this.expenses,
    required this.detentionRevenue,
    required this.netProfit,
    required this.profitMargin,
  });

  factory TripProfitability.fromJson(Map<String, dynamic> json) {
    return TripProfitability(
      revenue: (json['revenue'] ?? 0).toDouble(),
      expenses: (json['expenses'] ?? 0).toDouble(),
      detentionRevenue: (json['detention_revenue'] ?? 0).toDouble(),
      netProfit: (json['net_profit'] ?? 0).toDouble(),
      profitMargin: (json['profit_margin'] ?? 0).toDouble(),
    );
  }
}
