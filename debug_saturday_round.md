# 不忘课表 Flutter App — 周六轮次过滤 Bug

## 现象

1. 课表页面选择"周六轮次 1/2/3"任一轮次，周六列显示的课程完全一样（都是三轮综合）
2. 首页（今日课程）在周六时完全不显示任何课程

## 背景

这是一 Flutter 课表 App。学校周六有"三轮轮次"制度（隔周上课），不同轮次的周六课程不同。

数据来源是教务系统生成的 HTML 文件，内含两个 JavaScript 变量：

### SCHEDULE_MF（周一到周五课表）
```javascript
// 结构: { "节次": { "星期几": "HTML内容" } }
const SCHEDULE_MF = {
  "1": {"1": "高一9班<br><span>数学</span>"},        // 第1节 周一
  "2": {"1": "高一1班<br><span>数学</span>", "4": "高一9班<br><span>数学</span>"},  // 第2节 周一周四
  "9": {"1": "高一1班...", "2": "高一9班...", "3": "高一1班..."}
};
// 外层key = 节次(period), 内层key = 星期几(1=Mon..5=Fri)
```

### SCHEDULE_SAT_CONFIG（周六各轮次课表）
```javascript
// 结构: { "轮次rotation_type": { "节次period_index": "HTML内容" } }
const SCHEDULE_SAT_CONFIG = {
  "1": {"6": "高一9班...", "7": "高一1班...", "8": "高一9班..."},  // 第1轮: 节次6,7,8有课
  "2": {"3": "高一1班...", "4": "高一9班...", "7": "高一9班...", "8": "高一1班..."},  // 第2轮: 节次3,4,7,8
  "3": {"3": "高一1班...", "4": "高一1班...", "5": "高一9班..."}   // 第3轮: 节次3,4,5
};
// 外层key = 轮次(rotation_type: 1/2/3), 内层key = 节次(period_index: 1-12)
// ⚠️ 注意：外层内层含义与 SCHEDULE_MF 完全相反！
```

HTML页面中的轮次选择器：
```html
<select id="satSelector">
  <option value="0">双休</option>
  <option value="1">第1轮</option>
  <option value="2">第2轮</option>
  <option value="3">第3轮</option>
</select>
```

渲染逻辑（原始HTML页面的JS，能正确工作）：
```javascript
const satSchedule = SCHEDULE_SAT_CONFIG[currentSatMode]; // currentSatMode = "1"/"2"/"3"
if (satSchedule && satSchedule[p]) {  // p = period_index
  satCourseHtml = satSchedule[p];
}
```

## 数据模型

```dart
class Course {
  final int? id;
  final String name;       // 班级名 e.g. '高一1班'
  final String? subject;   // 科目 e.g. '数学'
  final int dayOfWeek;     // 1-6 (Mon-Sat)
  final int period;        // 0-12 (节次)
  final int round;         // 周六轮次 (0=非周六, 1/2/3=轮次)
  final int color;
  // ...
}
```

数据库 SQLite:
```sql
CREATE TABLE courses (
  id INTEGER PRIMARY KEY AUTOINCREMENT,
  name TEXT NOT NULL, subject TEXT,
  dayOfWeek INTEGER NOT NULL, period INTEGER NOT NULL,
  location TEXT, teacher TEXT, color INTEGER DEFAULT 0,
  round INTEGER DEFAULT 0  -- v2新增
);
```

## 当前解析器代码（有问题的版本）

```dart
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
      // ... parse html ...

      if (isSaturday) {
        courses.add(Course(
          dayOfWeek: 6,
          period: innerVal,   // inner key = 节次
          round: outerVal,    // outer key = 轮次
          // ...
        ));
      } else {
        courses.add(Course(
          dayOfWeek: innerVal,  // inner key = 星期几
          period: outerVal,     // outer key = 节次
          round: 0,
          // ...
        ));
      }
    });
  });
  return courses;
}
```

## 课表显示过滤

```dart
// timetable_screen.dart
int get _saturdayRound => _saturdayMode.index; // off=0, round1=1, round2=2, round3=3

List<Course> _coursesForColumn(int col) {
  final dayOfWeek = col + 1; // 1=Mon..6=Sat
  if (dayOfWeek == 6 && _saturdayMode != SaturdayMode.off) {
    return _allCourses.where((c) => c.dayOfWeek == 6 && c.round == _saturdayRound).toList();
  }
  return _allCourses.where((c) => c.dayOfWeek == dayOfWeek).toList();
}
```

## 首页过滤

```dart
// home_screen.dart
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
  }
}

// database_service.dart
Future<List<Course>> getSaturdayCourses(int round) async {
  final db = await database;
  final maps = await db.query('courses',
    where: 'dayOfWeek = 6 AND round = ?',
    whereArgs: [round],
    orderBy: 'period');
  return maps.map((m) => Course.fromMap(m)).toList();
}
```

## 诉求

请审查以上代码逻辑，找出为什么：
1. 选择不同轮次（1/2/3）时，周六列显示的课程完全一样
2. 首页在周六时完全不显示课程

核心疑点：解析器是否正确地把 `SCHEDULE_SAT_CONFIG` 的外层 key 作为 round、内层 key 作为 period 存入数据库？过滤逻辑 `_saturdayRound = _saturdayMode.index` 是否与数据库中 round 的值匹配？

如果代码逻辑没问题，那问题可能在用户还没重新导入HTML课表（旧数据 round=0）。请确认这一点。
