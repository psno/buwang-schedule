import 'dart:convert';
import 'dart:io';
import '../models/course.dart';

class HtmlScheduleParser {
  HtmlScheduleParser._();

  /// Parse a local HTML timetable file and return a list of [Course] objects.
  ///
  /// The HTML is expected to contain JavaScript variables like:
  ///   const SCHEDULE_MF = {"2": {"1": "高一1班<br><span ...>数学</span>"}, ...}
  ///   const SCHEDULE_SAT_CONFIG = { ... };
  ///
  /// [filePath] – absolute path to the .html file.
  /// [teacherName] – override teacher name (falls back to title tag / filename).
  static Future<ParseResult> parseFile(
    String filePath, {
    String? teacherName,
  }) async {
    final file = File(filePath);

    // Read with BOM handling
    String html;
    try {
      final bytes = await file.readAsBytes();
      html = utf8.decode(bytes, allowMalformed: true);
    } catch (e) {
      // Fallback: try reading as latin1 and convert
      html = await file.readAsString(encoding: latin1);
    }

    // Strip UTF-8 BOM if present
    if (html.startsWith('\uFEFF')) {
      html = html.substring(1);
    }

    return parseHtmlString(
      html,
      teacherName: teacherName,
      fallbackFilename: file.uri.pathSegments.last,
    );
  }

  /// Parse an HTML string directly.
  static ParseResult parseHtmlString(
    String html, {
    String? teacherName,
    String? fallbackFilename,
  }) {
    final List<Course> courses = [];

    // ── Extract teacher name ──
    String? teacher = teacherName;
    if (teacher == null || teacher.isEmpty) {
      // Try <title> tag
      final titleMatch = RegExp(r'<title>(.*?)</title>', dotAll: true).firstMatch(html);
      if (titleMatch != null) {
        teacher = _stripTags(titleMatch.group(1)!).trim();
      }
    }
    if ((teacher == null || teacher.isEmpty) && fallbackFilename != null) {
      // Derive from filename, e.g. "张老师.html" → "张老师"
      teacher = fallbackFilename.replaceAll(RegExp(r'\.(html?|htm)$', caseSensitive: false), '').trim();
    }

    // ── Parse SCHEDULE_MF (weekday schedule) ──
    final scheduleMf = _extractJsonVariable(html, 'SCHEDULE_MF');
    if (scheduleMf != null) {
      courses.addAll(_parseScheduleMap(scheduleMf, teacher: teacher, isSaturday: false));
    }

    // ── Parse SCHEDULE_SAT_CONFIG (Saturday schedule) ──
    final scheduleSat = _extractJsonVariable(html, 'SCHEDULE_SAT_CONFIG');
    if (scheduleSat != null) {
      courses.addAll(_parseScheduleMap(scheduleSat, teacher: teacher, isSaturday: true));
    }

    return ParseResult(
      courses: courses,
      teacherName: teacher,
    );
  }

  // ═══════════════════════════════════════════════
  // JSON variable extraction
  // ═══════════════════════════════════════════════

  /// Extract a JavaScript/JSON object from a `const VAR_NAME = {...};` declaration.
  static Map<String, dynamic>? _extractJsonVariable(String html, String varName) {
    // 策略1: 精确匹配 const VAR = {...};
    final pattern = RegExp(
      r"(?:const|var|let)\s+$varName\s*=\s*(\{.*?\});",
      dotAll: true,
    );
    var match = pattern.firstMatch(html);
    if (match != null) {
      final result = _tryParseJson(match.group(1)!);
      if (result != null) return result;
    }

    // 策略2: 不要求末尾分号
    final patternNoSemi = RegExp(
      r"(?:const|var|let)\s+$varName\s*=\s*(\{.*\})",
      dotAll: true,
    );
    match = patternNoSemi.firstMatch(html);
    if (match != null) {
      final result = _tryParseJson(match.group(1)!);
      if (result != null) return result;
    }

    // 策略3: 手动花括号配对提取
    final idx = html.indexOf('$varName');
    if (idx < 0) return null;
    final eqIdx = html.indexOf('=', idx + varName.length);
    if (eqIdx < 0) return null;
    final braceIdx = html.indexOf('{', eqIdx);
    if (braceIdx < 0) return null;

    int depth = 0;
    int end = -1;
    for (int i = braceIdx; i < html.length; i++) {
      if (html[i] == '{') depth++;
      if (html[i] == '}') {
        depth--;
        if (depth == 0) { end = i; break; }
      }
    }
    if (end > braceIdx) {
      final result = _tryParseJson(html.substring(braceIdx, end + 1));
      if (result != null) return result;
    }

    return null;
  }

  /// 尝试解析 JSON 字符串，含清理逻辑
  static Map<String, dynamic>? _tryParseJson(String jsonStr) {
    // 直接解析
    try {
      final decoded = json.decode(jsonStr);
      if (decoded is Map<String, dynamic>) return decoded;
    } catch (_) {}

    // 清理后解析
    try {
      String cleaned = jsonStr;
      // 保护 HTML 属性中的单引号
      cleaned = cleaned.replaceAllMapped(
        RegExp(r'''=\s*'([^']*?)' ''', caseSensitive: false),
        (m) => '=\x01${m.group(1)}\x01',
      );
      // 单引号字符串 → 双引号
      cleaned = cleaned.replaceAllMapped(RegExp(r"'([^']*)'"), (m) {
        final content = m.group(1)!.replaceAll('"', '\\"');
        return '"$content"';
      });
      cleaned = cleaned.replaceAll('\x01', "'");
      cleaned = cleaned.replaceAll('\x00', "'");
      // 去尾逗号
      cleaned = cleaned
          .replaceAll(RegExp(r',\s*\}'), '}')
          .replaceAll(RegExp(r',\s*\]'), ']');

      final decoded = json.decode(cleaned);
      if (decoded is Map<String, dynamic>) return decoded;
    } catch (_) {}

    return null;
  }

  /// 调试用：返回 JSON 提取每步的结果描述
  static String extractJsonDebug(String html, String varName) {
    final pattern = RegExp(
      r"(?:const|var|let)\s+$varName\s*=\s*(\{.*?\});",
      dotAll: true,
    );
    final match = pattern.firstMatch(html);
    if (match == null) {
      return '正则未匹配, 含关键词: ${html.contains(varName)}';
    }
    final jsonStr = match.group(1)!;
    try {
      json.decode(jsonStr);
      return 'JSON解析成功${jsonStr.length}字符';
    } catch (e) {
      return 'JSON解析失败: $e';
    }
  }

  // ═══════════════════════════════════════════════
  // Schedule map parsing
  // ═══════════════════════════════════════════════

  /// Parse a schedule map structure:
  ///   { "period": { "dayOfWeek": "html_string", ... }, ... }
  static List<Course> _parseScheduleMap(
    Map<String, dynamic> scheduleMap, {
    String? teacher,
    bool isSaturday = false,
  }) {
    final List<Course> courses = [];
    int colorCounter = 0;

    scheduleMap.forEach((periodStr, dayMap) {
      final period = int.tryParse(periodStr);
      if (period == null || dayMap is! Map) return;

      (dayMap as Map<String, dynamic>).forEach((dayStr, htmlValue) {
        final dayOfWeek = int.tryParse(dayStr);
        if (dayOfWeek == null) return;

        final htmlStr = htmlValue?.toString();
        if (htmlStr == null || htmlStr.isEmpty || htmlStr == 'null') return;

        // Skip empty / placeholder entries
        final stripped = _stripTags(htmlStr).trim();
        if (stripped.isEmpty || stripped == '&nbsp;') return;

        // Parse the HTML into name + subject
        final parsed = _parseCourseHtml(htmlStr);

        courses.add(Course(
          name: parsed.name,
          subject: parsed.subject,
          dayOfWeek: isSaturday ? 6 : dayOfWeek,
          period: period,
          teacher: teacher,
          color: colorCounter++ % 10,
        ));
      });
    });

    return courses;
  }

  // ═══════════════════════════════════════════════
  // HTML content parsing
  // ═══════════════════════════════════════════════

  /// Parse course HTML like:
  ///   `高一1班<br><span style='font-size:10px; opacity:0.8;'>数学</span>`
  /// into (name: "高一1班", subject: "数学").
  static _CourseHtmlParsed _parseCourseHtml(String html) {
    // Split by <br> or <br/> or <br /> (case-insensitive)
    final brPattern = RegExp(r'<br\s*/?>', caseSensitive: false);
    final parts = html.split(brPattern);

    String name;
    String? subject;

    if (parts.length >= 2) {
      // First part is the class name
      name = _stripTags(parts[0]).trim();
      // Second part (in a <span>) is the subject
      subject = _stripTags(parts[1]).trim();
    } else {
      // Everything in one part
      name = _stripTags(html).trim();
      subject = null;
    }

    // Clean up &nbsp; and other HTML entities
    name = _decodeEntities(name);
    if (subject != null) {
      subject = _decodeEntities(subject);
    }

    // If name is empty after stripping, use subject as name
    if (name.isEmpty && subject != null && subject.isNotEmpty) {
      name = subject;
      subject = null;
    }

    return _CourseHtmlParsed(name: name, subject: subject);
  }

  /// Strip all HTML tags from a string.
  static String _stripTags(String html) {
    return html.replaceAll(RegExp(r'<[^>]*>'), '');
  }

  /// Decode common HTML entities.
  static String _decodeEntities(String text) {
    return text
        .replaceAll('&nbsp;', ' ')
        .replaceAll('&amp;', '&')
        .replaceAll('&lt;', '<')
        .replaceAll('&gt;', '>')
        .replaceAll('&quot;', '"')
        .replaceAll('&#39;', "'")
        .replaceAll(RegExp(r'\s+'), ' ')
        .trim();
  }
}

// ═══════════════════════════════════════════════
// Helper classes
// ═══════════════════════════════════════════════

class _CourseHtmlParsed {
  final String name;
  final String? subject;
  const _CourseHtmlParsed({required this.name, this.subject});
}

/// Result returned by the HTML parser.
class ParseResult {
  final List<Course> courses;
  final String? teacherName;

  const ParseResult({
    required this.courses,
    this.teacherName,
  });

  int get courseCount => courses.length;
  bool get isEmpty => courses.isEmpty;

  @override
  String toString() =>
      'ParseResult(teacher: $teacherName, courses: ${courses.length})';
}
