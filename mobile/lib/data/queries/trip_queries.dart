class TripQueries {
  /// The name of the database table for trips.
  static const String table = 'trips';

  /// Selects a trip along with its related load, truck, and driver information.
  ///
  /// This query is typically used for displaying comprehensive trip details,
  /// including nested rate confirmations and their stops, truck details,
  /// and the driver's full name.
  ///
  /// **Used in:**
  /// - `TripService.getTrips`: To list trips.
  /// - `TripService.getTripByLoadId`: To find a trip associated with a load.
  static const String selectTripWithRelations = '''
    *,
    load:loads(*, rate_confirmations(*, rc_stops!rc_stops_rate_confirmation_id_fkey(*))),
    truck:trucks(truck_number, make, model),
    driver:profiles(full_name)
  ''';

  /// Selects a trip with relations specifically for update operations.
  /// Similar to `selectTripWithRelations` but excludes driver profile join if not needed for the object return.
  ///
  /// **Used in:**
  /// - `TripService.createTrip`: Returning the created trip.
  /// - `TripService.updateTrip`: Returning the updated trip.
  static const String selectTripWithRelationsForUpdate = '''
    *,
    load:loads(*, rate_confirmations(*, rc_stops!rc_stops_rate_confirmation_id_fkey(*))),
    truck:trucks(truck_number, make, model)
  ''';

  /// Selects the active trip for a driver.
  ///
  /// **Used in:**
  /// - `TripService.getActiveTrip`: To check for currently active trips.
  static const String selectActiveTrip = '''
    *,
    load:loads(*, rate_confirmations(*, rc_stops!rc_stops_rate_confirmation_id_fkey(*))),
    truck:trucks(truck_number, make, model)
  ''';
}
