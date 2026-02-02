class DetentionQueries {
  static const String recordsTable = 'detention_records';
  static const String invoicesTable = 'detention_invoices';

  /// Selects detention records.
  static const String selectRecords = '*';

  /// Selects detention invoices.
  static const String selectInvoices = '*';

  /// Selects detention record with invoice
  static const String selectRecordWithInvoice = '*, detention_invoices(*)';
}
