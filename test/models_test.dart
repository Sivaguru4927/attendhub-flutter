import 'package:flutter_test/flutter_test.dart';
import 'package:attend_hub/core/utils/import_parser.dart';
import 'package:attend_hub/data/models/master_student.dart';
import 'package:attend_hub/data/models/report_row.dart';
import 'package:attend_hub/data/models/scan_event.dart';

void main() {
  group('import parser', () {
    test('maps common header names and normalises stream', () {
      final r = parseStudentTable([
        ['Roll Number', 'Full Name', 'Dept', 'Category', 'Mobile Number', 'Email ID'],
        ['25bma127', 'Siva', 'Maths', 'self finance', '9876543210', 'a@b.c'],
        ['25BMA128', 'Guru', '', 'Aided', '', ''],
        ['', 'No roll', '', '', '', ''],
      ]);
      expect(r.rows.length, 2);
      expect(r.skipped, 1);
      expect(r.rows[0].category, 'SF');
      expect(r.rows[1].category, 'Aided');
      expect(r.rows[1].department, isNull);
    });

    test('throws when there is no roll column', () {
      expect(() => parseStudentTable([['Name', 'Dept'], ['a', 'b']]),
          throwsFormatException);
    });

    test('csv with quotes and CRLF', () {
      final t = parseCsv('Roll No,Name\r\n1,"Doe, Jane"\r\n2,"He said ""hi"""\r\n');
      expect(t[1][1], 'Doe, Jane');
      expect(t[2][1], 'He said "hi"');
      expect(t.length, 3);
    });
  });

  group('models', () {
    test('MasterStudent.fromJson', () {
      final s = MasterStudent.fromJson({
        'id': '1', 'master_list_id': '2', 'roll_no': 'R1',
        'student_name': 'A', 'category': 'SF',
      });
      expect(s.category, 'SF');
      expect(s.department, isNull);
    });

    test('ScanResult with and without master-list match', () {
      final ok = ScanResult.fromRpcJson({
        'status': 'SUCCESS', 'message': 'x', 'roll_no': 'R1',
        'student_name': 'A', 'listed': true,
        'scanned_at': '2026-10-02T10:00:00Z',
      });
      expect(ok.isSuccess, isTrue);
      expect(ok.listed, isTrue);
      final unlisted = ScanResult.fromRpcJson({
        'status': 'SUCCESS', 'message': 'Scanned student', 'roll_no': 'R9',
        'listed': false,
      });
      expect(unlisted.listed, isFalse);
      expect(unlisted.studentName, isNull);
    });

    test('ReportRow.fromJson', () {
      final r = ReportRow.fromJson({
        'roll_no': 'R9', 'student_name': 'Scanned student',
        'category': 'Unlisted', 'status': 'Attended',
      });
      expect(r.isUnlisted, isTrue);
      expect(r.attended, isTrue);
    });
  });
}
