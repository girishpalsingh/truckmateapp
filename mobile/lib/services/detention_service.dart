import 'dart:typed_data';

import 'package:supabase_flutter/supabase_flutter.dart';
import '../core/utils/app_logger.dart';
import '../data/models/detention_record.dart';
import '../data/models/detention_invoice.dart';
import '../data/queries/detention_queries.dart';
import 'document_service.dart';

class DetentionService {
  final SupabaseClient _client;
  final DocumentService _documentService;

  DetentionService({SupabaseClient? client, DocumentService? documentService})
      : _client = client ?? Supabase.instance.client,
        _documentService = documentService ?? DocumentService();

  /// Start detention: Upload photo, track location, create record
  Future<DetentionRecord> startDetention({
    required String organizationId,
    required String loadId,
    required String stopId,
    required double lat,
    required double lng,
    required Uint8List photoBytes,
  }) async {
    try {
      // 1. Upload Photo
      final photoPath = await _documentService.uploadDocument(
        organizationId: organizationId,
        tripId:
            loadId, // Using loadId as folder grouping for simplicity if tripId unknown
        documentType: 'detention_evidence',
        imageBytes: photoBytes,
        fileName:
            'detention_start_${DateTime.now().millisecondsSinceEpoch}.jpg',
      );

      // 2. Insert Record
      final response = await _client
          .from(DetentionQueries.recordsTable)
          .insert({
            'organization_id': organizationId,
            'load_id': loadId,
            'stop_id': stopId,
            'start_time': DateTime.now().toIso8601String(),
            'start_location_lat': lat,
            'start_location_lng': lng,
            'evidence_photo_url': photoPath,
            'evidence_photo_time': DateTime.now().toIso8601String(),
          })
          .select()
          .single();

      return DetentionRecord.fromJson(response);
    } catch (e, stack) {
      AppLogger.e('DetentionService: Error starting detention', e, stack);
      rethrow;
    }
  }

  /// Stop detention: Update record with end time/location
  Future<DetentionRecord> stopDetention({
    required String recordId,
    required double lat,
    required double lng,
  }) async {
    try {
      final response = await _client
          .from(DetentionQueries.recordsTable)
          .update({
            'end_time': DateTime.now().toIso8601String(),
            'end_location_lat': lat,
            'end_location_lng': lng,
          })
          .eq('id', recordId)
          .select()
          .single();

      return DetentionRecord.fromJson(response);
    } catch (e, stack) {
      AppLogger.e('DetentionService: Error stopping detention', e, stack);
      rethrow;
    }
  }

  /// Get active detention for a load (if any)
  Future<DetentionRecord?> getActiveDetention(String loadId) async {
    try {
      final response = await _client
          .from(DetentionQueries.recordsTable)
          .select()
          .eq('load_id', loadId)
          .isFilter('end_time', null) // Check if end_time is null
          .maybeSingle();

      if (response == null) return null;
      return DetentionRecord.fromJson(response);
    } catch (e, stack) {
      AppLogger.e('DetentionService: Error getting active detention', e, stack);
      rethrow;
    }
  }

  /// Get active detention across all loads (for dashboard)
  Future<List<DetentionRecord>> getAllActiveDetentions(
      String organizationId) async {
    try {
      final response = await _client
          .from(DetentionQueries.recordsTable)
          .select()
          .eq('organization_id', organizationId)
          .isFilter('end_time', null);

      return (response as List)
          .map((e) => DetentionRecord.fromJson(e))
          .toList();
    } catch (e, stack) {
      AppLogger.e(
          'DetentionService: Error getting all active detentions', e, stack);
      rethrow;
    }
  }

  /// Calculate draft invoice details locally
  /// Returns a Map with calculated values to be reviewed by user
  Future<Map<String, dynamic>> calculateDraftInvoice(String recordId) async {
    try {
      // Fetch record with load details
      final recordRes = await _client
          .from(DetentionQueries.recordsTable)
          .select('*, loads(*, rate_confirmations(*, rc_risk_clauses(*)))')
          .eq('id', recordId)
          .single();

      final record = DetentionRecord.fromJson(recordRes);

      // Calculate Duration
      final endTime = record.endTime ?? DateTime.now();
      final duration = endTime.difference(record.startTime);
      final totalHours = duration.inMinutes / 60.0;

      // Default Values
      double freeTimeHours = 2.0;
      double ratePerHour = 50.0;

      // Try to parse from Rate Con Clauses
      final load = recordRes['loads'];
      if (load != null && load['rate_confirmations'] != null) {
        // Logic to parse rate_confirmations -> rc_risk_clauses
        // This depends on how deep the relation is fetched.
        // Assuming we can find a clause with 'detention'
      }

      double payableHours =
          (totalHours - freeTimeHours).clamp(0.0, double.infinity);
      double totalDue = payableHours * ratePerHour;

      return {
        'rate_per_hour': ratePerHour,
        'total_hours': totalHours,
        'payable_hours': payableHours,
        'total_due': totalDue,
        'currency': 'USD',
        'free_time_hours': freeTimeHours,
        'bol_number': '', // To be filled by user or fetched if linked
        'facility_address': '', // Fetch from stop if linked
      };
    } catch (e, stack) {
      AppLogger.e(
          'DetentionService: Error calculating draft invoice', e, stack);
      rethrow;
    }
  }

  /// Create Final Invoice via Edge Function
  Future<DetentionInvoice> createInvoice({
    required String detentionRecordId,
    required Map<String, dynamic> invoiceDetails,
  }) async {
    try {
      final response = await _client.functions.invoke(
        'create-detention-invoice',
        body: {
          'detention_record_id': detentionRecordId,
          'invoice_details': invoiceDetails,
        },
      );

      if (response.status != 200) {
        throw Exception(response.data?['error'] ?? 'Invoice creation failed');
      }

      // Edge function returns { success: true, invoice_id: ..., url: ... }
      // We might need to fetch the full record again or construct it.
      // Let's fetch the newly created record
      final invoiceId = response.data['invoice_id'];
      final invRes = await _client
          .from(DetentionQueries.invoicesTable)
          .select()
          .eq('id', invoiceId)
          .single();

      return DetentionInvoice.fromJson(invRes);
    } catch (e, stack) {
      AppLogger.e('DetentionService: Error creating invoice', e, stack);
      rethrow;
    }
  }
}
