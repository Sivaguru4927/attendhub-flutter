/// The result returned by `record_volunteer_scan` / `record_admin_scan`.
class ScanResult {
  const ScanResult({
    required this.status,
    required this.message,
    this.rollNo,
    this.studentName,
    this.department,
    this.category,
    this.mobile,
    this.email,
    this.listed = false,
    this.scannedAt,
  });

  final ScanResultStatus status;
  final String message;
  final String? rollNo;
  final String? studentName;
  final String? department;
  final String? category;
  final String? mobile;
  final String? email;

  /// true  -> roll number found in the master list (details available)
  /// false -> "Scanned student": only roll number + scan time are known
  final bool listed;
  final DateTime? scannedAt;

  bool get isSuccess => status == ScanResultStatus.success;

  factory ScanResult.error(String message) =>
      ScanResult(status: ScanResultStatus.error, message: message);

  factory ScanResult.fromRpcJson(Map<String, dynamic> json) {
    String? s(String k) {
      final v = json[k];
      if (v == null) return null;
      final t = v.toString().trim();
      return t.isEmpty ? null : t;
    }

    return ScanResult(
      status: ScanResultStatus.fromString(json['status'] as String? ?? 'NOT_FOUND'),
      message: json['message'] as String? ?? '',
      rollNo: s('roll_no'),
      studentName: s('student_name'),
      department: s('department'),
      category: s('category'),
      mobile: s('mobile'),
      email: s('email'),
      listed: json['listed'] == true,
      scannedAt: json['scanned_at'] != null
          ? DateTime.tryParse(json['scanned_at'].toString())?.toLocal()
          : null,
    );
  }
}

enum ScanResultStatus {
  success('SUCCESS'),
  alreadyCheckedIn('ALREADY_CHECKED_IN'),
  notFound('NOT_FOUND'),
  sessionEnded('SESSION_ENDED'),
  error('ERROR');

  const ScanResultStatus(this.value);
  final String value;

  static ScanResultStatus fromString(String s) => ScanResultStatus.values
      .firstWhere((e) => e.value == s, orElse: () => ScanResultStatus.error);
}
