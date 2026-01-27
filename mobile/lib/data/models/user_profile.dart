/// Represents the public profile of a user in the application.
class UserProfile {
  final String id;
  final String fullName;
  final String phoneNumber;
  final String? email;
  final String role;
  final String? organizationId;

  UserProfile({
    required this.id,
    required this.fullName,
    required this.phoneNumber,
    this.email,
    required this.role,
    this.organizationId,
  });

  /// Factory constructor to create a [UserProfile] from a JSON map.
  factory UserProfile.fromJson(Map<String, dynamic> json) {
    return UserProfile(
      id: json['id'],
      fullName: json['full_name'] ?? '',
      phoneNumber: json['phone_number'] ?? '',
      email: json['email_address'],
      role: json['role'] ?? 'driver',
      organizationId: json['organization_id'],
    );
  }

  @override
  String toString() {
    return 'UserProfile(id: $id, fullName: $fullName, phoneNumber: $phoneNumber, email: $email, role: $role, organizationId: $organizationId)';
  }

  @override
  bool operator ==(Object other) {
    if (identical(this, other)) return true;

    return other is UserProfile &&
        other.id == id &&
        other.fullName == fullName &&
        other.phoneNumber == phoneNumber &&
        other.email == email &&
        other.role == role &&
        other.organizationId == organizationId;
  }

  @override
  int get hashCode {
    return id.hashCode ^
        fullName.hashCode ^
        phoneNumber.hashCode ^
        email.hashCode ^
        role.hashCode ^
        organizationId.hashCode;
  }
}
