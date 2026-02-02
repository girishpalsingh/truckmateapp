/// Model representing a detention invoice with financial details and metadata
class DetentionInvoice {
  final String id;
  final String invoiceNumber;
  final String detentionRecordId;
  final String? loadId;
  final double amount;
  final double totalDue;
  final double ratePerHour;
  final double totalHours;
  final double payableHours;
  final String? currency;
  final String status;
  final String? pdfUrl;

  // Reference numbers
  final String? poNumber;
  final String? bolNumber;

  // Facility info
  final String? facilityName;
  final String? facilityAddress;

  // Time and location
  final DateTime? startTime;
  final DateTime? endTime;
  final double? startLocationLat;
  final double? startLocationLng;
  final double? endLocationLat;
  final double? endLocationLng;

  // Evidence
  final String? detentionPhotoLink;
  final DateTime? detentionPhotoTime;

  // Email
  final String? brokerEmail;
  final DateTime? sentAt;

  final DateTime createdAt;

  DetentionInvoice({
    required this.id,
    required this.invoiceNumber,
    required this.detentionRecordId,
    this.loadId,
    required this.amount,
    required this.totalDue,
    required this.ratePerHour,
    required this.totalHours,
    required this.payableHours,
    this.currency,
    required this.status,
    this.pdfUrl,
    this.poNumber,
    this.bolNumber,
    this.facilityName,
    this.facilityAddress,
    this.startTime,
    this.endTime,
    this.startLocationLat,
    this.startLocationLng,
    this.endLocationLat,
    this.endLocationLng,
    this.detentionPhotoLink,
    this.detentionPhotoTime,
    this.brokerEmail,
    this.sentAt,
    required this.createdAt,
  });

  /// Parse from Supabase JSON response
  factory DetentionInvoice.fromJson(Map<String, dynamic> json) {
    return DetentionInvoice(
      id: json['id'],
      invoiceNumber: json['detention_invoice_display_number'] ??
          json['invoice_number'] ??
          'N/A',
      detentionRecordId: json['detention_record_id'],
      loadId: json['load_id'],
      amount: (json['amount'] as num?)?.toDouble() ?? 0.0,
      totalDue: (json['total_due'] as num?)?.toDouble() ?? 0.0,
      ratePerHour: (json['rate_per_hour'] as num?)?.toDouble() ?? 0.0,
      totalHours: (json['total_hours'] as num?)?.toDouble() ?? 0.0,
      payableHours: (json['payable_hours'] as num?)?.toDouble() ?? 0.0,
      currency: json['currency'] ?? 'USD',
      status: json['status'] ?? 'DRAFT',
      pdfUrl: json['pdf_url'],
      poNumber: json['po_number'],
      bolNumber: json['bol_number'],
      facilityName: json['facility_name'],
      facilityAddress: json['facility_address'],
      startTime: json['start_time'] != null
          ? DateTime.parse(json['start_time'])
          : null,
      endTime:
          json['end_time'] != null ? DateTime.parse(json['end_time']) : null,
      startLocationLat: (json['start_location_lat'] as num?)?.toDouble(),
      startLocationLng: (json['start_location_lng'] as num?)?.toDouble(),
      endLocationLat: (json['end_location_lat'] as num?)?.toDouble(),
      endLocationLng: (json['end_location_lng'] as num?)?.toDouble(),
      detentionPhotoLink: json['detention_photo_link'],
      detentionPhotoTime: json['detention_photo_time'] != null
          ? DateTime.parse(json['detention_photo_time'])
          : null,
      brokerEmail: json['broker_email'],
      sentAt: json['sent_at'] != null ? DateTime.parse(json['sent_at']) : null,
      createdAt: DateTime.parse(json['created_at']),
    );
  }

  /// Convert to JSON for API requests
  Map<String, dynamic> toJson() {
    return {
      'id': id,
      'invoice_number': invoiceNumber,
      'detention_record_id': detentionRecordId,
      'load_id': loadId,
      'amount': amount,
      'total_due': totalDue,
      'rate_per_hour': ratePerHour,
      'total_hours': totalHours,
      'payable_hours': payableHours,
      'currency': currency,
      'status': status,
      'pdf_url': pdfUrl,
      'po_number': poNumber,
      'bol_number': bolNumber,
      'facility_name': facilityName,
      'facility_address': facilityAddress,
      'broker_email': brokerEmail,
    };
  }

  /// Check if email has been sent
  bool get isEmailSent => sentAt != null;

  /// Get formatted total duration
  String get formattedDuration {
    final hours = totalHours.floor();
    final minutes = ((totalHours - hours) * 60).round();
    return '${hours}h ${minutes}m';
  }
}
