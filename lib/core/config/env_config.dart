/// AttendHub environment configuration.
library;

import 'package:flutter/foundation.dart' show kIsWeb;

class EnvConfig {
  EnvConfig._();

  // Supabase credentials (publishable / anon key – safe to ship in the client;
  // security comes from the RLS policies in the SQL file).
  static const String supabaseUrl = 'https://bhcsfnnxxkvfkkexmdfr.supabase.co';

  static const String supabaseAnonKey =
      'sb_publishable_snpFrM1UyYW4LsK99322Dw_JcWyrLwb';

  /// Optional: build with --dart-define=APP_BASE_URL=https://your-site.netlify.app
  /// so volunteer links are correct when sharing from the Android app.
  static const String appBaseUrl =
      String.fromEnvironment('APP_BASE_URL', defaultValue: '');

  /// Base address used in volunteer share links. On the web build this is the
  /// address the app is served from, so links always match the live site.
  static String get shareBase {
    if (appBaseUrl.isNotEmpty) return appBaseUrl.replaceAll(RegExp(r'/+$'), '');
    if (kIsWeb) return Uri.base.origin;
    return 'https://YOUR-SITE.netlify.app';
  }
}
