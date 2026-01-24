import 'reference_number.dart';
import 'stop.dart';
import 'charge.dart';
import 'risk_clause.dart';

/// Traffic light risk levels for overall rate con
enum RateConTrafficLight { red, yellow, green, unknown }

/// Rate Confirmation model matching new normalized schema
class RateCon {
  final String id;
  final String rateConId;
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
  final String? carrierAddress;
  final String? carrierPhone;
  final String? carrierEmail;
  final String? carrierEquipmentType;
  final String? carrierEquipmentNumber;

  // Financials
  final double? totalRateAmount;
  final String currency;
  final String? paymentTerms;

  // Commodity
  final String? commodityName;
  final double? commodityWeight;
  final String? commodityUnit;
  final int? palletCount;

  // Risk
  final RateConTrafficLight overallTrafficLight;
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
    required this.rateConId,
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
    this.totalRateAmount,
    this.currency = 'USD',
    this.paymentTerms,
    this.commodityName,
    this.commodityWeight,
    this.commodityUnit,
    this.palletCount,
    this.overallTrafficLight = RateConTrafficLight.unknown,
    required this.status,
    required this.createdAt,
    required this.updatedAt,
    this.referenceNumbers = const [],
    this.stops = const [],
    this.charges = const [],
    this.riskClauses = const [],
  });

  factory RateCon.fromJson(Map<String, dynamic> json) {
    return RateCon(
      id: json['id'],
      rateConId: json['rate_con_id'] ?? '',
      documentId: json['document_id'],
      organizationId: json['organization_id'],

      // Broker
      brokerName: json['broker_name'],
      brokerMcNumber: json['broker_mc_number'],
      brokerAddress: json['broker_address'],
      brokerPhone: json['broker_phone'],
      brokerEmail: json['broker_email'],

      // Carrier
      carrierName: json['carrier_name'],
      carrierDotNumber: json['carrier_dot_number'],
      carrierAddress: json['carrier_address'],
      carrierPhone: json['carrier_phone'],
      carrierEmail: json['carrier_email'],
      carrierEquipmentType: json['carrier_equipment_type'],
      carrierEquipmentNumber: json['carrier_equipment_number'],

      // Financials
      totalRateAmount: json['total_rate_amount'] != null
          ? (json['total_rate_amount'] as num).toDouble()
          : null,
      currency: json['currency'] ?? 'USD',
      paymentTerms: json['payment_terms'],

      // Commodity
      commodityName: json['commodity_name'],
      commodityWeight: json['commodity_weight'] != null
          ? (json['commodity_weight'] as num).toDouble()
          : null,
      commodityUnit: json['commodity_unit'],
      palletCount: json['pallet_count'],

      // Risk
      overallTrafficLight: _parseTrafficLight(json['overall_traffic_light']),
      status: json['status'] ?? 'under_review',

      // Timestamps
      createdAt: DateTime.parse(json['created_at']),
      updatedAt: DateTime.parse(json['updated_at']),

      // Related data (populated if included in query)
      referenceNumbers: json['reference_numbers'] != null
          ? (json['reference_numbers'] as List)
              .map((e) => ReferenceNumber.fromJson(e))
              .toList()
          : [],
      stops: json['stops'] != null
          ? (json['stops'] as List).map((e) => Stop.fromJson(e)).toList()
          : [],
      charges: json['charges'] != null
          ? (json['charges'] as List).map((e) => Charge.fromJson(e)).toList()
          : [],
      riskClauses: json['risk_clauses'] != null
          ? (json['risk_clauses'] as List)
              .map((e) => RiskClause.fromJson(e))
              .toList()
          : [],
    );
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
      'rate_con_id': rateConId,
      'document_id': documentId,
      'organization_id': organizationId,
      'broker_name': brokerName,
      'broker_mc_number': brokerMcNumber,
      'broker_address': brokerAddress,
      'broker_phone': brokerPhone,
      'broker_email': brokerEmail,
      'carrier_name': carrierName,
      'carrier_dot_number': carrierDotNumber,
      'carrier_address': carrierAddress,
      'carrier_phone': carrierPhone,
      'carrier_email': carrierEmail,
      'carrier_equipment_type': carrierEquipmentType,
      'carrier_equipment_number': carrierEquipmentNumber,
      'total_rate_amount': totalRateAmount,
      'currency': currency,
      'payment_terms': paymentTerms,
      'commodity_name': commodityName,
      'commodity_weight': commodityWeight,
      'commodity_unit': commodityUnit,
      'pallet_count': palletCount,
      'overall_traffic_light': overallTrafficLight.name.toUpperCase(),
      'status': status,
      'created_at': createdAt.toIso8601String(),
      'updated_at': updatedAt.toIso8601String(),
    };
  }

  RateCon copyWith({
    String? id,
    String? rateConId,
    String? documentId,
    String? organizationId,
    String? brokerName,
    String? brokerMcNumber,
    String? brokerAddress,
    String? brokerPhone,
    String? brokerEmail,
    String? carrierName,
    String? carrierDotNumber,
    String? carrierAddress,
    String? carrierPhone,
    String? carrierEmail,
    String? carrierEquipmentType,
    String? carrierEquipmentNumber,
    double? totalRateAmount,
    String? currency,
    String? paymentTerms,
    String? commodityName,
    double? commodityWeight,
    String? commodityUnit,
    int? palletCount,
    RateConTrafficLight? overallTrafficLight,
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
      rateConId: rateConId ?? this.rateConId,
      documentId: documentId ?? this.documentId,
      organizationId: organizationId ?? this.organizationId,
      brokerName: brokerName ?? this.brokerName,
      brokerMcNumber: brokerMcNumber ?? this.brokerMcNumber,
      brokerAddress: brokerAddress ?? this.brokerAddress,
      brokerPhone: brokerPhone ?? this.brokerPhone,
      brokerEmail: brokerEmail ?? this.brokerEmail,
      carrierName: carrierName ?? this.carrierName,
      carrierDotNumber: carrierDotNumber ?? this.carrierDotNumber,
      carrierAddress: carrierAddress ?? this.carrierAddress,
      carrierPhone: carrierPhone ?? this.carrierPhone,
      carrierEmail: carrierEmail ?? this.carrierEmail,
      carrierEquipmentType: carrierEquipmentType ?? this.carrierEquipmentType,
      carrierEquipmentNumber:
          carrierEquipmentNumber ?? this.carrierEquipmentNumber,
      totalRateAmount: totalRateAmount ?? this.totalRateAmount,
      currency: currency ?? this.currency,
      paymentTerms: paymentTerms ?? this.paymentTerms,
      commodityName: commodityName ?? this.commodityName,
      commodityWeight: commodityWeight ?? this.commodityWeight,
      commodityUnit: commodityUnit ?? this.commodityUnit,
      palletCount: palletCount ?? this.palletCount,
      overallTrafficLight: overallTrafficLight ?? this.overallTrafficLight,
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
    switch (overallTrafficLight) {
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

  String get displayTotalRate => totalRateAmount != null
      ? '\$${totalRateAmount!.toStringAsFixed(2)}'
      : 'N/A';

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
