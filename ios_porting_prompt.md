# 不忘课表 (BuWang Schedule) — iOS 移植完整说明

## 一、项目概况

- **应用名**：不忘课表 (BuWang Schedule)
- **包名**：`com.sno.buwang`
- **当前版本**：v1.4.4 (Android)
- **技术栈**：Flutter 3.x + Dart + SQLite
- **总代码量**：约 6,800 行（21 个 Dart 文件）
- **开发者**：SNO（个人开发者，预算有限，需免费方案优先）

## 二、功能模块

### 2.1 数据模型

**Course（课程）**
| 字段 | 类型 | 说明 |
|------|------|------|
| id | int? | 主键 |
| name | String | 班级名，如"高一1班" |
| subject | String? | 科目，如"数学" |
| dayOfWeek | int | 1-6 (周一到周六) |
| period | int | 0-12 节次 |
| location | String? | 教室地点 |
| teacher | String? | 教师姓名 |
| color | int | 颜色索引(0-7) |

**TimeSlot（时间节次）**
- 高中：12 节（第0-11节），含早读、午休、晚自习
- 大学：10 节（第0-9节），支持大节（如1-2节连上）
- 每节有 startTime / endTime / label
- 周六下午有独立时间配置（轮次模式）

**UserRole（用户角色）**
- `student`：学生版 — 卡片显示"科目(大) + 教师(中) + 地点(小)"
- `teacher`：教师版 — 卡片显示"班级(大) + 科目(中) + 地点(小)"

**SchoolType（学校类型）**
- `highSchool`：高中 — 12节/天，无单双周
- `university`：大学 — 10节/天，支持大节

**SaturdayMode（周六模式）**
- off：隐藏周六
- round1/round2/round3：三轮轮次（隔周上课）

**CustomReminder（自定义提醒）**
- name/hour/minute/enabled/method(alarm/notification)
- 独立于课程的个人提醒

### 2.2 四个主页面（BottomNavigationBar）

1. **首页 (home_screen)** — 今日课程、当前课程高亮、下节课程预览
2. **课表 (timetable_screen)** — 周视图网格，左侧固定时间列，右侧水平滑动，整体可垂直滑动
3. **提醒 (reminder_screen)** — 日历同步、课程提醒、自定义提醒
4. **更多 (more_screen)** — 设置、主题切换、导入导出、关于

### 2.3 数据导入

支持两种格式：
- **HTML**：学校教务系统导出的课表页面，解析 `<table>` 提取课程
- **JSON**：AI 生成的结构化数据，格式：
```json
{
  "courses": [
    {"name": "高一1班", "subject": "数学", "dayOfWeek": 1, "period": 0, "location": "实验楼302", "teacher": "张老师", "color": 0}
  ],
  "timeSlots": [
    {"period": 0, "startTime": "08:25", "endTime": "09:05", "label": "第1节"}
  ]
}
```

### 2.4 日历同步

- 一键将整学期课表写入系统日历（Calendar Provider）
- 创建独立"不忘课表"日历账户，不污染用户个人日历
- 支持选择开学日期、总周数、提前提醒分钟数
- Android 端用 `device_calendar` 写入 + 原生 ContentResolver 清理

### 2.5 通知/提醒

三种方式：
1. **系统闹钟**：MethodChannel 调用 `AlarmClock.ACTION_SET_ALARM`
2. **系统日历**：写入 Calendar Provider，系统自动提醒
3. **应用内通知**：`flutter_local_notifications`，支持定时和即时

### 2.6 主题系统

三套主题（Apple 风格圆角卡片设计）：
- 默认蓝 (#007AFF)
- 樱花粉 (#FF6B9D)
- 薄荷绿 (#00C9A7)

使用 `google_fonts` 英文字体，Material 3 但不使用 fromSeed（手动控制颜色）。

### 2.7 开发者模式

- 更多页底部 Logo 连点 5 次开启
- LogService 记录关键操作到本地文件
- 支持一键导出日志（share_plus）

## 三、Android 特有实现（iOS 需要对应替换）

| 功能 | Android 实现 | iOS 替代方案 |
|------|-------------|-------------|
| 日历写入 | device_calendar + Calendar Provider | EventKit (EKEventStore) |
| 日历清理 | 原生 MethodChannel + ContentResolver | EventKit API |
| 闹钟 | MethodChannel + AlarmClock.ACTION_SET_ALARM | UNNotification / AlarmKit (iOS 16+) |
| 通知 | flutter_local_notifications | 同（插件已支持 iOS） |
| 权限 | permission_handler | permission_handler (已支持 iOS) |
| 文件选择 | file_picker | 同（已支持 iOS） |
| 分享 | share_plus | 同（已支持 iOS） |

## 四、数据库结构 (SQLite)

```sql
CREATE TABLE courses (
  id INTEGER PRIMARY KEY AUTOINCREMENT,
  name TEXT NOT NULL,
  subject TEXT,
  dayOfWeek INTEGER NOT NULL,
  period INTEGER NOT NULL,
  location TEXT,
  teacher TEXT,
  color INTEGER DEFAULT 0
);

CREATE TABLE custom_reminders (
  id INTEGER PRIMARY KEY AUTOINCREMENT,
  name TEXT NOT NULL,
  hour INTEGER NOT NULL,
  minute INTEGER NOT NULL,
  enabled INTEGER DEFAULT 1,
  method INTEGER DEFAULT 0
);

CREATE TABLE time_slots (
  id INTEGER PRIMARY KEY AUTOINCREMENT,
  period INTEGER NOT NULL,
  startTime TEXT NOT NULL,
  endTime TEXT NOT NULL,
  label TEXT NOT NULL,
  isSaturdayAfternoon INTEGER DEFAULT 0
);

CREATE TABLE settings (
  key TEXT PRIMARY KEY,
  value TEXT
);
```

## 五、项目文件结构

```
lib/
├── main.dart                    # 入口
├── app.dart                     # MaterialApp + 导航
├── models/
│   ├── app_mode.dart            # UserRole, SchoolType 枚举
│   ├── course.dart              # Course 数据模型
│   ├── custom_reminder.dart     # CustomReminder 数据模型
│   ├── saturday_mode.dart       # SaturdayMode 枚举
│   └── time_slot.dart           # TimeSlot 数据模型
├── screens/
│   ├── home_screen.dart         # 首页(564行)
│   ├── timetable_screen.dart    # 课表页(1133行)
│   ├── reminder_screen.dart     # 提醒页(1132行)
│   └── more_screen.dart         # 更多页(677行)
├── services/
│   ├── alarm_service.dart       # 闹钟服务(94行)
│   ├── calendar_sync_service.dart # 日历同步(473行)
│   ├── calendar_native_service.dart # 原生日历(63行)
│   ├── database_service.dart    # SQLite数据库(227行)
│   ├── html_parser.dart         # HTML解析器(323行)
│   ├── log_service.dart         # 日志服务(139行)
│   └── notification_service.dart # 通知服务(253行)
├── theme/
│   └── app_theme.dart           # 主题定义(441行)
└── utils/
    ├── constants.dart           # 常量+时间表(426行)
    └── extensions.dart          # 扩展方法(384行)

android/app/src/main/kotlin/.../MainActivity.kt  # 原生通道(闹钟+日历)
```

## 六、依赖清单

```yaml
dependencies:
  sqflite: ^2.3.0              # SQLite
  path: ^1.9.0
  path_provider: ^2.1.2        # 文件路径
  file_picker: ^8.0.3          # 文件选择
  html: ^0.15.4                # HTML解析
  share_plus: ^9.0.0           # 分享
  intl: ^0.19.0                # 国际化
  shared_preferences: ^2.2.0   # 轻量存储
  google_fonts: ^6.1.0         # 字体
  device_calendar: ^4.3.2      # 日历插件
  permission_handler: ^11.0.0  # 权限
  timezone: ^0.9.2             # 时区
  flutter_local_notifications: ^18.0.1  # 通知
  logger: ^2.5.0               # 日志
```

## 七、iOS 移植注意事项

1. **sqflite** — iOS 已支持，无需改动
2. **device_calendar** — iOS 端用 EventKit，API 不同，需重写日历服务层
3. **闹钟** — iOS 无直接设闹钟 API，用 `UNNotification` 替代，或 `AlarmKit` (iOS 16+)
4. **flutter_local_notifications** — iOS 端需配置 APNs，插件已支持
5. **permission_handler** — iOS 需在 Info.plist 声明权限描述
6. **file_picker** — iOS 已支持
7. **原生 MethodChannel** — Android 的 MainActivity.kt 不适用于 iOS，需写 Swift/ObjC 对应代码

### iOS 需要的权限 (Info.plist)
```xml
<key>NSCalendarsUsageDescription</key>
<string>不忘课表需要访问日历以同步课程提醒</string>
<key>NSRemindersUsageDescription</key>
<string>不忘课表需要设置提醒以通知您上课时间</string>
<key>NSPhotoLibraryUsageDescription</key>
<string>用于选择赞赏码图片</string>
```

## 八、你的任务

基于以上信息，生成一个完整的 prompt，用于指导新 session 的 AI 助手完成：

1. **在现有 Flutter 项目中添加 iOS 支持**（不是重写，是跨平台适配）
2. **iOS 原生层实现**（Swift）：日历写入(EventKit)、通知、闹钟替代方案
3. **iOS 权限配置**（Info.plist）
4. **iOS 构建和测试**
5. **App Store 上架准备**（签名、截图、描述等）

prompt 需要：
- 包含所有必要的技术细节
- 列出需要修改/新增的文件
- 给出关键代码的 iOS 实现方案
- 标注与 Android 的差异点
- 包含构建和测试步骤
