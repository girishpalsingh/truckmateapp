class LoadQueries {
  static const String table = 'loads';

  /// Selects loads with their deep nested hierarchy:
  /// - `rate_confirmations`: Linked RCs.
  ///   - `rc_stops`: Stops for the RC (explicit fk).
  ///     - `rc_commodities`: Commodities for each stop.
  /// - `dispatch_assignments`: Active assignments (explicit fk).
  ///   - `driver`, `truck`: Details of the assigned resources.
  ///
  /// **Used in:**
  /// - `LoadService.getLoads`: To display the main list of loads.
  static const String selectLoadWithRelations = '''
    *, 
    rate_confirmations(*, rc_stops!rc_stops_rate_confirmation_id_fkey(*, rc_commodities(*))), 
    dispatch_assignments!dispatch_assignments_load_id_fkey(*, driver:driver_id(*), truck:truck_id(*))
  ''';

  /// Selects a load with its rate confirmations.
  /// Lighter than `selectLoadWithRelations` as it doesn't fetch deep stops or assignments initially.
  ///
  /// **Used in:**
  /// - `LoadService.getLatestLoad`: For dashboard overview.
  /// - `LoadService.getLoad`: To fetch single load details.
  /// - `LoadService.getLoadByRateConId`: To find a load by RC ID.
  static const String selectLoadWithRateCon = '*, rate_confirmations(*)';

  /// Selects details of a dispatch assignment.
  /// Includes joined `driver`, `truck`, and `trailer` details.
  ///
  /// **Used in:**
  /// - `LoadService.getAssignment`: To show current assignment status.
  static const String selectAssignmentWithRelations = '''
    *,
    driver:driver_id(*),
    truck:truck_id(*),
    trailer:trailer_id(*)
  ''';
}
