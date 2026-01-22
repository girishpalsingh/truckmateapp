import 'package:supabase_flutter/supabase_flutter.dart';
import '../data/models/rate_con_model.dart';

class RateConService {
  final SupabaseClient _client;

  RateConService({SupabaseClient? client})
      : _client = client ?? Supabase.instance.client;

  Future<RateCon> getRateCon(String id) async {
    final response =
        await _client.from('rate_cons').select().eq('id', id).single();
    return RateCon.fromJson(response);
  }

  Future<void> updateRateCon(String id, Map<String, dynamic> updates) async {
    await _client.from('rate_cons').update(updates).eq('id', id);
  }

  Future<void> approveRateCon(
      String id, Map<String, dynamic> finalUpdates) async {
    final updates = {
      ...finalUpdates,
      'status': 'approved',
      'updated_at': DateTime.now().toIso8601String(),
    };
    await _client.from('rate_cons').update(updates).eq('id', id);
  }
}
