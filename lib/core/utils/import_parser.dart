/// Pure-Dart helpers for reading student lists from CSV / Excel rows.
library;

/// One student row ready to send to the `import_master_students` RPC.
class ImportRow {
  const ImportRow({
    required this.rollNo,
    required this.studentName,
    this.department,
    this.category = 'Aided',
    this.mobile,
    this.email,
  });

  final String rollNo;
  final String studentName;
  final String? department;
  final String category; // 'SF' | 'Aided'
  final String? mobile;
  final String? email;

  Map<String, dynamic> toJson() => {
        'roll_no': rollNo,
        'student_name': studentName,
        'department': department,
        'category': category,
        'mobile': mobile,
        'email': email,
      };
}

class ImportParseResult {
  const ImportParseResult({required this.rows, required this.skipped});
  final List<ImportRow> rows;

  /// Rows ignored because they had no roll number.
  final int skipped;
}

String _norm(String s) => s.toLowerCase().replaceAll(RegExp(r'[^a-z0-9]'), '');

const _rollAliases = {
  'rollno', 'rollnumber', 'roll', 'regno', 'registernumber',
  'registrationnumber', 'registerno', 'rno', 'id', 'studentid', 'rollnum',
};
const _nameAliases = {
  'name', 'studentname', 'fullname', 'candidatename', 'nameofthestudent',
};
const _deptAliases = {
  'department', 'dept', 'branch', 'course', 'class', 'programme', 'program',
};
const _catAliases = {
  'category', 'stream', 'type', 'sfaided', 'sforaided', 'participantcategory',
};
const _mobileAliases = {
  'mobile', 'mobileno', 'mobilenumber', 'phone', 'phoneno', 'phonenumber',
  'contact', 'contactnumber', 'whatsappnumber', 'whatsapp',
};
const _emailAliases = {'email', 'emailid', 'mail', 'emailaddress'};

int _find(List<String> header, Set<String> aliases) {
  for (var i = 0; i < header.length; i++) {
    if (aliases.contains(header[i])) return i;
  }
  return -1;
}

String? _clean(String? s) {
  final t = s?.trim();
  return (t == null || t.isEmpty) ? null : t;
}

String normalizeCategory(String? raw) {
  final n = _norm(raw ?? '');
  if (n == 'sf' || n.startsWith('self')) return 'SF';
  return 'Aided';
}

/// Turns a table of strings (first rows may contain the header) into rows.
///
/// Throws [FormatException] if no "Roll No" column can be found.
ImportParseResult parseStudentTable(List<List<String>> table) {
  var headerRow = -1;
  var rollCol = -1;
  final limit = table.length < 6 ? table.length : 6;
  for (var r = 0; r < limit; r++) {
    final h = table[r].map(_norm).toList();
    final c = _find(h, _rollAliases);
    if (c >= 0) {
      headerRow = r;
      rollCol = c;
      break;
    }
  }
  if (headerRow < 0) {
    throw const FormatException(
        'Could not find a "Roll No" column. Use the Template for the right headers.');
  }
  final h = table[headerRow].map(_norm).toList();
  final nameCol = _find(h, _nameAliases);
  final deptCol = _find(h, _deptAliases);
  final catCol = _find(h, _catAliases);
  final mobCol = _find(h, _mobileAliases);
  final mailCol = _find(h, _emailAliases);

  String? at(List<String> row, int c) =>
      (c >= 0 && c < row.length) ? row[c] : null;

  final out = <ImportRow>[];
  var skipped = 0;
  for (var r = headerRow + 1; r < table.length; r++) {
    final row = table[r];
    final roll = _clean(at(row, rollCol));
    if (roll == null) {
      if (row.any((c) => c.trim().isNotEmpty)) skipped++;
      continue;
    }
    out.add(ImportRow(
      rollNo: roll,
      studentName: _clean(at(row, nameCol)) ?? 'Unknown',
      department: _clean(at(row, deptCol)),
      category: normalizeCategory(at(row, catCol)),
      mobile: _clean(at(row, mobCol)),
      email: _clean(at(row, mailCol)),
    ));
  }
  return ImportParseResult(rows: out, skipped: skipped);
}

/// Small RFC-4180 style CSV reader (quotes, escaped quotes, CRLF).
List<List<String>> parseCsv(String text) {
  final rows = <List<String>>[];
  var row = <String>[];
  final field = StringBuffer();
  var inQuotes = false;
  var i = 0;
  if (text.isNotEmpty && text.codeUnitAt(0) == 0xFEFF) i = 1; // BOM
  void endField() {
    row.add(field.toString());
    field.clear();
  }

  void endRow() {
    endField();
    rows.add(row);
    row = <String>[];
  }

  for (; i < text.length; i++) {
    final ch = text[i];
    if (inQuotes) {
      if (ch == '"') {
        if (i + 1 < text.length && text[i + 1] == '"') {
          field.write('"');
          i++;
        } else {
          inQuotes = false;
        }
      } else {
        field.write(ch);
      }
    } else if (ch == '"') {
      inQuotes = true;
    } else if (ch == ',') {
      endField();
    } else if (ch == '\n') {
      endRow();
    } else if (ch == '\r') {
      // swallow; the following \n ends the row
    } else {
      field.write(ch);
    }
  }
  if (field.isNotEmpty || row.isNotEmpty) endRow();
  return rows;
}
