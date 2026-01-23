import 'clause_notification.dart';

/// Traffic light risk levels
enum TrafficLight { red, yellow, green }

/// Model for risk clauses identified in rate confirmations
class RiskClause {
  final String id;
  final String rateConfirmationId;
  final String? clauseType;
  final TrafficLight trafficLight;
  final String? clauseTitle;
  final String? clauseTitlePunjabi;
  final String? dangerSimpleLanguage;
  final String? dangerSimplePunjabi;
  final String? originalText;
  final ClauseNotification? notification;
  final DateTime createdAt;

  RiskClause({
    required this.id,
    required this.rateConfirmationId,
    this.clauseType,
    required this.trafficLight,
    this.clauseTitle,
    this.clauseTitlePunjabi,
    this.dangerSimpleLanguage,
    this.dangerSimplePunjabi,
    this.originalText,
    this.notification,
    required this.createdAt,
  });

  factory RiskClause.fromJson(Map<String, dynamic> json) {
    return RiskClause(
      id: json['id'],
      rateConfirmationId: json['rate_confirmation_id'],
      clauseType: json['clause_type'],
      trafficLight: _parseTrafficLight(json['traffic_light']),
      clauseTitle: json['clause_title'],
      clauseTitlePunjabi: json['clause_title_punjabi'],
      dangerSimpleLanguage: json['danger_simple_language'],
      dangerSimplePunjabi: json['danger_simple_punjabi'],
      originalText: json['original_text'],
      notification: json['clause_notifications'] != null &&
              (json['clause_notifications'] as List).isNotEmpty
          ? ClauseNotification.fromJson(
              (json['clause_notifications'] as List).first)
          : null,
      createdAt: DateTime.parse(json['created_at']),
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
      'id': id,
      'rate_confirmation_id': rateConfirmationId,
      'clause_type': clauseType,
      'traffic_light': trafficLight.name.toUpperCase(),
      'clause_title': clauseTitle,
      'clause_title_punjabi': clauseTitlePunjabi,
      'danger_simple_language': dangerSimpleLanguage,
      'danger_simple_punjabi': dangerSimplePunjabi,
      'original_text': originalText,
      'created_at': createdAt.toIso8601String(),
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
