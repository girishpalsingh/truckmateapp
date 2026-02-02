class DetentionRecord {
  final String id;
  final String organizationId;
  final String loadId;
  final String stopId;
  final DateTime startTime;
  final Map<String, dynamic>? startLocation; // {lat: double, lng: double}
  final DateTime? endTime;
  final Map<String, dynamic>? endLocation;
  final String? evidencePhotoUrl;
  final DateTime? evidencePhotoTime;
  final DateTime createdAt;

  DetentionRecord({
    required this.id,
    required this.organizationId,
    required this.loadId,
    required this.stopId,
    required this.startTime,
    this.startLocation,
    this.endTime,
    this.endLocation,
    this.evidencePhotoUrl,
    this.evidencePhotoTime,
    required this.createdAt,
  });

  factory DetentionRecord.fromJson(Map<String, dynamic> json) {
    return DetentionRecord(
      id: json['id'].toString(),
      organizationId: json['organization_id'].toString(),
      loadId: json['load_id'].toString(),
      stopId: json['stop_id'].toString(),
      startTime: DateTime.parse(json['start_time']),
      startLocation: json['start_location_json'] != null
          ? Map<String, dynamic>.from(json[
              'start_location_json']) // access logic dependent on how we save geography/json
          : (json['start_location_lat'] != null
              ? {
                  'lat': json['start_location_lat'],
                  'lng': json['start_location_lng']
                }
              : null),
      endTime:
          json['end_time'] != null ? DateTime.parse(json['end_time']) : null,
      endLocation: json['end_location_lat'] != null
          ? {'lat': json['end_location_lat'], 'lng': json['end_location_lng']}
          : null,
      evidencePhotoUrl: json['evidence_photo_url'],
      evidencePhotoTime: json['evidence_photo_time'] != null
          ? DateTime.parse(json['evidence_photo_time'])
          : null,
      createdAt: DateTime.parse(json['created_at']),
    );
  }

  Map<String, dynamic> toJson() {
    return {
      'id': id,
      'organization_id': organizationId,
      'load_id': loadId,
      'stop_id': stopId,
      'start_time': startTime.toIso8601String(),
      'start_location_lat': startLocation?['lat'],
      'start_location_lng': startLocation?['lng'],
      'end_time': endTime?.toIso8601String(),
      'end_location_lat': endLocation?['lat'],
      'end_location_lng': endLocation?['lng'],
      'evidence_photo_url': evidencePhotoUrl,
      'evidence_photo_time': evidencePhotoTime?.toIso8601String(),
      'created_at': createdAt.toIso8601String(),
    };
  }

  Duration get duration {
    final end = endTime ?? DateTime.now();
    return end.difference(startTime);
  }
}
