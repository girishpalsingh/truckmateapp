/// Enum for stop types
enum StopType { pickup, delivery }

/// Model for pickup and delivery stops
class Stop {
  final String id;
  final String rateConfirmationId;
  final int sequenceNumber;
  final StopType stopType;
  final String? address;
  final String? contactPerson;
  final String? phone;
  final String? email;
  final DateTime? scheduledArrival;
  final DateTime? scheduledDeparture;
  final String? dateRaw;
  final String? timeRaw;
  final String? specialInstructions;
  final DateTime createdAt;

  Stop({
    required this.id,
    required this.rateConfirmationId,
    required this.sequenceNumber,
    required this.stopType,
    this.address,
    this.contactPerson,
    this.phone,
    this.email,
    this.scheduledArrival,
    this.scheduledDeparture,
    this.dateRaw,
    this.timeRaw,
    this.specialInstructions,
    required this.createdAt,
  });

  factory Stop.fromJson(Map<String, dynamic> json) {
    return Stop(
      id: json['id'],
      rateConfirmationId: json['rate_confirmation_id'],
      sequenceNumber: json['sequence_number'] ?? 0,
      stopType:
          json['stop_type'] == 'Pickup' ? StopType.pickup : StopType.delivery,
      address: json['address'],
      contactPerson: json['contact_person'],
      phone: json['phone'],
      email: json['email'],
      scheduledArrival: json['scheduled_arrival'] != null
          ? DateTime.tryParse(json['scheduled_arrival'])
          : null,
      scheduledDeparture: json['scheduled_departure'] != null
          ? DateTime.tryParse(json['scheduled_departure'])
          : null,
      dateRaw: json['date_raw'],
      timeRaw: json['time_raw'],
      specialInstructions: json['special_instructions'],
      createdAt: DateTime.parse(json['created_at']),
    );
  }

  Map<String, dynamic> toJson() {
    return {
      'id': id,
      'rate_confirmation_id': rateConfirmationId,
      'sequence_number': sequenceNumber,
      'stop_type': stopType == StopType.pickup ? 'Pickup' : 'Delivery',
      'address': address,
      'contact_person': contactPerson,
      'phone': phone,
      'email': email,
      'scheduled_arrival': scheduledArrival?.toIso8601String(),
      'scheduled_departure': scheduledDeparture?.toIso8601String(),
      'date_raw': dateRaw,
      'time_raw': timeRaw,
      'special_instructions': specialInstructions,
      'created_at': createdAt.toIso8601String(),
    };
  }

  String get displayType => stopType == StopType.pickup ? 'Pickup' : 'Delivery';

  String get displaySchedule {
    if (dateRaw != null && timeRaw != null) {
      return '$dateRaw at $timeRaw';
    } else if (dateRaw != null) {
      return dateRaw!;
    } else if (scheduledArrival != null) {
      return scheduledArrival!.toLocal().toString();
    }
    return 'Not specified';
  }
}
