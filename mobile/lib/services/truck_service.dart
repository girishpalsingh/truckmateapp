import 'package:supabase_flutter/supabase_flutter.dart';
import '../data/models/truck.dart';
import '../core/utils/app_logger.dart';

/// Service for managing trucks
class TruckService {
  final SupabaseClient _client;

  TruckService({SupabaseClient? client})
      : _client = client ?? Supabase.instance.client;

  /// Get all trucks for an organization
  Future<List<Truck>> getTrucks(String organizationId) async {
    AppLogger.d('TruckService: Fetching trucks for org $organizationId');
    try {
      final response = await _client
          .from('trucks')
          .select()
          .eq('organization_id', organizationId)
          .order('truck_number');

      return (response as List).map((json) => Truck.fromJson(json)).toList();
    } catch (e, stack) {
      AppLogger.e('TruckService: Error fetching trucks', e, stack);
      rethrow;
    }
  }

  /// Match a truck by truck number or license plate
  Future<Truck?> matchTruck(String organizationId, String? identifier) async {
    if (identifier == null || identifier.isEmpty) return null;

    AppLogger.d('TruckService: Attempting to match truck: $identifier');
    try {
      // Try exact match on truck number
      final exactMatch = await _client
          .from('trucks')
          .select()
          .eq('organization_id', organizationId)
          .eq('truck_number', identifier)
          .maybeSingle();

      if (exactMatch != null) return Truck.fromJson(exactMatch);

      // Try license plate match
      final plateMatch = await _client
          .from('trucks')
          .select()
          .eq('organization_id', organizationId)
          .eq('license_plate', identifier)
          .maybeSingle();

      if (plateMatch != null) return Truck.fromJson(plateMatch);

      return null;
    } catch (e) {
      AppLogger.w('TruckService: Error matching truck: $e');
      return null;
    }
  }
}
