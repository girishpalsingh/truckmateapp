import 'clause_notification.dart';

/// Traffic light risk levels
enum TrafficLight { red, yellow, green }

/// Model for risk clauses identified in rate confirmations
class RiskClause {
  final String id; // This might be clause_id (serial)
  final int? clauseId;
  final String? rateConfirmationId; // UUID
  final int? rcId; // Serial

  final String? clauseType;
  final TrafficLight trafficLight;

  final String? titleEn;
  final String? titlePunjabi;

  final String? explanationEn;
  final String? explanationPunjabi;

  final String? originalText;
  final ClauseNotification? notification;
  final DateTime? createdAt; // Might not be returned by default query

  RiskClause({
    required this.id,
    this.clauseId,
    this.rateConfirmationId,
    this.rcId,
    this.clauseType,
    required this.trafficLight,
    this.titleEn,
    this.titlePunjabi,
    this.explanationEn,
    this.explanationPunjabi,
    this.originalText,
    this.notification,
    this.createdAt,
  });

  factory RiskClause.fromJson(Map<String, dynamic> json) {
    return RiskClause(
      id: json['clause_id']?.toString() ?? '',
      clauseId: json['clause_id'],
      rateConfirmationId: json['rate_confirmation_id'],
      rcId: json['rc_id'],

      clauseType: json['clause_type'],
      trafficLight: _parseTrafficLight(json['traffic_light']),

      titleEn: json['title_en'],
      titlePunjabi: json['title_punjabi'],

      explanationEn: json['explanation_en'],
      explanationPunjabi: json['explanation_punjabi'],

      originalText: json['original_text'],

      // Handle both cases: joined rc_notifications (single or array)
      notification: json['rc_notifications'] != null
          ? (json['rc_notifications'] is List
              ? (json['rc_notifications'] as List).isNotEmpty
                  ? ClauseNotification.fromJson(
                      (json['rc_notifications'] as List).first)
                  : null
              : ClauseNotification.fromJson(json['rc_notifications']))
          : null,

      createdAt: json['created_at'] != null
          ? DateTime.parse(json['created_at'])
          : null,
    );
  }

  static TrafficLight _parseTrafficLight(String? value) {
    switch (value?.toUpperCase()) {
      case 'RED':
        return TrafficLight.red;
      case 'GREEN':
        return TrafficLight.green;
      case 'YELLOW':
      default:
        return TrafficLight.yellow;
    }
  }

  Map<String, dynamic> toJson() {
    return {
      'clause_id': clauseId,
      'rate_confirmation_id': rateConfirmationId,
      'rc_id': rcId,
      'clause_type': clauseType,
      'traffic_light': trafficLight.name.toUpperCase(),
      'title_en': titleEn,
      'title_punjabi': titlePunjabi,
      'explanation_en': explanationEn,
      'explanation_punjabi': explanationPunjabi,
      'original_text': originalText,
      'created_at': createdAt?.toIso8601String(),
    };
  }

  String get trafficLightDisplay {
    switch (trafficLight) {
      case TrafficLight.red:
        return '🔴';
      case TrafficLight.yellow:
        return '🟡';
      case TrafficLight.green:
        return '🟢';
    }
  }
}
