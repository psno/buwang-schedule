import 'package:flutter_test/flutter_test.dart';
import 'package:buwang_schedule/services/html_parser.dart';

/// 新版教务系统导出：const DATA = {...}，mf 外层=星期、sat 外层=轮次，
/// 内层=节次，值为 {t: 科目, s: 班级}。
const String _newSchemaHtml = '''
<html><head><title>邓老师 · 课表</title></head>
<script>
const DATA = {"periods": [], "satPeriods": [],
  "mf": {"1": {"2": {"t": "数学", "s": "高一1班"}, "3": {"t": "语文", "s": "高一1班"}}},
  "sat": {"1": {"2": {"t": "英语", "s": "高一1班"}}},
  "sun": {}, "has_sat": true, "default_sat": "1"};
const MF = DATA.mf; const SAT = DATA.sat;
</script></html>
''';

/// 旧版 SCHEDULE_MF / SCHEDULE_SAT_CONFIG：值为 HTML 字符串。
const String _legacyHtml = '''
const SCHEDULE_MF = {"2": {"1": "高一1班<br><span>数学</span>"}};
const SCHEDULE_SAT_CONFIG = {"1": {"3": "高一1班<br><span>英语</span>"}};
''';

void main() {
  test('parses new-style const DATA schedule', () {
    final result = HtmlScheduleParser.parseHtmlString(_newSchemaHtml);
    expect(result.teacherName, '邓老师 · 课表');
    expect(result.courses.length, 3);

    final math = result.courses.firstWhere((c) => c.subject == '数学');
    expect(math.dayOfWeek, 1); // mf 外层键 = 星期
    expect(math.period, 2); // mf 内层键 = 节次
    expect(math.round, 0);
    expect(math.name, '高一1班');

    final sat = result.courses.firstWhere((c) => c.dayOfWeek == 6);
    expect(sat.round, 1); // sat 外层键 = 轮次
    expect(sat.period, 2);
    expect(sat.subject, '英语');
  });

  test('still parses legacy SCHEDULE_MF / SCHEDULE_SAT_CONFIG', () {
    final result = HtmlScheduleParser.parseHtmlString(_legacyHtml);
    expect(result.courses.length, 2);
    expect(
      result.courses
          .any((c) => c.dayOfWeek == 6 && c.round == 1 && c.period == 3),
      isTrue,
    );
    expect(
      result.courses
          .any((c) => c.dayOfWeek == 1 && c.period == 2 && c.subject == '数学'),
      isTrue,
    );
  });
}
