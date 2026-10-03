import 'dart:async';
import 'dart:convert';
import 'dart:typed_data';
import 'package:excel/excel.dart';
import 'package:file_picker/file_picker.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import '../../../core/theme/app_colors.dart';
import '../../../core/utils/file_saver.dart';
import '../../../core/utils/import_parser.dart';
import '../../../data/models/master_list.dart';
import '../../../data/models/master_student.dart';
import '../../../logic/admin/master_list_provider.dart';
import 'widgets/student_list_tile.dart';

/// Attendee Master Directory: lists, import / export, add, search, delete.
/// Built for 14,000+ students (server-side paging, search and counting).
class AttendeeMasterScreen extends ConsumerStatefulWidget {
  const AttendeeMasterScreen({super.key});

  @override
  ConsumerState<AttendeeMasterScreen> createState() =>
      _AttendeeMasterScreenState();
}

class _AttendeeMasterScreenState extends ConsumerState<AttendeeMasterScreen> {
  final _searchCtrl = TextEditingController();
  final _scroll = ScrollController();
  Timer? _debounce;

  bool _busy = false;
  String _busyText = '';
  double? _busyValue;

  static const _importChunk = 500;

  @override
  void initState() {
    super.initState();
    _scroll.addListener(() {
      if (_scroll.position.pixels >= _scroll.position.maxScrollExtent - 300) {
        ref.read(masterStudentsProvider.notifier).loadMore();
      }
    });
  }

  @override
  void dispose() {
    _debounce?.cancel();
    _searchCtrl.dispose();
    _scroll.dispose();
    super.dispose();
  }

  void _toast(String msg, {bool error = false}) {
    if (!mounted) return;
    ScaffoldMessenger.of(context).showSnackBar(SnackBar(
      content: Text(msg),
      backgroundColor: error ? AppColors.error : AppColors.success,
    ));
  }

  void _setBusy(bool v, {String text = '', double? value}) {
    if (!mounted) return;
    setState(() {
      _busy = v;
      _busyText = text;
      _busyValue = value;
    });
  }

  void _refreshAll() {
    ref.invalidate(masterStudentsProvider);
    ref.invalidate(masterStudentCountProvider);
    ref.read(masterListsProvider.notifier).refresh();
  }

  // ------------------------------------------------------------------ lists
  Future<void> _newList() async {
    final ctrl = TextEditingController();
    final name = await showDialog<String>(
      context: context,
      builder: (ctx) => AlertDialog(
        title: const Text('New master list'),
        content: TextField(
          controller: ctrl,
          autofocus: true,
          decoration: const InputDecoration(hintText: 'e.g. Fest 2026 – All students'),
          onSubmitted: (v) => Navigator.of(ctx).pop(v),
        ),
        actions: [
          TextButton(
              onPressed: () => Navigator.of(ctx).pop(),
              child: const Text('Cancel')),
          FilledButton(
              onPressed: () => Navigator.of(ctx).pop(ctrl.text),
              child: const Text('Create')),
        ],
      ),
    );
    // (controller left to the garbage collector: disposing right after the
    // dialog closes can throw while its exit animation is still running)
    if (name == null || name.trim().isEmpty) return;
    try {
      final list = await ref.read(masterListsProvider.notifier).create(name);
      ref.read(selectedMasterListIdProvider.notifier).state = list.id;
    } catch (e) {
      _toast('Could not create list: $e', error: true);
    }
  }

  Future<void> _deleteList(MasterList list) async {
    final ok = await showDialog<bool>(
      context: context,
      builder: (ctx) => AlertDialog(
        title: const Text('Delete this list?'),
        content: Text(
            '"${list.name}" and its ${list.studentCount} students will be deleted. '
            'Sessions that use it keep their scans, but lose this roster.'),
        actions: [
          TextButton(
              onPressed: () => Navigator.of(ctx).pop(false),
              child: const Text('Cancel')),
          FilledButton(
              style: FilledButton.styleFrom(backgroundColor: AppColors.error),
              onPressed: () => Navigator.of(ctx).pop(true),
              child: const Text('Delete')),
        ],
      ),
    );
    if (ok != true) return;
    try {
      await ref.read(masterListsProvider.notifier).delete(list.id);
      ref.read(selectedMasterListIdProvider.notifier).state = null;
    } catch (e) {
      _toast('Could not delete: $e', error: true);
    }
  }

  // ----------------------------------------------------------------- import
  String _cellText(Data? cell) {
    final dynamic v = cell?.value;
    if (v == null) return '';
    if (v is TextCellValue) {
      final dynamic x = (v as dynamic).value;
      if (x is String) return x;
      try {
        return (x as dynamic).toPlainText() as String;
      } catch (_) {
        return x.toString();
      }
    }
    if (v is IntCellValue) return v.value.toString();
    if (v is DoubleCellValue) {
      final d = v.value;
      return d == d.truncateToDouble() ? d.toInt().toString() : d.toString();
    }
    return v.toString();
  }

  Future<void> _import(String listId, String listName) async {
    final picked = await FilePicker.platform.pickFiles(
      type: FileType.custom,
      allowedExtensions: const ['xlsx', 'csv'],
      withData: true,
    );
    if (picked == null || picked.files.isEmpty) return;
    final file = picked.files.first;
    final Uint8List? bytes = file.bytes;
    if (bytes == null) {
      _toast('Could not read the file.', error: true);
      return;
    }

    _setBusy(true, text: 'Reading ${file.name}…');
    await Future<void>.delayed(const Duration(milliseconds: 50));

    ImportParseResult parsed;
    try {
      final List<List<String>> table;
      if (file.name.toLowerCase().endsWith('.csv')) {
        table = parseCsv(utf8.decode(bytes, allowMalformed: true));
      } else {
        final book = Excel.decodeBytes(bytes);
        final sheet = book.tables.values.first;
        table = sheet.rows
            .map((r) => r.map(_cellText).toList())
            .toList();
      }
      parsed = parseStudentTable(table);
    } on FormatException catch (e) {
      _setBusy(false);
      _toast(e.message, error: true);
      return;
    } catch (e) {
      _setBusy(false);
      _toast('Could not read this file. Try saving it as CSV.\n$e', error: true);
      return;
    }
    _setBusy(false);

    if (parsed.rows.isEmpty) {
      _toast('No students found in the file.', error: true);
      return;
    }
    if (!mounted) return;
    final go = await showDialog<bool>(
      context: context,
      builder: (ctx) => AlertDialog(
        title: const Text('Import students?'),
        content: Text(
            '${parsed.rows.length} students found in "${file.name}".'
            '${parsed.skipped > 0 ? '\n${parsed.skipped} rows without a roll number will be skipped.' : ''}'
            '\n\nThey will be added to "$listName". Roll numbers that already '
            'exist in this list are skipped.'),
        actions: [
          TextButton(
              onPressed: () => Navigator.of(ctx).pop(false),
              child: const Text('Cancel')),
          FilledButton(
              onPressed: () => Navigator.of(ctx).pop(true),
              child: const Text('Import')),
        ],
      ),
    );
    if (go != true) return;

    final repo = ref.read(masterListRepositoryProvider);
    final rows = parsed.rows;
    var added = 0;
    try {
      for (var i = 0; i < rows.length; i += _importChunk) {
        final end = (i + _importChunk).clamp(0, rows.length);
        _setBusy(true,
            text: 'Importing $i / ${rows.length}…', value: i / rows.length);
        added += await repo.importRows(listId, rows.sublist(i, end));
      }
      _setBusy(false);
      final dup = rows.length - added;
      _toast('Imported $added new students'
          '${dup > 0 ? ' ($dup already in the list)' : ''}.');
    } catch (e) {
      _setBusy(false);
      _toast('Import failed after $added students: $e', error: true);
    } finally {
      _refreshAll();
    }
  }

  // ------------------------------------------------------------ add student
  Future<void> _addStudent(String listId) async {
    final roll = TextEditingController();
    final name = TextEditingController();
    final dept = TextEditingController();
    final mobile = TextEditingController();
    final email = TextEditingController();
    var category = 'Aided';
    final key = GlobalKey<FormState>();

    final ok = await showDialog<bool>(
      context: context,
      builder: (ctx) => StatefulBuilder(
        builder: (ctx, setD) => AlertDialog(
          title: const Text('Add student'),
          content: SingleChildScrollView(
            child: Form(
              key: key,
              child: Column(
                mainAxisSize: MainAxisSize.min,
                children: [
                  TextFormField(
                    controller: roll,
                    textCapitalization: TextCapitalization.characters,
                    decoration: const InputDecoration(labelText: 'Roll No *'),
                    validator: (v) =>
                        (v == null || v.trim().isEmpty) ? 'Required' : null,
                  ),
                  TextFormField(
                    controller: name,
                    textCapitalization: TextCapitalization.words,
                    decoration: const InputDecoration(labelText: 'Name'),
                  ),
                  TextFormField(
                    controller: dept,
                    decoration: const InputDecoration(labelText: 'Department'),
                  ),
                  const SizedBox(height: 8),
                  DropdownButtonFormField<String>(
                    initialValue: category,
                    decoration: const InputDecoration(labelText: 'Stream'),
                    items: const [
                      DropdownMenuItem(value: 'Aided', child: Text('Aided')),
                      DropdownMenuItem(value: 'SF', child: Text('SF (Self-finance)')),
                    ],
                    onChanged: (v) => setD(() => category = v ?? 'Aided'),
                  ),
                  TextFormField(
                    controller: mobile,
                    keyboardType: TextInputType.phone,
                    decoration: const InputDecoration(labelText: 'Mobile'),
                  ),
                  TextFormField(
                    controller: email,
                    keyboardType: TextInputType.emailAddress,
                    decoration: const InputDecoration(labelText: 'Email'),
                  ),
                ],
              ),
            ),
          ),
          actions: [
            TextButton(
                onPressed: () => Navigator.of(ctx).pop(false),
                child: const Text('Cancel')),
            FilledButton(
                onPressed: () {
                  if (key.currentState!.validate()) Navigator.of(ctx).pop(true);
                },
                child: const Text('Add')),
          ],
        ),
      ),
    );

    final row = ImportRow(
      rollNo: roll.text.trim(),
      studentName: name.text.trim().isEmpty ? 'Unknown' : name.text.trim(),
      department: dept.text.trim().isEmpty ? null : dept.text.trim(),
      category: category,
      mobile: mobile.text.trim().isEmpty ? null : mobile.text.trim(),
      email: email.text.trim().isEmpty ? null : email.text.trim(),
    );
    if (ok != true) return;

    try {
      final added = await ref
          .read(masterListRepositoryProvider)
          .importRows(listId, [row]);
      _toast(added > 0
          ? 'Student added.'
          : 'That roll number is already in this list.', error: added == 0);
      _refreshAll();
    } catch (e) {
      _toast('Could not add student: $e', error: true);
    }
  }

  // --------------------------------------------------- template / export
  Uint8List _buildWorkbook(String sheetName, List<List<String>> rows) {
    final book = Excel.createExcel();
    final def = book.getDefaultSheet();
    if (def != null) book.rename(def, sheetName);
    final sheet = book[sheetName];
    for (final r in rows) {
      sheet.appendRow(r.map<CellValue?>((c) => TextCellValue(c)).toList());
    }
    final out = book.encode();
    return Uint8List.fromList(out ?? <int>[]);
  }

  Future<void> _template() async {
    final bytes = _buildWorkbook('Students', const [
      ['Roll No', 'Student Name', 'Department', 'Category (SF/Aided)', 'Mobile', 'Email'],
      ['25BMA127', 'Example Student', 'Mathematics', 'Aided', '9876543210', 'example@mail.com'],
    ]);
    await saveBytes(fileName: 'attendhub_students_template.xlsx', bytes: bytes);
  }

  Future<void> _export(MasterList list) async {
    try {
      _setBusy(true, text: 'Loading students…');
      final all = await ref.read(masterListRepositoryProvider).fetchAllStudents(
            list.id,
            onProgress: (n) => _setBusy(true, text: 'Loading $n students…'),
          );
      _setBusy(true, text: 'Building Excel file…');
      await Future<void>.delayed(const Duration(milliseconds: 50));
      final rows = <List<String>>[
        ['S.No', 'Roll No', 'Student Name', 'Department', 'Category', 'Mobile', 'Email'],
        for (var i = 0; i < all.length; i++)
          [
            '${i + 1}',
            all[i].rollNo,
            all[i].studentName,
            all[i].department ?? '',
            all[i].category,
            all[i].mobile ?? '',
            all[i].email ?? '',
          ],
      ];
      final bytes = _buildWorkbook('Students', rows);
      _setBusy(false);
      final safe = list.name.replaceAll(RegExp(r'[^A-Za-z0-9]+'), '_');
      await saveBytes(fileName: '${safe}_students.xlsx', bytes: bytes);
      _toast('Exported ${all.length} students.');
    } catch (e) {
      _setBusy(false);
      _toast('Export failed: $e', error: true);
    }
  }

  // ------------------------------------------------------------ delete one
  Future<void> _deleteStudent(MasterStudent s) async {
    final ok = await showDialog<bool>(
      context: context,
      builder: (ctx) => AlertDialog(
        title: const Text('Remove student?'),
        content: Text('Remove ${s.studentName} (${s.rollNo}) from this list?'),
        actions: [
          TextButton(
              onPressed: () => Navigator.of(ctx).pop(false),
              child: const Text('Cancel')),
          FilledButton(
              style: FilledButton.styleFrom(backgroundColor: AppColors.error),
              onPressed: () => Navigator.of(ctx).pop(true),
              child: const Text('Remove')),
        ],
      ),
    );
    if (ok != true) return;
    try {
      await ref.read(masterListRepositoryProvider).deleteStudent(s.id);
      _refreshAll();
    } catch (e) {
      _toast('Could not remove: $e', error: true);
    }
  }

  // ------------------------------------------------------------------ build
  @override
  Widget build(BuildContext context) {
    final listsAsync = ref.watch(masterListsProvider);
    final listId = ref.watch(effectiveListIdProvider);
    final lists = listsAsync.valueOrNull ?? const <MasterList>[];
    final active = lists.where((l) => l.id == listId).firstOrNull;

    return Scaffold(
      appBar: AppBar(
        title: const Text('Attendee Master Directory'),
        actions: [
          IconButton(
            tooltip: 'New list',
            icon: const Icon(Icons.playlist_add),
            onPressed: _busy ? null : _newList,
          ),
          IconButton(
            tooltip: 'Delete this list',
            icon: const Icon(Icons.delete_outline, color: AppColors.error),
            onPressed: (_busy || active == null) ? null : () => _deleteList(active),
          ),
        ],
        bottom: PreferredSize(
          preferredSize: const Size.fromHeight(4),
          child: _busy
              ? LinearProgressIndicator(value: _busyValue, minHeight: 4)
              : Container(height: 1, color: AppColors.divider),
        ),
      ),
      body: listsAsync.when(
        loading: () => const Center(child: CircularProgressIndicator()),
        error: (e, _) => _ErrorBox(
          message: 'Error loading lists: $e',
          onRetry: () => ref.invalidate(masterListsProvider),
        ),
        data: (_) => Column(
          children: [
            _toolbar(lists, active),
            if (_busy && _busyText.isNotEmpty)
              Padding(
                padding: const EdgeInsets.only(top: 6),
                child: Text(_busyText,
                    style: const TextStyle(
                        fontSize: 12, color: AppColors.textSecondary)),
              ),
            const Divider(height: 16),
            _searchRow(),
            Expanded(child: _studentList(active)),
          ],
        ),
      ),
    );
  }

  Widget _toolbar(List<MasterList> lists, MasterList? active) {
    if (lists.isEmpty) {
      return Padding(
        padding: const EdgeInsets.all(24),
        child: Column(
          children: [
            const Icon(Icons.folder_open, size: 56, color: AppColors.textMuted),
            const SizedBox(height: 10),
            const Text('No master list yet',
                style: TextStyle(fontWeight: FontWeight.w700, fontSize: 16)),
            const SizedBox(height: 12),
            FilledButton.icon(
              onPressed: _newList,
              icon: const Icon(Icons.add),
              label: const Text('Create your first list'),
            ),
          ],
        ),
      );
    }
    final disabled = _busy || active == null;
    return Padding(
      padding: const EdgeInsets.fromLTRB(16, 12, 16, 0),
      child: Column(
        children: [
          DropdownButtonFormField<String>(
            key: ValueKey(active?.id),
            initialValue: active?.id,
            isExpanded: true,
            decoration: const InputDecoration(
              labelText: 'Active Master List',
              prefixIcon: Icon(Icons.folder_shared_outlined),
            ),
            items: [
              for (final l in lists)
                DropdownMenuItem(
                  value: l.id,
                  child: Text('${l.name} (${l.studentCount} attendees)',
                      overflow: TextOverflow.ellipsis),
                ),
            ],
            onChanged: _busy
                ? null
                : (v) {
                    ref.read(selectedMasterListIdProvider.notifier).state = v;
                    _searchCtrl.clear();
                    ref.read(studentSearchQueryProvider.notifier).state = '';
                  },
          ),
          const SizedBox(height: 10),
          Wrap(
            spacing: 8,
            runSpacing: 8,
            children: [
              FilledButton.icon(
                onPressed: disabled ? null : () => _import(active!.id, active!.name),
                icon: const Icon(Icons.upload_file, size: 18),
                label: const Text('Import Excel / CSV'),
              ),
              FilledButton.tonalIcon(
                onPressed: disabled ? null : () => _addStudent(active!.id),
                icon: const Icon(Icons.person_add_alt, size: 18),
                label: const Text('Add Student'),
              ),
              OutlinedButton.icon(
                onPressed: _busy ? null : _template,
                icon: const Icon(Icons.file_download_outlined, size: 18),
                label: const Text('Template'),
              ),
              OutlinedButton.icon(
                onPressed: disabled ? null : () => _export(active!),
                icon: const Icon(Icons.download, size: 18),
                label: const Text('Export Excel'),
              ),
            ],
          ),
        ],
      ),
    );
  }

  Widget _searchRow() {
    final countAsync = ref.watch(masterStudentCountProvider);
    return Padding(
      padding: const EdgeInsets.fromLTRB(16, 0, 16, 8),
      child: Row(
        children: [
          Expanded(
            child: TextField(
              controller: _searchCtrl,
              decoration: const InputDecoration(
                hintText: 'Search by name, roll no, department…',
                prefixIcon: Icon(Icons.search, color: AppColors.textMuted),
                contentPadding:
                    EdgeInsets.symmetric(horizontal: 16, vertical: 12),
              ),
              onChanged: (q) {
                _debounce?.cancel();
                _debounce = Timer(const Duration(milliseconds: 350), () {
                  ref.read(studentSearchQueryProvider.notifier).state = q;
                });
              },
            ),
          ),
          const SizedBox(width: 10),
          Container(
            padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 10),
            decoration: BoxDecoration(
              color: AppColors.primaryContainer,
              borderRadius: BorderRadius.circular(10),
            ),
            child: Text(
              countAsync.when(
                data: (c) => '$c total',
                loading: () => '… total',
                error: (_, __) => '— total',
              ),
              style: const TextStyle(
                fontSize: 12,
                fontWeight: FontWeight.w700,
                color: AppColors.primaryDark,
              ),
            ),
          ),
        ],
      ),
    );
  }

  Widget _studentList(MasterList? active) {
    if (active == null) return const SizedBox.shrink();
    final async = ref.watch(masterStudentsProvider);
    return async.when(
      loading: () => const Center(child: CircularProgressIndicator()),
      error: (e, _) => _ErrorBox(
        message: 'Error loading attendees: $e',
        onRetry: () => ref.invalidate(masterStudentsProvider),
      ),
      data: (students) {
        if (students.isEmpty) {
          return const Center(
            child: Text('No students here yet.\nImport an Excel / CSV or add one.',
                textAlign: TextAlign.center,
                style: TextStyle(color: AppColors.textSecondary)),
          );
        }
        final hasMore = ref.read(masterStudentsProvider.notifier).hasMore;
        return ListView.separated(
          controller: _scroll,
          padding: const EdgeInsets.fromLTRB(16, 0, 16, 32),
          itemCount: students.length + (hasMore ? 1 : 0),
          separatorBuilder: (_, __) => const SizedBox(height: 8),
          itemBuilder: (_, i) {
            if (i >= students.length) {
              return const Padding(
                padding: EdgeInsets.all(16),
                child: Center(child: CircularProgressIndicator(strokeWidth: 2)),
              );
            }
            return StudentListTile(
              student: students[i],
              onDelete: () => _deleteStudent(students[i]),
            );
          },
        );
      },
    );
  }
}

class _ErrorBox extends StatelessWidget {
  const _ErrorBox({required this.message, required this.onRetry});
  final String message;
  final VoidCallback onRetry;

  @override
  Widget build(BuildContext context) {
    return Center(
      child: Padding(
        padding: const EdgeInsets.all(24),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            const Icon(Icons.error_outline, size: 48, color: AppColors.error),
            const SizedBox(height: 12),
            Text(message, textAlign: TextAlign.center),
            const SizedBox(height: 12),
            OutlinedButton(onPressed: onRetry, child: const Text('Retry')),
          ],
        ),
      ),
    );
  }
}
