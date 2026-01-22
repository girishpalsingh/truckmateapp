class RateConClause {
  final String id;
  final String rateConId;
  final String? clauseType;
  final String? trafficLight; // 'RED', 'YELLOW', 'GREEN'
  final String? dangerSimpleLanguage;
  final String? dangerSimplePunjabi;
  final String? originalText;
  final String? warningEn;
  final String? warningPa;
  final Map<String, dynamic>? notification;
  final DateTime createdAt;

  RateConClause({
    required this.id,
    required this.rateConId,
    this.clauseType,
    this.trafficLight,
    this.dangerSimpleLanguage,
    this.dangerSimplePunjabi,
    this.originalText,
    this.warningEn,
    this.warningPa,
    this.notification,
    required this.createdAt,
  });

  factory RateConClause.fromJson(Map<String, dynamic> json) {
    return RateConClause(
      id: json['id'],
      rateConId: json['rate_con_id'],
      clauseType: json['clause_type'],
      trafficLight: json['traffic_light'],
      dangerSimpleLanguage: json['danger_simple_language'],
      dangerSimplePunjabi: json['danger_simple_punjabi'],
      originalText: json['original_text'],
      warningEn: json['warning_en'],
      warningPa: json['warning_pa'],
      notification: json['notification'],
      createdAt: DateTime.parse(json['created_at']),
    );
  }
}
