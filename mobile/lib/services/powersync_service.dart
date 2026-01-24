import 'package:powersync/powersync.dart';
import 'package:supabase_flutter/supabase_flutter.dart';
import 'package:path_provider/path_provider.dart';
import 'package:path/path.dart';

import '../config/app_config.dart';
import '../core/utils/app_logger.dart';

/// Service for managing PowerSync (Offline-first data)
class PowerSyncService {
  late final PowerSyncDatabase _db;
  bool _initialized = false;

  static final PowerSyncService _instance = PowerSyncService._internal();

  factory PowerSyncService() {
    return _instance;
  }

  PowerSyncService._internal();

  PowerSyncDatabase get db => _db;

  Future<void> initialize() async {
    if (_initialized) return;

    // final config = AppConfig.instance;
    // Open the local database
    final dir = await getApplicationSupportDirectory();
    final path = join(dir.path, 'truckmate.db');

    _db = PowerSyncDatabase(
      schema: _schema,
      path: path,
    );

    await _db.initialize();

    // Connect to Supabase
    final connector = SupabaseConnector(_db);
    _db.connect(connector: connector);

    _initialized = true;
  }

  /// Define the local schema mapping
  final Schema _schema = const Schema([
    Table('trips', [
      Column.text('organization_id'),
      Column.text('load_id'),
      Column.text('truck_id'),
      Column.text('driver_id'),
      Column.text('origin_address'),
      Column.text('destination_address'),
      Column.integer('odometer_start'),
      Column.integer('odometer_end'),
      Column.integer('total_miles'),
      Column.text('status'),
      Column.text('created_at'),
      Column.text('updated_at'),
      Column.integer('detention_hours'),
    ]),
    Table('loads', [
      Column.text('organization_id'),
      Column.text('broker_name'),
      Column.text('broker_mc_number'),
      Column.text('broker_load_id'),
      Column.real('primary_rate'),
      Column.real('fuel_surcharge'),
      Column.text('payment_terms'),
      Column.integer('detention_policy_hours'),
      Column.real('detention_rate_per_hour'),
      Column.text('commodity_type'),
      Column.real('weight_lbs'),
      Column.text('pickup_address'), // stored as JSON string
      Column.text('delivery_address'), // stored as JSON string
      Column.text('notes'),
      Column.text('status'),
      Column.text('created_at'),
      Column.text('updated_at'),
    ]),
    Table('expenses', [
      Column.text('organization_id'),
      Column.text('trip_id'),
      Column.text('category'),
      Column.real('amount'),
      Column.text('currency'),
      Column.text('vendor_name'),
      Column.text('jurisdiction'),
      Column.real('gallons'),
      Column.real('price_per_gallon'),
      Column.text('date'),
      Column.integer('is_reimbursable'), // boolean as integer
      Column.text('receipt_image_path'),
      Column.text('notes'),
      Column.text('created_at'),
      Column.text('updated_at'),
    ]),
    Table('profiles', [
      Column.text('organization_id'),
      Column.text('role'),
      Column.text('full_name'),
      Column.text('phone_number'),
      Column.text('email_address'),
      Column.text('address'), // JSON string
      Column.text('preferred_language'),
      Column.text('fcm_token'),
      Column.integer('is_active'),
    ]),
    Table('trucks', [
      Column.text('organization_id'),
      Column.text('truck_number'),
      Column.text('make'),
      Column.text('model'),
      Column.integer('year'),
      Column.text('vin'),
      Column.text('plate_number'),
      Column.text('status'),
    ]),
  ]);
}

/// Connector to bridge PowerSync and Supabase
class SupabaseConnector extends PowerSyncBackendConnector {
  final PowerSyncDatabase db;

  SupabaseConnector(this.db);

  @override
  Future<PowerSyncCredentials?> fetchCredentials() async {
    // Get session from Supabase
    final session = Supabase.instance.client.auth.currentSession;
    if (session == null) {
      // Not logged in
      AppLogger.w('PowerSync: fetchCredentials called but user not logged in');
      return null;
    }

    // In a real implementation with valid Supabase Edge Function:
    // final response = await Supabase.instance.client.functions.invoke('powersync-auth');
    // return PowerSyncCredentials(
    //   endpoint: response.data['endpoint'],
    //   token: response.data['token'],
    // );

    // For now, assume AppConfig has the endpoint and we use a temporary token logic
    // OR return null if strictly requiring the backend token generation which we don't have here.
    // NOTE: This usually requires a backend function to generate the PowerSync token.
    // I will use a placeholder or read from Config if available, but standard is backend generation.

    final config = AppConfig.instance;
    if (config.powersync.instanceUrl.isEmpty) {
      return null;
    }

    // Just returning null for now as we don't have the backend token generator readily available
    // in the user request context.
    // To make this work "offline" conceptually, we assume the token is fetched or config is set.

    // WARNING: This part strictly fails without a backend token.
    // I will insert a TODO to call the edge function.

    try {
      final response =
          await Supabase.instance.client.functions.invoke('powersync-auth');
      return PowerSyncCredentials(
        endpoint: config.powersync.instanceUrl,
        token: response.data['token'],
      );
    } catch (e, stack) {
      AppLogger.e('PowerSync Auth Failed', e, stack);
      return null;
    }
  }

  @override
  Future<void> uploadData(PowerSyncDatabase database) async {
    final transaction = await database.getNextCrudTransaction();
    if (transaction == null) return;

    try {
      for (var op in transaction.crud) {
        final table = op.table;
        final id = op.id;
        final data = op.opData;

        // Map operations to Supabase calls
        switch (op.op) {
          case UpdateType.put:
            // Upsert
            await Supabase.instance.client
                .from(table)
                .upsert(data!); // Data includes ID
            break;
          case UpdateType.patch:
            // Update
            await Supabase.instance.client
                .from(table)
                .update(data!)
                .eq('id', id);
            break;
          case UpdateType.delete:
            // Delete
            await Supabase.instance.client.from(table).delete().eq('id', id);
            break;
        }
      }
      await transaction.complete();
      await transaction.complete();
    } catch (e, stack) {
      AppLogger.e('Sync upload error', e, stack);
      // Verify connectivity before throwing, or specific error handling
      rethrow;
    }
  }
}
