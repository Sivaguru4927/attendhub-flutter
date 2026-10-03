import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:intl/intl.dart';
import '../../../../core/theme/app_colors.dart';
import '../../../../data/models/attendance_session.dart';
import '../../../../logic/admin/master_list_provider.dart';
import '../../../../logic/admin/session_control_provider.dart';

/// Dialog for creating a new attendance session on top of saved master lists.
class CreateSessionDialog extends ConsumerStatefulWidget {
  const CreateSessionDialog({super.key, required this.onCreated});

  final void Function(AttendanceSession session) onCreated;

  @override
  ConsumerState<CreateSessionDialog> createState() =>
      _CreateSessionDialogState();
}

class _CreateSessionDialogState extends ConsumerState<CreateSessionDialog> {
  final _nameCtrl = TextEditingController();
  final _venueCtrl = TextEditingController();
  final _formKey = GlobalKey<FormState>();
  final Set<String> _listIds = {};
  DateTime _date = DateTime.now();
  double _hours = 8;
  bool _allowDup = false;
  bool _loading = false;
  String? _listError;

  @override
  void dispose() {
    _nameCtrl.dispose();
    _venueCtrl.dispose();
    super.dispose();
  }

  Future<void> _pickDate() async {
    final d = await showDatePicker(
      context: context,
      initialDate: _date,
      firstDate: DateTime.now().subtract(const Duration(days: 365)),
      lastDate: DateTime.now().add(const Duration(days: 730)),
    );
    if (d != null) setState(() => _date = d);
  }

  Future<void> _create() async {
    final okForm = _formKey.currentState!.validate();
    if (_listIds.isEmpty) {
      setState(() => _listError = 'Select at least one master list');
      return;
    }
    if (!okForm) return;
    setState(() => _loading = true);
    try {
      final session = await ref.read(sessionsListProvider.notifier).createSession(
            name: _nameCtrl.text.trim(),
            masterListIds: _listIds.toList(),
            venue: _venueCtrl.text.trim().isEmpty ? null : _venueCtrl.text.trim(),
            eventDate: _date,
            durationHours: _hours,
            allowDuplicateScans: _allowDup,
          );
      if (mounted) {
        Navigator.of(context).pop();
        widget.onCreated(session);
      }
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text(e.toString()), backgroundColor: AppColors.error),
        );
      }
    } finally {
      if (mounted) setState(() => _loading = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    final listsAsync = ref.watch(masterListsProvider);

    return AlertDialog(
      title: const Text('New Session'),
      content: SizedBox(
        width: 380,
        child: SingleChildScrollView(
          child: Form(
            key: _formKey,
            child: Column(
              mainAxisSize: MainAxisSize.min,
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                TextFormField(
                  controller: _nameCtrl,
                  decoration: const InputDecoration(
                    labelText: 'Session Name *',
                    prefixIcon: Icon(Icons.event_outlined, size: 20),
                  ),
                  validator: (v) =>
                      (v == null || v.trim().isEmpty) ? 'Name required' : null,
                ),
                const SizedBox(height: 12),
                TextFormField(
                  controller: _venueCtrl,
                  decoration: const InputDecoration(
                    labelText: 'Venue (optional)',
                    prefixIcon: Icon(Icons.location_on_outlined, size: 20),
                  ),
                ),
                const SizedBox(height: 12),
                OutlinedButton.icon(
                  onPressed: _pickDate,
                  icon: const Icon(Icons.calendar_today, size: 16),
                  label: Text('Event date: ${DateFormat('d MMM yyyy').format(_date)}'),
                ),
                const SizedBox(height: 14),
                const Text('Master lists *',
                    style: TextStyle(fontWeight: FontWeight.w700, fontSize: 13)),
                const SizedBox(height: 4),
                listsAsync.when(
                  loading: () => const Padding(
                    padding: EdgeInsets.all(12),
                    child: Center(child: CircularProgressIndicator(strokeWidth: 2)),
                  ),
                  error: (e, _) => Text('Could not load lists: $e'),
                  data: (lists) {
                    if (lists.isEmpty) {
                      return const Text(
                        'Create a master list first (Dashboard → Master Lists).',
                        style: TextStyle(color: AppColors.error, fontSize: 13),
                      );
                    }
                    return ConstrainedBox(
                      constraints: const BoxConstraints(maxHeight: 190),
                      child: SingleChildScrollView(
                        child: Column(
                          children: [
                            for (final l in lists)
                              CheckboxListTile(
                                dense: true,
                                contentPadding: EdgeInsets.zero,
                                value: _listIds.contains(l.id),
                                title: Text(l.name),
                                subtitle: Text('${l.studentCount} attendees'),
                                onChanged: (v) => setState(() {
                                  _listError = null;
                                  if (v == true) {
                                    _listIds.add(l.id);
                                  } else {
                                    _listIds.remove(l.id);
                                  }
                                }),
                              ),
                          ],
                        ),
                      ),
                    );
                  },
                ),
                if (_listError != null)
                  Text(_listError!,
                      style: const TextStyle(color: AppColors.error, fontSize: 12)),
                const SizedBox(height: 10),
                Wrap(
                  spacing: 6,
                  crossAxisAlignment: WrapCrossAlignment.center,
                  children: [
                    const Text('Open for',
                        style: TextStyle(
                            fontWeight: FontWeight.w600,
                            fontSize: 13,
                            color: AppColors.textSecondary)),
                    for (final h in const [2.0, 4.0, 8.0, 12.0, 24.0])
                      ChoiceChip(
                        label: Text('${h.toInt()}h'),
                        selected: _hours == h,
                        onSelected: (_) => setState(() => _hours = h),
                      ),
                  ],
                ),
                SwitchListTile(
                  dense: true,
                  contentPadding: EdgeInsets.zero,
                  title: const Text('Allow duplicate scans'),
                  subtitle: const Text('Off = a roll number counts only once'),
                  value: _allowDup,
                  onChanged: (v) => setState(() => _allowDup = v),
                ),
              ],
            ),
          ),
        ),
      ),
      actions: [
        TextButton(
          onPressed: () => Navigator.of(context).pop(),
          child: const Text('Cancel'),
        ),
        FilledButton(
          onPressed: _loading ? null : _create,
          child: _loading
              ? const SizedBox(
                  width: 18,
                  height: 18,
                  child: CircularProgressIndicator(strokeWidth: 2, color: Colors.white),
                )
              : const Text('Create Session'),
        ),
      ],
    );
  }
}
