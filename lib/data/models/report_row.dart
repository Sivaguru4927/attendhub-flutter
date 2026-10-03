/// One line of the JSON array returned by `get_session_report`.
class ReportRow {
  const ReportRow({
    required this.rollNo,
    required this.studentName,
    this.department,
    required this.category,
    this.mobile,
    this.email,
    required this.attended,
    this.scannedAt,
  });

  final String rollNo;
  final String studentName;
  final String? department;

  /// 'SF', 'Aided' or 'Unlisted' (scanned but not in the master list).
  final String category;
  final String? mobile;
  final String? email;
  final bool attended;
  final DateTime? scannedAt;

  bool get isUnlisted => category == 'Unlisted';

  factory ReportRow.fromJson(Map<String, dynamic> j) => ReportRow(
        rollNo: (j['roll_no'] as String?) ?? '',
        studentName: (j['student_name'] as String?) ?? '',
        department: j['department'] as String?,
        category: (j['category'] as String?) ?? 'Aided',
        mobile: j['mobile'] as String?,
        email: j['email'] as String?,
        attended: j['status'] == 'Attended',
        scannedAt: j['scanned_at'] == null
            ? null
            : DateTime.tryParse(j['scanned_at'].toString())?.toLocal(),
      );
}
