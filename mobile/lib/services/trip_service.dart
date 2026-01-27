import 'package:supabase_flutter/supabase_flutter.dart';
import 'expense_service.dart';
import '../core/utils/app_logger.dart';
import '../data/models/trip.dart';

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
    AppLogger.d(
        'TripService: Fetching trips (status: $status, driver: $driverId)');
    var query = _client.from('trips').select('''
      *,
      load:loads(*, rate_confirmations(*, rc_stops(*))),
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

    final trips =
        (response as List).map((json) => Trip.fromJson(json)).toList();
    AppLogger.d('TripService: Fetched ${trips.length} trips');
    return trips;
  }

  /// Get active trip for current driver
  Future<Trip?> getActiveTrip() async {
    final userId = _client.auth.currentUser?.id;
    if (userId == null) {
      AppLogger.w(
          'TripService: Attempted to fetch active trip without logged-in user');
      return null;
    }

    AppLogger.d('TripService: Fetching active trip for user $userId');
    try {
      final response = await _client
          .from('trips')
          .select('''
          *,
          load:loads(*, rate_confirmations(*, rc_stops(*))),
          truck:trucks(truck_number, make, model)
        ''')
          .eq('driver_id', userId)
          .eq('status', 'active')
          .order('created_at', ascending: false)
          .limit(1)
          .maybeSingle();

      return response != null ? Trip.fromJson(response) : null;
    } catch (e, stack) {
      AppLogger.e('TripService: Error fetching active trip', e, stack);
      rethrow;
    }
  }

  /// Get trip by load ID
  Future<Trip?> getTripByLoadId(String loadId) async {
    try {
      final response = await _client
          .from('trips')
          .select('''
          *,
          load:loads(*, rate_confirmations(*, rc_stops(*))),
          truck:trucks(truck_number, make, model),
          driver:profiles(full_name)
        ''')
          .eq('load_id',
              loadId) // Removed .neq('status', 'cancelled') as it is invalid enum
          .limit(1)
          .maybeSingle();

      return response != null ? Trip.fromJson(response) : null;
    } catch (e, stack) {
      AppLogger.e(
          'TripService: Error fetching trip for load $loadId', e, stack);
      return null;
    }
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
    AppLogger.i('TripService: Creating trip (load: $loadId)');
    try {
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

      final tripId = response['id'];

      // Insert into trip_loads if loadId is provided
      if (loadId != null) {
        try {
          await _client.from('trip_loads').insert({
            'trip_id': tripId,
            'load_id': loadId,
            'pickup_sequence': 1,
            'delivery_sequence': 1,
          });
        } catch (e) {
          AppLogger.w('TripService: Failed to create trip_loads mapping', e);
          // Non-critical (?) or should we fail?
          // For now logging warning
        }
      }

      AppLogger.i('TripService: Trip created successfully');
      return Trip.fromJson(response);
    } catch (e, stack) {
      AppLogger.e('TripService: Error creating trip', e, stack);
      rethrow;
    }
  }

  /// Update trip
  Future<Trip> updateTrip(String tripId, Map<String, dynamic> updates) async {
    AppLogger.i('TripService: Updating trip $tripId');
    try {
      final response = await _client
          .from('trips')
          .update(updates)
          .eq('id', tripId)
          .select('''
          *,
          load:loads(*),
          truck:trucks(truck_number, make, model)
        ''').single();

      return Trip.fromJson(response);
    } catch (e, stack) {
      AppLogger.e('TripService: Error updating trip $tripId', e, stack);
      rethrow;
    }
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
  Future<String> generateDispatcherSheet(
      {String? tripId, String? loadId}) async {
    AppLogger.i(
        'TripService: Generating dispatcher sheet (trip: $tripId, load: $loadId)');
    try {
      final response = await _client.functions.invoke(
        'generate-dispatch-sheet',
        body: {
          if (tripId != null) 'trip_id': tripId,
          if (loadId != null) 'load_id': loadId,
        },
      );

      final data = response.data as Map<String, dynamic>;
      if (data['url'] == null) {
        throw Exception('Failed to generate dispatcher sheet: No URL returned');
      }

      return data['url'] as String;
    } catch (e, stack) {
      AppLogger.e('TripService: Error generating dispatch sheet', e, stack);
      rethrow;
    }
  }

  /// Update stop status and timestamps
  Future<void> updateStopStatus({
    required String stopId,
    required String status,
    DateTime? actualArrival,
    DateTime? actualDeparture,
  }) async {
    AppLogger.i('TripService: Updating stop $stopId status to $status');
    try {
      final updates = <String, dynamic>{
        'status': status,
      };
      if (actualArrival != null) {
        updates['actual_arrival'] = actualArrival.toIso8601String();
      }
      if (actualDeparture != null) {
        updates['actual_departure'] = actualDeparture.toIso8601String();
      }

      await _client.from('rc_stops').update(updates).eq('id', stopId);
    } catch (e, stack) {
      AppLogger.e('TripService: Error updating stop status', e, stack);
      rethrow;
    }
  }
}
