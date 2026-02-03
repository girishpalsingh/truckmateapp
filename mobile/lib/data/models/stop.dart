import 'commodity.dart';

/// Enum for stop types
enum StopType { pickup, delivery }

/// Model for pickup and delivery stops
class Stop {
  final String
      id; // This might be stop_id (int) or serial converted to string? Model usually expects string ID.
  // In new schema stop_id is SERIAL (int). Flutter usually handles string IDs cleanly, but if we get int from JSON, we should .toString()
  final int? stopId; // Mapping stop_id
  final String? rateConfirmationId; // UUID
  final int? rcId; // Serial

  final int sequenceNumber;
  final StopType stopType;

  final String? address; // facility_address
  final String? contactPerson; // contact_name
  final String? phone; // contact_phone
  final String? email; // contact_email

  final DateTime? scheduledArrival;
  final DateTime? scheduledDeparture;
  final String? dateRaw; // raw_date_text

  final String? specialInstructions;
  final String? specialInstructionsPunjabi;
  final List<Commodity> commodities;

  // Computed helpers for display
  String get timeRaw {
    // raw_date_text might contain time.
    return dateRaw ?? '';
  }

  Stop({
    required this.id,
    this.stopId,
    this.rateConfirmationId,
    this.rcId,
    required this.sequenceNumber,
    required this.stopType,
    this.address,
    this.contactPerson,
    this.phone,
    this.email,
    this.scheduledArrival,
    this.scheduledDeparture,
    this.dateRaw,
    this.specialInstructions,
    this.specialInstructionsPunjabi,
    this.commodities = const [],
  });

  factory Stop.fromJson(Map<String, dynamic> json) {
    return Stop(
      id: json['stop_id']?.toString() ?? '',
      stopId: json['stop_id'],
      rateConfirmationId: json['rate_confirmation_id'],
      rcId: json['rc_id'],
      sequenceNumber: json['stop_sequence'] ?? 0,
      stopType:
          json['stop_type'] == 'Pickup' ? StopType.pickup : StopType.delivery,
      address: json['facility_address'],
      contactPerson: json['contact_name'],
      phone: json['contact_phone'],
      email: json['contact_email'],
      scheduledArrival: json['scheduled_arrival'] != null
          ? DateTime.tryParse(json['scheduled_arrival'])
          : null,
      scheduledDeparture: json['scheduled_departure'] != null
          ? DateTime.tryParse(json['scheduled_departure'])
          : null,
      dateRaw: json['raw_date_text'],
      specialInstructions: json['special_instructions'],
      specialInstructionsPunjabi: json['special_instructions_punjabi'],
      commodities: json['rc_commodities'] != null
          ? (json['rc_commodities'] as List)
              .map((e) => Commodity.fromJson(e))
              .toList()
          : [],
    );
  }

  Map<String, dynamic> toJson() {
    return {
      'stop_id': stopId,
      'rate_confirmation_id': rateConfirmationId,
      'rc_id': rcId,
      'stop_sequence': sequenceNumber,
      'stop_type': stopType == StopType.pickup ? 'Pickup' : 'Delivery',
      'facility_address': address,
      'contact_name': contactPerson,
      'contact_phone': phone,
      'contact_email': email,
      'scheduled_arrival': scheduledArrival?.toIso8601String(),
      'scheduled_departure': scheduledDeparture?.toIso8601String(),
      'raw_date_text': dateRaw,
      'special_instructions': specialInstructions,
      'special_instructions_punjabi': specialInstructionsPunjabi,
      'rc_commodities': commodities.map((e) => e.toJson()).toList(),
    };
  }

  String get displayType => stopType == StopType.pickup ? 'Pickup' : 'Delivery';

  String get displaySchedule {
    if (dateRaw != null && dateRaw!.isNotEmpty) {
      return dateRaw!;
    } else if (scheduledArrival != null) {
      return scheduledArrival!.toLocal().toString();
    }
    return 'Not specified';
  }
}
