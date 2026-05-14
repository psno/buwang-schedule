import 'dart:io';
import 'package:flutter/services.dart';

import 'notification_service.dart';

/// 闹钟服务
/// - Android: 通过 MethodChannel 调用原生 AlarmClock API，静默设置系统闹钟
/// - iOS: 无系统闹钟 API，用本地通知替代（明确告知用户差异）
class AlarmService {
  AlarmService._();
  static final AlarmService instance = AlarmService._();

  static const _channel = MethodChannel('com.sno.buwang_schedule/alarm');

  /// 设置闹钟/提醒
  ///
  /// [hour] 小时 (0-23)
  /// [minute] 分钟 (0-59)
  /// [label] 闹钟标签
  /// [skipUi] 是否跳过确认界面（仅 Android 生效）
  ///
  /// Android: 直接设置系统闹钟
  /// iOS: 用本地通知替代（iOS 不支持第三方设置系统闹钟）
  Future<AlarmResult> setAlarm({
    required int hour,
    required int minute,
    required String label,
    bool skipUi = true,
  }) async {
    // ─── iOS: 本地通知替代 ───
    if (Platform.isIOS) {
      return _setAlarmIOS(hour: hour, minute: minute, label: label);
    }

    // ─── Android: 系统闹钟（保持原有逻辑）───
    try {
      final result = await _channel.invokeMethod('setAlarm', {
        'hour': hour,
        'minute': minute,
        'label': label,
        'skipUi': skipUi,
      });
      if (result == true) {
        return AlarmResult.success(
          '闹钟已设置: ${hour.toString().padLeft(2, '0')}:${minute.toString().padLeft(2, '0')} $label',
        );
      }
      return AlarmResult.error('设置失败');
    } on PlatformException catch (e) {
      return AlarmResult.error('设置闹钟失败: ${e.message}');
    } catch (e) {
      return AlarmResult.error('未知错误: $e');
    }
  }

  /// iOS 闹钟替代方案：用本地定时通知
  Future<AlarmResult> _setAlarmIOS({
    required int hour,
    required int minute,
    required String label,
  }) async {
    try {
      final now = DateTime.now();
      var alarmTime = DateTime(now.year, now.month, now.day, hour, minute);
      // 如果设置的时间已过，推到明天
      if (alarmTime.isBefore(now)) {
        alarmTime = alarmTime.add(const Duration(days: 1));
      }

      await NotificationService.instance.scheduleNotification(
        id: hour * 60 + minute, // 用时间生成唯一 ID
        title: '⏰ $label',
        body: '闹钟提醒 · ${hour.toString().padLeft(2, '0')}:${minute.toString().padLeft(2, '0')}',
        scheduledTime: alarmTime,
      );

      return AlarmResult.success(
        '已设置通知提醒: ${hour.toString().padLeft(2, '0')}:${minute.toString().padLeft(2, '0')} $label\n'
        '（iOS 不支持直接设置系统闹钟，已用通知替代）',
      );
    } catch (e) {
      return AlarmResult.error('iOS 通知提醒设置失败: $e');
    }
  }

  /// 为课程设置闹钟
  ///
  /// [courseName] 班级名/课程名
  /// [subject] 科目
  /// [location] 教室
  /// [startHour] 上课时间-小时
  /// [startMinute] 上课时间-分钟
  /// [minutesBefore] 提前多少分钟
  Future<AlarmResult> setAlarmForCourse({
    required String courseName,
    String? subject,
    String? location,
    required int startHour,
    required int startMinute,
    int minutesBefore = 10,
  }) async {
    // 计算闹钟时间
    final totalMinutes = startHour * 60 + startMinute - minutesBefore;
    final alarmHour = (totalMinutes ~/ 60) % 24;
    final alarmMinute = totalMinutes % 60;

    // 构建标签
    final parts = <String>[
      if (subject != null && subject.isNotEmpty) subject,
      courseName,
      if (location != null && location.isNotEmpty) '@ $location',
    ];
    final label = parts.join(' ');

    return await setAlarm(
      hour: alarmHour,
      minute: alarmMinute,
      label: label,
    );
  }
}

/// 闹钟结果
class AlarmResult {
  final bool success;
  final String message;

  AlarmResult._({required this.success, required this.message});

  factory AlarmResult.success(String msg) =>
      AlarmResult._(success: true, message: msg);

  factory AlarmResult.error(String msg) =>
      AlarmResult._(success: false, message: msg);
}
