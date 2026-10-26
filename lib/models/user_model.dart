class UserModel {
  final int id;
  final String email;
  final String username;
  final String firstName;
  final String lastName;
  final String fullName;
  final String role;
  final String phoneNumber;
  final String? avatar;
  final bool isVerified;

  UserModel({
    required this.id,
    required this.email,
    required this.username,
    required this.firstName,
    required this.lastName,
    required this.fullName,
    required this.role,
    this.phoneNumber = '',
    this.avatar,
    this.isVerified = false,
  });

  bool get isCandidate => role == 'CANDIDATE';
  bool get isRecruiter => role == 'RECRUITER';
  bool get isSuperAdmin => role == 'SUPER_ADMIN';

  factory UserModel.fromJson(Map<String, dynamic> json) {
    return UserModel(
      id: json['id'] ?? 0,
      email: json['email'] ?? '',
      username: json['username'] ?? '',
      firstName: json['first_name'] ?? '',
      lastName: json['last_name'] ?? '',
      fullName: json['full_name'] ?? json['email'] ?? '',
      role: json['role'] ?? 'CANDIDATE',
      phoneNumber: json['phone_number'] ?? '',
      avatar: json['avatar'],
      isVerified: json['is_verified'] ?? false,
    );
  }

  Map<String, dynamic> toJson() {
    return {
      'id': id,
      'email': email,
      'username': username,
      'first_name': firstName,
      'last_name': lastName,
      'full_name': fullName,
      'role': role,
      'phone_number': phoneNumber,
      'avatar': avatar,
      'is_verified': isVerified,
    };
  }
}
