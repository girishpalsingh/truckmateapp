import 'package:supabase_flutter/supabase_flutter.dart';
import '../data/models/rate_con_model.dart';
import '../data/models/risk_clause.dart';

class RateConService {
  final SupabaseClient _client;

  RateConService({SupabaseClient? client})
      : _client = client ?? Supabase.instance.client;

  /// Get a rate confirmation with all related data
  Future<RateCon> getRateCon(String id) async {
    final response = await _client.from('rate_confirmations').select('''
          *,
          reference_numbers(*),
          stops(*),
          charges(*),
          risk_clauses(
            *,
            clause_notifications(*)
          )
        ''').eq('id', id).single();

    return RateCon.fromJson(response);
  }

  /// Get rate confirmation by document ID
  Future<RateCon?> getRateConByDocumentId(String documentId) async {
    final response = await _client.from('rate_confirmations').select('''
          *,
          reference_numbers(*),
          stops(*),
          charges(*),
          risk_clauses(
            *,
            clause_notifications(*)
          )
        ''').eq('document_id', documentId).maybeSingle();

    if (response == null) return null;
    return RateCon.fromJson(response);
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

  /// Approve rate confirmation with optional edits
  Future<void> approveRateCon(String id, Map<String, dynamic> edits) async {
    final updates = {
      ...edits,
      'status': 'approved',
      'updated_at': DateTime.now().toIso8601String(),
    };
    await _client.from('rate_confirmations').update(updates).eq('id', id);
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
    final response = await _client.from('risk_clauses').select('''
          *,
          clause_notifications(*)
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
