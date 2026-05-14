import 'dart:io';
import 'package:flutter/services.dart';
import 'package:device_calendar/device_calendar.dart';
import 'log_service.dart';

/// 原生日历服务
/// - Android: 通过 MethodChannel 调用 ContentResolver（绕过国产ROM兼容性问题）
/// - iOS: 通过 device_calendar Dart API 调用 EventKit（不需要写 Swift）
class CalendarNativeService {
  CalendarNativeService._();
  static final CalendarNativeService instance = CalendarNativeService._();

  static const _channel = MethodChannel('com.sno.buwang_schedule/calendar');
  static const _tag = '[CalendarNative]';

  // iOS 用 device_calendar 插件
  final DeviceCalendarPlugin _iosPlugin = DeviceCalendarPlugin();

  /// 列出所有日历账户
  Future<List<Map<String, dynamic>>> listCalendars() async {
    if (Platform.isIOS) return _listCalendarsIOS();
    return _listCalendarsAndroid();
  }

  /// 删除所有日历中标题或描述包含关键词的事件
  Future<Map<String, dynamic>> deleteEventsByKeyword(String keyword) async {
    if (Platform.isIOS) return _deleteEventsByKeywordIOS(keyword);
    return _deleteEventsByKeywordAndroid(keyword);
  }

  /// 删除指定日历下的所有事件
  Future<Map<String, dynamic>> deleteAllEventsInCalendar(int calendarId) async {
    if (Platform.isIOS) return _deleteAllEventsInCalendarIOS(calendarId.toString());
    return _deleteAllEventsInCalendarAndroid(calendarId);
  }

  // ════════════════════════════════════════════
  //  iOS 实现（device_calendar Dart API）
  // ════════════════════════════════════════════

  Future<List<Map<String, dynamic>>> _listCalendarsIOS() async {
    final log = LogService.instance;
    try {
      final result = await _iosPlugin.retrieveCalendars();
      final calendars = result.isSuccess ? (result.data ?? <Calendar>[]) : <Calendar>[];
      log.i('$_tag [iOS] listCalendars: 找到 ${calendars.length} 个日历');
      for (final cal in calendars) {
        log.i('  ${cal.id}: ${cal.name} (${cal.accountName})');
      }
      return calendars.map((c) => {
        'id': int.tryParse(c.id ?? '0') ?? 0,
        'name': c.name ?? '',
        'accountName': c.accountName ?? '',
        'accountType': c.accountType ?? '',
      }).toList();
    } catch (e) {
      log.e('$_tag [iOS] listCalendars 失败: $e');
      return [];
    }
  }

  Future<Map<String, dynamic>> _deleteEventsByKeywordIOS(String keyword) async {
    final log = LogService.instance;
    log.i('$_tag [iOS] deleteEventsByKeyword: keyword=$keyword');
    int totalDeleted = 0;
    final logMessages = <String>[];

    try {
      final calendarsResult = await _iosPlugin.retrieveCalendars();
      final calendars = calendarsResult.isSuccess
          ? (calendarsResult.data ?? <Calendar>[]) : <Calendar>[];

      for (final cal in calendars) {
        if (cal.id == null || cal.isReadOnly == true) continue;

        final eventsResult = await _iosPlugin.retrieveEvents(
          cal.id!,
          RetrieveEventsParams(
            startDate: DateTime(2024, 1, 1),
            endDate: DateTime(2028, 12, 31),
          ),
        );

        if (!eventsResult.isSuccess || eventsResult.data == null) continue;

        for (final event in eventsResult.data!) {
          final title = event.title ?? '';
          final desc = event.description ?? '';
          if (title.contains(keyword) || desc.contains(keyword)) {
            try {
              final deleteResult = await _iosPlugin.deleteEvent(cal.id!, event.eventId);
              if (deleteResult?.isSuccess == true) {
                totalDeleted++;
                logMessages.add('✅ 已删: $title (日历: ${cal.name})');
              } else {
                logMessages.add('❌ 未删: $title (日历: ${cal.name})');
              }
            } catch (e) {
              logMessages.add('❌ 异常: $title → $e');
            }
          }
        }
      }
    } catch (e) {
      logMessages.add('查询异常: $e');
    }

    logMessages.insert(0, '通过 EventKit 删除含「$keyword」的事件');
    logMessages.add('共删除 $totalDeleted 个事件');
    log.i('$_tag [iOS] deleteEventsByKeyword 结果: $totalDeleted 个');
    return {'deleted': totalDeleted, 'log': logMessages.join('\n')};
  }

  Future<Map<String, dynamic>> _deleteAllEventsInCalendarIOS(String calendarId) async {
    final log = LogService.instance;
    log.i('$_tag [iOS] deleteAllEventsInCalendar: calendarId=$calendarId');
    int totalDeleted = 0;
    final logMessages = <String>[];

    try {
      final eventsResult = await _iosPlugin.retrieveEvents(
        calendarId,
        RetrieveEventsParams(
          startDate: DateTime(2024, 1, 1),
          endDate: DateTime(2028, 12, 31),
        ),
      );

      if (eventsResult.isSuccess && eventsResult.data != null) {
        for (final event in eventsResult.data!) {
          try {
            final deleteResult = await _iosPlugin.deleteEvent(calendarId, event.eventId);
            if (deleteResult?.isSuccess == true) totalDeleted++;
          } catch (_) {}
        }
      }
      logMessages.add('删除日历 $calendarId 下的 $totalDeleted 个事件');
    } catch (e) {
      logMessages.add('删除异常: $e');
    }

    return {'deleted': totalDeleted, 'log': logMessages.join('\n')};
  }

  // ════════════════════════════════════════════
  //  Android 实现（原有 MethodChannel 逻辑，完全不变）
  // ════════════════════════════════════════════

  Future<List<Map<String, dynamic>>> _listCalendarsAndroid() async {
    final log = LogService.instance;
    try {
      final result = await _channel.invokeMethod('listCalendars');
      final calendars = (result as List).map((e) => Map<String, dynamic>.from(e)).toList();
      log.i('$_tag listCalendars: 找到 ${calendars.length} 个日历');
      for (final cal in calendars) {
        log.i('  ${cal['id']}: ${cal['name']} (${cal['accountName']})');
      }
      return calendars;
    } catch (e) {
      log.e('$_tag listCalendars 失败: $e');
      return [];
    }
  }

  Future<Map<String, dynamic>> _deleteEventsByKeywordAndroid(String keyword) async {
    final log = LogService.instance;
    log.i('$_tag deleteEventsByKeyword: keyword=$keyword');
    try {
      final result = await _channel.invokeMethod('deleteEventsByKeyword', {
        'keyword': keyword,
      });
      final map = Map<String, dynamic>.from(result);
      log.i('$_tag deleteEventsByKeyword 结果: ${map['log']}');
      return map;
    } catch (e) {
      log.e('$_tag deleteEventsByKeyword 失败: $e');
      return {'deleted': 0, 'log': '调用失败: $e'};
    }
  }

  Future<Map<String, dynamic>> _deleteAllEventsInCalendarAndroid(int calendarId) async {
    final log = LogService.instance;
    log.i('$_tag deleteAllEventsInCalendar: calendarId=$calendarId');
    try {
      final result = await _channel.invokeMethod('deleteAllEventsInCalendar', {
        'calendarId': calendarId,
      });
      final map = Map<String, dynamic>.from(result);
      log.i('$_tag deleteAllEventsInCalendar 结果: ${map['log']}');
      return map;
    } catch (e) {
      log.e('$_tag deleteAllEventsInCalendar 失败: $e');
      return {'deleted': 0, 'log': '调用失败: $e'};
    }
  }
}
