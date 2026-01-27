/// Model for trailer data
class Trailer {
  final String id;
  final String organizationId;
  final String trailerNumber;
  final String? trailerType;
  final int? lengthFeet;
  final String status; // active, sold etc
  final String availabilityStatus; // AVAILABLE, ON_TRIP, etc
  final DateTime createdAt;
  final DateTime updatedAt;

  Trailer({
    required this.id,
    required this.organizationId,
    required this.trailerNumber,
    this.trailerType,
    this.lengthFeet,
    this.status = 'ACTIVE',
    this.availabilityStatus = 'AVAILABLE',
    required this.createdAt,
    required this.updatedAt,
  });

  factory Trailer.fromJson(Map<String, dynamic> json) {
    return Trailer(
      id: json['id'],
      organizationId: json['organization_id'],
      trailerNumber: json['trailer_number'],
      trailerType: json['trailer_type'],
      lengthFeet: json['length_feet'],
      status: json['status'] ?? 'ACTIVE',
      availabilityStatus: json['availability_status'] ?? 'AVAILABLE',
      createdAt: DateTime.parse(json['created_at']),
      updatedAt: DateTime.parse(json['updated_at']),
    );
  }

  Map<String, dynamic> toJson() {
    return {
      'id': id,
      'organization_id': organizationId,
      'trailer_number': trailerNumber,
      'trailer_type': trailerType,
      'length_feet': lengthFeet,
      'status': status,
      'availability_status': availabilityStatus,
      'created_at': createdAt.toIso8601String(),
      'updated_at': updatedAt.toIso8601String(),
    };
  }

  @override
  String toString() => 'Trailer(number: $trailerNumber, $trailerType)';
}
