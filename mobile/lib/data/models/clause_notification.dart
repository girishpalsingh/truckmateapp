/// Trigger types for notifications
enum TriggerType { absolute, relative, conditional }

/// Start event types for notifications
enum NotificationEvent {
  beforeContractSignature,
  dailyCheckCall,
  status,
  detentionStart,
  deliveryDelay,
  deliveryDone,
  pickupDelay,
  pickupDone,
  other,
}

/// Model for clause notifications (machine-readable alerts)
class ClauseNotification {
  final String id;
  final String riskClauseId;
  final String? title;
  final String? description;
  final TriggerType? triggerType;
  final NotificationEvent? startEvent;
  final DateTime? deadlineIso;
  final int? relativeMinutesOffset;
  final String? originalClauseExcerpt;
  final DateTime? createdAt;

  ClauseNotification({
    required this.id,
    required this.riskClauseId,
    this.title,
    this.description,
    this.triggerType,
    this.startEvent,
    this.deadlineIso,
    this.relativeMinutesOffset,
    this.originalClauseExcerpt,
    this.createdAt,
  });

  factory ClauseNotification.fromJson(Map<String, dynamic> json) {
    return ClauseNotification(
      id: json['notif_id']?.toString() ?? '',
      riskClauseId: json['clause_id']?.toString() ?? '',
      title: json['title'],
      description: json['description'],
      triggerType: _parseTriggerType(json['trigger_type']),
      startEvent: _parseStartEvent(json['start_event']),
      deadlineIso: json['deadline_iso'] != null
          ? DateTime.tryParse(json['deadline_iso'])
          : null,
      relativeMinutesOffset: json['relative_minutes_offset'],
      originalClauseExcerpt: json['original_clause_excerpt'],
      createdAt: json['created_at'] != null
          ? DateTime.parse(json['created_at'])
          : null,
    );
  }

  static TriggerType? _parseTriggerType(String? value) {
    switch (value) {
      case 'Absolute':
        return TriggerType.absolute;
      case 'Relative':
        return TriggerType.relative;
      case 'Conditional':
        return TriggerType.conditional;
      default:
        return null;
    }
  }

  static NotificationEvent? _parseStartEvent(String? value) {
    switch (value) {
      case 'Before Contract signature':
        return NotificationEvent.beforeContractSignature;
      case 'Daily Check Call':
        return NotificationEvent.dailyCheckCall;
      case 'Status':
        return NotificationEvent.status;
      case 'Detention Start':
        return NotificationEvent.detentionStart;
      case 'Delivery Delay':
        return NotificationEvent.deliveryDelay;
      case 'Delivery Done':
        return NotificationEvent.deliveryDone;
      case 'Pickup Delay':
        return NotificationEvent.pickupDelay;
      case 'Pickup Done':
        return NotificationEvent.pickupDone;
      default:
        return NotificationEvent.other;
    }
  }

  Map<String, dynamic> toJson() {
    return {
      'id': id,
      'risk_clause_id': riskClauseId,
      'title': title,
      'description': description,
      'trigger_type': triggerType?.name,
      'start_event': startEvent?.name,
      'deadline_iso': deadlineIso?.toIso8601String(),
      'relative_minutes_offset': relativeMinutesOffset,
      'original_clause_excerpt': originalClauseExcerpt,
      'created_at': createdAt?.toIso8601String(),
    };
  }

  String get displayTiming {
    if (triggerType == TriggerType.relative && relativeMinutesOffset != null) {
      final minutes = relativeMinutesOffset!.abs();
      if (minutes >= 60) {
        return '${(minutes / 60).floor()} hours before';
      }
      return '$minutes mins before';
    }
    if (deadlineIso != null) {
      return 'By ${deadlineIso!.toLocal()}';
    }
    return 'When triggered';
  }
}
