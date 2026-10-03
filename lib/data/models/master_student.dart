/// A row of `public.master_students`.
class MasterStudent {
  const MasterStudent({
    required this.id,
    required this.masterListId,
    required this.rollNo,
    required this.studentName,
    this.department,
    this.category = 'Aided',
    this.mobile,
    this.email,
  });

  final String id;
  final String masterListId;
  final String rollNo;
  final String studentName;
  final String? department;
  final String category; // 'SF' | 'Aided'
  final String? mobile;
  final String? email;

  factory MasterStudent.fromJson(Map<String, dynamic> json) => MasterStudent(
        id: json['id'] as String,
        masterListId: json['master_list_id'] as String,
        rollNo: json['roll_no'] as String,
        studentName: (json['student_name'] as String?) ?? '',
        department: json['department'] as String?,
        category: (json['category'] as String?) ?? 'Aided',
        mobile: json['mobile'] as String?,
        email: json['email'] as String?,
      );
}
