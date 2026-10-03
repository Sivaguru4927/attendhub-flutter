import 'package:supabase_flutter/supabase_flutter.dart';
import '../../core/utils/import_parser.dart';
import '../models/master_list.dart';
import '../models/master_student.dart';

/// Master lists + their students. Everything heavy goes through RPCs so that
/// 14,000+ students are paged / counted on the server.
class MasterListRepository {
  MasterListRepository(this._supabase);
  final SupabaseClient _supabase;

  /// Server caps results at 1000 rows per request.
  static const int maxPage = 500;

  Future<List<MasterList>> fetchLists() async {
    final rows = await _supabase.from('master_lists').select().order('created_at');
    final countsRes = await _supabase.rpc('get_master_list_counts');
    final counts = <String, int>{};
    for (final r in (countsRes as List)) {
      final m = r as Map<String, dynamic>;
      counts[m['master_list_id'] as String] =
          (m['student_count'] as num?)?.toInt() ?? 0;
    }
    return (rows as List).map((r) {
      final m = r as Map<String, dynamic>;
      return MasterList.fromJson(m, count: counts[m['id']] ?? 0);
    }).toList();
  }

  Future<MasterList> createList(String name) async {
    final row = await _supabase
        .from('master_lists')
        .insert({
          'name': name.trim(),
          'admin_id': _supabase.auth.currentUser?.id,
        })
        .select()
        .single();
    return MasterList.fromJson(row);
  }

  Future<void> deleteList(String id) async {
    await _supabase.from('master_lists').delete().eq('id', id);
  }

  Future<List<MasterStudent>> fetchStudents({
    required String listId,
    String? query,
    int limit = 200,
    int offset = 0,
  }) async {
    final res = await _supabase.rpc('get_master_students', params: {
      'p_list_id': listId,
      'p_query': (query == null || query.trim().isEmpty) ? null : query.trim(),
      'p_limit': limit,
      'p_offset': offset,
    });
    return (res as List)
        .map((r) => MasterStudent.fromJson(r as Map<String, dynamic>))
        .toList();
  }

  Future<int> countStudents({required String listId, String? query}) async {
    final res = await _supabase.rpc('count_master_students', params: {
      'p_list_id': listId,
      'p_query': (query == null || query.trim().isEmpty) ? null : query.trim(),
    });
    return (res as num).toInt();
  }

  /// Sends [rows] to `import_master_students`. Returns how many were NEW
  /// (roll numbers already in the list are skipped).
  Future<int> importRows(String listId, List<ImportRow> rows) async {
    final res = await _supabase.rpc('import_master_students', params: {
      'p_list_id': listId,
      'p_rows': rows.map((r) => r.toJson()).toList(),
    });
    return (res as num).toInt();
  }

  Future<void> deleteStudent(String id) async {
    await _supabase.from('master_students').delete().eq('id', id);
  }

  /// Loads every student of a list (for Excel export), page by page.
  Future<List<MasterStudent>> fetchAllStudents(
    String listId, {
    void Function(int loaded)? onProgress,
  }) async {
    final all = <MasterStudent>[];
    var offset = 0;
    while (true) {
      final page = await fetchStudents(
          listId: listId, limit: maxPage, offset: offset);
      all.addAll(page);
      offset += page.length;
      onProgress?.call(all.length);
      if (page.length < maxPage) break;
    }
    return all;
  }
}
