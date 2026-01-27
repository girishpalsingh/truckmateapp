import 'package:supabase_flutter/supabase_flutter.dart';
import '../data/models/load.dart';
import '../data/models/trip.dart';
import '../core/utils/app_logger.dart';
import '../data/queries/load_queries.dart';

class LoadService {
  final SupabaseClient _supabase = Supabase.instance.client;

  // Get all loads for the organization
  Future<List<Load>> getLoads() async {
    final response = await _supabase
        .from(LoadQueries.table)
        .select(LoadQueries
            .selectLoadWithRelations) // Fetch RC, rc_stops, rc_commodities, assignments
        .order('created_at', ascending: false);

    return (response as List).map((e) => Load.fromJson(e)).toList();
  }

  // Get Latest Pending/Assigned Load for Dashboard (Optional: Keep if needed for widget)
  Future<Load?> getLatestLoad() async {
    final response = await _supabase
        .from(LoadQueries.table)
        .select(
            LoadQueries.selectLoadWithRateCon) // Fetch linked RC for details
        .order('created_at', ascending: false)
        .limit(1)
        .maybeSingle();

    if (response == null) return null;
    return Load.fromJson(response);
  }

  // Get single load by ID
  Future<Load?> getLoad(String loadId) async {
    final response = await _supabase
        .from(LoadQueries.table)
        .select(LoadQueries.selectLoadWithRateCon)
        .eq('id', loadId)
        .maybeSingle();

    if (response == null) return null;
    return Load.fromJson(response);
  }

  /// Get a load by its associated Rate Con ID (integer rc_id)
  Future<Map<String, dynamic>?> getLoadByRateConId(int rcId) async {
    try {
      final response = await _supabase
          .from(LoadQueries.table)
          .select(LoadQueries.selectLoadWithRateCon)
          .eq('active_rate_con_id', rcId)
          .maybeSingle();
      return response;
    } catch (e, stack) {
      AppLogger.e('LoadService: Error fetching load by rc_id', e, stack);
      return null;
    }
  }

  // Create Trip for a Load
  Future<String> createTripForLoad({
    required String loadId,
    required Map<String, dynamic> tripData,
    // sequences
  }) async {
    // 1. Create Trip
    final tripResponse =
        await _supabase.from('trips').insert(tripData).select().single();

    final tripId = tripResponse['id'];

    // 2. Link in trip_loads
    await _supabase.from('trip_loads').insert({
      'trip_id': tripId,
      'load_id': loadId,
      'pickup_sequence': 1,
      'delivery_sequence': 1,
    });

    return tripId;
  }

  // Get current active assignment for a load
  Future<Map<String, dynamic>?> getAssignment(String loadId) async {
    final response = await _supabase
        .from('dispatch_assignments')
        .select(LoadQueries.selectAssignmentWithRelations)
        .eq('load_id', loadId)
        .eq('status', 'ACTIVE')
        .maybeSingle();
    return response;
  }

  // Assign Driver and Truck to Load
  Future<void> assignLoad({
    required String loadId,
    required String organizationId,
    required String driverId,
    required String truckId,
    String? trailerId,
  }) async {
    // 1. Check for existing active assignment
    final existing = await _supabase
        .from('dispatch_assignments')
        .select()
        .eq('load_id', loadId)
        .eq('status', 'ACTIVE')
        .maybeSingle();

    if (existing != null) {
      // Mark as cancelled or simply update it?
      // Let's update the existing one to keep it simple and avoid constraint issues if we wanted to replace it.
      await _supabase.from('dispatch_assignments').update({
        'driver_id': driverId,
        'truck_id': truckId,
        'trailer_id': trailerId,
        'assigned_at': DateTime.now().toIso8601String(),
      }).eq('id', existing['id']);
    } else {
      // Insert new
      await _supabase.from('dispatch_assignments').insert({
        'load_id': loadId,
        'organization_id': organizationId,
        'driver_id': driverId,
        'truck_id': truckId,
        'trailer_id': trailerId,
        'status': 'ACTIVE',
      });
    }

    // Also update Load status to 'assigned' if it's currently 'created'
    // AND sync the resource IDs to the loads table for RLS/Caching
    await _supabase.from('loads').update({
      'status': 'assigned', // Workflow: moves from created -> assigned
      'driver_id': driverId,
      'truck_id': truckId,
      'trailer_id': trailerId,
    }).eq('id', loadId);
  }

  // Generate Dispatch Sheet
  // Note: Function accepts load_id or trip_id.
  // For Load ID, it's safer to pass the Rate Confirmation UUID (rc['id'])
  // because the backend association between load -> rc might be via an integer ID that PostgREST doesn't expand easily in the function.
  Future<Map<String, dynamic>> generateDispatchSheet(String id,
      {String? tripId}) async {
    AppLogger.i(
        'LoadService: generateDispatchSheet invoking with load_id=$id, trip_id=$tripId');
    final response = await _supabase.functions.invoke(
      'generate-dispatch-sheet',
      body: {
        'load_id': id,
        if (tripId != null) 'trip_id': tripId,
      },
    );

    if (response.status != 200) {
      AppLogger.e(
          'LoadService: Dispatch Sheet Generation Failed. Status: ${response.status}, Data: ${response.data}');
      throw Exception('Failed to generate dispatch sheet: ${response.data}');
    }

    return response.data as Map<String, dynamic>;
  }

  // Generate Invoice (Requires Trip ID)
  Future<void> generateInvoice(String tripId) async {
    final response = await _supabase.functions.invoke(
      'generate-invoice',
      body: {'trip_id': tripId},
    );

    if (response.status != 200) {
      throw Exception('Failed to generate invoice: ${response.data}');
    }
  }
}
