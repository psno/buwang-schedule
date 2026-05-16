# 不忘课表 — 周六轮次过滤 Bug（第二轮排查）

## 现象

1. 课表页选"第1轮/第2轮/第3轮"，周六列显示的课程**完全一样**
2. 首页在周六时**不显示任何课程**

## 已确认无问题的链路

- `isSaturday: true` 在调用时传了（html_parser.dart 第75行）
- `Course.toMap()` 包含 `round` 字段
- `Course.fromMap()` 读取 `round` 字段
- 数据库迁移 v1→v2 加了 `round` 列
- 过滤逻辑 `_allCourses.where((c) => c.dayOfWeek == 6 && c.round == _saturdayRound)` 看起来正确

## 数据结构（关键！）

```javascript
// SCHEDULE_MF: 外层=节次, 内层=星期几
const SCHEDULE_MF = {
  "1": {"1": "高一9班<br>数学"},   // 第1节 周一
  "9": {"1": "高一1班...", "2": "高一9班..."}
};

// SCHEDULE_SAT_CONFIG: 外层=轮次, 内层=节次（与MF相反！）
const SCHEDULE_SAT_CONFIG = {
  "1": {"6": "高一9班...", "7": "高一1班...", "8": "高一9班..."},  // 第1轮: 节次6,7,8
  "2": {"3": "高一1班...", "4": "高一9班...", "7": "...", "8": "..."},  // 第2轮: 节次3,4,7,8
  "3": {"3": "高一1班...", "4": "高一1班...", "5": "高一9班..."}   // 第3轮: 节次3,4,5
};
```

用户已确认：**更新APK后重新导入了HTML课表，问题依旧**。

## 完整代码

### 解析器 (html_parser.dart)

```dart
// 调用处（第66-76行）
final scheduleMf = _extractJsonVariable(html, 'SCHEDULE_MF');
if (scheduleMf != null) {
  courses.addAll(_parseScheduleMap(scheduleMf, teacher: teacher, isSaturday: false));
}
final scheduleSat = _extractJsonVariable(html, 'SCHEDULE_SAT_CONFIG');
if (scheduleSat != null) {
  courses.addAll(_parseScheduleMap(scheduleSat, teacher: teacher, isSaturday: true));
}

// 解析函数
static List<Course> _parseScheduleMap(
  Map<String, dynamic> scheduleMap, {
  String? teacher,
  bool isSaturday = false,
}) {
  final List<Course> courses = [];
  int colorCounter = 0;

  scheduleMap.forEach((outerKey, innerMap) {
    final outerVal = int.tryParse(outerKey);
    if (outerVal == null || innerMap is! Map) return;

    (innerMap as Map<String, dynamic>).forEach((innerKey, htmlValue) {
      final innerVal = int.tryParse(innerKey);
      if (innerVal == null) return;

      final htmlStr = htmlValue?.toString();
      if (htmlStr == null || htmlStr.isEmpty || htmlStr == 'null') return;

      final stripped = _stripTags(htmlStr).trim();
      if (stripped.isEmpty || stripped == '&nbsp;') return;

      final parsed = _parseCourseHtml(htmlStr);

      if (isSaturday) {
        // SAT_CONFIG: outer=rotation_type, inner=period_index
        courses.add(Course(
          name: parsed.name,
          subject: parsed.subject,
          dayOfWeek: 6,
          period: innerVal,      // inner key = 节次
          teacher: teacher,
          color: colorCounter++ % 10,
          round: outerVal,       // outer key = 轮次
        ));
      } else {
        // SCHEDULE_MF: outer=period, inner=dayOfWeek
        courses.add(Course(
          name: parsed.name,
          subject: parsed.subject,
          dayOfWeek: innerVal,   // inner key = 星期几
          period: outerVal,      // outer key = 节次
          teacher: teacher,
          color: colorCounter++ % 10,
          round: 0,
        ));
      }
    });
  });
  return courses;
}
```

### Course 模型 (course.dart)

```dart
class Course {
  final int? id;
  final String name;
  final String? subject;
  final int dayOfWeek;     // 1-6 (Mon-Sat)
  final int period;        // 0-12
  final String? location;
  final String? teacher;
  final int color;
  final int round;         // 周六轮次 (0=非周六, 1/2/3=轮次)

  Map<String, dynamic> toMap() {
    return {
      if (id != null) 'id': id,
      'name': name, 'subject': subject,
      'dayOfWeek': dayOfWeek, 'period': period,
      'location': location, 'teacher': teacher,
      'color': color, 'round': round,
    };
  }

  factory Course.fromMap(Map<String, dynamic> map) {
    return Course(
      id: map['id'] as int?,
      name: map['name'] as String,
      subject: map['subject'] as String?,
      dayOfWeek: map['dayOfWeek'] as int,
      period: map['period'] as int,
      location: map['location'] as String?,
      teacher: map['teacher'] as String?,
      color: map['color'] as int? ?? 0,
      round: map['round'] as int? ?? 0,
    );
  }
}
```

### 数据库 (database_service.dart)

```dart
static const int _dbVersion = 2;

// 建表（含round）
CREATE TABLE courses (
  id INTEGER PRIMARY KEY AUTOINCREMENT,
  name TEXT NOT NULL, subject TEXT,
  dayOfWeek INTEGER NOT NULL, period INTEGER NOT NULL,
  location TEXT, teacher TEXT, color INTEGER DEFAULT 0,
  round INTEGER DEFAULT 0
);

// 迁移
Future<void> _onUpgrade(Database db, int oldVersion, int newVersion) async {
  if (oldVersion < 2) {
    await db.execute('ALTER TABLE courses ADD COLUMN round INTEGER DEFAULT 0');
  }
}

// 导入（替换所有）
Future<void> importCourses(List<Course> courses) async {
  final db = await database;
  await db.transaction((txn) async {
    await txn.delete('courses');
    for (final course in courses) {
      await txn.insert('courses', course.toMap());
    }
  });
}

// 周六查询
Future<List<Course>> getSaturdayCourses(int round) async {
  final db = await database;
  final maps = await db.query('courses',
    where: 'dayOfWeek = 6 AND round = ?',
    whereArgs: [round], orderBy: 'period');
  return maps.map((m) => Course.fromMap(m)).toList();
}
```

### 导入调用 (more_screen.dart)

```dart
List<Course> _parseHtmlCourses(String htmlStr) {
  final result = HtmlScheduleParser.parseHtmlString(htmlStr);
  return result.courses;
}

Future<void> _importFromFile() async {
  // ... pick file ...
  if (ext == 'json') {
    courses = _parseJsonCourses(content);
  } else {
    courses = _parseHtmlCourses(content);
  }
  await _db.importCourses(courses);
}
```

### 课表过滤 (timetable_screen.dart)

```dart
SaturdayMode _saturdayMode = SaturdayMode.off; // off=0, round1=1, round2=2, round3=3

int get _saturdayRound => _saturdayMode.index;

List<Course> _coursesForColumn(int col) {
  final dayOfWeek = col + 1; // 1=Mon..6=Sat
  if (dayOfWeek == 6 && _saturdayMode != SaturdayMode.off) {
    return _allCourses.where((c) => c.dayOfWeek == 6 && c.round == _saturdayRound).toList();
  }
  return _allCourses.where((c) => c.dayOfWeek == dayOfWeek).toList();
}
```

### 首页 (home_screen.dart)

```dart
Future<void> _loadTodayCourses() async {
  final today = DateTime.now().weekday;
  if (today == 6) {
    final satMode = await _db.getSetting('saturday_mode');
    final mode = SaturdayMode.values[int.tryParse(satMode ?? '0') ?? 0];
    if (mode != SaturdayMode.off) {
      _todayCourses = await _db.getSaturdayCourses(mode.index);
    } else {
      _todayCourses = [];
    }
  } else if (today <= 5) {
    _todayCourses = await _db.getCoursesForDay(today);
  }
}
```

## 用户的 HTML 文件中 SCHEDULE_SAT_CONFIG 实际数据

邓旭洲_专属课表.html:
```json
{
  "1": {"6": "高一9班<br>数学", "7": "高一1班<br>数学", "8": "高一9班<br>数学"},
  "2": {"3": "高一1班<br>数学", "4": "高一9班<br>数学", "7": "高一9班<br>数学", "8": "高一1班<br>数学"},
  "3": {"3": "高一1班<br>数学", "4": "高一1班<br>数学", "5": "高一9班<br>数学"}
}
```

期望结果：
- 选第1轮 → 周六显示节次6,7,8
- 选第2轮 → 周六显示节次3,4,7,8
- 选第3轮 → 周六显示节次3,4,5

## 诉求

以上是全部相关代码和数据。用户已确认更新APK后重新导入了HTML，问题依旧。

请审查完整链路，找出问题所在。如果代码逻辑确实没问题，请告诉用户需要提供什么调试信息（比如在App里加一段日志打印导入后的Course数据，或查询SQLite数据库内容）。
