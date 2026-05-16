import 'package:flutter/material.dart';

import '../models/app_mode.dart';

/// 不忘课表 - App Constants
class AppConstants {
  AppConstants._();

  // ─── App Info ───
  static const String appName = '不忘课表';
  static const String appVersion = '1.4.5';

  // ─── Storage Keys ───
  static const String keyThemeMode = 'theme_mode';
  static const String keyThemeColor = 'theme_color';
  static const String keyWeekdayOnly = 'weekday_only_reminders';
  static const String keySchedule = 'schedule_data';
  static const String keyTimeSlots = 'time_slots';
  static const String keyCurrentWeek = 'current_week';
  static const String keySemesterStart = 'semester_start';
  static const String keyTotalWeeks = 'total_weeks';
  static const String keyNotifications = 'notifications_enabled';
  static const String keyNotificationMinutes = 'notification_minutes_before';
  static const String keyUserRole = 'user_role';
  static const String keySchoolType = 'school_type';

  // ─── Defaults ───
  static const int defaultTotalWeeks = 20;
  static const int defaultNotificationMinutes = 10;
  static const int maxWeeks = 30;
  static const int maxPeriods = 13; // 0-12
  static const int maxDaysPerWeek = 7;
}

/// Time slot definition for a class period
class TimeSlot {
  final int period;
  final TimeOfDay startTime;
  final TimeOfDay endTime;
  final String label;
  final bool isSaturdayAfternoon;

  const TimeSlot({
    required this.period,
    required this.startTime,
    required this.endTime,
    required this.label,
    this.isSaturdayAfternoon = false,
  });

  /// Formatted time range string, e.g. "08:25 - 09:05"
  String get timeRange {
    return '${_formatTime(startTime)} - ${_formatTime(endTime)}';
  }

  /// Duration of this time slot
  Duration get duration {
    final startMinutes = startTime.hour * 60 + startTime.minute;
    final endMinutes = endTime.hour * 60 + endTime.minute;
    return Duration(minutes: endMinutes - startMinutes);
  }

  /// Whether the given time falls within this slot
  bool containsTime(TimeOfDay time) {
    final now = time.hour * 60 + time.minute;
    final start = startTime.hour * 60 + startTime.minute;
    final end = endTime.hour * 60 + endTime.minute;
    return now >= start && now < end;
  }

  /// Whether the given time is before this slot
  bool isBeforeTime(TimeOfDay time) {
    final now = time.hour * 60 + time.minute;
    final start = startTime.hour * 60 + startTime.minute;
    return now < start;
  }

  static String _formatTime(TimeOfDay time) {
    final h = time.hour.toString().padLeft(2, '0');
    final m = time.minute.toString().padLeft(2, '0');
    return '$h:$m';
  }

  @override
  String toString() => 'TimeSlot($period: $timeRange $label)';

  @override
  bool operator ==(Object other) =>
      identical(this, other) ||
      other is TimeSlot &&
          runtimeType == other.runtimeType &&
          period == other.period;

  @override
  int get hashCode => period.hashCode;
}

/// Default time slots - standard weekdays
const List<TimeSlot> defaultTimeSlots = [
  TimeSlot(
    period: 0,
    startTime: TimeOfDay(hour: 7, minute: 5),
    endTime: TimeOfDay(hour: 7, minute: 45),
    label: '早自习',
  ),
  TimeSlot(
    period: 1,
    startTime: TimeOfDay(hour: 8, minute: 25),
    endTime: TimeOfDay(hour: 9, minute: 5),
    label: '第1节',
  ),
  TimeSlot(
    period: 2,
    startTime: TimeOfDay(hour: 9, minute: 15),
    endTime: TimeOfDay(hour: 9, minute: 55),
    label: '第2节',
  ),
  TimeSlot(
    period: 3,
    startTime: TimeOfDay(hour: 10, minute: 25),
    endTime: TimeOfDay(hour: 11, minute: 5),
    label: '第3节',
  ),
  TimeSlot(
    period: 4,
    startTime: TimeOfDay(hour: 11, minute: 20),
    endTime: TimeOfDay(hour: 12, minute: 0),
    label: '第4节',
  ),
  TimeSlot(
    period: 5,
    startTime: TimeOfDay(hour: 14, minute: 0),
    endTime: TimeOfDay(hour: 14, minute: 40),
    label: '第5节',
  ),
  TimeSlot(
    period: 6,
    startTime: TimeOfDay(hour: 14, minute: 50),
    endTime: TimeOfDay(hour: 15, minute: 30),
    label: '第6节',
  ),
  TimeSlot(
    period: 7,
    startTime: TimeOfDay(hour: 15, minute: 45),
    endTime: TimeOfDay(hour: 16, minute: 25),
    label: '第7节',
  ),
  TimeSlot(
    period: 8,
    startTime: TimeOfDay(hour: 16, minute: 35),
    endTime: TimeOfDay(hour: 17, minute: 15),
    label: '第8节',
  ),
  TimeSlot(
    period: 9,
    startTime: TimeOfDay(hour: 18, minute: 10),
    endTime: TimeOfDay(hour: 18, minute: 50),
    label: '第9节',
  ),
  TimeSlot(
    period: 10,
    startTime: TimeOfDay(hour: 19, minute: 0),
    endTime: TimeOfDay(hour: 19, minute: 40),
    label: '第10节',
  ),
  TimeSlot(
    period: 11,
    startTime: TimeOfDay(hour: 19, minute: 50),
    endTime: TimeOfDay(hour: 20, minute: 30),
    label: '第11节',
  ),
  TimeSlot(
    period: 12,
    startTime: TimeOfDay(hour: 20, minute: 40),
    endTime: TimeOfDay(hour: 21, minute: 20),
    label: '第12节',
  ),
];

/// Saturday afternoon time slots (periods 5-8 start 1 hour earlier at 13:00)
const List<TimeSlot> saturdayAfternoonTimeSlots = [
  TimeSlot(
    period: 5,
    startTime: TimeOfDay(hour: 13, minute: 0),
    endTime: TimeOfDay(hour: 13, minute: 40),
    label: '第5节',
    isSaturdayAfternoon: true,
  ),
  TimeSlot(
    period: 6,
    startTime: TimeOfDay(hour: 13, minute: 50),
    endTime: TimeOfDay(hour: 14, minute: 30),
    label: '第6节',
    isSaturdayAfternoon: true,
  ),
  TimeSlot(
    period: 7,
    startTime: TimeOfDay(hour: 14, minute: 45),
    endTime: TimeOfDay(hour: 15, minute: 25),
    label: '第7节',
    isSaturdayAfternoon: true,
  ),
  TimeSlot(
    period: 8,
    startTime: TimeOfDay(hour: 15, minute: 35),
    endTime: TimeOfDay(hour: 16, minute: 15),
    label: '第8节',
    isSaturdayAfternoon: true,
  ),
];

/// University default time slots
const List<TimeSlot> universityTimeSlots = [
  TimeSlot(
    period: 0,
    startTime: TimeOfDay(hour: 8, minute: 0),
    endTime: TimeOfDay(hour: 8, minute: 45),
    label: '第1节',
  ),
  TimeSlot(
    period: 1,
    startTime: TimeOfDay(hour: 8, minute: 55),
    endTime: TimeOfDay(hour: 9, minute: 40),
    label: '第2节',
  ),
  TimeSlot(
    period: 2,
    startTime: TimeOfDay(hour: 10, minute: 0),
    endTime: TimeOfDay(hour: 10, minute: 45),
    label: '第3节',
  ),
  TimeSlot(
    period: 3,
    startTime: TimeOfDay(hour: 10, minute: 55),
    endTime: TimeOfDay(hour: 11, minute: 40),
    label: '第4节',
  ),
  TimeSlot(
    period: 4,
    startTime: TimeOfDay(hour: 14, minute: 0),
    endTime: TimeOfDay(hour: 14, minute: 45),
    label: '第5节',
  ),
  TimeSlot(
    period: 5,
    startTime: TimeOfDay(hour: 14, minute: 55),
    endTime: TimeOfDay(hour: 15, minute: 40),
    label: '第6节',
  ),
  TimeSlot(
    period: 6,
    startTime: TimeOfDay(hour: 16, minute: 0),
    endTime: TimeOfDay(hour: 16, minute: 45),
    label: '第7节',
  ),
  TimeSlot(
    period: 7,
    startTime: TimeOfDay(hour: 16, minute: 55),
    endTime: TimeOfDay(hour: 17, minute: 40),
    label: '第8节',
  ),
  TimeSlot(
    period: 8,
    startTime: TimeOfDay(hour: 19, minute: 0),
    endTime: TimeOfDay(hour: 19, minute: 45),
    label: '第9节',
  ),
  TimeSlot(
    period: 9,
    startTime: TimeOfDay(hour: 19, minute: 55),
    endTime: TimeOfDay(hour: 20, minute: 40),
    label: '第10节',
  ),
];

/// Get default time slots based on school type.
List<TimeSlot> getDefaultTimeSlots(SchoolType type) {
  switch (type) {
    case SchoolType.highSchool:
      return defaultTimeSlots;
    case SchoolType.university:
      return universityTimeSlots;
  }
}

/// Get the time slot for a given period and day.
/// Returns Saturday afternoon variant when [dayOfWeek] == 6 (Saturday) and period is 5-8.
TimeSlot getTimeSlot(int period, {int dayOfWeek = 1, SchoolType schoolType = SchoolType.highSchool}) {
  final slots = getDefaultTimeSlots(schoolType);

  if (schoolType == SchoolType.highSchool) {
    if (dayOfWeek == 6 && period >= 5 && period <= 8) {
      return saturdayAfternoonTimeSlots.firstWhere(
        (s) => s.period == period,
        orElse: () => slots.firstWhere((s) => s.period == period),
      );
    }
  }

  return slots.firstWhere(
    (s) => s.period == period,
    orElse: () => slots.first,
  );
}

/// Day names in Chinese (index 0 = Monday, 6 = Sunday)
const List<String> dayNamesChinese = [
  '周一',
  '周二',
  '周三',
  '周四',
  '周五',
  '周六',
  '周日',
];

/// Day names in Chinese (short)
const List<String> dayNamesShort = [
  '一',
  '二',
  '三',
  '四',
  '五',
  '六',
  '日',
];

/// Full day names
const List<String> dayNamesFull = [
  '星期一',
  '星期二',
  '星期三',
  '星期四',
  '星期五',
  '星期六',
  '星期日',
];

/// Period labels for display
const List<String> periodLabels = [
  '早自习',
  '第1节',
  '第2节',
  '第3节',
  '第4节',
  '第5节',
  '第6节',
  '第7节',
  '第8节',
  '第9节',
  '第10节',
  '第11节',
  '第12节',
];

/// Short period labels
const List<String> periodLabelsShort = [
  '早',
  '1',
  '2',
  '3',
  '4',
  '5',
  '6',
  '7',
  '8',
  '9',
  '10',
  '11',
  '12',
];

/// Course color palette - 10 nice, distinguishable colors
/// These work well on both light and dark backgrounds
const List<Color> courseColors = [
  Color(0xFF007AFF), // Blue
  Color(0xFFFF3B30), // Red
  Color(0xFF34C759), // Green
  Color(0xFFFF9500), // Orange
  Color(0xFFAF52DE), // Purple
  Color(0xFFFF2D55), // Pink
  Color(0xFF5AC8FA), // Light Blue
  Color(0xFF64D2FF), // Cyan
  Color(0xFFFFCC00), // Yellow
  Color(0xFFFF6482), // Coral
];

/// Dark mode course color palette (slightly brighter variants)
const List<Color> courseColorsDark = [
  Color(0xFF0A84FF), // Blue
  Color(0xFFFF453A), // Red
  Color(0xFF30D158), // Green
  Color(0xFFFF9F0A), // Orange
  Color(0xFFBF5AF2), // Purple
  Color(0xFFFF375F), // Pink
  Color(0xFF64D2FF), // Light Blue
  Color(0xFF70D7FF), // Cyan
  Color(0xFFFFD60A), // Yellow
  Color(0xFFFF6482), // Coral
];

/// Get course color by index (wraps around)
Color getCourseColor(int index, {bool isDark = false}) {
  final colors = isDark ? courseColorsDark : courseColors;
  return colors[index % colors.length];
}

/// Get a semi-transparent version of a course color for backgrounds
Color getCourseColorBackground(int index, {bool isDark = false, double opacity = 0.12}) {
  final color = getCourseColor(index, isDark: isDark);
  return color.withOpacity(opacity);
}

/// Section names for a typical schedule
const List<String> sectionNames = [
  '上午',
  '下午',
  '晚上',
];

/// Section time ranges (for display)
const List<String> sectionTimeRanges = [
  '07:05 - 12:00',
  '13:00 - 17:15',
  '18:10 - 21:20',
];
