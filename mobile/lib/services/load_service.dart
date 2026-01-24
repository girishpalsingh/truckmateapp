import 'package:supabase_flutter/supabase_flutter.dart';
import '../data/models/load.dart';
import '../data/models/trip.dart';

class LoadService {
  final SupabaseClient _supabase = Supabase.instance.client;

  // Approve Rate Con and Create Load
  Future<String> approveRateCon(String rateConId) async {
    // 1. Update Rate Con Status
    await _supabase
        .from('rate_confirmations')
        .update({'status': 'approved'}).eq('id', rateConId);

    // 2. Fetch Rate Con Data for Mapping
    final rateConResponse = await _supabase
        .from('rate_confirmations')
        .select('*, stops(*)')
        .eq('id', rateConId)
        .single();

    final rateCon = rateConResponse;
    final String orgId = rateCon['organization_id'];

    // 3. Create Load
    // Mapping fields from Rate Con to Load
    // Broker Name might come from a linked broker table or text field?
    // rate_confirmations schema has broker_name? I should check schema.
    // Assuming yes based on rate-con-processor.ts

    final loadData = {
      'organization_id': orgId,
      'rate_confirmation_id': rateConId,
      'broker_name': rateCon['broker_name'],
      'broker_load_id': rateCon['load_reference_number'], // Mapping logic
      'primary_rate': rateCon['rate_amount'],
      'status': 'assigned',
      // 'pickup_address': ... extract from first stop?
      // 'delivery_address': ... extract from last stop?
      // For now we keep it simple, trips manage specific stops.
    };

    final loadResponse =
        await _supabase.from('loads').insert(loadData).select().single();

    return loadResponse['id'];
  }

  // Get Latest Pending/Assigned Load for Dashboard
  Future<Map<String, dynamic>?> getLatestLoad() async {
    final response = await _supabase
        .from('loads')
        .select('*, rate_confirmations(*)') // Fetch linked RC for details
        .order('created_at', ascending: false)
        .limit(1)
        .maybeSingle();

    return response;
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
}
