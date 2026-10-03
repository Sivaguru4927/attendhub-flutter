import 'package:flutter/material.dart';
import '../../../../core/theme/app_colors.dart';
import '../../../../data/models/master_student.dart';

/// One student row in the master list.
class StudentListTile extends StatelessWidget {
  const StudentListTile({
    super.key,
    required this.student,
    required this.onDelete,
  });

  final MasterStudent student;
  final VoidCallback onDelete;

  @override
  Widget build(BuildContext context) {
    final name = student.studentName.trim();
    final initials = name
        .split(' ')
        .where((w) => w.isNotEmpty)
        .take(2)
        .map((w) => w[0].toUpperCase())
        .join();
    final isSf = student.category == 'SF';
    final extra = [
      if (student.mobile != null) student.mobile!,
      if (student.email != null) student.email!,
    ].join('  ·  ');

    return Container(
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(12),
        border: Border.all(color: AppColors.cardBorder),
      ),
      child: ListTile(
        contentPadding: const EdgeInsets.symmetric(horizontal: 14, vertical: 2),
        leading: CircleAvatar(
          backgroundColor: AppColors.primaryContainer,
          child: Text(
            initials.isEmpty ? '?' : initials,
            style: const TextStyle(
              fontWeight: FontWeight.w700,
              color: AppColors.primaryDark,
              fontSize: 14,
            ),
          ),
        ),
        title: Text(
          name.isEmpty ? student.rollNo : name,
          maxLines: 1,
          overflow: TextOverflow.ellipsis,
          style: const TextStyle(
              fontWeight: FontWeight.w600,
              fontSize: 14,
              color: AppColors.textPrimary),
        ),
        subtitle: Text(
          [
            student.rollNo,
            if (student.department != null) student.department!,
            if (extra.isNotEmpty) extra,
          ].join('  ·  '),
          maxLines: 2,
          overflow: TextOverflow.ellipsis,
          style: const TextStyle(fontSize: 12, color: AppColors.textSecondary),
        ),
        trailing: Row(
          mainAxisSize: MainAxisSize.min,
          children: [
            Container(
              padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 3),
              decoration: BoxDecoration(
                color: isSf ? AppColors.warningContainer : AppColors.primaryContainer,
                borderRadius: BorderRadius.circular(6),
              ),
              child: Text(
                student.category,
                style: TextStyle(
                  fontSize: 10,
                  fontWeight: FontWeight.w700,
                  color: isSf ? AppColors.warning : AppColors.primaryDark,
                ),
              ),
            ),
            IconButton(
              icon: const Icon(Icons.delete_outline,
                  color: AppColors.textMuted, size: 18),
              onPressed: onDelete,
              tooltip: 'Remove',
              padding: const EdgeInsets.all(6),
            ),
          ],
        ),
      ),
    );
  }
}
