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
        'start_time': DateTime.now().toUtc().toIso8601String(),
        'start_location_lat': lat,
        'start_location_lng': lng,
      };

      // Only add photo fields if photo was uploaded
      if (photoPath != null) {
        insertData['evidence_photo_url'] = photoPath;
        insertData['evidence_photo_time'] =
            DateTime.now().toUtc().toIso8601String();
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
            'end_time': DateTime.now().toUtc().toIso8601String(),
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
      // Fetch Stop Details
      Map<String, dynamic>? stop;
      try {
        final stopIdInt = int.tryParse(record.stopId);
        if (stopIdInt != null) {
          final stopRes = await _client
              .from('rc_stops')
              .select()
              .eq('stop_id', stopIdInt)
              .maybeSingle();
          stop = stopRes;
        }
      } catch (e) {
        AppLogger.w(
            'DetentionService: Could not fetch stop details for invoice');
      }

      final load = recordRes['loads'];
      String? bolNumber;
      String? poNumber;

      if (load != null) {
        // Use broker_load_id as PO Number by default
        poNumber = load['broker_load_id'];

        // Try to parse rate from clauses
        if (load['rate_confirmations'] != null &&
            load['rate_confirmations'] is List &&
            (load['rate_confirmations'] as List).isNotEmpty) {
          final rc = (load['rate_confirmations'] as List).first;
          if (rc['rc_risk_clauses'] != null) {
            final clauses = rc['rc_risk_clauses'] as List;
            for (final clause in clauses) {
              final title =
                  (clause['clause_title'] as String?)?.toLowerCase() ?? '';
              final text =
                  (clause['original_text'] as String?)?.toLowerCase() ?? '';

              if (title.contains('detention') || text.contains('detention')) {
                // Try to find rate pattern like $50, $50/hour, $ 50
                final RegExp rateRegex = RegExp(r'\$\s?(\d+)');
                final match = rateRegex.firstMatch(text);
                if (match != null) {
                  final rateStr = match.group(1);
                  if (rateStr != null) {
                    final parsedRate = double.tryParse(rateStr);
                    if (parsedRate != null) {
                      ratePerHour = parsedRate;
                      AppLogger.d(
                          'Auto-detected detention rate: \$$ratePerHour from clause: $title');
                      break; // Stop after finding first detention rate
                    }
                  }
                }
              }
            }
          }
        }
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
        'bol_number': bolNumber ?? '',
        'po_number': poNumber ?? '',
        'facility_name': stop?['contact_name'] ??
            '', // Use contact as facility name fallback
        'facility_address': stop?['facility_address'] ?? '',
        'start_location_lat': record.startLocation?['lat'],
        'start_location_lng': record.startLocation?['lng'],
        'end_location_lat': record.endLocation?['lat'],
        'end_location_lng': record.endLocation?['lng'],
        'start_time': record.startTime.toIso8601String(),
        'end_time': record.endTime?.toIso8601String(),
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
      final invoiceUrl = response.data['url']; // URL from edge function

      final invRes = await _client
          .from(DetentionQueries.invoicesTable)
          .select()
          .eq('id', invoiceId)
          .single();

      // Create object and inject the signed URL from the response
      // The DB likely only stores the path or raw URL, not the signed one needed for immediate viewing
      return DetentionInvoice.fromJson(invRes).copyWith(pdfUrl: invoiceUrl);
    } catch (e, stack) {
      AppLogger.e('DetentionService: Error creating invoice', e, stack);
      rethrow;
    }
  }
}
