import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:supabase_flutter/supabase_flutter.dart';
import '../../data/models/master_list.dart';
import '../../data/models/master_student.dart';
import '../../data/repositories/master_list_repository.dart';

final masterListRepositoryProvider = Provider<MasterListRepository>((ref) {
  return MasterListRepository(Supabase.instance.client);
});

// ---------------------------------------------------------------------------
// Lists (with student counts)
// ---------------------------------------------------------------------------
final masterListsProvider =
    AsyncNotifierProvider<MasterListsNotifier, List<MasterList>>(
        MasterListsNotifier.new);

class MasterListsNotifier extends AsyncNotifier<List<MasterList>> {
  @override
  Future<List<MasterList>> build() =>
      ref.read(masterListRepositoryProvider).fetchLists();

  /// Reload without flashing a spinner (keeps the dropdown stable).
  Future<void> refresh() async {
    state = await AsyncValue.guard(
        () => ref.read(masterListRepositoryProvider).fetchLists());
  }

  Future<MasterList> create(String name) async {
    final list = await ref.read(masterListRepositoryProvider).createList(name);
    await refresh();
    return list;
  }

  Future<void> delete(String id) async {
    await ref.read(masterListRepositoryProvider).deleteList(id);
    await refresh();
  }
}

/// Total number of students over all lists (dashboard card).
final totalStudentsProvider = FutureProvider<int>((ref) async {
  final lists = await ref.watch(masterListsProvider.future);
  return lists.fold<int>(0, (sum, l) => sum + l.studentCount);
});

// ---------------------------------------------------------------------------
// Selection + search
// ---------------------------------------------------------------------------
final selectedMasterListIdProvider = StateProvider<String?>((ref) => null);
final studentSearchQueryProvider = StateProvider<String>((ref) => '');

/// The selected list, or the first list when nothing valid is selected.
final effectiveListIdProvider = Provider<String?>((ref) {
  final selected = ref.watch(selectedMasterListIdProvider);
  final lists = ref.watch(masterListsProvider).valueOrNull;
  if (lists == null || lists.isEmpty) return null;
  if (selected != null && lists.any((l) => l.id == selected)) return selected;
  return lists.first.id;
});

// ---------------------------------------------------------------------------
// Students of the active list (server-side search + paging)
// ---------------------------------------------------------------------------
final masterStudentsProvider =
    AsyncNotifierProvider<MasterStudentsNotifier, List<MasterStudent>>(
        MasterStudentsNotifier.new);

class MasterStudentsNotifier extends AsyncNotifier<List<MasterStudent>> {
  static const int pageSize = 200;
  int _offset = 0;
  bool _hasMore = true;
  bool _busy = false;

  bool get hasMore => _hasMore;

  @override
  Future<List<MasterStudent>> build() async {
    final listId = ref.watch(effectiveListIdProvider);
    final query = ref.watch(studentSearchQueryProvider);
    _offset = 0;
    _hasMore = true;
    _busy = false;
    if (listId == null) {
      _hasMore = false;
      return [];
    }
    final rows = await ref.read(masterListRepositoryProvider).fetchStudents(
          listId: listId,
          query: query,
          limit: pageSize,
          offset: 0,
        );
    _offset = rows.length;
    _hasMore = rows.length >= pageSize;
    return rows;
  }

  Future<void> loadMore() async {
    if (_busy || !_hasMore) return;
    final listId = ref.read(effectiveListIdProvider);
    if (listId == null) return;
    _busy = true;
    try {
      final more = await ref.read(masterListRepositoryProvider).fetchStudents(
            listId: listId,
            query: ref.read(studentSearchQueryProvider),
            limit: pageSize,
            offset: _offset,
          );
      _offset += more.length;
      _hasMore = more.length >= pageSize;
      state = AsyncData([...(state.valueOrNull ?? <MasterStudent>[]), ...more]);
    } catch (_) {
      // keep what we have; the user can scroll again to retry
    } finally {
      _busy = false;
    }
  }
}

/// "N total" for the active list + search.
final masterStudentCountProvider = FutureProvider.autoDispose<int>((ref) async {
  final listId = ref.watch(effectiveListIdProvider);
  final query = ref.watch(studentSearchQueryProvider);
  if (listId == null) return 0;
  return ref
      .read(masterListRepositoryProvider)
      .countStudents(listId: listId, query: query);
});
