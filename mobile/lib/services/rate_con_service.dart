import 'package:supabase_flutter/supabase_flutter.dart';
import '../data/models/rate_con_model.dart';
import '../data/models/risk_clause.dart';
import '../core/utils/app_logger.dart';

class RateConService {
  final SupabaseClient _client;

  RateConService({SupabaseClient? client})
      : _client = client ?? Supabase.instance.client;

  /// Get a rate confirmation with all related data
  Future<RateCon> getRateCon(String id) async {
    AppLogger.d('RateConService: Fetching RateCon $id');
    try {
      final response = await _client.from('rate_confirmations').select('''
          *,
          rc_references:rc_references!rc_references_rate_confirmation_id_fkey(*),
          rc_stops:rc_stops!rc_stops_rate_confirmation_id_fkey(
            *,
            rc_commodities(*)
          ),
          rc_charges:rc_charges!rc_charges_rate_confirmation_id_fkey(*),
          rc_risk_clauses:rc_risk_clauses!rc_risk_clauses_rate_confirmation_id_fkey(
            *,
            rc_notifications(*)
          )
        ''').eq('id', id).maybeSingle();

      if (response == null) {
        throw Exception('Rate confirmation not found with id: $id');
      }
      return RateCon.fromJson(response);
    } catch (e, stack) {
      AppLogger.e('RateConService: Error fetching RateCon $id', e, stack);
      rethrow;
    }
  }

  /// Get rate confirmation by document ID
  Future<RateCon?> getRateConByDocumentId(String documentId) async {
    AppLogger.d('RateConService: Fetching RateCon by doc ID $documentId');
    try {
      final response = await _client.from('rate_confirmations').select('''
          *,
          rc_references:rc_references!rc_references_rate_confirmation_id_fkey(*),
          rc_stops:rc_stops!rc_stops_rate_confirmation_id_fkey(
            *,
            rc_commodities(*)
          ),
          rc_charges:rc_charges!rc_charges_rate_confirmation_id_fkey(*),
          rc_risk_clauses:rc_risk_clauses!rc_risk_clauses_rate_confirmation_id_fkey(
            *,
            rc_notifications(*)
          )
        ''').eq('document_id', documentId).maybeSingle();

      if (response == null) return null;
      return RateCon.fromJson(response);
    } catch (e, stack) {
      AppLogger.e('RateConService: Error fetching RateCon by doc $documentId',
          e, stack);
      rethrow;
    }
  }

  /// List all rate confirmations for the organization (without full related data)
  Future<List<RateCon>> listRateCons() async {
    final response = await _client
        .from('rate_confirmations')
        .select()
        .order('created_at', ascending: false);

    return (response as List).map((e) => RateCon.fromJson(e)).toList();
  }

  /// Update rate confirmation fields
  Future<void> updateRateCon(String id, Map<String, dynamic> updates) async {
    await _client.from('rate_confirmations').update({
      ...updates,
      'updated_at': DateTime.now().toIso8601String(),
    }).eq('id', id);
  }

  /// Approve rate confirmation and create load. Returns the new Load ID.
  Future<String> approveRateCon(String id, Map<String, dynamic> edits) async {
    AppLogger.i('RateConService: Approving RateCon $id (Client-side)');
    try {
      // 1. Update status and Apply Edits to Rate Con
      final updateData = {
        ...edits,
        'status': 'approved',
        'updated_at': DateTime.now().toIso8601String(),
      };
      await _client.from('rate_confirmations').update(updateData).eq('id', id);

      // 2. Fetch Rate Con Data for Mapping
      // We re-fetch to ensure we have the latest merged data (edits + existing)
      final rateConResponse = await _client
          .from('rate_confirmations')
          .select()
          .eq('id', id)
          .single();

      // 3. Create Load
      // Map fields from Rate Con to Load
      final loadData = {
        'organization_id': rateConResponse['organization_id'],
        'rate_confirmation_id': id,
        'broker_name': rateConResponse['broker_name'],
        'broker_load_id': rateConResponse['load_reference_number'],
        'primary_rate': rateConResponse['total_rate_amount'] ??
            rateConResponse['rate_amount'],
        'status': 'assigned',
        'created_at': DateTime.now().toIso8601String(),
      };

      final loadResponse =
          await _client.from('loads').insert(loadData).select().single();

      return loadResponse['id'] as String;
    } catch (e, stack) {
      AppLogger.e('RateConService: Error approving RateCon $id', e, stack);
      rethrow;
    }
  }

  /// Reject rate confirmation
  Future<void> rejectRateCon(String id) async {
    final updates = {
      'status': 'rejected',
      'updated_at': DateTime.now().toIso8601String(),
    };
    await _client.from('rate_confirmations').update(updates).eq('id', id);
  }

  /// Get risk clauses for a rate confirmation
  Future<List<RiskClause>> getRiskClauses(String rateConfirmationId) async {
    final response = await _client.from('rc_risk_clauses').select('''
          *,
          rc_notifications(*)
        ''').eq('rate_confirmation_id', rateConfirmationId).order('created_at');

    return (response as List).map((e) => RiskClause.fromJson(e)).toList();
  }

  /// Get the document image URL for the rate confirmation
  Future<String?> getDocumentUrl(String documentId) async {
    final response = await _client
        .from('documents')
        .select('image_url')
        .eq('id', documentId)
        .maybeSingle();

    if (response == null) return null;

    final imagePath = response['image_url'] as String?;
    if (imagePath == null) return null;

    // Generate signed URL for private storage
    final signedUrl = await _client.storage
        .from('documents')
        .createSignedUrl(imagePath, 3600); // 1 hour expiry

    return signedUrl;
  }
}
