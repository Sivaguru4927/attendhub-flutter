import 'package:supabase_flutter/supabase_flutter.dart';
import '../models/attendance_session.dart';
import '../models/report_row.dart';
import '../models/scan_event.dart';

/// Admin-side session operations (all via the SQL RPC functions).
class SessionRepository {
  SessionRepository(this._supabase);
  final SupabaseClient _supabase;

  Future<AttendanceSession> createSession({
    required String name,
    required List<String> masterListIds,
    String? venue,
    String? description,
    DateTime? eventDate,
    num durationHours = 8,
    bool allowDuplicateScans = false,
  }) async {
    final d = eventDate ?? DateTime.now();
    final dateStr =
        '${d.year.toString().padLeft(4, '0')}-${d.month.toString().padLeft(2, '0')}-${d.day.toString().padLeft(2, '0')}';
    final res = await _supabase.rpc('create_session', params: {
      'p_name': name,
      'p_master_list_ids': masterListIds,
      'p_venue': venue,
      'p_description': description,
      'p_event_date': dateStr,
      'p_duration_hours': durationHours,
      'p_allow_duplicate_scans': allowDuplicateScans,
    });
    return AttendanceSession.fromJson(res as Map<String, dynamic>);
  }

  Future<void> endSession(String sessionId) async {
    await _supabase.rpc('end_session', params: {'p_session_id': sessionId});
  }

  Future<List<AttendanceSession>> listSessions() async {
    final rows = await _supabase
        .from('sessions')
        .select()
        .order('started_at', ascending: false);
    return (rows as List)
        .map((r) => AttendanceSession.fromJson(r as Map<String, dynamic>))
        .toList();
  }

  Future<AttendanceSession?> fetchSession(String sessionId) async {
    final row = await _supabase
        .from('sessions')
        .select()
        .eq('id', sessionId)
        .maybeSingle();
    if (row == null) return null;
    return AttendanceSession.fromJson(row);
  }

  Future<int> scanCount(String sessionId) async {
    final res = await _supabase
        .from('scan_events')
        .select('id')
        .eq('session_id', sessionId)
        .count(CountOption.exact);
    return res.count;
  }

  /// Admin scanning from the app (also used for manual roll-number entry).
  Future<ScanResult> recordAdminScan({
    required String sessionId,
    required String payload,
    String method = 'QR Camera',
  }) async {
    final res = await _supabase.rpc('record_admin_scan', params: {
      'p_session_id': sessionId,
      'p_scanned_payload': payload.trim(),
      'p_method': method,
    });
    return ScanResult.fromRpcJson(res as Map<String, dynamic>);
  }

  /// Full attendance report (one JSON array, so >1000 rows are not cut off).
  Future<List<ReportRow>> report(String sessionId) async {
    final res = await _supabase
        .rpc('get_session_report', params: {'p_session_id': sessionId});
    return (res as List)
        .map((r) => ReportRow.fromJson(r as Map<String, dynamic>))
        .toList();
  }
}
