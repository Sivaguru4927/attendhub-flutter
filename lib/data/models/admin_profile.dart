/// Admin account model representing a row in `public.admins`.
class AdminProfile {
  const AdminProfile({
    required this.id,
    required this.email,
    required this.status,
    this.approvedBy,
    required this.createdAt,
  });

  final String id;
  final String email;
  final AdminStatus status;
  final String? approvedBy;
  final DateTime createdAt;

  factory AdminProfile.fromJson(Map<String, dynamic> json) => AdminProfile(
        id: json['id'] as String,
        email: json['email'] as String,
        status: AdminStatus.fromString(json['status'] as String),
        approvedBy: json['approved_by'] as String?,
        createdAt: DateTime.parse(json['created_at'] as String),
      );

  Map<String, dynamic> toJson() => {
        'id': id,
        'email': email,
        'status': status.value,
        if (approvedBy != null) 'approved_by': approvedBy,
        'created_at': createdAt.toIso8601String(),
      };

  AdminProfile copyWith({AdminStatus? status, String? approvedBy}) =>
      AdminProfile(
        id: id,
        email: email,
        status: status ?? this.status,
        approvedBy: approvedBy ?? this.approvedBy,
        createdAt: createdAt,
      );
}

enum AdminStatus {
  unauthenticated('unauthenticated'),
  pending('pending'),
  approved('approved'),
  revoked('revoked');

  const AdminStatus(this.value);
  final String value;

  static AdminStatus fromString(String s) =>
      AdminStatus.values.firstWhere((e) => e.value == s,
          orElse: () => AdminStatus.pending);
}
