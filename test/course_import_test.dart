import 'package:flutter_test/flutter_test.dart';
import 'package:buwang_schedule/models/course.dart';

void main() {
  group('Course.fromFlexibleMap', () {
    test('accepts string / double numbers and alternate field names', () {
      final c = Course.fromFlexibleMap(<String, dynamic>{
        'className': '高二3班',
        'subject': '物理',
        'day': '3',
        'period': 4.0,
        'room': '实验楼201',
        'teacher': '王老师',
        'color': '5',
        'round': null,
        'id': 99, // 导入应忽略旧主键
      });
      expect(c.id, isNull);
      expect(c.name, '高二3班');
      expect(c.subject, '物理');
      expect(c.dayOfWeek, 3);
      expect(c.period, 4);
      expect(c.location, '实验楼201');
      expect(c.color, 5);
      expect(c.round, 0);
    });

    test('falls back name to subject when no name/className', () {
      final c = Course.fromFlexibleMap(<String, dynamic>{
        'subject': '数学',
        'dayOfWeek': 1,
        'period': 0,
      });
      expect(c.name, '数学');
      expect(c.subject, '数学');
    });

    test('throws FormatException on missing name', () {
      expect(
        () => Course.fromFlexibleMap(<String, dynamic>{
          'dayOfWeek': 1,
          'period': 1,
        }),
        throwsA(isA<FormatException>()),
      );
    });

    test('throws FormatException on missing / unparsable day or period', () {
      expect(
        () => Course.fromFlexibleMap(<String, dynamic>{
          'name': '语文',
          'dayOfWeek': '星期几',
          'period': 1,
        }),
        throwsA(isA<FormatException>()),
      );
    });
  });
}
