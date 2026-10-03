import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:supabase_flutter/supabase_flutter.dart';
import '../../data/repositories/volunteer_scan_repository.dart';

final volunteerScanRepositoryProvider =
    Provider<VolunteerScanRepository>((ref) {
  return VolunteerScanRepository(Supabase.instance.client);
});
