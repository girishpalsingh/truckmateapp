import 'package:equatable/equatable.dart';

/// Status of a document in the sync queue
enum DocumentSyncStatus {
  pending, // Saved locally, not yet uploaded
  uploading, // Currently uploading to server
  uploaded, // Uploaded, waiting for LLM processing
  processing, // Server is processing with LLM
  complete, // LLM processing complete, response received
  failed, // Upload or processing failed
}

/// Model for documents pending sync
class PendingDocument extends Equatable {
  final String id;
  final String localPath;
  final String documentType;
  final String? tripId;
  final String? loadId;
  final String? organizationId;
  final DocumentSyncStatus syncStatus;
  final String? remoteUrl;
  final String? remoteDocumentId;
  final Map<String, dynamic>? llmResponse;
  final double? confidence;
  final List<dynamic>? dangerousClauses;
  final String? errorMessage;
  final DateTime createdAt;
  final DateTime? syncedAt;
  final int retryCount;

  const PendingDocument({
    required this.id,
    required this.localPath,
    required this.documentType,
    this.tripId,
    this.loadId,
    this.organizationId,
    this.syncStatus = DocumentSyncStatus.pending,
    this.remoteUrl,
    this.remoteDocumentId,
    this.llmResponse,
    this.confidence,
    this.dangerousClauses,
    this.errorMessage,
    required this.createdAt,
    this.syncedAt,
    this.retryCount = 0,
  });

  PendingDocument copyWith({
    String? id,
    String? localPath,
    String? documentType,
    String? tripId,
    String? loadId,
    String? organizationId,
    DocumentSyncStatus? syncStatus,
    String? remoteUrl,
    String? remoteDocumentId,
    Map<String, dynamic>? llmResponse,
    double? confidence,
    List<dynamic>? dangerousClauses,
    String? errorMessage,
    DateTime? createdAt,
    DateTime? syncedAt,
    int? retryCount,
  }) {
    return PendingDocument(
      id: id ?? this.id,
      localPath: localPath ?? this.localPath,
      documentType: documentType ?? this.documentType,
      tripId: tripId ?? this.tripId,
      loadId: loadId ?? this.loadId,
      organizationId: organizationId ?? this.organizationId,
      syncStatus: syncStatus ?? this.syncStatus,
      remoteUrl: remoteUrl ?? this.remoteUrl,
      remoteDocumentId: remoteDocumentId ?? this.remoteDocumentId,
      llmResponse: llmResponse ?? this.llmResponse,
      confidence: confidence ?? this.confidence,
      dangerousClauses: dangerousClauses ?? this.dangerousClauses,
      errorMessage: errorMessage ?? this.errorMessage,
      createdAt: createdAt ?? this.createdAt,
      syncedAt: syncedAt ?? this.syncedAt,
      retryCount: retryCount ?? this.retryCount,
    );
  }

  Map<String, dynamic> toJson() {
    return {
      'id': id,
      'local_path': localPath,
      'document_type': documentType,
      'trip_id': tripId,
      'load_id': loadId,
      'organization_id': organizationId,
      'sync_status': syncStatus.name,
      'remote_url': remoteUrl,
      'remote_document_id': remoteDocumentId,
      'llm_response': llmResponse,
      'confidence': confidence,
      'dangerous_clauses': dangerousClauses,
      'error_message': errorMessage,
      'created_at': createdAt.toIso8601String(),
      'synced_at': syncedAt?.toIso8601String(),
      'retry_count': retryCount,
    };
  }

  factory PendingDocument.fromJson(Map<String, dynamic> json) {
    return PendingDocument(
      id: json['id'] as String,
      localPath: json['local_path'] as String,
      documentType: json['document_type'] as String,
      tripId: json['trip_id'] as String?,
      loadId: json['load_id'] as String?,
      organizationId: json['organization_id'] as String?,
      syncStatus: DocumentSyncStatus.values.firstWhere(
        (e) => e.name == json['sync_status'],
        orElse: () => DocumentSyncStatus.pending,
      ),
      remoteUrl: json['remote_url'] as String?,
      remoteDocumentId: json['remote_document_id'] as String?,
      llmResponse: json['llm_response'] as Map<String, dynamic>?,
      confidence: (json['confidence'] as num?)?.toDouble(),
      dangerousClauses: json['dangerous_clauses'] as List<dynamic>?,
      errorMessage: json['error_message'] as String?,
      createdAt: DateTime.parse(json['created_at'] as String),
      syncedAt: json['synced_at'] != null
          ? DateTime.parse(json['synced_at'] as String)
          : null,
      retryCount: json['retry_count'] as int? ?? 0,
    );
  }

  bool get isPending => syncStatus == DocumentSyncStatus.pending;
  bool get isComplete => syncStatus == DocumentSyncStatus.complete;
  bool get isFailed => syncStatus == DocumentSyncStatus.failed;
  bool get isProcessing =>
      syncStatus == DocumentSyncStatus.processing ||
      syncStatus == DocumentSyncStatus.uploading;
  bool get hasLlmResponse => llmResponse != null;
  bool get hasDangerousClauses =>
      dangerousClauses != null && dangerousClauses!.isNotEmpty;

  String get statusDisplay {
    switch (syncStatus) {
      case DocumentSyncStatus.pending:
        return 'Pending Sync';
      case DocumentSyncStatus.uploading:
        return 'Uploading...';
      case DocumentSyncStatus.uploaded:
        return 'Processing...';
      case DocumentSyncStatus.processing:
        return 'Analyzing...';
      case DocumentSyncStatus.complete:
        return 'Complete';
      case DocumentSyncStatus.failed:
        return 'Failed';
    }
  }

  String get documentTypeDisplay {
    switch (documentType) {
      case 'rate_con':
        return 'Rate Confirmation';
      case 'bol':
        return 'Bill of Lading';
      case 'fuel_receipt':
        return 'Fuel Receipt';
      case 'lumper_receipt':
        return 'Lumper Receipt';
      case 'scale_ticket':
        return 'Scale Ticket';
      case 'detention_evidence':
        return 'Detention Evidence';
      default:
        return 'Document';
    }
  }

  @override
  List<Object?> get props => [
        id,
        localPath,
        documentType,
        tripId,
        loadId,
        organizationId,
        syncStatus,
        remoteUrl,
        remoteDocumentId,
        llmResponse,
        confidence,
        dangerousClauses,
        errorMessage,
        createdAt,
        syncedAt,
        retryCount,
      ];
}
