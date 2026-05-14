import 'dart:io';
import 'package:flutter/foundation.dart';
import 'package:device_calendar/device_calendar.dart';
import 'package:permission_handler/permission_handler.dart';
import 'package:timezone/timezone.dart' as tz;
import 'package:timezone/data/latest.dart' as tz;

import '../models/course.dart';
import '../utils/constants.dart';
import '../models/app_mode.dart';
import 'database_service.dart';
import 'log_service.dart';
import 'calendar_native_service.dart';

/// 静默写入系统日历服务
/// 直接通过 CalendarProvider 写入，不跳转任何 App
class CalendarSyncService {
  CalendarSyncService._();
  static final CalendarSyncService instance = CalendarSyncService._();

  final DeviceCalendarPlugin _plugin = DeviceCalendarPlugin();
  final DatabaseService _db = DatabaseService.instance;

  static const String _tag = '[CalendarSync]';
  static const String _calendarName = '不忘课表';
  static const String _settingKeyCalendarId = 'synced_calendar_id';
  static const String _settingKeySyncedWeeks = 'synced_weeks';
  static const String _settingKeyLastSync = 'last_sync_time';

  bool _tzInitialized = false;

  /// 确保 timezone 数据已初始化
  void _ensureTimezone() {
    if (!_tzInitialized) {
      tz.initializeTimeZones();
      _tzInitialized = true;
    }
  }

  /// 请求日历读写权限
  Future<bool> requestPermissions() async {
    if (Platform.isIOS) {
      // iOS: calendarFullAccess 在 iOS 17+ 才有，低版本用 calendarWriteOnly
      // permission_handler 会自动处理版本差异
      final status = await Permission.calendarFullAccess.request();
      if (status.isGranted) return true;
      // 降级尝试
      final fallback = await Permission.calendarWriteOnly.request();
      return fallback.isGranted;
    }
    // Android
    final status = await Permission.calendarFullAccess.request();
    return status.isGranted;
  }

  /// 检查权限
  Future<bool> hasPermissions() async {
    if (Platform.isIOS) {
      final full = await Permission.calendarFullAccess.isGranted;
      if (full) return true;
      return await Permission.calendarWriteOnly.isGranted;
    }
    return await Permission.calendarFullAccess.isGranted;
  }

  /// 获取或创建"不忘课表"专属日历
  /// 策略：缓存优先 → 放宽匹配 → 才创建
  Future<String?> _getOrCreateCalendar() async {
    final log = LogService.instance;
    log.i('$_tag _getOrCreateCalendar: start');

    // ① 优先读缓存的 calendarId
    final storedId = await _db.getSetting(_settingKeyCalendarId);
    if (storedId != null && storedId.isNotEmpty) {
      final checkResult = await _plugin.retrieveCalendars();
      final calendars = checkResult.isSuccess ? (checkResult.data ?? []) : <Calendar>[];
      final hit = calendars.where((c) => c.id == storedId).firstOrNull;
      if (hit != null) {
        log.i('$_tag 命中缓存 calendarId=$storedId, name=${hit.name}, account=${hit.accountName}');
        return storedId;
      }
      log.w('$_tag 缓存 calendarId=$storedId 已失效，重新定位');
    }

    // ② 扫描所有日历
    final calendarsResult = await _plugin.retrieveCalendars();
    final allCalendars = calendarsResult.isSuccess ? (calendarsResult.data ?? <Calendar>[]) : <Calendar>[];
    log.i('$_tag 扫描到 ${allCalendars.length} 个日历');

    // ③ 放宽匹配：名字/accountName/displayName 包含关键词
    final matchingCalendars = allCalendars.where((c) {
      final n = (c.name ?? '').toLowerCase();
      final an = (c.accountName ?? '').toLowerCase();
      return n.contains('不忘') || n.contains('课表') ||
             an.contains('不忘') || an.contains('课表') ||
             n == _calendarName.toLowerCase() || an == _calendarName.toLowerCase();
    }).toList();

    log.i('$_tag 宽松匹配找到 ${matchingCalendars.length} 个候选');
    for (final c in matchingCalendars) {
      log.i('  候选: id=${c.id}, name=${c.name}, account=${c.accountName}, readOnly=${c.isReadOnly}');
    }

    if (matchingCalendars.isNotEmpty) {
      // 优先选可写的
      final picked = matchingCalendars.firstWhere(
        (c) => c.isReadOnly != true,
        orElse: () => matchingCalendars.first,
      );
      if (picked.id != null) {
        await _db.setSetting(_settingKeyCalendarId, picked.id!);
        log.i('$_tag 复用日历: ${picked.id} / ${picked.name}');
        return picked.id;
      }
    }

    // ④ 打印全部日历供调试
    for (final c in allCalendars) {
      log.i('  全部: id=${c.id}, name=${c.name}, account=${c.accountName}, type=${c.accountType}');
    }

    // ⑤ 真的没有才创建
    log.i('$_tag 没有找到匹配日历，创建新的');
    final result = await _plugin.createCalendar(
      _calendarName,
      localAccountName: _calendarName,
    );

    if (result.isSuccess && result.data != null) {
      await _db.setSetting(_settingKeyCalendarId, result.data!);
      log.i('$_tag 创建成功: ${result.data}');
      return result.data;
    }

    log.e('$_tag 创建日历失败: ${result.errors}');
    return null;
  }

  /// 一键同步整学期课表到系统日历
  ///
  /// [semesterStart] 开学第一周的周一日期
  /// [totalWeeks] 总周数（默认20周）
  /// [reminderMinutes] 提前提醒分钟数（默认10分钟）
  ///
  /// 返回成功同步的课程数
  Future<SyncResult> syncAllCourses({
    required DateTime semesterStart,
    int totalWeeks = 20,
    int reminderMinutes = 10,
  }) async {
    final log = LogService.instance;
    log.i('$_tag syncAllCourses: 开始同步，开学日期=$semesterStart, 周数=$totalWeeks');

    _ensureTimezone();

    // 检查权限
    if (!await hasPermissions()) {
      final granted = await requestPermissions();
      if (!granted) {
        log.e('$_tag 未授予日历权限');
        return SyncResult.error('未授予日历权限');
      }
    }

    // 获取日历ID
    final calendarId = await _getOrCreateCalendar();
    if (calendarId == null) {
      log.e('$_tag 无法创建或找到日历');
      return SyncResult.error('无法创建或找到日历');
    }
    log.i('$_tag 使用日历ID: $calendarId');

    // 获取所有课程
    final courses = await _db.getAllCourses();
    if (courses.isEmpty) {
      log.e('$_tag 没有课程数据');
      return SyncResult.error('没有课程数据，请先导入课表');
    }
    log.i('$_tag 共 ${courses.length} 个课程，将创建 ${courses.length * totalWeeks} 个事件');

    // 获取用户角色和学校类型
    final roleStr = await _db.getSetting(AppConstants.keyUserRole);
    final userRole = UserRole.values[int.tryParse(roleStr ?? '0') ?? 0];
    final schoolStr = await _db.getSetting(AppConstants.keySchoolType);
    final schoolType = SchoolType.values[int.tryParse(schoolStr ?? '0') ?? 0];

    // 先清除旧的同步数据
    await clearSyncedEvents(calendarId);

    int successCount = 0;
    int failCount = 0;
    final location = tz.local;

    // 逐周逐课程写入
    for (int week = 0; week < totalWeeks; week++) {
      for (final course in courses) {
        // 计算这一周该课程的具体日期
        // semesterStart 是第1周的周一
        final eventDate = semesterStart.add(Duration(
          days: week * 7 + (course.dayOfWeek - 1), // dayOfWeek: 1=Mon
        ));

        // 获取时间段
        final slot = getTimeSlot(
          course.period,
          dayOfWeek: course.dayOfWeek,
          schoolType: schoolType,
        );

        final startDateTime = DateTime(
          eventDate.year, eventDate.month, eventDate.day,
          slot.startTime.hour, slot.startTime.minute,
        );
        final endDateTime = DateTime(
          eventDate.year, eventDate.month, eventDate.day,
          slot.endTime.hour, slot.endTime.minute,
        );

        // 构建事件标题和描述（根据角色）
        final title = _buildEventTitle(course, userRole, slot);
        final description = _buildEventDescription(course, userRole, week + 1);
        final eventLocation = course.location ?? '';

        // 创建日历事件
        final event = Event(
          calendarId,
          title: title,
          start: tz.TZDateTime.from(startDateTime, location),
          end: tz.TZDateTime.from(endDateTime, location),
          description: description,
          location: eventLocation,
          reminders: [Reminder(minutes: reminderMinutes)],
        );

        final result = await _plugin.createOrUpdateEvent(event);
        if (result?.isSuccess == true) {
          successCount++;
        } else {
          failCount++;
        }
      }
    }

    // 记录同步信息
    await _db.setSetting(_settingKeyLastSync, DateTime.now().toIso8601String());
    await _db.setSetting(_settingKeySyncedWeeks, totalWeeks.toString());

    if (failCount == 0) {
      return SyncResult.success(successCount, totalWeeks);
    } else {
      return SyncResult.partial(successCount, failCount, totalWeeks);
    }
  }

  /// 清除已同步的日历事件
  Future<int> clearSyncedEvents(String calendarId) async {
    int deletedCount = 0;
    try {
      final events = await _plugin.retrieveEvents(
        calendarId,
        RetrieveEventsParams(
          startDate: DateTime(2024, 1, 1),
          endDate: DateTime(2028, 12, 31),
        ),
      );

      if (events.isSuccess && events.data != null) {
        for (final event in events.data!) {
          if (event.title != null && _isOurEvent(event.title!, description: event.description)) {
            final result = await _plugin.deleteEvent(calendarId, event.eventId);
            if (result?.isSuccess == true) deletedCount++;
          }
        }
      }
    } catch (e) {
      debugPrint('清除日历事件异常: $e');
    }
    return deletedCount;
  }

  /// 判断是否是我们写入的事件（通过标题格式+描述标签双重判断）
  bool _isOurEvent(String title, {String? description}) {
    // 描述中有我们独有的标签
    if (description != null && description.contains('【不忘课表】')) return true;
    // 标题格式: "第X节: XXX"
    return title.contains('第') && title.contains('节') && title.contains(':');
  }

  /// 根据角色构建事件标题
  String _buildEventTitle(Course course, UserRole role, TimeSlot slot) {
    final periodLabel = slot.label;

    if (role == UserRole.teacher) {
      // 教师版: "第1节: 高一1班 - 数学"
      final className = course.name;
      final subject = course.subject ?? '';
      if (subject.isNotEmpty) {
        return '$periodLabel: $className - $subject';
      }
      return '$periodLabel: $className';
    } else {
      // 学生版: "第1节: 数学 - 张老师"
      final subject = course.subject ?? course.name;
      final teacher = course.teacher ?? '';
      if (teacher.isNotEmpty) {
        return '$periodLabel: $subject - $teacher';
      }
      return '$periodLabel: $subject';
    }
  }

  /// 构建事件描述
  String _buildEventDescription(Course course, UserRole role, int week) {
    final parts = <String>[
      '【不忘课表】第${week}周',
      '',
      if (course.subject != null) '科目: ${course.subject}',
      '班级: ${course.name}',
      if (course.teacher != null) '教师: ${course.teacher}',
      if (course.location != null) '教室: ${course.location}',
    ];
    return parts.join('\n');
  }

  /// 一键清除所有由本App写入的日历事件（原生模式）
  Future<SyncResult> clearAllEvents() async {
    if (!await hasPermissions()) {
      final granted = await requestPermissions();
      if (!granted) return SyncResult.error('未授予日历权限');
    }

    try {
      // 用原生删除含"不忘课表"标签的事件（我们的描述里有【不忘课表】）
      final result = await CalendarNativeService.instance.deleteEventsByKeyword('不忘课表');
      final deleted = result['deleted'] ?? 0;

      await _db.setSetting(_settingKeyLastSync, '');
      await _db.setSetting(_settingKeySyncedWeeks, '');
      await _db.setSetting(_settingKeyCalendarId, '');

      if (deleted > 0) {
        return SyncResult._(success: true, customMessage: '已清除 $deleted 个课表日历事件');
      } else {
        return SyncResult._(success: true, customMessage: '日历中没有找到课表事件');
      }
    } catch (e) {
      return SyncResult.error('清除失败: $e');
    }
  }

  /// 获取上次同步信息
  Future<SyncInfo> getSyncInfo() async {
    final lastSync = await _db.getSetting(_settingKeyLastSync);
    final weeks = await _db.getSetting(_settingKeySyncedWeeks);
    final calendarId = await _db.getSetting(_settingKeyCalendarId);

    return SyncInfo(
      lastSyncTime: lastSync != null ? DateTime.tryParse(lastSync) : null,
      syncedWeeks: int.tryParse(weeks ?? '0') ?? 0,
      calendarId: calendarId,
      hasCalendar: calendarId != null,
    );
  }

  /// 深度清理：用原生 ContentResolver 直接查询和删除
  Future<SyncResult> deepCleanCalendar() async {
    final log = LogService.instance;
    log.i('$_tag deepCleanCalendar: 开始深度清理（原生模式）');

    if (!await hasPermissions()) {
      final granted = await requestPermissions();
      if (!granted) {
        log.e('$_tag 未授予日历权限');
        return SyncResult.error('未授予日历权限');
      }
    }

    final List<String> debugLog = [];
    try {
      // ① 先用原生列出所有日历
      final nativeCalendars = await CalendarNativeService.instance.listCalendars();
      debugLog.add('原生扫描到 ${nativeCalendars.length} 个日历账户');
      for (final cal in nativeCalendars) {
        debugLog.add('  ${cal['id']}: ${cal['name']} (账户: ${cal['accountName']}, 类型: ${cal['accountType']})');
      }

      // ② 用原生删除含"课表"的事件
      final deleteResult = await CalendarNativeService.instance.deleteEventsByKeyword('课表');
      final deleted = deleteResult['deleted'] ?? 0;
      final nativeLog = deleteResult['log'] ?? '';
      debugLog.add('');
      debugLog.add('──── 原生删除日志 ────');
      debugLog.add(nativeLog);

      // ③ 再用原生删除含"不忘"的事件
      final deleteResult2 = await CalendarNativeService.instance.deleteEventsByKeyword('不忘');
      final deleted2 = deleteResult2['deleted'] ?? 0;
      final nativeLog2 = deleteResult2['log'] ?? '';
      debugLog.add('');
      debugLog.add('──── 关键词「不忘」删除日志 ────');
      debugLog.add(nativeLog2);

      final totalDeleted = deleted + deleted2;

      // 清除本地记录
      await _db.setSetting(_settingKeyLastSync, '');
      await _db.setSetting(_settingKeySyncedWeeks, '');
      await _db.setSetting(_settingKeyCalendarId, '');

      final msg = StringBuffer();
      msg.writeln('深度清理完成（原生模式）');
      msg.writeln('共删除 $totalDeleted 个事件');
      msg.writeln();
      msg.writeln('──── 详细日志 ────');
      msg.write(debugLog.join('\n'));
      log.i('$_tag 深度清理完成: 删除$totalDeleted 个事件');
      return SyncResult._(success: true, customMessage: msg.toString());
    } catch (e) {
      log.e('$_tag 深度清理异常: $e');
      return SyncResult.error('深度清理失败: $e\n\n${debugLog.join('\n')}');
    }
  }
}

/// 同步结果
class SyncResult {
  final bool success;
  final String? error;
  final int syncedCount;
  final int failedCount;
  final int totalWeeks;
  final String? _customMessage;

  SyncResult._({
    required this.success,
    this.error,
    this.syncedCount = 0,
    this.failedCount = 0,
    this.totalWeeks = 0,
    String? customMessage,
  }) : _customMessage = customMessage;

  factory SyncResult.success(int count, int weeks) =>
      SyncResult._(success: true, syncedCount: count, totalWeeks: weeks);

  factory SyncResult.partial(int success, int fail, int weeks) =>
      SyncResult._(
        success: true,
        syncedCount: success,
        failedCount: fail,
        totalWeeks: weeks,
      );

  factory SyncResult.error(String msg) =>
      SyncResult._(success: false, error: msg);

  String get message {
    if (_customMessage != null) return _customMessage!;
    if (!success) return '同步失败: $error';
    if (failedCount > 0) {
      return '部分同步成功: ${syncedCount}节成功, ${failedCount}节失败 (共${totalWeeks}周)';
    }
    return '同步成功! 已将 ${syncedCount} 节课写入系统日历 (共${totalWeeks}周)';
  }
}

/// 同步信息
class SyncInfo {
  final DateTime? lastSyncTime;
  final int syncedWeeks;
  final String? calendarId;
  final bool hasCalendar;

  SyncInfo({
    this.lastSyncTime,
    this.syncedWeeks = 0,
    this.calendarId,
    this.hasCalendar = false,
  });

  String get displayText {
    if (lastSyncTime == null) return '尚未同步';
    return '已同步${syncedWeeks}周 · ${_formatTime(lastSyncTime!)}';
  }

  String _formatTime(DateTime dt) {
    return '${dt.month}/${dt.day} ${dt.hour}:${dt.minute.toString().padLeft(2, '0')}';
  }
}
