import 'reference_number.dart';
import 'stop.dart';
import 'charge.dart';
import 'risk_clause.dart';

/// Traffic light risk levels for overall rate con
enum RateConTrafficLight { red, yellow, green, unknown }

/// Rate Confirmation model matching new normalized schema
class RateCon {
  final String id; // UUID
  final int? rcId; // Serial
  final String? loadId; // Commercial ID
  final String? documentId;
  final String organizationId;

  // Broker Details
  final String? brokerName;
  final String? brokerMcNumber;
  final String? brokerAddress;
  final String? brokerPhone;
  final String? brokerEmail;

  // Carrier Details
  final String? carrierName;
  final String? carrierDotNumber;
  final String? carrierAddress; // Not in new schema? check migration.
  // Migration has carrier_name, carrier_dot, carrier_equipment_type, carrier_equipment_number.
  // Address/Phone/Email for carrier might be missing in new schema?
  // Checking migration...
  // carrier_name, carrier_dot, carrier_equipment_type, carrier_equipment_number.
  // No address/phone/email. I will keep them nullable in model but they won't be populated.

  final String? carrierPhone;
  final String? carrierEmail;
  final String? carrierEquipmentType;
  final String? carrierEquipmentNumber;

  // Financials
  final double? totalRate; // total_rate
  final String currency;
  final String? paymentTerms;

  // Commodity (Gone? Now in stops. Keeping simplified getters if needed or removing)
  // New schema has rc_commodities linked to stops.
  // I will remove logic that assumes single commodity on RC.

  // Risk
  final RateConTrafficLight riskScore; // risk_score
  final String status;

  // Timestamps
  final DateTime createdAt;
  final DateTime updatedAt;

  // Related data (loaded separately)
  final List<ReferenceNumber> referenceNumbers;
  final List<Stop> stops;
  final List<Charge> charges;
  final List<RiskClause> riskClauses;

  RateCon({
    required this.id,
    this.rcId,
    this.loadId,
    this.documentId,
    required this.organizationId,
    this.brokerName,
    this.brokerMcNumber,
    this.brokerAddress,
    this.brokerPhone,
    this.brokerEmail,
    this.carrierName,
    this.carrierDotNumber,
    this.carrierAddress,
    this.carrierPhone,
    this.carrierEmail,
    this.carrierEquipmentType,
    this.carrierEquipmentNumber,
    this.totalRate,
    this.currency = 'USD',
    this.paymentTerms,
    this.riskScore = RateConTrafficLight.unknown,
    required this.status,
    required this.createdAt,
    required this.updatedAt,
    this.referenceNumbers = const [],
    this.stops = const [],
    this.charges = const [],
    this.riskClauses = const [],
  });

  factory RateCon.fromJson(Map<String, dynamic> json) {
    try {
      return RateCon(
        id: json['id'],
        rcId: json['rc_id'],
        loadId: json['load_id'],
        documentId: json['document_id'],
        organizationId: json['organization_id'],

        // Broker
        brokerName: json['broker_name'],
        brokerMcNumber: json['broker_mc'],
        brokerAddress: json['broker_address'],
        brokerPhone: json['broker_phone'],
        brokerEmail: json['broker_email'],

        // Carrier
        carrierName: json['carrier_name'],
        carrierDotNumber: json['carrier_dot'],
        carrierEquipmentType: json['carrier_equipment_type'],
        carrierEquipmentNumber: json['carrier_equipment_number'],

        // Financials
        totalRate: json['total_rate'] != null
            ? (json['total_rate'] as num).toDouble()
            : null,
        currency: json['currency'] ?? 'USD',
        paymentTerms: json['payment_terms'],

        // Risk
        riskScore: _parseTrafficLight(json['risk_score']),
        status: json['status'] ?? 'under_review',

        // Timestamps
        createdAt: DateTime.parse(json['created_at']),
        updatedAt: DateTime.parse(json['updated_at']),

        // Related data
        referenceNumbers: json['rc_references'] != null
            ? (json['rc_references'] as List).map((e) {
                try {
                  return ReferenceNumber.fromJson(e);
                } catch (err) {
                  throw Exception('Error parsing ReferenceNumber: $err IN $e');
                }
              }).toList()
            : [],
        stops: json['rc_stops'] != null
            ? (json['rc_stops'] as List).map((e) {
                try {
                  return Stop.fromJson(e);
                } catch (err) {
                  throw Exception('Error parsing Stop: $err IN $e');
                }
              }).toList()
            : [],
        charges: json['rc_charges'] != null
            ? (json['rc_charges'] as List).map((e) {
                try {
                  return Charge.fromJson(e);
                } catch (err) {
                  throw Exception('Error parsing Charge: $err IN $e');
                }
              }).toList()
            : [],
        riskClauses: json['rc_risk_clauses'] != null
            ? (json['rc_risk_clauses'] as List).map((e) {
                try {
                  return RiskClause.fromJson(e);
                } catch (err) {
                  // Catch nested Notification errors too
                  throw Exception('Error parsing RiskClause: $err IN $e');
                }
              }).toList()
            : [],
      );
    } catch (e) {
      // Catch top-level errors (like id being null)
      throw Exception('Error parsing RateCon: $e. JSON: $json');
    }
  }

  static RateConTrafficLight _parseTrafficLight(String? value) {
    switch (value?.toUpperCase()) {
      case 'RED':
        return RateConTrafficLight.red;
      case 'YELLOW':
        return RateConTrafficLight.yellow;
      case 'GREEN':
        return RateConTrafficLight.green;
      default:
        return RateConTrafficLight.unknown;
    }
  }

  Map<String, dynamic> toJson() {
    return {
      'id': id,
      'rc_id': rcId,
      'load_id': loadId,
      'document_id': documentId,
      'organization_id': organizationId,
      'broker_name': brokerName,
      'broker_mc': brokerMcNumber,
      'broker_address': brokerAddress,
      'broker_phone': brokerPhone,
      'broker_email': brokerEmail,
      'carrier_name': carrierName,
      'carrier_dot': carrierDotNumber,
      'carrier_equipment_type': carrierEquipmentType,
      'carrier_equipment_number': carrierEquipmentNumber,
      'total_rate': totalRate,
      'currency': currency,
      'payment_terms': paymentTerms,
      'risk_score': riskScore.name.toUpperCase(),
      'status': status,
      'created_at': createdAt.toIso8601String(),
      'updated_at': updatedAt.toIso8601String(),
    };
  }

  RateCon copyWith({
    String? id,
    int? rcId,
    String? loadId,
    String? documentId,
    String? organizationId,
    String? brokerName,
    String? brokerMcNumber,
    String? brokerAddress,
    String? brokerPhone,
    String? brokerEmail,
    String? carrierName,
    String? carrierDotNumber,
    String? carrierEquipmentType,
    String? carrierEquipmentNumber,
    double? totalRate,
    String? currency,
    String? paymentTerms,
    RateConTrafficLight? riskScore,
    String? status,
    DateTime? createdAt,
    DateTime? updatedAt,
    List<ReferenceNumber>? referenceNumbers,
    List<Stop>? stops,
    List<Charge>? charges,
    List<RiskClause>? riskClauses,
  }) {
    return RateCon(
      id: id ?? this.id,
      rcId: rcId ?? this.rcId,
      loadId: loadId ?? this.loadId,
      documentId: documentId ?? this.documentId,
      organizationId: organizationId ?? this.organizationId,
      brokerName: brokerName ?? this.brokerName,
      brokerMcNumber: brokerMcNumber ?? this.brokerMcNumber,
      brokerAddress: brokerAddress ?? this.brokerAddress,
      brokerPhone: brokerPhone ?? this.brokerPhone,
      brokerEmail: brokerEmail ?? this.brokerEmail,
      carrierName: carrierName ?? this.carrierName,
      carrierDotNumber: carrierDotNumber ?? this.carrierDotNumber,
      carrierEquipmentType: carrierEquipmentType ?? this.carrierEquipmentType,
      carrierEquipmentNumber:
          carrierEquipmentNumber ?? this.carrierEquipmentNumber,
      totalRate: totalRate ?? this.totalRate,
      currency: currency ?? this.currency,
      paymentTerms: paymentTerms ?? this.paymentTerms,
      riskScore: riskScore ?? this.riskScore,
      status: status ?? this.status,
      createdAt: createdAt ?? this.createdAt,
      updatedAt: updatedAt ?? this.updatedAt,
      referenceNumbers: referenceNumbers ?? this.referenceNumbers,
      stops: stops ?? this.stops,
      charges: charges ?? this.charges,
      riskClauses: riskClauses ?? this.riskClauses,
    );
  }

  String get trafficLightEmoji {
    switch (riskScore) {
      case RateConTrafficLight.red:
        return '🔴';
      case RateConTrafficLight.yellow:
        return '🟡';
      case RateConTrafficLight.green:
        return '🟢';
      case RateConTrafficLight.unknown:
        return '⚪';
    }
  }

  String get displayTotalRate =>
      totalRate != null ? '\$${totalRate!.toStringAsFixed(2)}' : 'N/A';

  /// Suggests an origin address based on the first pickup stop
  String? get originAddress {
    if (stops.isEmpty) return null;
    try {
      return stops.firstWhere((s) => s.stopType == StopType.pickup).address;
    } catch (_) {
      return stops.first.address;
    }
  }

  /// Suggests a destination address based on the last delivery stop
  String? get destinationAddress {
    if (stops.isEmpty) return null;
    try {
      return stops.lastWhere((s) => s.stopType == StopType.delivery).address;
    } catch (_) {
      return stops.last.address;
    }
  }
}
