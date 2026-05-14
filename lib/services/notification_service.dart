import 'package:flutter/foundation.dart';
import '../utils/constants.dart';
import '../models/app_mode.dart';
import 'package:flutter_local_notifications/flutter_local_notifications.dart';
import 'package:permission_handler/permission_handler.dart';
import 'package:timezone/timezone.dart' as tz;
import 'package:timezone/data/latest.dart' as tz;

/// 应用内通知服务 — flutter_local_notifications
/// 不依赖系统日历/闹钟，独立通知通道
class NotificationService {
  NotificationService._();
  static final NotificationService instance = NotificationService._();

  final FlutterLocalNotificationsPlugin _plugin = FlutterLocalNotificationsPlugin();
  bool _initialized = false;

  /// 初始化通知服务
  Future<bool> initialize() async {
    if (_initialized) return true;

    try {
      // timezone 初始化
      tz.initializeTimeZones();
      tz.setLocalLocation(tz.getLocation('Asia/Shanghai'));

      const androidSettings = AndroidInitializationSettings('@mipmap/ic_launcher');
      const darwinSettings = DarwinInitializationSettings(
        requestAlertPermission: true,
        requestBadgePermission: true,
        requestSoundPermission: true,
      );
      const settings = InitializationSettings(
        android: androidSettings,
        iOS: darwinSettings,
        macOS: darwinSettings,
      );

      final result = await _plugin.initialize(settings);
      _initialized = result ?? false;

      if (!_initialized) {
        debugPrint('通知初始化失败');
        return false;
      }

      // Android 13+ 动态请求通知权限
      final androidPlugin = _plugin.resolvePlatformSpecificImplementation<AndroidFlutterLocalNotificationsPlugin>();
      final granted = await androidPlugin?.requestNotificationsPermission();
      debugPrint('通知权限(Android): $granted');

      // iOS 权限由 DarwinInitializationSettings 自动请求
      // 额外确认一下
      final iosPlugin = _plugin.resolvePlatformSpecificImplementation<IOSFlutterLocalNotificationsPlugin>();
      if (iosPlugin != null) {
        final iosGranted = await iosPlugin.requestPermissions(
          alert: true, badge: true, sound: true,
        );
        debugPrint('通知权限(iOS): $iosGranted');
      }

      // 创建通知渠道（仅 Android）
      await _createNotificationChannel();

      return true;
    } catch (e, s) {
      debugPrint('通知初始化异常: $e');
      debugPrintStack(stackTrace: s);
      _initialized = false;
      return false;
    }
  }

  /// 创建高优先级通知渠道
  Future<void> _createNotificationChannel() async {
    const channel = AndroidNotificationChannel(
      'buwang_course_reminder',
      '课程提醒',
      description: '上课前的课程提醒通知',
      importance: Importance.high,
      playSound: true,
      enableVibration: true,
    );

    await _plugin
        .resolvePlatformSpecificImplementation<AndroidFlutterLocalNotificationsPlugin>()
        ?.createNotificationChannel(channel);
  }

  /// 请求通知权限
  Future<bool> requestPermissions() async {
    final status = await Permission.notification.request();
    return status.isGranted;
  }

  /// 检查通知权限
  Future<bool> hasPermissions() async {
    return await Permission.notification.isGranted;
  }

  /// 立即显示通知
  Future<void> showNotification({
    required int id,
    required String title,
    required String body,
  }) async {
    if (!_initialized) {
      final ok = await initialize();
      if (!ok) return;
    }

    const androidDetails = AndroidNotificationDetails(
      'buwang_course_reminder',
      '课程提醒',
      channelDescription: '上课前的课程提醒通知',
      importance: Importance.max,
      priority: Priority.high,
      playSound: true,
      enableVibration: true,
    );
    const darwinDetails = DarwinNotificationDetails(
      presentAlert: true,
      presentBadge: true,
      presentSound: true,
    );
    const details = NotificationDetails(
      android: androidDetails,
      iOS: darwinDetails,
      macOS: darwinDetails,
    );
    await _plugin.show(id, title, body, details);
  }

  /// 定时通知（指定时间触发）
  Future<void> scheduleNotification({
    required int id,
    required String title,
    required String body,
    required DateTime scheduledTime,
  }) async {
    if (!_initialized) {
      final ok = await initialize();
      if (!ok) return;
    }

    try {
      final tzTime = tz.TZDateTime.from(scheduledTime, tz.local);

      const androidDetails = AndroidNotificationDetails(
        'buwang_course_reminder',
        '课程提醒',
        channelDescription: '上课前的课程提醒通知',
        importance: Importance.max,
        priority: Priority.high,
        playSound: true,
        enableVibration: true,
      );
      const darwinDetails = DarwinNotificationDetails(
        presentAlert: true,
        presentBadge: true,
        presentSound: true,
      );
      const details = NotificationDetails(
        android: androidDetails,
        iOS: darwinDetails,
        macOS: darwinDetails,
      );

      await _plugin.zonedSchedule(
        id,
        title,
        body,
        tzTime,
        details,
        androidScheduleMode: AndroidScheduleMode.inexactAllowWhileIdle,
        uiLocalNotificationDateInterpretation: UILocalNotificationDateInterpretation.absoluteTime,
      );
    } catch (e) {
      debugPrint('定时通知调度失败: $e');
    }
  }

  /// X秒后触发测试通知（用show+延迟，避开zonedSchedule原生崩溃）
  Future<void> showTestNotification({int secondsLater = 5}) async {
    try {
      final ok = await initialize();
      if (!ok) {
        debugPrint('通知系统初始化失败');
        return;
      }

      // 用Future.delayed + show()代替zonedSchedule，避免原生层崩溃
      Future.delayed(Duration(seconds: secondsLater), () async {
        try {
          await showNotification(
            id: 99999,
            title: '🔔 测试提醒',
            body: '如果你看到这条通知，说明功能正常！',
          );
          debugPrint('测试通知已发送');
        } catch (e) {
          debugPrint('测试通知发送失败: $e');
        }
      });
    } catch (e, s) {
      debugPrint('测试通知异常: $e');
      debugPrintStack(stackTrace: s);
    }
  }

  /// 为所有课程批量设置定时通知
  Future<int> scheduleAllCourseReminders({
    required List<Map<String, dynamic>> courses,
    required DateTime semesterStart,
    required int totalWeeks,
    required int minutesBefore,
    required String Function(Map<String, dynamic>) titleBuilder,
    SchoolType schoolType = SchoolType.highSchool,
  }) async {
    if (!_initialized) {
      final ok = await initialize();
      if (!ok) return 0;
    }

    await cancelAllCourseReminders();

    int count = 0;
    int idBase = 1000;

    for (int week = 0; week < totalWeeks; week++) {
      for (int i = 0; i < courses.length; i++) {
        final course = courses[i];
        final dayOfWeek = course['dayOfWeek'] as int;
        final period = course['period'] as int;

        final eventDate = semesterStart.add(Duration(days: week * 7 + (dayOfWeek - 1)));

        final slot = _getPeriodTimeSlot(period, schoolType);
        if (slot == null) continue;

        final startHour = slot.startTime.hour;
        final startMinute = slot.startTime.minute;

        final alarmTime = eventDate.add(Duration(hours: startHour, minutes: startMinute - minutesBefore));

        if (alarmTime.isBefore(DateTime.now())) continue;

        final title = titleBuilder(course);
        final body = '还有${minutesBefore}分钟开始上课';

        try {
          await scheduleNotification(
            id: idBase + week * 100 + i,
            title: title,
            body: body,
            scheduledTime: alarmTime,
          );
          count++;
        } catch (_) {}
      }
    }

    return count;
  }

  /// 取消所有课程提醒
  Future<void> cancelAllCourseReminders() async {
    for (int id = 1000; id < 100000; id += 100) {
      try {
        await _plugin.cancel(id);
      } catch (_) {}
    }
  }

  /// 取消所有通知
  Future<void> cancelAll() async {
    await _plugin.cancelAll();
  }

  /// 获取节次对应的上课时间（使用共享的TimeSlot数据）
  TimeSlot? _getPeriodTimeSlot(int period, SchoolType schoolType) {
    try {
      return getTimeSlot(period, schoolType: schoolType);
    } catch (_) {
      return null;
    }
  }
}
