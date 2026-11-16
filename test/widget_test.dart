import 'package:flutter_test/flutter_test.dart';
import 'package:buwang_schedule/services/schedule_import_service.dart';

void main() {
  group('ScheduleImportService.parseJson', () {
    test('parses a plain course array', () {
      final courses = ScheduleImportService.parseJson(
        '[{"name":"高一1班","subject":"数学","dayOfWeek":1,"period":2,"color":3}]',
      );
      expect(courses.length, 1);
      expect(courses.first.name, '高一1班');
      expect(courses.first.dayOfWeek, 1);
      expect(courses.first.period, 2);
    });

    test('accepts BOM, code fence, trailing commas and wrapper object', () {
      final ticks = String.fromCharCodes(List.filled(3, 96));
      final nl = String.fromCharCode(10);
      final bom = String.fromCharCode(0xFEFF);
      final raw =
          '$bom${ticks}json$nl{"courses":[{"name":"语文","dayOfWeek":"2","period":"3",},],"timeSlots":[{"period":1}]}$nl$ticks';
      final courses = ScheduleImportService.parseJson(raw);
      expect(courses.length, 1);
      expect(courses.first.dayOfWeek, 2);
      expect(courses.first.period, 3);
    });

    test('skips out-of-range / malformed entries and ignores id', () {
      const raw = '[{"id":42,"name":"有效","dayOfWeek":1,"period":1},'
          '{"name":"越界","dayOfWeek":9,"period":1},'
          '{"name":"缺字段"}]';
      final courses = ScheduleImportService.parseJson(raw);
      expect(courses.length, 1);
      expect(courses.first.id, isNull);
    });

    test('throws a clear error for non-JSON text', () {
      expect(
        () => ScheduleImportService.parseJson('not json at all'),
        throwsA(isA<Exception>()),
      );
    });
  });
}
