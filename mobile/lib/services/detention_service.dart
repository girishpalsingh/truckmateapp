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

  /// Start detention: Upload photo (optional), track location, create record
  Future<DetentionRecord> startDetention({
    required String organizationId,
    required String loadId,
    required String stopId,
    required double lat,
    required double lng,
    Uint8List? photoBytes, // Optional for simulator testing
  }) async {
    try {
      String? photoPath;

      // 1. Upload Photo only if provided
      if (photoBytes != null) {
        photoPath = await _documentService.uploadDocument(
          organizationId: organizationId,
          tripId:
              loadId, // Using loadId as folder grouping for simplicity if tripId unknown
          documentType: 'detention_evidence',
          imageBytes: photoBytes,
          fileName:
              'detention_start_${DateTime.now().millisecondsSinceEpoch}.jpg',
        );
      }

      // 2. Insert Record
      final insertData = {
        'organization_id': organizationId,
        'load_id': loadId,
        'stop_id': stopId,
        'start_time': DateTime.now().toIso8601String(),
        'start_location_lat': lat,
        'start_location_lng': lng,
      };

      // Only add photo fields if photo was uploaded
      if (photoPath != null) {
        insertData['evidence_photo_url'] = photoPath;
        insertData['evidence_photo_time'] = DateTime.now().toIso8601String();
      }

      final response = await _client
          .from(DetentionQueries.recordsTable)
          .insert(insertData)
          .select()
          .single();

      return DetentionRecord.fromJson(response);
    } catch (e, stack) {
      AppLogger.e('DetentionService: Error starting detention', e, stack);
      rethrow;
    }
  }

  /// Delete a detention record
  Future<void> deleteDetention(String recordId) async {
    try {
      await _client
          .from(DetentionQueries.recordsTable)
          .delete()
          .eq('id', recordId);
      AppLogger.i('DetentionService: Deleted detention record $recordId');
    } catch (e, stack) {
      AppLogger.e('DetentionService: Error deleting detention', e, stack);
      rethrow;
    }
  }

  /// Get existing detention for a specific stop (including completed ones)
  Future<DetentionRecord?> getExistingDetentionForStop(String stopId) async {
    try {
      final response = await _client
          .from(DetentionQueries.recordsTable)
          .select()
          .eq('stop_id', stopId)
          .order('start_time', ascending: false)
          .limit(1);

      if (response.isEmpty) return null;
      return DetentionRecord.fromJson(response.first);
    } catch (e, stack) {
      AppLogger.e(
          'DetentionService: Error getting detention for stop', e, stack);
      rethrow;
    }
  }

  /// Get active detention for a load (if any)
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
      // Get the most recent active detention (no end_time)
      // Using limit(1) to handle case where multiple records exist
      final response = await _client
          .from(DetentionQueries.recordsTable)
          .select()
          .eq('load_id', loadId)
          .isFilter('end_time', null) // Check if end_time is null
          .order('start_time', ascending: false)
          .limit(1);

      if (response.isEmpty) return null;
      return DetentionRecord.fromJson(response.first);
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
  ///
  /// [detentionRecordId] - The ID of the detention record
  /// [invoiceDetails] - Map containing invoice details (rate, hours, etc.)
  /// [sendEmail] - If true, sends the invoice via email to the broker
  Future<DetentionInvoice> createInvoice({
    required String detentionRecordId,
    required Map<String, dynamic> invoiceDetails,
    bool sendEmail = false,
  }) async {
    try {
      final response = await _client.functions.invoke(
        'create-detention-invoice',
        body: {
          'detention_record_id': detentionRecordId,
          'invoice_details': invoiceDetails,
          'send_email': sendEmail,
        },
      );

      if (response.status != 200) {
        throw Exception(response.data?['error'] ?? 'Invoice creation failed');
      }

      // Edge function returns { success: true, invoice_id: ..., url: ... }
      // Fetch the newly created record
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
