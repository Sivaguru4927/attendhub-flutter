import 'package:flutter/material.dart';
import 'package:intl/intl.dart';
import '../../core/theme/app_colors.dart';
import '../../data/models/scan_event.dart';

/// Result panel shown after a scan is confirmed.
///
/// * Student found in the master list  -> all details + scan date/time.
/// * Not in the master list            -> "Scanned student", roll no, date/time.
class ScanResultCard extends StatelessWidget {
  const ScanResultCard({super.key, required this.result, required this.onNext});
  final ScanResult result;
  final VoidCallback onNext;

  static final _fmt = DateFormat('dd MMM yyyy, hh:mm:ss a');

  @override
  Widget build(BuildContext context) {
    final (icon, color, bg, title) = _style();
    final time = result.scannedAt;

    final lines = <MapEntry<String, String>>[];
    if (result.rollNo != null) lines.add(MapEntry('Roll No', result.rollNo!));
    if (result.status == ScanResultStatus.success ||
        result.status == ScanResultStatus.alreadyCheckedIn) {
      if (result.listed && result.studentName != null) {
        lines.add(MapEntry('Name', result.studentName!));
      }
      if (result.department != null) {
        lines.add(MapEntry('Department', result.department!));
      }
      if (result.category != null) {
        lines.add(MapEntry('Stream', result.category!));
      }
      if (result.mobile != null) lines.add(MapEntry('Mobile', result.mobile!));
      if (result.email != null) lines.add(MapEntry('Email', result.email!));
    }
    if (time != null) {
      lines.add(MapEntry(
          result.status == ScanResultStatus.alreadyCheckedIn
              ? 'First scanned'
              : 'Scanned at',
          _fmt.format(time)));
    }

    return Material(
      color: Colors.transparent,
      child: Container(
        padding: const EdgeInsets.all(16),
        decoration: BoxDecoration(
          color: bg,
          borderRadius: BorderRadius.circular(20),
          boxShadow: [
            BoxShadow(
              color: color.withValues(alpha: 0.35),
              blurRadius: 20,
              offset: const Offset(0, 6),
            ),
          ],
        ),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            Row(
              children: [
                CircleAvatar(
                  radius: 22,
                  backgroundColor: color,
                  child: Icon(icon, color: Colors.white, size: 26),
                ),
                const SizedBox(width: 12),
                Expanded(
                  child: Text(
                    title,
                    style: TextStyle(
                      fontSize: 17,
                      fontWeight: FontWeight.w800,
                      color: color,
                    ),
                  ),
                ),
              ],
            ),
            if (result.status == ScanResultStatus.success &&
                !result.listed &&
                result.rollNo != null) ...[
              const SizedBox(height: 8),
              const Text(
                'Scanned student (not in master list)',
                style: TextStyle(
                  fontSize: 14,
                  fontWeight: FontWeight.w700,
                  color: AppColors.textPrimary,
                ),
              ),
            ],
            if (lines.isEmpty && result.message.isNotEmpty) ...[
              const SizedBox(height: 8),
              Text(result.message,
                  style: const TextStyle(color: AppColors.textSecondary)),
            ],
            if (lines.isNotEmpty) ...[
              const SizedBox(height: 10),
              for (final e in lines)
                Padding(
                  padding: const EdgeInsets.symmetric(vertical: 2),
                  child: Row(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      SizedBox(
                        width: 96,
                        child: Text(e.key,
                            style: const TextStyle(
                                fontSize: 12, color: AppColors.textSecondary)),
                      ),
                      Expanded(
                        child: Text(e.value,
                            style: const TextStyle(
                              fontSize: 14,
                              fontWeight: FontWeight.w600,
                              color: AppColors.textPrimary,
                            )),
                      ),
                    ],
                  ),
                ),
            ],
            const SizedBox(height: 10),
            FilledButton(
              onPressed: onNext,
              style: FilledButton.styleFrom(backgroundColor: color),
              child: const Text('Next scan  (Enter)'),
            ),
          ],
        ),
      ),
    );
  }

  (IconData, Color, Color, String) _style() {
    switch (result.status) {
      case ScanResultStatus.success:
        return (Icons.check_circle_rounded, AppColors.success,
            AppColors.successContainer, 'Check-in successful');
      case ScanResultStatus.alreadyCheckedIn:
        return (Icons.repeat_rounded, AppColors.warning,
            AppColors.warningContainer, 'Already checked in');
      case ScanResultStatus.notFound:
        return (Icons.error_outline_rounded, AppColors.error,
            AppColors.errorContainer, 'Could not record scan');
      case ScanResultStatus.sessionEnded:
        return (Icons.lock_rounded, AppColors.textSecondary, AppColors.shimmer,
            'Session ended');
      case ScanResultStatus.error:
        return (Icons.error_outline_rounded, AppColors.error,
            AppColors.errorContainer, 'Scan error');
    }
  }
}
