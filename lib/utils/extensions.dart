import 'package:flutter/material.dart';

import 'constants.dart';

/// String extensions
extension StringExtensions on String {
  /// Pad left with given character to reach total width
  String padLeftCustom(int width, [String padding = ' ']) {
    if (length >= width) return this;
    return '${padding * (width - length)}$this';
  }

  /// Pad right with given character to reach total width
  String padRightCustom(int width, [String padding = ' ']) {
    if (length >= width) return this;
    return '$this${padding * (width - length)}';
  }

  /// Pad left with zeros to reach total width
  String padLeftZero(int width) => padLeft(width, '0');

  /// Try parsing this string as a TimeOfDay (format: "HH:mm" or "H:mm")
  TimeOfDay? toTimeOfDay() {
    try {
      final parts = split(':');
      if (parts.length != 2) return null;
      final hour = int.parse(parts[0]);
      final minute = int.parse(parts[1]);
      if (hour < 0 || hour > 23 || minute < 0 || minute > 59) return null;
      return TimeOfDay(hour: hour, minute: minute);
    } catch (_) {
      return null;
    }
  }

  /// Try parsing this string as a DateTime (format: "yyyy-MM-dd" or "yyyy-MM-dd HH:mm")
  DateTime? toDateTime() {
    try {
      return DateTime.parse(this);
    } catch (_) {
      return null;
    }
  }

  /// Try parsing this string as a date-only DateTime (format: "yyyy-MM-dd")
  DateTime? toDate() {
    try {
      final parts = split('-');
      if (parts.length < 3) return null;
      return DateTime(
        int.parse(parts[0]),
        int.parse(parts[1]),
        int.parse(parts[2]),
      );
    } catch (_) {
      return null;
    }
  }

  /// Truncate string to maxLength, appending ellipsis if needed
  String truncate(int maxLength, {String ellipsis = '…'}) {
    if (length <= maxLength) return this;
    return '${substring(0, maxLength - ellipsis.length)}$ellipsis';
  }

  /// Check if string is a valid number
  bool get isNumeric {
    return double.tryParse(this) != null;
  }

  /// Check if string is a valid integer
  bool get isInteger {
    return int.tryParse(this) != null;
  }

  /// Remove all whitespace
  String get removeWhitespace {
    return replaceAll(RegExp(r'\s+'), '');
  }
}

/// TimeOfDay extensions
extension TimeOfDayExtensions on TimeOfDay {
  /// Format as "HH:mm"
  String get formatted {
    final h = hour.toString().padLeft(2, '0');
    final m = minute.toString().padLeft(2, '0');
    return '$h:$m';
  }

  /// Format as "H:mm" (no leading zero for hour)
  String get formattedShort {
    final m = minute.toString().padLeft(2, '0');
    return '$hour:$m';
  }

  /// Format as "上午/下午 H:mm"
  String get formatted12 {
    final period = hour < 12 ? '上午' : '下午';
    final h = hour <= 12 ? hour : hour - 12;
    final m = minute.toString().padLeft(2, '0');
    return '$period ${h == 0 ? 12 : h}:$m';
  }

  /// Total minutes since midnight
  int get totalMinutes => hour * 60 + minute;

  /// Difference in minutes from another TimeOfDay
  int differenceMinutes(TimeOfDay other) {
    return totalMinutes - other.totalMinutes;
  }

  /// Whether this time is before the other
  bool isBefore(TimeOfDay other) {
    return totalMinutes < other.totalMinutes;
  }

  /// Whether this time is after the other
  bool isAfter(TimeOfDay other) {
    return totalMinutes > other.totalMinutes;
  }

  /// Whether this time is between [start] and [end] (inclusive)
  bool isBetween(TimeOfDay start, TimeOfDay end) {
    return totalMinutes >= start.totalMinutes &&
        totalMinutes <= end.totalMinutes;
  }

  /// Add minutes to this time (wraps around 24 hours)
  TimeOfDay addMinutes(int minutes) {
    final total = totalMinutes + minutes;
    final wrapped = total % (24 * 60);
    return TimeOfDay(hour: wrapped ~/ 60, minute: wrapped % 60);
  }

  /// Subtract minutes from this time (wraps around 24 hours)
  TimeOfDay subtractMinutes(int minutes) {
    final total = totalMinutes - minutes;
    final wrapped = total % (24 * 60);
    return TimeOfDay(
      hour: wrapped < 0 ? (wrapped + 24 * 60) ~/ 60 : wrapped ~/ 60,
      minute: wrapped < 0 ? (wrapped + 24 * 60) % 60 : wrapped % 60,
    );
  }
}

/// DateTime extensions
extension DateTimeExtensions on DateTime {
  /// Get the Monday of the current week
  DateTime get weekStart {
    final daysFromMonday = weekday - DateTime.monday;
    return subtract(Duration(days: daysFromMonday));
  }

  /// Get the Sunday of the current week
  DateTime get weekEnd {
    final daysToSunday = DateTime.sunday - weekday;
    return add(Duration(days: daysToSunday));
  }

  /// Whether this date is today
  bool get isToday {
    final now = DateTime.now();
    return year == now.year && month == now.month && day == now.day;
  }

  /// Whether this date is tomorrow
  bool get isTomorrow {
    final tomorrow = DateTime.now().add(const Duration(days: 1));
    return year == tomorrow.year &&
        month == tomorrow.month &&
        day == tomorrow.day;
  }

  /// Whether this date is yesterday
  bool get isYesterday {
    final yesterday = DateTime.now().subtract(const Duration(days: 1));
    return year == yesterday.year &&
        month == yesterday.month &&
        day == yesterday.day;
  }

  /// Whether this date is on the weekend (Saturday or Sunday)
  bool get isWeekend {
    return weekday == DateTime.saturday || weekday == DateTime.sunday;
  }

  /// Get day of week as Chinese string (周一, 周二, ...)
  String get dayOfWeekChinese {
    return dayNamesChinese[weekday - 1];
  }

  /// Get day of week as short Chinese string (一, 二, ...)
  String get dayOfWeekShort {
    return dayNamesShort[weekday - 1];
  }

  /// Format as "yyyy-MM-dd"
  String get dateFormatted {
    return '${year.toString()}-'
        '${month.toString().padLeft(2, '0')}-'
        '${day.toString().padLeft(2, '0')}';
  }

  /// Format as "MM月dd日"
  String get dateFormattedChinese {
    return '${month}月$day日';
  }

  /// Format as "yyyy年MM月dd日"
  String get dateFormattedFullChinese {
    return '${year}年${month}月$day日';
  }

  /// Format as "MM/dd"
  String get dateFormattedShort {
    return '${month.toString().padLeft(2, '0')}/${day.toString().padLeft(2, '0')}';
  }

  /// Calculate week number relative to [semesterStart]
  /// Returns 1-based week number
  int weekNumber(DateTime semesterStart) {
    final startDate = DateTime(
      semesterStart.year,
      semesterStart.month,
      semesterStart.day,
    );
    final currentDate = DateTime(year, month, day);
    final difference = currentDate.difference(startDate).inDays;
    if (difference < 0) return 0;
    return (difference / 7).floor() + 1;
  }

  /// Calculate days difference from [other] (positive if this is after other)
  int daysDifference(DateTime other) {
    final thisDate = DateTime(year, month, day);
    final otherDate = DateTime(other.year, other.month, other.day);
    return thisDate.difference(otherDate).inDays;
  }

  /// Start of day (00:00:00)
  DateTime get startOfDay {
    return DateTime(year, month, day);
  }

  /// End of day (23:59:59.999)
  DateTime get endOfDay {
    return DateTime(year, month, day, 23, 59, 59, 999);
  }

  /// Whether this is the same calendar date as [other]
  bool isSameDate(DateTime other) {
    return year == other.year && month == other.month && day == other.day;
  }

  /// Get the display string for a relative date
  String get relativeDateString {
    if (isToday) return '今天';
    if (isTomorrow) return '明天';
    if (isYesterday) return '昨天';

    final now = DateTime.now();
    final diff = daysDifference(now);
    if (diff > 0 && diff <= 6) {
      return dayOfWeekChinese;
    }
    return dateFormattedChinese;
  }
}

/// Duration extensions
extension DurationExtensions on Duration {
  /// Format duration as "HH:mm:ss"
  String get formatted {
    final hours = inHours;
    final minutes = inMinutes.remainder(60);
    final seconds = inSeconds.remainder(60);
    return '${hours.toString().padLeft(2, '0')}:'
        '${minutes.toString().padLeft(2, '0')}:'
        '${seconds.toString().padLeft(2, '0')}';
  }

  /// Format duration as "X小时Y分钟" or "Y分钟"
  String get formattedChinese {
    if (inHours > 0) {
      final minutes = inMinutes.remainder(60);
      if (minutes > 0) {
        return '$inHours小时$minutes分钟';
      }
      return '$inHours小时';
    }
    return '$inMinutes分钟';
  }

  /// Format duration as "Xh Ym" or "Ym"
  String get formattedShort {
    if (inHours > 0) {
      final minutes = inMinutes.remainder(60);
      if (minutes > 0) {
        return '${inHours}h ${minutes}m';
      }
      return '${inHours}h';
    }
    return '${inMinutes}m';
  }
}

/// BuildContext extensions for convenience
extension BuildContextExtensions on BuildContext {
  /// Get the current Theme
  ThemeData get theme => Theme.of(this);

  /// Get the current ColorScheme
  ColorScheme get colorScheme => theme.colorScheme;

  /// Get the current TextTheme
  TextTheme get textTheme => theme.textTheme;

  /// Get the current MediaQuery
  MediaQueryData get mediaQuery => MediaQuery.of(this);

  /// Get screen size
  Size get screenSize => mediaQuery.size;

  /// Get screen width
  double get screenWidth => screenSize.width;

  /// Get screen height
  double get screenHeight => screenSize.height;

  /// Get safe area padding
  EdgeInsets get padding => mediaQuery.padding;

  /// Get top safe area height
  double get topPadding => padding.top;

  /// Get bottom safe area height
  double get bottomPadding => padding.bottom;

  /// Check if dark mode is active
  bool get isDarkMode => theme.brightness == Brightness.dark;

  /// Get device pixel ratio
  double get devicePixelRatio => mediaQuery.devicePixelRatio;

  /// Show a simple snackbar
  ScaffoldFeatureController<SnackBar, SnackBarClosedReason> showSnackBar(
    String message, {
    Duration duration = const Duration(seconds: 2),
    SnackBarAction? action,
  }) {
    return ScaffoldMessenger.of(this).showSnackBar(
      SnackBar(
        content: Text(message),
        duration: duration,
        action: action,
      ),
    );
  }

  /// Show a success snackbar
  void showSuccessSnackBar(String message) {
    showSnackBar(
      message,
      duration: const Duration(seconds: 2),
    );
  }

  /// Show an error snackbar
  void showErrorSnackBar(String message) {
    ScaffoldMessenger.of(this).showSnackBar(
      SnackBar(
        content: Text(message),
        backgroundColor: colorScheme.error,
        duration: const Duration(seconds: 3),
      ),
    );
  }

  /// Hide keyboard
  void hideKeyboard() {
    FocusScope.of(this).unfocus();
  }
}
