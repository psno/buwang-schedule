import 'dart:convert';

import '../models/course.dart';
import '../utils/constants.dart';

/// 课表 JSON 导入解析（容错）。业务逻辑放在 services/，UI 只负责选文件与确认。
class ScheduleImportService {
  ScheduleImportService._();

  /// 解析 JSON 文本为课程列表。
  /// 容错：UTF-8 BOM、markdown 代码围栏、尾逗号、顶层数组或
  /// {"courses":[...]} 等包装对象、字符串/双精度数字、缺字段、多余字段。
  /// 越界或结构非法的元素跳过；全部失败抛异常并说明跳过数量。
  static List<Course> parseJson(String raw) {
    String s = raw;
    final bom = String.fromCharCode(0xFEFF);
    if (s.startsWith(bom)) s = s.substring(1);
    s = s.trim();
    if (s.isEmpty) throw Exception('JSON内容为空');

    // 去除 markdown 代码围栏，例如三个反引号 json ... 三个反引号
    final fence = String.fromCharCodes(List.filled(3, 96));
    if (s.startsWith(fence)) {
      final nl = s.indexOf(String.fromCharCode(10));
      s = nl >= 0 ? s.substring(nl + 1) : s.substring(fence.length);
    }
    s = s.trim();
    if (s.endsWith(fence)) {
      s = s.substring(0, s.length - fence.length).trim();
    }
    // 去除对象/数组末尾的尾逗号
    s = s.replaceAllMapped(RegExp(r',\s*([}\]])'), (m) => m.group(1)!);

    final dynamic decoded;
    try {
      decoded = jsonDecode(s);
    } catch (e) {
      throw Exception('JSON解析失败: $e');
    }

    final List<dynamic> items;
    if (decoded is List) {
      items = decoded;
    } else if (decoded is Map) {
      List<dynamic>? found;
      for (final key in const [
        'courses',
        'schedule',
        'data',
        'list',
        'items',
        '课程',
        '课表',
        '课程列表',
      ]) {
        final v = decoded[key];
        if (v is List) {
          found = v;
          break;
        }
      }
      if (found == null) {
        throw Exception(
            'JSON对象中未找到课程数组（需要 courses/schedule/data/list 字段，或直接是数组）');
      }
      items = found;
    } else {
      throw Exception('JSON顶层必须是数组或对象');
    }

    final courses = <Course>[];
    int skipped = 0;
    for (final item in items) {
      if (item is! Map) {
        skipped++;
        continue;
      }
      try {
        final course = Course.fromFlexibleMap(Map<String, dynamic>.from(item));
        if (course.dayOfWeek < 1 ||
            course.dayOfWeek > AppConstants.maxDaysPerWeek ||
            course.period < 0 ||
            course.period >= AppConstants.maxPeriods) {
          skipped++;
          continue;
        }
        courses.add(course);
      } catch (_) {
        skipped++;
      }
    }

    if (courses.isEmpty) {
      throw Exception('未解析到有效课程（共 ${items.length} 项，跳过 $skipped 项）；'
          '请检查 dayOfWeek(1-${AppConstants.maxDaysPerWeek}) 与 period(0-${AppConstants.maxPeriods - 1})');
    }
    return courses;
  }
}
