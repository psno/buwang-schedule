import 'package:flutter/material.dart';

import '../models/custom_reminder.dart';
import '../models/course.dart';
import '../models/app_mode.dart';
import '../utils/constants.dart';
import '../utils/extensions.dart';
import '../services/database_service.dart';
import '../services/calendar_sync_service.dart';
import '../services/alarm_service.dart';
import '../services/notification_service.dart';

/// 不忘课表 - Reminder Screen (提醒)
/// Manage course reminders and custom reminders.
class ReminderScreen extends StatefulWidget {
  const ReminderScreen({super.key});

  @override
  State<ReminderScreen> createState() => _ReminderScreenState();
}

class _ReminderScreenState extends State<ReminderScreen> {
  final DatabaseService _db = DatabaseService.instance;
  final CalendarSyncService _calendarSync = CalendarSyncService.instance;
  List<CustomReminder> _reminders = [];
  List<Course> _courses = [];
  bool _isLoading = true;

  // Course reminder settings
  bool _courseRemindersEnabled = false;
  int _reminderMinutesBefore = 10;
  int _reminderMethod = 0; // 0=alarm, 1=calendar

  // Calendar sync state
  SyncInfo _syncInfo = SyncInfo();
  bool _isSyncing = false;

  @override
  void initState() {
    super.initState();
    _loadData();
  }

  Future<void> _loadData() async {
    setState(() => _isLoading = true);
    try {
      _reminders = await _db.getAllReminders();
      _courses = await _db.getAllCourses();

      final enabled = await _db.getSetting('notifications_enabled');
      _courseRemindersEnabled = enabled == '1';

      final minutes = await _db.getSetting('notification_minutes_before');
      _reminderMinutesBefore = int.tryParse(minutes ?? '10') ?? 10;

      final method = await _db.getSetting('reminder_method');
      _reminderMethod = int.tryParse(method ?? '0') ?? 0;

      _syncInfo = await _calendarSync.getSyncInfo();
    } catch (_) {}
    if (mounted) setState(() => _isLoading = false);
  }

  Future<void> _toggleCourseReminders(bool value) async {
    // 请求通知权限
    if (value) {
      final granted = await NotificationService.instance.requestPermissions();
      if (!granted && mounted) {
        context.showErrorSnackBar('未授予通知权限，无法启用课程提醒');
        return;
      }
    }

    await _db.setSetting('notifications_enabled', value ? '1' : '0');
    setState(() => _courseRemindersEnabled = value);

    if (value) {
      // 启用时立即调度所有课程通知
      await _scheduleAllNotifications();
    } else {
      // 关闭时取消所有课程通知
      await NotificationService.instance.cancelAllCourseReminders();
    }

    if (mounted) {
      context.showSnackBar(value ? '课程提醒已开启' : '课程提醒已关闭');
    }
  }

  Future<void> _scheduleAllNotifications() async {
    if (_courses.isEmpty) return;

    final semesterStr = await _db.getSetting(AppConstants.keySemesterStart);
    if (semesterStr == null) {
      if (mounted) context.showErrorSnackBar('请先在下方设置开学日期');
      return;
    }

    final semesterStart = DateTime.tryParse(semesterStr);
    if (semesterStart == null) return;

    final weeksStr = await _db.getSetting(AppConstants.keyTotalWeeks);
    final totalWeeks = int.tryParse(weeksStr ?? '20') ?? 20;

    final roleStr = await _db.getSetting(AppConstants.keyUserRole);
    final userRole = UserRole.values[int.tryParse(roleStr ?? '0') ?? 0];
    final schoolStr = await _db.getSetting(AppConstants.keySchoolType);
    final schoolType = SchoolType.values[int.tryParse(schoolStr ?? '0') ?? 0];

    final count = await NotificationService.instance.scheduleAllCourseReminders(
      courses: _courses.map((c) => c.toMap()).toList(),
      semesterStart: semesterStart,
      totalWeeks: totalWeeks,
      minutesBefore: _reminderMinutesBefore,
      schoolType: schoolType,
      titleBuilder: (courseMap) {
        if (userRole == UserRole.teacher) {
          return '${courseMap['name']} · ${courseMap['subject'] ?? ''}';
        }
        return '${courseMap['subject'] ?? courseMap['name']} · ${courseMap['teacher'] ?? ''}';
      },
    );

    if (mounted) {
      context.showSuccessSnackBar('已设置 $count 个课程提醒');
    }
  }

  Future<void> _setReminderMinutes(int minutes) async {
    await _db.setSetting('notification_minutes_before', minutes.toString());
    setState(() => _reminderMinutesBefore = minutes);
  }

  Future<void> _setReminderMethod(int method) async {
    await _db.setSetting('reminder_method', method.toString());
    setState(() => _reminderMethod = method);
  }

  Future<void> _addOrEditReminder({CustomReminder? existing}) async {
    final result = await showModalBottomSheet<CustomReminder>(
      context: context,
      isScrollControlled: true,
      builder: (_) => _ReminderEditorSheet(reminder: existing),
    );
    if (result == null) return;

    if (existing != null) {
      await _db.updateReminder(result);
    } else {
      await _db.insertReminder(result);
    }

    // 如果是闹钟方式，调用系统闹钟
    if (result.enabled && result.method == ReminderMethod.alarm) {
      final alarmResult = await AlarmService.instance.setAlarm(
        hour: result.hour,
        minute: result.minute,
        label: result.name,
      );
      if (mounted) {
        context.showSnackBar(alarmResult.message);
      }
    }

    await _loadData();
  }

  Future<void> _deleteReminder(CustomReminder reminder) async {
    final confirm = await showDialog<bool>(
      context: context,
      builder: (ctx) => AlertDialog(
        title: const Text('删除提醒'),
        content: Text('确定删除「${reminder.name}」？'),
        actions: [
          TextButton(onPressed: () => Navigator.pop(ctx, false), child: const Text('取消')),
          TextButton(
            onPressed: () => Navigator.pop(ctx, true),
            child: Text('删除', style: TextStyle(color: context.colorScheme.error)),
          ),
        ],
      ),
    );
    if (confirm == true) {
      await _db.deleteReminder(reminder.id!);
      await _loadData();
    }
  }

  Future<void> _toggleReminder(CustomReminder reminder) async {
    await _db.updateReminder(reminder.copyWith(enabled: !reminder.enabled));
    await _loadData();
  }

  @override
  Widget build(BuildContext context) {
    final cs = context.colorScheme;
    final ts = context.textTheme;

    return Scaffold(
      appBar: AppBar(
        title: Text('提醒', style: ts.titleLarge?.copyWith(fontSize: 18)),
        actions: [
          IconButton(
            icon: const Icon(Icons.refresh),
            onPressed: _loadData,
            tooltip: '刷新',
          ),
        ],
      ),
      body: _isLoading
          ? const Center(child: CircularProgressIndicator())
          : ListView(
              padding: const EdgeInsets.symmetric(vertical: 8),
              children: [
                // ─── Calendar Sync Section ───
                _buildSectionHeader(context, '同步到系统日历', Icons.calendar_month),
                _buildCalendarSyncSection(context),
                const SizedBox(height: 16),

                // ─── Course Reminders Section ───
                _buildSectionHeader(context, '课程提醒', Icons.school),
                _buildCourseReminderSection(context),
                const SizedBox(height: 16),

                // ─── Custom Reminders Section ───
                _buildSectionHeader(context, '自定义提醒', Icons.alarm),
                if (_reminders.isEmpty)
                  _buildEmptyReminders(context)
                else
                  ..._reminders.map((r) => _buildReminderCard(context, r)),
                const SizedBox(height: 8),

                // ─── Add Reminder FAB ───
                Padding(
                  padding: const EdgeInsets.symmetric(horizontal: 16),
                  child: OutlinedButton.icon(
                    onPressed: () => _addOrEditReminder(),
                    icon: const Icon(Icons.add),
                    label: const Text('添加自定义提醒'),
                  ),
                ),
                const SizedBox(height: 24),
              ],
            ),
      floatingActionButton: FloatingActionButton(
        onPressed: () => _addOrEditReminder(),
        tooltip: '添加提醒',
        child: const Icon(Icons.add_alarm),
      ),
    );
  }

  Widget _buildSectionHeader(BuildContext context, String title, IconData icon) {
    final cs = context.colorScheme;
    final ts = context.textTheme;

    return Padding(
      padding: const EdgeInsets.fromLTRB(20, 8, 20, 8),
      child: Row(
        children: [
          Icon(icon, size: 20, color: cs.primary),
          const SizedBox(width: 8),
          Text(
            title,
            style: ts.titleSmall?.copyWith(
              color: cs.primary,
              fontWeight: FontWeight.w600,
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildCalendarSyncSection(BuildContext context) {
    final cs = context.colorScheme;
    final ts = context.textTheme;

    return Card(
      margin: const EdgeInsets.symmetric(horizontal: 16, vertical: 4),
      child: Padding(
        padding: const EdgeInsets.all(16),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            // 说明文字
            Row(
              children: [
                Icon(Icons.info_outline, size: 16, color: cs.primary),
                const SizedBox(width: 8),
                Expanded(
                  child: Text(
                    '一键将整学期课表写入系统日历，自动设置每节课提醒',
                    style: ts.bodySmall?.copyWith(color: cs.onSurfaceVariant),
                  ),
                ),
              ],
            ),
            const SizedBox(height: 12),

            // 上次同步信息
            if (_syncInfo.lastSyncTime != null) ...[
              Container(
                padding: const EdgeInsets.all(10),
                decoration: BoxDecoration(
                  color: cs.primaryContainer.withOpacity(0.3),
                  borderRadius: BorderRadius.circular(8),
                ),
                child: Row(
                  children: [
                    Icon(Icons.check_circle_outline, size: 16, color: cs.primary),
                    const SizedBox(width: 8),
                    Text(
                      _syncInfo.displayText,
                      style: ts.bodySmall?.copyWith(color: cs.onSurfaceVariant),
                    ),
                  ],
                ),
              ),
              const SizedBox(height: 12),
            ],

            // 提前提醒时间
            Row(
              children: [
                Icon(Icons.timer_outlined, size: 18, color: cs.onSurfaceVariant),
                const SizedBox(width: 8),
                Text('提前', style: ts.bodyMedium),
                const SizedBox(width: 8),
                Container(
                  padding: const EdgeInsets.symmetric(horizontal: 12),
                  decoration: BoxDecoration(
                    color: cs.surfaceContainerHighest.withOpacity(0.5),
                    borderRadius: BorderRadius.circular(8),
                  ),
                  child: DropdownButton<int>(
                    value: _reminderMinutesBefore,
                    underline: const SizedBox.shrink(),
                    items: const [5, 10, 15, 20, 30].map((m) {
                      return DropdownMenuItem(value: m, child: Text('$m 分钟'));
                    }).toList(),
                    onChanged: (v) {
                      if (v != null) _setReminderMinutes(v);
                    },
                  ),
                ),
                Text('  提醒', style: ts.bodyMedium),
              ],
            ),
            const SizedBox(height: 12),

            // 同步按钮
            SizedBox(
              width: double.infinity,
              child: FilledButton.icon(
                onPressed: _isSyncing ? null : _syncToCalendar,
                icon: _isSyncing
                    ? const SizedBox(
                        width: 18, height: 18,
                        child: CircularProgressIndicator(strokeWidth: 2, color: Colors.white),
                      )
                    : const Icon(Icons.sync),
                label: Text(_isSyncing
                    ? '同步中...'
                    : _syncInfo.lastSyncTime != null
                        ? '重新同步整学期课表'
                        : '一键同步整学期课表'),
              ),
            ),
            if (_courses.isNotEmpty) ...[
              const SizedBox(height: 8),
              Text(
                '共 ${_courses.length} 个课程，将创建 ${_courses.length * 20} 个日历事件',
                style: ts.bodySmall?.copyWith(
                  color: cs.onSurfaceVariant.withOpacity(0.7),
                ),
                textAlign: TextAlign.center,
              ),
            ],

            // 清除日历中的课表日程
            const SizedBox(height: 12),
            const Divider(),
            const SizedBox(height: 8),
            Row(
              children: [
                Icon(Icons.delete_sweep, size: 18, color: cs.error),
                const SizedBox(width: 8),
                Expanded(
                  child: Text(
                    '清除日历中的课表相关数据',
                    style: ts.bodySmall?.copyWith(color: cs.onSurfaceVariant),
                  ),
                ),
              ],
            ),
            const SizedBox(height: 8),
            SizedBox(
              width: double.infinity,
              child: OutlinedButton.icon(
                onPressed: _isSyncing ? null : _clearCalendarSync,
                icon: const Icon(Icons.delete_outline, size: 18),
                label: const Text('删除本App写入的日程'),
                style: OutlinedButton.styleFrom(
                  foregroundColor: cs.error,
                  side: BorderSide(color: cs.error.withOpacity(0.5)),
                ),
              ),
            ),
            const SizedBox(height: 8),
            SizedBox(
              width: double.infinity,
              child: OutlinedButton.icon(
                onPressed: _isSyncing ? null : _deepCleanCalendar,
                icon: const Icon(Icons.cleaning_services, size: 18),
                label: const Text('深度清理：删除所有含「课表」的日程'),
                style: OutlinedButton.styleFrom(
                  foregroundColor: cs.error,
                  side: BorderSide(color: cs.error.withOpacity(0.3)),
                ),
              ),
            ),
            const SizedBox(height: 4),
            Text(
              '深度清理会扫描所有日历账户，包括重复的「不忘课表」分组',
              style: ts.bodySmall?.copyWith(color: cs.onSurfaceVariant.withOpacity(0.5), fontSize: 10),
            ),
          ],
        ),
      ),
    );
  }

  Future<void> _syncToCalendar() async {
    // 弹出开学日期选择器
    final semesterStart = await _pickSemesterStart();
    if (semesterStart == null) return;

    setState(() => _isSyncing = true);

    try {
      final totalWeeksStr = await _db.getSetting(AppConstants.keyTotalWeeks);
      final totalWeeks = int.tryParse(totalWeeksStr ?? '20') ?? 20;

      final result = await _calendarSync.syncAllCourses(
        semesterStart: semesterStart,
        totalWeeks: totalWeeks,
        reminderMinutes: _reminderMinutesBefore,
      );

      if (mounted) {
        if (result.success) {
          context.showSuccessSnackBar(result.message);
        } else {
          context.showErrorSnackBar(result.message);
        }
        _syncInfo = await _calendarSync.getSyncInfo();
      }
    } catch (e) {
      if (mounted) context.showErrorSnackBar('同步失败: $e');
    } finally {
      if (mounted) setState(() => _isSyncing = false);
    }
  }


  Future<void> _clearCalendarSync() async {
    final confirm = await showDialog<bool>(
      context: context,
      builder: (ctx) => AlertDialog(
        title: const Text('清除日历数据'),
        content: const Text('将删除「不忘课表」日历账户中的所有课程事件，不会影响你的其他日程。确定继续？'),
        actions: [
          TextButton(onPressed: () => Navigator.pop(ctx, false), child: const Text('取消')),
          TextButton(
            onPressed: () => Navigator.pop(ctx, true),
            child: Text('确定清除', style: TextStyle(color: context.colorScheme.error)),
          ),
        ],
      ),
    );
    if (confirm != true) return;

    setState(() => _isSyncing = true);
    try {
      final result = await _calendarSync.clearAllEvents();
      if (mounted) {
        if (result.success) {
          context.showSuccessSnackBar(result.message);
        } else {
          context.showErrorSnackBar(result.message);
        }
        _syncInfo = await _calendarSync.getSyncInfo();
      }
    } catch (e) {
      if (mounted) context.showErrorSnackBar('清除失败: $e');
    } finally {
      if (mounted) setState(() => _isSyncing = false);
    }
  }


  /// 深度清理：扫描所有日历中含"课表"的日程
  Future<void> _deepCleanCalendar() async {
    final confirm = await showDialog<bool>(
      context: context,
      builder: (ctx) => AlertDialog(
        title: const Text('深度清理日历'),
        content: const Text('将扫描所有日历，删除标题或描述中包含「课表」的所有日程。这包括本App和其他来源写入的课表相关日程。\n\n确定继续？'),
        actions: [
          TextButton(onPressed: () => Navigator.pop(ctx, false), child: const Text('取消')),
          TextButton(
            onPressed: () => Navigator.pop(ctx, true),
            child: Text('确定清理', style: TextStyle(color: context.colorScheme.error)),
          ),
        ],
      ),
    );
    if (confirm != true) return;

    setState(() => _isSyncing = true);
    try {
      final result = await _calendarSync.deepCleanCalendar();
      if (mounted) {
        if (result.success) {
          // 显示详细结果弹窗（含调试日志）
          await showDialog(
            context: context,
            builder: (ctx) => AlertDialog(
              title: const Text('清理结果'),
              content: SingleChildScrollView(
                child: Text(result.message, style: const TextStyle(fontSize: 12)),
              ),
              actions: [
                TextButton(
                  onPressed: () => Navigator.pop(ctx),
                  child: const Text('知道了'),
                ),
              ],
            ),
          );
        } else {
          // 错误也显示弹窗
          await showDialog(
            context: context,
            builder: (ctx) => AlertDialog(
              title: const Text('清理失败'),
              content: SingleChildScrollView(
                child: Text(result.message, style: const TextStyle(fontSize: 12)),
              ),
              actions: [
                TextButton(
                  onPressed: () => Navigator.pop(ctx),
                  child: const Text('知道了'),
                ),
              ],
            ),
          );
        }
        _syncInfo = await _calendarSync.getSyncInfo();
      }
    } catch (e) {
      if (mounted) context.showErrorSnackBar('深度清理失败: $e');
    } finally {
      if (mounted) setState(() => _isSyncing = false);
    }
  }

  Future<DateTime?> _pickSemesterStart() async {
    // 先检查是否已有设置
    final saved = await _db.getSetting(AppConstants.keySemesterStart);
    DateTime initialDate;
    if (saved != null) {
      initialDate = DateTime.tryParse(saved) ?? DateTime.now();
    } else {
      // 默认: 最近的周一
      final now = DateTime.now();
      initialDate = now.subtract(Duration(days: now.weekday - 1));
    }

    if (!mounted) return null;

    final picked = await showDatePicker(
      context: context,
      initialDate: initialDate,
      firstDate: DateTime(2024, 1, 1),
      lastDate: DateTime(2027, 12, 31),
      helpText: '选择开学第一周的周一',
      confirmText: '确定',
      cancelText: '取消',
    );

    if (picked != null) {
      // 确保选的是周一
      if (picked.weekday != 1) {
        final monday = picked.subtract(Duration(days: picked.weekday - 1));
        if (mounted) {
          context.showSnackBar('已自动调整为该周的周一: ${monday.month}/${monday.day}');
        }
        await _db.setSetting(AppConstants.keySemesterStart, monday.toIso8601String());
        return monday;
      }
      await _db.setSetting(AppConstants.keySemesterStart, picked.toIso8601String());
    }
    return picked;
  }

  Widget _buildCourseReminderSection(BuildContext context) {
    final cs = context.colorScheme;
    final ts = context.textTheme;

    return Card(
      margin: const EdgeInsets.symmetric(horizontal: 16, vertical: 4),
      child: Padding(
        padding: const EdgeInsets.all(16),
        child: Column(
          children: [
            // Enable/Disable toggle
            SwitchListTile(
              title: const Text('启用课程提醒'),
              subtitle: Text(
                _courseRemindersEnabled
                    ? '上课前 $_reminderMinutesBefore 分钟提醒'
                    : '已关闭',
                style: ts.bodySmall?.copyWith(color: cs.onSurfaceVariant),
              ),
              value: _courseRemindersEnabled,
              onChanged: _toggleCourseReminders,
              contentPadding: EdgeInsets.zero,
            ),

            if (_courseRemindersEnabled) ...[
              const Divider(height: 1),
              const SizedBox(height: 12),

              // Minutes before selector
              Row(
                children: [
                  Icon(Icons.timer_outlined, size: 18, color: cs.onSurfaceVariant),
                  const SizedBox(width: 8),
                  Text('提前', style: ts.bodyMedium),
                  const SizedBox(width: 8),
                  // Dropdown for minutes
                  Container(
                    padding: const EdgeInsets.symmetric(horizontal: 12),
                    decoration: BoxDecoration(
                      color: cs.surfaceVariant.withOpacity(0.5),
                      borderRadius: BorderRadius.circular(8),
                    ),
                    child: DropdownButton<int>(
                      value: _reminderMinutesBefore,
                      underline: const SizedBox.shrink(),
                      items: const [5, 10, 15, 20, 30].map((m) {
                        return DropdownMenuItem(
                          value: m,
                          child: Text('$m 分钟'),
                        );
                      }).toList(),
                      onChanged: (v) {
                        if (v != null) _setReminderMinutes(v);
                      },
                    ),
                  ),
                  Text('  提醒', style: ts.bodyMedium),
                ],
              ),
              const SizedBox(height: 12),

              // Reminder method selector - 三个按钮不挤
              Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Row(
                    children: [
                      Icon(Icons.notifications_outlined, size: 18, color: cs.onSurfaceVariant),
                      const SizedBox(width: 8),
                      Text('提醒方式', style: ts.bodyMedium),
                    ],
                  ),
                  const SizedBox(height: 8),
                  Row(
                    children: [
                      _buildMethodChip(context, 0, Icons.alarm, '闹钟'),
                      const SizedBox(width: 8),
                      _buildMethodChip(context, 1, Icons.calendar_today, '日历'),
                      const SizedBox(width: 8),
                      _buildMethodChip(context, 2, Icons.notifications, '通知'),
                    ],
                  ),
                ],
              ),
              const SizedBox(height: 12),

              // Test notification button
              SizedBox(
                width: double.infinity,
                child: OutlinedButton.icon(
                  onPressed: () async {
                    try {
                      await NotificationService.instance.showTestNotification(secondsLater: 5);
                      if (mounted) context.showSnackBar('5秒后将弹出测试通知');
                    } catch (e) {
                      // 定时失败，直接弹即时通知
                      try {
                        await NotificationService.instance.showNotification(
                          id: 99999,
                          title: '🔔 测试提醒',
                          body: '如果你看到这条通知，说明应用内提醒功能正常！',
                        );
                        if (mounted) context.showSnackBar('已发送即时测试通知');
                      } catch (e2) {
                        if (mounted) context.showErrorSnackBar('通知失败: $e2');
                      }
                    }
                  },
                  icon: const Icon(Icons.notifications_active, size: 18),
                  label: const Text('测试通知（5秒后）'),
                ),
              ),
              const SizedBox(height: 8),

              // Course count info
              Container(
                padding: const EdgeInsets.all(10),
                decoration: BoxDecoration(
                  color: cs.primaryContainer.withOpacity(0.3),
                  borderRadius: BorderRadius.circular(8),
                ),
                child: Row(
                  children: [
                    Icon(Icons.info_outline, size: 16, color: cs.primary),
                    const SizedBox(width: 8),
                    Expanded(
                      child: Text(
                        '已导入 ${_courses.length} 个课程，将为每节课设置提醒',
                        style: ts.bodySmall?.copyWith(color: cs.onSurfaceVariant),
                      ),
                    ),
                  ],
                ),
              ),
              const SizedBox(height: 8),

              // Weekday-only switch
              FutureBuilder<String?>(
                future: _db.getSetting(AppConstants.keyWeekdayOnly),
                builder: (context, snapshot) {
                  final weekdayOnly = snapshot.data == '1';
                  return SwitchListTile(
                    title: const Text('仅工作日提醒'),
                    subtitle: Text(
                      weekdayOnly ? '周六日不提醒' : '每天都提醒',
                      style: ts.bodySmall?.copyWith(color: cs.onSurfaceVariant),
                    ),
                    value: weekdayOnly,
                    onChanged: (v) async {
                      await _db.setSetting(AppConstants.keyWeekdayOnly, v ? '1' : '0');
                      setState(() {});
                      if (mounted) context.showSnackBar(v ? '仅工作日提醒' : '每天都提醒');
                    },
                    contentPadding: EdgeInsets.zero,
                  );
                },
              ),
            ],
          ],
        ),
      ),
    );
  }


  /// 构建提醒方式选择按钮
  Widget _buildMethodChip(BuildContext context, int method, IconData icon, String label) {
    final cs = context.colorScheme;
    final selected = _reminderMethod == method;
    return Expanded(
      child: GestureDetector(
        onTap: () => _setReminderMethod(method),
        child: AnimatedContainer(
          duration: const Duration(milliseconds: 200),
          padding: const EdgeInsets.symmetric(vertical: 10),
          decoration: BoxDecoration(
            color: selected ? cs.primary : cs.surfaceContainerHighest.withOpacity(0.5),
            borderRadius: BorderRadius.circular(10),
            border: Border.all(
              color: selected ? cs.primary : cs.outline.withOpacity(0.3),
            ),
          ),
          child: Row(
            mainAxisAlignment: MainAxisAlignment.center,
            children: [
              Icon(icon, size: 16, color: selected ? cs.onPrimary : cs.onSurfaceVariant),
              const SizedBox(width: 4),
              Text(
                label,
                style: TextStyle(
                  fontSize: 13,
                  fontWeight: selected ? FontWeight.w600 : FontWeight.normal,
                  color: selected ? cs.onPrimary : cs.onSurfaceVariant,
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }

  Widget _buildReminderCard(BuildContext context, CustomReminder reminder) {
    final cs = context.colorScheme;
    final ts = context.textTheme;

    final repeatText = _repeatTypeText(reminder.repeatType, reminder.repeatDays);
    final methodText = reminder.method == ReminderMethod.alarm ? '闹钟' : '日历';
    final timeStr =
        '${reminder.hour.toString().padLeft(2, '0')}:${reminder.minute.toString().padLeft(2, '0')}';

    return Card(
      margin: const EdgeInsets.symmetric(horizontal: 16, vertical: 4),
      child: ListTile(
        leading: Container(
          width: 44,
          height: 44,
          decoration: BoxDecoration(
            color: reminder.enabled
                ? cs.primary.withOpacity(0.1)
                : cs.onSurface.withOpacity(0.05),
            borderRadius: BorderRadius.circular(12),
          ),
          child: Center(
            child: Text(
              timeStr,
              style: ts.labelSmall?.copyWith(
                color: reminder.enabled ? cs.primary : cs.onSurfaceVariant,
                fontWeight: FontWeight.w600,
              ),
            ),
          ),
        ),
        title: Text(
          reminder.name,
          style: ts.bodyLarge?.copyWith(
            fontWeight: FontWeight.w500,
            color: reminder.enabled ? cs.onSurface : cs.onSurfaceVariant,
          ),
        ),
        subtitle: Text(
          '$repeatText · $methodText',
          style: ts.bodySmall?.copyWith(color: cs.onSurfaceVariant),
        ),
        trailing: Row(
          mainAxisSize: MainAxisSize.min,
          children: [
            Switch(
              value: reminder.enabled,
              onChanged: (_) => _toggleReminder(reminder),
            ),
            PopupMenuButton<String>(
              icon: Icon(Icons.more_vert, color: cs.onSurfaceVariant),
              onSelected: (action) {
                if (action == 'edit') {
                  _addOrEditReminder(existing: reminder);
                } else if (action == 'delete') {
                  _deleteReminder(reminder);
                }
              },
              itemBuilder: (_) => [
                const PopupMenuItem(value: 'edit', child: Text('编辑')),
                PopupMenuItem(
                  value: 'delete',
                  child: Text('删除', style: TextStyle(color: cs.error)),
                ),
              ],
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildEmptyReminders(BuildContext context) {
    final cs = context.colorScheme;
    final ts = context.textTheme;

    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 32),
      child: Center(
        child: Column(
          children: [
            Icon(Icons.alarm_off, size: 48, color: cs.onSurfaceVariant.withOpacity(0.4)),
            const SizedBox(height: 12),
            Text(
              '暂无自定义提醒',
              style: ts.bodyMedium?.copyWith(color: cs.onSurfaceVariant),
            ),
            const SizedBox(height: 4),
            Text(
              '点击下方按钮添加',
              style: ts.bodySmall?.copyWith(color: cs.onSurfaceVariant.withOpacity(0.7)),
            ),
          ],
        ),
      ),
    );
  }

  String _repeatTypeText(RepeatType type, List<int> days) {
    switch (type) {
      case RepeatType.daily:
        return '每天';
      case RepeatType.weekdays:
        return '工作日';
      case RepeatType.weekly:
        if (days.isEmpty) return '每周';
        final dayNames = days.map((d) => dayNamesChinese[d - 1]).join('、');
        return '每周$dayNames';
      case RepeatType.once:
        return '仅一次';
    }
  }
}

/// Bottom sheet editor for creating/editing a custom reminder.
class _ReminderEditorSheet extends StatefulWidget {
  final CustomReminder? reminder;
  const _ReminderEditorSheet({this.reminder});

  @override
  State<_ReminderEditorSheet> createState() => _ReminderEditorSheetState();
}

class _ReminderEditorSheetState extends State<_ReminderEditorSheet> {
  late TextEditingController _nameController;
  late int _hour;
  late int _minute;
  late RepeatType _repeatType;
  late List<int> _repeatDays;
  late ReminderMethod _method;

  @override
  void initState() {
    super.initState();
    final r = widget.reminder;
    _nameController = TextEditingController(text: r?.name ?? '');
    _hour = r?.hour ?? 8;
    _minute = r?.minute ?? 0;
    _repeatType = r?.repeatType ?? RepeatType.daily;
    _repeatDays = List<int>.from(r?.repeatDays ?? []);
    _method = r?.method ?? ReminderMethod.alarm;
  }

  @override
  void dispose() {
    _nameController.dispose();
    super.dispose();
  }

  void _save() {
    if (_nameController.text.trim().isEmpty) {
      context.showErrorSnackBar('请输入提醒名称');
      return;
    }
    final reminder = CustomReminder(
      id: widget.reminder?.id,
      name: _nameController.text.trim(),
      hour: _hour,
      minute: _minute,
      repeatType: _repeatType,
      repeatDays: _repeatDays,
      method: _method,
      enabled: widget.reminder?.enabled ?? true,
    );
    Navigator.pop(context, reminder);
  }

  Future<void> _pickTime() async {
    final picked = await showTimePicker(
      context: context,
      initialTime: TimeOfDay(hour: _hour, minute: _minute),
    );
    if (picked != null) {
      setState(() {
        _hour = picked.hour;
        _minute = picked.minute;
      });
    }
  }

  @override
  Widget build(BuildContext context) {
    final cs = context.colorScheme;
    final ts = context.textTheme;
    final bottomPadding = MediaQuery.of(context).viewInsets.bottom;

    return Padding(
      padding: EdgeInsets.fromLTRB(24, 16, 24, bottomPadding + 16),
      child: SingleChildScrollView(
        child: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            // Handle bar
            Center(
              child: Container(
                width: 40,
                height: 4,
                decoration: BoxDecoration(
                  color: cs.onSurfaceVariant.withOpacity(0.3),
                  borderRadius: BorderRadius.circular(2),
                ),
              ),
            ),
            const SizedBox(height: 16),
            Text(
              widget.reminder != null ? '编辑提醒' : '新建提醒',
              style: ts.titleLarge?.copyWith(fontWeight: FontWeight.bold),
            ),
            const SizedBox(height: 16),

            // Name field
            TextField(
              controller: _nameController,
              decoration: const InputDecoration(
                labelText: '提醒名称',
                hintText: '例如: 起床',
              ),
              autofocus: widget.reminder == null,
            ),
            const SizedBox(height: 16),

            // Time picker
            ListTile(
              leading: Icon(Icons.access_time, color: cs.primary),
              title: const Text('提醒时间'),
              subtitle: Text(
                '${_hour.toString().padLeft(2, '0')}:${_minute.toString().padLeft(2, '0')}',
                style: ts.headlineSmall?.copyWith(
                  color: cs.primary,
                  fontWeight: FontWeight.bold,
                ),
              ),
              onTap: _pickTime,
              contentPadding: EdgeInsets.zero,
            ),
            const SizedBox(height: 8),

            // Repeat type
            Text('重复', style: ts.titleSmall?.copyWith(fontWeight: FontWeight.w600)),
            const SizedBox(height: 8),
            Wrap(
              spacing: 8,
              children: RepeatType.values.map((type) {
                final selected = _repeatType == type;
                return ChoiceChip(
                  label: Text(_repeatLabel(type)),
                  selected: selected,
                  onSelected: (_) => setState(() {
                    _repeatType = type;
                    if (type != RepeatType.weekly) _repeatDays = [];
                  }),
                );
              }).toList(),
            ),

            // Day selectors for weekly
            if (_repeatType == RepeatType.weekly) ...[
              const SizedBox(height: 12),
              Wrap(
                spacing: 6,
                children: List.generate(7, (i) {
                  final dayNum = i + 1;
                  final selected = _repeatDays.contains(dayNum);
                  return FilterChip(
                    label: Text(dayNamesShort[i]),
                    selected: selected,
                    onSelected: (v) {
                      setState(() {
                        if (v) {
                          _repeatDays.add(dayNum);
                        } else {
                          _repeatDays.remove(dayNum);
                        }
                      });
                    },
                  );
                }),
              ),
            ],
            const SizedBox(height: 16),

            // Method
            Text('提醒方式', style: ts.titleSmall?.copyWith(fontWeight: FontWeight.w600)),
            const SizedBox(height: 8),
            SegmentedButton<ReminderMethod>(
              segments: const [
                ButtonSegment(value: ReminderMethod.alarm, label: Text('闹钟'), icon: Icon(Icons.alarm)),
                ButtonSegment(value: ReminderMethod.calendar, label: Text('日历'), icon: Icon(Icons.calendar_today)),
              ],
              selected: {_method},
              onSelectionChanged: (s) => setState(() => _method = s.first),
            ),
            const SizedBox(height: 24),

            // Save button
            SizedBox(
              width: double.infinity,
              child: FilledButton(
                onPressed: _save,
                child: Text(widget.reminder != null ? '保存修改' : '创建提醒'),
              ),
            ),
            const SizedBox(height: 8),
          ],
        ),
      ),
    );
  }

  String _repeatLabel(RepeatType type) {
    switch (type) {
      case RepeatType.daily:
        return '每天';
      case RepeatType.weekdays:
        return '工作日';
      case RepeatType.weekly:
        return '每周';
      case RepeatType.once:
        return '仅一次';
    }
  }
}
