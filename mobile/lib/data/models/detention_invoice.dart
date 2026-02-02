class DetentionInvoice {
  final String id;
  final String invoiceNumber; // The display number
  final String detentionRecordId;
  final double amount;
  final double totalDue;
  final double ratePerHour;
  final double totalHours;
  final double payableHours;
  final String status;
  final String? pdfUrl;
  final DateTime createdAt;

  DetentionInvoice({
    required this.id,
    required this.invoiceNumber,
    required this.detentionRecordId,
    required this.amount,
    required this.totalDue,
    required this.ratePerHour,
    required this.totalHours,
    required this.payableHours,
    required this.status,
    this.pdfUrl,
    required this.createdAt,
  });

  factory DetentionInvoice.fromJson(Map<String, dynamic> json) {
    return DetentionInvoice(
      id: json['id'],
      invoiceNumber: json['detention_invoice_display_number'] ??
          json['invoice_number'], // handling both keys
      detentionRecordId: json['detention_record_id'],
      amount: (json['amount'] as num).toDouble(),
      totalDue: (json['total_due'] as num).toDouble(),
      ratePerHour: (json['rate_per_hour'] as num).toDouble(),
      totalHours: (json['total_hours'] as num).toDouble(),
      payableHours: (json['payable_hours'] as num).toDouble(),
      status: json['status'],
      pdfUrl: json['pdf_url'],
      createdAt: DateTime.parse(json['created_at']),
    );
  }
}
