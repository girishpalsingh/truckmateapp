class RateConClause {
  final String id;
  final String rateConId;
  final String? clauseType;
  final String? trafficLight; // 'RED', 'YELLOW', 'GREEN'
  final String? clauseTitle;
  final String? clauseTitlePunjabi;
  final String? dangerSimpleLanguage;
  final String? dangerSimplePunjabi;
  final String? originalText;
  final String? warningEn;
  final String? warningPa;
  final Map<String, dynamic>? notification;
  final Map<String, dynamic>?
      notificationData; // Map from notification_data jsonb

  // Explicit notification fields
  final String? notificationTitle;
  final String? notificationDescription;
  final String? notificationTriggerType;
  final DateTime? notificationDeadline;
  final int? notificationRelativeOffset;
  final String? notificationStartEvent;

  final DateTime createdAt;

  RateConClause({
    required this.id,
    required this.rateConId,
    this.clauseType,
    this.trafficLight,
    this.clauseTitle,
    this.clauseTitlePunjabi,
    this.dangerSimpleLanguage,
    this.dangerSimplePunjabi,
    this.originalText,
    this.warningEn,
    this.warningPa,
    this.notification,
    this.notificationData,
    this.notificationTitle,
    this.notificationDescription,
    this.notificationTriggerType,
    this.notificationDeadline,
    this.notificationRelativeOffset,
    this.notificationStartEvent,
    required this.createdAt,
  });

  factory RateConClause.fromJson(Map<String, dynamic> json) {
    return RateConClause(
      id: json['id'],
      rateConId: json['rate_con_id'],
      clauseType: json['clause_type'],
      trafficLight: json['traffic_light'],
      clauseTitle: json['clause_title'],
      clauseTitlePunjabi: json['clause_title_punjabi'],
      dangerSimpleLanguage: json['danger_simple_language'],
      dangerSimplePunjabi: json['danger_simple_punjabi'],
      originalText: json['original_text'],
      warningEn: json['warning_en'],
      warningPa: json['warning_pa'],
      notification: json['notification'],
      notificationData: json['notification_data'],
      notificationTitle: json['notification_title'],
      notificationDescription: json['notification_description'],
      notificationTriggerType: json['notification_trigger_type'],
      notificationDeadline: json['notification_deadline'] != null
          ? DateTime.tryParse(json['notification_deadline'])
          : null,
      notificationRelativeOffset: json['notification_relative_offset'],
      notificationStartEvent: json['notification_start_event'],
      createdAt: DateTime.parse(json['created_at']),
    );
  }
}
