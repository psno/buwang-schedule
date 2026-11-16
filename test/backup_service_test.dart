import 'package:flutter_test/flutter_test.dart';
import 'package:buwang_schedule/services/backup_service.dart';

void main() {
  group('BackupService static helpers', () {
    const full = '{"version":1,"settings":{"theme_mode":"1"},'
        '"courses":[{"name":"数学","dayOfWeek":1,"period":1}],'
        '"reminders":[],"timeSlots":{"highSchool":null}}';

    test('recognises a full-backup payload', () {
      expect(BackupService.looksLikeFullBackup(full), isTrue);
      expect(BackupService.courseCountIn(full), 1);
    });

    test('rejects a plain course array and course-only wrapper', () {
      expect(
        BackupService.looksLikeFullBackup(
            '[{"name":"数学","dayOfWeek":1,"period":1}]'),
        isFalse,
      );
      expect(
        BackupService.looksLikeFullBackup(
            '{"courses":[{"name":"数学","dayOfWeek":1,"period":1}]}'),
        isFalse,
      );
    });

    test('rejects malformed JSON and returns count 0', () {
      expect(BackupService.looksLikeFullBackup('{broken'), isFalse);
      expect(BackupService.courseCountIn('{broken'), 0);
    });
  });
}
