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
}
