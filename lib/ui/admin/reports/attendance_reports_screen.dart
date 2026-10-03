import 'dart:typed_data';
import 'package:excel/excel.dart' hide Border;
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:intl/intl.dart';
import '../../../core/theme/app_colors.dart';
import '../../../core/utils/file_saver.dart';
import '../../../data/models/attendance_session.dart';
import '../../../data/models/report_row.dart';
import '../../../logic/admin/session_control_provider.dart';

enum _Stream { both, sf, aided }

enum _Status { both, present, absent }

/// Attendance report with Stream (SF / Aided) and Present / Absent filters.
/// Works on the whole roster (14,000+ rows) because the server returns one
/// JSON array, and filtering / counting happens on the device.
class AttendanceReportsScreen extends ConsumerStatefulWidget {
  const AttendanceReportsScreen({super.key});

  @override
  ConsumerState<AttendanceReportsScreen> createState() =>
      _AttendanceReportsScreenState();
}

class _AttendanceReportsScreenState
    extends ConsumerState<AttendanceReportsScreen> {
  String? _sessionId;
  _Stream _stream = _Stream.both;
  _Status _status = _Status.both;
  String _search = '';
  bool _exporting = false;

  static final _dateFmt = DateFormat('dd MMM yyyy');
  static final _timeFmt = DateFormat('hh:mm:ss a');

  List<ReportRow> _filter(List<ReportRow> all) {
    final q = _search.trim().toLowerCase();
    return all.where((r) {
      switch (_stream) {
        case _Stream.sf:
          if (r.category != 'SF') return false;
        case _Stream.aided:
          if (r.category != 'Aided') return false;
        case _Stream.both:
          break;
      }
      switch (_status) {
        case _Status.present:
          if (!r.attended) return false;
        case _Status.absent:
          if (r.attended) return false;
        case _Status.both:
          break;
      }
      if (q.isNotEmpty &&
          !r.rollNo.toLowerCase().contains(q) &&
          !r.studentName.toLowerCase().contains(q) &&
          !(r.department ?? '').toLowerCase().contains(q)) {
        return false;
      }
      return true;
    }).toList();
  }

  Future<void> _export(List<ReportRow> rows, String sessionName) async {
    setState(() => _exporting = true);
    try {
      await Future<void>.delayed(const Duration(milliseconds: 50));
      final book = Excel.createExcel();
      final def = book.getDefaultSheet();
      if (def != null) book.rename(def, 'Attendance');
      final sheet = book['Attendance'];
      sheet.appendRow(<CellValue?>[
        for (final h in const [
          'S.No', 'Roll No', 'Name', 'Department', 'Stream', 'Mobile',
          'Email', 'Status', 'Scan Date', 'Scan Time'
        ])
          TextCellValue(h)
      ]);
      for (var i = 0; i < rows.length; i++) {
        final r = rows[i];
        final t = r.scannedAt;
        sheet.appendRow(<CellValue?>[
          TextCellValue('${i + 1}'),
          TextCellValue(r.rollNo),
          TextCellValue(r.studentName),
          TextCellValue(r.department ?? ''),
          TextCellValue(r.category),
          TextCellValue(r.mobile ?? ''),
          TextCellValue(r.email ?? ''),
          TextCellValue(r.attended ? 'Present' : 'Absent'),
          TextCellValue(t == null ? '' : _dateFmt.format(t)),
          TextCellValue(t == null ? '' : _timeFmt.format(t)),
        ]);
      }
      final bytes = Uint8List.fromList(book.encode() ?? <int>[]);
      final safe = sessionName.replaceAll(RegExp(r'[^A-Za-z0-9]+'), '_');
      await saveBytes(
        fileName: '${safe}_attendance.xlsx',
        bytes: bytes,
        shareText: 'Attendance report: $sessionName',
      );
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context)
            .showSnackBar(SnackBar(content: Text('Export failed: $e')));
      }
    } finally {
      if (mounted) setState(() => _exporting = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    final sessionsAsync = ref.watch(sessionsListProvider);

    return Scaffold(
      appBar: AppBar(
        title: const Text('Attendance Reports'),
        actions: [
          if (_sessionId != null)
            IconButton(
              tooltip: 'Reload report',
              icon: const Icon(Icons.refresh),
              onPressed: () => ref.invalidate(sessionReportProvider(_sessionId!)),
            ),
        ],
        bottom: PreferredSize(
          preferredSize: const Size.fromHeight(1),
          child: Container(height: 1, color: AppColors.divider),
        ),
      ),
      body: sessionsAsync.when(
        loading: () => const Center(child: CircularProgressIndicator()),
        error: (e, _) => Center(child: Text('Error: $e')),
        data: (sessions) {
          if (sessions.isEmpty) {
            return const Center(child: Text('No sessions to report on yet.'));
          }
          final session = sessions.where((s) => s.id == _sessionId).firstOrNull;
          return Column(
            children: [
              Padding(
                padding: const EdgeInsets.fromLTRB(16, 12, 16, 0),
                child: DropdownButtonFormField<String>(
                  initialValue: session?.id,
                  isExpanded: true,
                  decoration: const InputDecoration(
                    labelText: 'Select Session',
                    prefixIcon: Icon(Icons.event_outlined, size: 20),
                  ),
                  items: [
                    for (final s in sessions)
                      DropdownMenuItem(
                        value: s.id,
                        child: Text(
                          '${s.name}  (${s.status == SessionStatus.active ? "LIVE" : "ENDED"})',
                          overflow: TextOverflow.ellipsis,
                        ),
                      ),
                  ],
                  onChanged: (v) => setState(() => _sessionId = v),
                ),
              ),
              if (session == null)
                const Expanded(
                  child: Center(child: Text('Pick a session to see its report.')),
                )
              else
                Expanded(child: _report(session)),
            ],
          );
        },
      ),
    );
  }

  Widget _chips<T>({
    required String label,
    required List<(T, String)> options,
    required T value,
    required void Function(T) onChanged,
  }) {
    return Padding(
      padding: const EdgeInsets.only(top: 10),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(label,
              style: const TextStyle(
                  fontWeight: FontWeight.w700,
                  fontSize: 13,
                  color: AppColors.textSecondary)),
          const SizedBox(height: 6),
          Wrap(
            spacing: 8,
            runSpacing: 6,
            children: [
              for (final o in options)
                ChoiceChip(
                  label: Text(o.$2),
                  selected: value == o.$1,
                  onSelected: (_) => onChanged(o.$1),
                ),
            ],
          ),
        ],
      ),
    );
  }

  Widget _report(AttendanceSession session) {
    final async = ref.watch(sessionReportProvider(session.id));
    return async.when(
      loading: () => const Center(child: CircularProgressIndicator()),
      error: (e, _) => Center(
        child: Padding(
          padding: const EdgeInsets.all(24),
          child: Text('Could not load report:\n$e', textAlign: TextAlign.center),
        ),
      ),
      data: (all) {
        final rows = _filter(all);
        final present = rows.where((r) => r.attended).length;
        final absent = rows.length - present;

        return Column(
          children: [
            Padding(
              padding: const EdgeInsets.symmetric(horizontal: 16),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  _chips<_Stream>(
                    label: 'Stream / Category',
                    options: const [
                      (_Stream.both, 'Both SF & Aided'),
                      (_Stream.sf, 'Only SF'),
                      (_Stream.aided, 'Only Aided'),
                    ],
                    value: _stream,
                    onChanged: (v) => setState(() => _stream = v),
                  ),
                  _chips<_Status>(
                    label: 'Attendance Status',
                    options: const [
                      (_Status.both, 'Present & Absent'),
                      (_Status.present, 'Only Present'),
                      (_Status.absent, 'Only Absent'),
                    ],
                    value: _status,
                    onChanged: (v) => setState(() => _status = v),
                  ),
                  const SizedBox(height: 10),
                  TextField(
                    decoration: const InputDecoration(
                      hintText: 'Search roll no, name, department…',
                      prefixIcon: Icon(Icons.search, color: AppColors.textMuted),
                      contentPadding:
                          EdgeInsets.symmetric(horizontal: 16, vertical: 10),
                    ),
                    onChanged: (v) => setState(() => _search = v),
                  ),
                  const SizedBox(height: 10),
                  Row(
                    children: [
                      _Stat('Showing', '${rows.length}', AppColors.primary),
                      const SizedBox(width: 8),
                      _Stat('Present', '$present', AppColors.success),
                      const SizedBox(width: 8),
                      _Stat('Absent', '$absent', AppColors.error),
                    ],
                  ),
                  const SizedBox(height: 10),
                  FilledButton.icon(
                    onPressed: (_exporting || rows.isEmpty)
                        ? null
                        : () => _export(rows, session.name),
                    icon: const Icon(Icons.download_outlined, size: 18),
                    label: Text(_exporting
                        ? 'Exporting…'
                        : 'Export ${rows.length} rows to Excel'),
                    style: FilledButton.styleFrom(
                      backgroundColor: AppColors.accent,
                      minimumSize: const Size.fromHeight(46),
                    ),
                  ),
                  const SizedBox(height: 8),
                ],
              ),
            ),
            const Divider(height: 1),
            Expanded(
              child: rows.isEmpty
                  ? const Center(child: Text('No rows match these filters.'))
                  : ListView.builder(
                      itemCount: rows.length,
                      itemBuilder: (_, i) => _RowTile(row: rows[i]),
                    ),
            ),
          ],
        );
      },
    );
  }
}

class _Stat extends StatelessWidget {
  const _Stat(this.label, this.value, this.color);
  final String label;
  final String value;
  final Color color;

  @override
  Widget build(BuildContext context) {
    return Expanded(
      child: Container(
        padding: const EdgeInsets.symmetric(vertical: 8),
        decoration: BoxDecoration(
          color: color.withValues(alpha: 0.1),
          borderRadius: BorderRadius.circular(10),
        ),
        child: Column(
          children: [
            Text(value,
                style: TextStyle(
                    fontSize: 20, fontWeight: FontWeight.w900, color: color)),
            Text(label,
                style: const TextStyle(
                    fontSize: 11, color: AppColors.textSecondary)),
          ],
        ),
      ),
    );
  }
}

class _RowTile extends StatelessWidget {
  const _RowTile({required this.row});
  final ReportRow row;

  static final _fmt = DateFormat('dd MMM, hh:mm:ss a');

  @override
  Widget build(BuildContext context) {
    final color = row.attended ? AppColors.success : AppColors.error;
    final t = row.scannedAt;
    return ListTile(
      dense: true,
      leading: Icon(
        row.attended ? Icons.check_circle : Icons.cancel_outlined,
        color: color,
      ),
      title: Text(
        row.isUnlisted ? 'Scanned student' : row.studentName,
        maxLines: 1,
        overflow: TextOverflow.ellipsis,
        style: const TextStyle(fontWeight: FontWeight.w600),
      ),
      subtitle: Text(
        [
          row.rollNo,
          if (row.department != null) row.department!,
          row.isUnlisted ? 'Not in master list' : row.category,
          if (t != null) _fmt.format(t),
        ].join('  ·  '),
        maxLines: 2,
        overflow: TextOverflow.ellipsis,
      ),
    );
  }
}
