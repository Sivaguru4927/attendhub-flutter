/// Represents a row in `public.sessions`.
class AttendanceSession {
  const AttendanceSession({
    required this.id,
    this.adminId,
    required this.name,
    this.venue,
    this.description,
    this.eventDate,
    required this.status,
    required this.shareToken,
    this.allowDuplicateScans = false,
    required this.startedAt,
    this.endedAt,
    required this.expiresAt,
  });

  final String id;
  final String? adminId;
  final String name;
  final String? venue;
  final String? description;
  final DateTime? eventDate;
  final SessionStatus status;

  /// Secret token used in the volunteer link: `/#/scan/:shareToken`.
  final String shareToken;
  final bool allowDuplicateScans;
  final DateTime startedAt;
  final DateTime? endedAt;
  final DateTime expiresAt;

  bool get isActive =>
      status == SessionStatus.active && expiresAt.isAfter(DateTime.now().toUtc());

  factory AttendanceSession.fromJson(Map<String, dynamic> json) =>
      AttendanceSession(
        id: json['id'] as String,
        adminId: json['admin_id'] as String?,
        name: json['name'] as String,
        venue: json['venue'] as String?,
        description: json['description'] as String?,
        eventDate: json['event_date'] == null
            ? null
            : DateTime.tryParse(json['event_date'].toString()),
        status: SessionStatus.fromString(json['status'] as String),
        shareToken: json['share_token'] as String,
        allowDuplicateScans: (json['allow_duplicate_scans'] as bool?) ?? false,
        startedAt: DateTime.parse(json['started_at'] as String),
        endedAt: json['ended_at'] != null
            ? DateTime.parse(json['ended_at'] as String)
            : null,
        expiresAt: DateTime.parse(json['expires_at'] as String),
      );
}

enum SessionStatus {
  active('active'),
  ended('ended');

  const SessionStatus(this.value);
  final String value;

  static SessionStatus fromString(String s) => SessionStatus.values
      .firstWhere((e) => e.value == s, orElse: () => SessionStatus.ended);
}
