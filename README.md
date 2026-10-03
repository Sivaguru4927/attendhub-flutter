# AttendHub – updated source (Flutter + Supabase)

This folder replaces `lib/`, `test/` and `pubspec.yaml` in your `flutter_app`
project and adds the SQL you need. NOTE: it was written without a Flutter SDK
available, so it has NOT been compiled or run. Run `flutter pub get` and
`flutter analyze` first and send me any error text.

## 1. Database (Supabase > SQL Editor)
1. Already ran `001_attendhub_master.sql`? Then DON'T run it again (it deletes data).
   Never ran it? Run it once, then run the patch.
2. Run `supabase/migrations/002_attendhub_patch.sql` (safe, deletes nothing).
   It adds: scan result details, counts, admin scan method, and removes the
   "Security Definer View" warning.

## 2. App
1. Copy `lib/`, `test/`, `pubspec.yaml` over your project (keep android/, web/, ios/).
2. DELETE these old files (no longer used):
   - lib/data/local/offline_scan_queue.dart
   - lib/data/models/student.dart
   - lib/data/repositories/student_repository.dart
   - lib/logic/admin/student_management_provider.dart
   - lib/ui/volunteer/scanner/widgets/   (whole folder)
   - test/widget_test.dart (replaced by an empty file)
3. `flutter pub get` -> `flutter analyze`
4. Web: `flutter build web --release` -> deploy `build/web` to Netlify
   (keep a `_redirects` file with `/*  /index.html  200`).
   Android: `flutter build apk --release`
   Optional for the APK: add `--dart-define=APP_BASE_URL=https://YOUR-SITE.netlify.app`
   so share links point to your site.

## What changed
- Flashlight: the old button only flipped a variable; it never called the camera.
  Now it calls the real torch, and is greyed out if the camera/browser has none.
- Scan flow: code must stay in view for the hold time (progress bar) -> roll no is
  shown -> Confirm (Enter) / Cancel (Esc) -> details saved. Hold time: timer icon
  (Instant / 0.5 / 1 / 1.5 / 2 / 3 s), remembered on the device.
- Result: roll no found in master list -> name, department, stream, mobile, email,
  scan date/time. Not found -> "Scanned student" + roll no + scan date/time.
- Admin page now has its own scanner (Session screen > Scan Attendance).
- Master lists: new list, delete list, import Excel/CSV (chunks of 500 with progress),
  add student, template, export, server-side search/paging/counts (14,000+ ready).
- Reports: Both/SF/Aided and Present/Absent/Both filters, search, Excel export.
- Volunteer join: paste link (the old 6-digit OTP does not exist in the new SQL).
- Sign-up now creates the pending admin row itself (no trigger needed).
