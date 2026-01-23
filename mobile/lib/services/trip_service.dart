import 'package:supabase_flutter/supabase_flutter.dart';
import 'expense_service.dart';

/// Service for managing trips
class TripService {
  final SupabaseClient _client;

  TripService({SupabaseClient? client})
      : _client = client ?? Supabase.instance.client;

  /// Get all trips for the current organization
  Future<List<Trip>> getTrips({
    String? status,
    String? driverId,
    int limit = 50,
  }) async {
    var query = _client.from('trips').select('''
      *,
      load:loads(*),
      truck:trucks(truck_number, make, model),
      driver:profiles(full_name)
    ''');

    if (status != null) {
      query = query.eq('status', status);
    }
    if (driverId != null) {
      query = query.eq('driver_id', driverId);
    }

    final response =
        await query.order('created_at', ascending: false).limit(limit);

    return (response as List).map((json) => Trip.fromJson(json)).toList();
  }

  /// Get active trip for current driver
  Future<Trip?> getActiveTrip() async {
    final response = await _client.from('trips').select('''
          *,
          load:loads(*),
          truck:trucks(truck_number, make, model)
        ''').eq('status', 'active').maybeSingle();

    return response != null ? Trip.fromJson(response) : null;
  }

  /// Create a new trip
  Future<Trip> createTrip({
    required String organizationId,
    String? loadId,
    String? truckId,
    String? driverId,
    required String originAddress,
    String? destinationAddress,
    required int odometerStart,
  }) async {
    final response = await _client.from('trips').insert({
      'organization_id': organizationId,
      'load_id': loadId,
      'truck_id': truckId,
      'driver_id': driverId,
      'origin_address': originAddress,
      'destination_address': destinationAddress,
      'odometer_start': odometerStart,
      'status': loadId != null ? 'active' : 'deadhead',
    }).select('''
          *,
          load:loads(*),
          truck:trucks(truck_number, make, model)
        ''').single();

    return Trip.fromJson(response);
  }

  /// Update trip
  Future<Trip> updateTrip(String tripId, Map<String, dynamic> updates) async {
    final response =
        await _client.from('trips').update(updates).eq('id', tripId).select('''
          *,
          load:loads(*),
          truck:trucks(truck_number, make, model)
        ''').single();

    return Trip.fromJson(response);
  }

  /// End/complete a trip
  Future<Trip> endTrip(String tripId, int odometerEnd) async {
    return updateTrip(tripId, {
      'odometer_end': odometerEnd,
      'status': 'completed',
    });
  }

  /// Get expenses for a trip
  Future<List<Expense>> getTripExpenses(String tripId) async {
    final response = await _client
        .from('expenses')
        .select('*')
        .eq('trip_id', tripId)
        .order('date', ascending: false);

    return (response as List).map((json) => Expense.fromJson(json)).toList();
  }

  /// Calculate trip profitability
  Future<TripProfitability?> calculateProfitability(String tripId) async {
    final response = await _client.rpc(
      'calculate_trip_profit',
      params: {'trip_uuid': tripId},
    );

    if (response != null && response is List && response.isNotEmpty) {
      return TripProfitability.fromJson(response.first);
    }
    return null;
  }

  /// Generate Dispatcher Sheet
  Future<String> generateDispatcherSheet(String loadId) async {
    final response = await _client.functions.invoke(
      'generate-dispatch-sheet',
      body: {'load_id': loadId},
    );

    final data = response.data as Map<String, dynamic>;
    if (data['url'] == null) {
      throw Exception('Failed to generate dispatcher sheet: No URL returned');
    }

    return data['url'] as String;
  }
}

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
