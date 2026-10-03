import 'dart:typed_data';
import 'package:file_picker/file_picker.dart';
import 'package:share_plus/share_plus.dart';

/// Saves [bytes] as a file (browser download / "Save as" on mobile).
/// Falls back to the system share sheet if saving is not supported.
Future<void> saveBytes({
  required String fileName,
  required Uint8List bytes,
  String? shareText,
}) async {
  final ext = fileName.contains('.') ? fileName.split('.').last : 'bin';
  try {
    await FilePicker.platform.saveFile(
      dialogTitle: 'Save $fileName',
      fileName: fileName,
      bytes: bytes,
      type: FileType.custom,
      allowedExtensions: [ext],
    );
  } catch (_) {
    await Share.shareXFiles(
      [XFile.fromData(bytes, name: fileName)],
      text: shareText,
    );
  }
}
