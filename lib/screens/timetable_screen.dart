import 'package:flutter/material.dart';
import 'package:shared_preferences/shared_preferences.dart';

import '../models/course.dart';
import '../models/app_mode.dart';
import '../utils/constants.dart';
import '../utils/extensions.dart';
import '../services/database_service.dart';
import '../models/saturday_mode.dart';
import '../theme/app_theme.dart';

/// 不忘课表 - Timetable Screen (课表)
/// Shows a weekly grid timetable with day columns and period rows.
class TimetableScreen extends StatefulWidget {
  const TimetableScreen({super.key});

  @override
  State<TimetableScreen> createState() => _TimetableScreenState();
}

class _TimetableScreenState extends State<TimetableScreen> {
  final DatabaseService _db = DatabaseService.instance;
  List<Course> _allCourses = [];
  bool _isLoading = true;

  // Current week offset from today (0 = this week)
  int _weekOffset = 0;
  SaturdayMode _saturdayMode = SaturdayMode.off;
  SchoolType _schoolType = SchoolType.highSchool;
  UserRole _userRole = UserRole.student;

  // Which days to show based on Saturday mode
  int get _visibleDays => _saturdayMode == SaturdayMode.off ? 5 : 6;

  @override
  void initState() {
    super.initState();
    _loadCourses();
    _loadSaturdayMode();
    _loadSchoolType();
    _loadUserRole();
  }

  Future<void> _loadSchoolType() async {
    try {
      final value = await _db.getSetting(AppConstants.keySchoolType);
      if (value != null && mounted) {
        setState(() {
          _schoolType = SchoolType.values[int.tryParse(value) ?? 0];
        });
      }
    } catch (_) {}
  }

  Future<void> _loadUserRole() async {
    try {
      final value = await _db.getSetting(AppConstants.keyUserRole);
      if (value != null && mounted) {
        setState(() {
          _userRole = UserRole.values[int.tryParse(value) ?? 0];
        });
      }
    } catch (_) {}
  }
  Future<void> _loadCourses() async {
    setState(() => _isLoading = true);
    try {
      _allCourses = await _db.getAllCourses();
    } catch (e) {
      _allCourses = [];
    }
    if (mounted) setState(() => _isLoading = false);
  }

  Future<void> _loadSaturdayMode() async {
    try {
      final value = await _db.getSetting('saturday_mode');
      if (value != null && mounted) {
        setState(() {
          _saturdayMode = SaturdayMode.values[int.tryParse(value) ?? 0];
        });
      }
    } catch (_) {}
  }

  Future<void> _setSaturdayMode(SaturdayMode mode) async {
    await _db.setSetting('saturday_mode', mode.index.toString());
    setState(() => _saturdayMode = mode);
  }

  /// Get the date of Monday of the displayed week.
  DateTime get _weekMonday {
    final now = DateTime.now();
    final monday = now.weekday == DateTime.sunday
        ? now.subtract(const Duration(days: 6))
        : now.subtract(Duration(days: now.weekday - 1));
    return monday.add(Duration(days: _weekOffset * 7));
  }

  /// Get date for a given column index (0=Mon, 5=Sat).
  DateTime _dateForColumn(int col) {
    return _weekMonday.add(Duration(days: col));
  }

  bool _isToday(int col) {
    return _dateForColumn(col).isSameDate(DateTime.now());
  }

  /// 周六模式对应的轮次编号 (round 字段值)
  int get _saturdayRound => _saturdayMode.index; // off=0, round1=1, round2=2, round3=3

  /// Get courses for a specific day column.
  List<Course> _coursesForColumn(int col) {
    final dayOfWeek = col + 1; // 1=Mon..6=Sat
    if (dayOfWeek == 6 && _saturdayMode != SaturdayMode.off) {
      // 周六：按轮次过滤
      return _allCourses.where((c) => c.dayOfWeek == 6 && c.round == _saturdayRound).toList();
    }
    return _allCourses.where((c) => c.dayOfWeek == dayOfWeek).toList();
  }

  /// Check if a course is currently active.
  bool _isCurrentClass(Course course, int col) {
    if (!_isToday(col)) return false;
    final now = DateTime.now();
    final slot = getTimeSlot(course.period, dayOfWeek: course.dayOfWeek, schoolType: _schoolType);
    final nowMin = now.hour * 60 + now.minute;
    final startMin = slot.startTime.hour * 60 + slot.startTime.minute;
    final endMin = slot.endTime.hour * 60 + slot.endTime.minute;
    return nowMin >= startMin && nowMin < endMin;
  }

  /// Check if a course is the next upcoming one.
  bool _isNextClass(Course course, int col) {
    if (!_isToday(col)) return false;
    final now = DateTime.now();
    final slot = getTimeSlot(course.period, dayOfWeek: course.dayOfWeek, schoolType: _schoolType);
    final nowMin = now.hour * 60 + now.minute;
    final startMin = slot.startTime.hour * 60 + slot.startTime.minute;
    if (nowMin >= startMin) return false;
    // Is it the earliest upcoming?
    final todayCourses = _coursesForColumn(col);
    for (final c in todayCourses) {
      final s = getTimeSlot(c.period, dayOfWeek: c.dayOfWeek, schoolType: _schoolType);
      final sMin = s.startTime.hour * 60 + s.startTime.minute;
      if (sMin > nowMin && sMin < startMin) return false;
    }
    return true;
  }

  String get _weekLabel {
    if (_weekOffset == 0) return '本周';
    if (_weekOffset == 1) return '下周';
    if (_weekOffset == -1) return '上周';
    return '${_weekOffset > 0 ? "+" : ""}$_weekOffset周';
  }

  void _prevWeek() => setState(() => _weekOffset--);
  void _nextWeek() => setState(() => _weekOffset++);
  void _goToThisWeek() => setState(() => _weekOffset = 0);

  // ═══════════════════════════════════════════
  // Course editing logic
  // ═══════════════════════════════════════════

  /// Open the add/edit course bottom sheet for an empty cell.
  void _onEmptyCellTapped(int dayOfWeek, int period) {
    final slot = getTimeSlot(period, dayOfWeek: dayOfWeek, schoolType: _schoolType);
    final dayName = dayNamesShort[dayOfWeek - 1];
    _showCourseFormSheet(
      title: '添加课程',
      course: null,
      dayOfWeek: dayOfWeek,
      period: period,
      slotLabel: '周$dayName ${slot.label} ${slot.startTime.formatted}-${slot.endTime.formatted}',
    );
  }

  /// Show the edit/delete bottom sheet for an existing course.
  void _onCourseTapped(Course course) {
    final cs = context.colorScheme;
    final ts = context.textTheme;
    final color = getCourseColor(course.color, isDark: context.isDarkMode);
    final slot = getTimeSlot(course.period, dayOfWeek: course.dayOfWeek, schoolType: _schoolType);

    showModalBottomSheet(
      context: context,
      isScrollControlled: true,
      builder: (ctx) => Padding(
        padding: const EdgeInsets.all(24),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(
              children: [
                Container(
                  width: 6,
                  height: 32,
                  decoration: BoxDecoration(
                    color: color,
                    borderRadius: BorderRadius.circular(3),
                  ),
                ),
                const SizedBox(width: 12),
                Expanded(
                  child: Text(
                    _userRole == UserRole.teacher
                        ? course.name
                        : (course.subject ?? course.name),
                    style: ts.titleLarge?.copyWith(fontWeight: FontWeight.bold),
                  ),
                ),
              ],
            ),
            const SizedBox(height: 16),
            _detailRow(context, Icons.schedule, '时间',
                '${slot.label} ${slot.startTime.formatted} - ${slot.endTime.formatted}'),
            if (course.name.isNotEmpty)
              _detailRow(context, Icons.class_, '班级', course.name),
            if (course.teacher != null && course.teacher!.isNotEmpty)
              _detailRow(context, Icons.person_outline, '教师', course.teacher!),
            if (course.location != null && course.location!.isNotEmpty)
              _detailRow(context, Icons.location_on_outlined, '地点', course.location!),
            const SizedBox(height: 20),
            // Edit and Delete buttons
            Row(
              children: [
                Expanded(
                  child: OutlinedButton.icon(
                    onPressed: () {
                      Navigator.pop(ctx);
                      final dayName = dayNamesShort[course.dayOfWeek - 1];
                      _showCourseFormSheet(
                        title: '编辑课程',
                        course: course,
                        dayOfWeek: course.dayOfWeek,
                        period: course.period,
                        slotLabel: '周$dayName ${slot.label} ${slot.startTime.formatted}-${slot.endTime.formatted}',
                      );
                    },
                    icon: const Icon(Icons.edit, size: 18),
                    label: const Text('编辑'),
                  ),
                ),
                const SizedBox(width: 12),
                Expanded(
                  child: OutlinedButton.icon(
                    onPressed: () {
                      Navigator.pop(ctx);
                      _confirmDeleteCourse(course);
                    },
                    icon: const Icon(Icons.delete_outline, size: 18),
                    label: const Text('删除'),
                    style: OutlinedButton.styleFrom(
                      foregroundColor: cs.error,
                      side: BorderSide(color: cs.error.withOpacity(0.5)),
                    ),
                  ),
                ),
              ],
            ),
            const SizedBox(height: 8),
            SizedBox(
              width: double.infinity,
              child: TextButton(
                onPressed: () => Navigator.pop(ctx),
                child: const Text('关闭'),
              ),
            ),
          ],
        ),
      ),
    );
  }

  /// Show confirmation dialog and delete course.
  void _confirmDeleteCourse(Course course) {
    showDialog(
      context: context,
      builder: (ctx) => AlertDialog(
        title: const Text('删除课程'),
        content: Text('确定要删除「${_userRole == UserRole.teacher ? course.name : (course.subject ?? course.name)}」吗？此操作不可撤销。'),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(ctx),
            child: const Text('取消'),
          ),
          TextButton(
            onPressed: () async {
              Navigator.pop(ctx);
              await _db.deleteCourse(course.id!);
              await _loadCourses();
              if (mounted) {
                ScaffoldMessenger.of(context).showSnackBar(
                  const SnackBar(content: Text('课程已删除')),
                );
              }
            },
            style: TextButton.styleFrom(foregroundColor: Theme.of(context).colorScheme.error),
            child: const Text('删除'),
          ),
        ],
      ),
    );
  }

  /// Show the add/edit course form bottom sheet.
  void _showCourseFormSheet({
    required String title,
    required Course? course,
    required int dayOfWeek,
    required int period,
    required String slotLabel,
  }) {
    final isEditing = course != null;

    showModalBottomSheet(
      context: context,
      isScrollControlled: true,
      builder: (ctx) => _CourseFormSheet(
        title: title,
        initialCourse: course,
        dayOfWeek: dayOfWeek,
        period: period,
        slotLabel: slotLabel,
        isEditing: isEditing,
        onSaved: () async {
          await _loadCourses();
        },
      ),
    );
  }

  // ═══════════════════════════════════════════

  @override
  Widget build(BuildContext context) {
    final cs = context.colorScheme;
    final ts = context.textTheme;
    final monday = _weekMonday;

    return Scaffold(
      appBar: AppBar(
        title: Text('课表', style: ts.titleLarge?.copyWith(fontSize: 18)),
        actions: [
          // Saturday mode toggle
          PopupMenuButton<SaturdayMode>(
            icon: Icon(
              _saturdayMode == SaturdayMode.off
                  ? Icons.calendar_view_week
                  : Icons.view_week,
            ),
            tooltip: '周六模式',
            onSelected: _setSaturdayMode,
            itemBuilder: (_) => [
              const PopupMenuItem(
                value: SaturdayMode.off,
                child: Text('隐藏周六'),
              ),
              const PopupMenuItem(
                value: SaturdayMode.round1,
                child: Text('周六轮次 1'),
              ),
              const PopupMenuItem(
                value: SaturdayMode.round2,
                child: Text('周六轮次 2'),
              ),
              const PopupMenuItem(
                value: SaturdayMode.round3,
                child: Text('周六轮次 3'),
              ),
            ],
          ),
          IconButton(
            icon: const Icon(Icons.refresh),
            onPressed: _loadCourses,
            tooltip: '刷新',
          ),
        ],
      ),
      body: Column(
        children: [
          // ─── Week navigation bar ───
          _buildWeekNavigator(context, monday),
          // ─── Timetable grid ───
          Expanded(
            child: _isLoading
                ? const Center(child: CircularProgressIndicator())
                : _buildTimetableGrid(context),
          ),
        ],
      ),
    );
  }

  /// Week navigator bar.
  Widget _buildWeekNavigator(BuildContext context, DateTime monday) {
    final cs = context.colorScheme;
    final ts = context.textTheme;
    final sunday = monday.add(const Duration(days: 6));

    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
      color: cs.surface,
      child: Row(
        mainAxisAlignment: MainAxisAlignment.spaceBetween,
        children: [
          IconButton(
            icon: const Icon(Icons.chevron_left),
            onPressed: _prevWeek,
            iconSize: 28,
          ),
          GestureDetector(
            onTap: _goToThisWeek,
            child: Column(
              children: [
                Text(
                  _weekLabel,
                  style: ts.titleSmall?.copyWith(
                    color: cs.primary,
                    fontWeight: FontWeight.bold,
                  ),
                ),
                Text(
                  '${monday.month}/${monday.day} - ${sunday.month}/${sunday.day}',
                  style: ts.bodySmall?.copyWith(color: cs.onSurfaceVariant),
                ),
              ],
            ),
          ),
          IconButton(
            icon: const Icon(Icons.chevron_right),
            onPressed: _nextWeek,
            iconSize: 28,
          ),
        ],
      ),
    );
  }

  /// Main timetable grid.
  Widget _buildTimetableGrid(BuildContext context) {
    final cs = context.colorScheme;
    final int lastPeriod = _schoolType == SchoolType.university ? 9 : 12;
    final int periodCount = lastPeriod + 1;

    return SingleChildScrollView(
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          // ─── 固定左侧时间列 ───
          Column(
            children: [
              // 左上角空格
              _buildTimeHeaderCell(context),
              // 时间标签列
              ...List.generate(periodCount, (i) => _buildTimeLabelCell(context, i)),
            ],
          ),
          // ─── 可水平滚动的课表区域 ───
          Expanded(
            child: SingleChildScrollView(
              scrollDirection: Axis.horizontal,
              child: Column(
                children: [
                  // 星期头部行
                  _buildDayHeaderScrollable(context),
                  // 课程行
                  ...List.generate(periodCount, (i) => _buildPeriodRowScrollable(context, i)),
                ],
              ),
            ),
          ),
        ],
      ),
    );
  }

  /// 左上角"节次"表头
  Widget _buildTimeHeaderCell(BuildContext context) {
    final cs = context.colorScheme;
    final ts = context.textTheme;
    return GestureDetector(
      onTap: _showTimeSlotEditor,
      child: Container(
        width: 60, height: 52,
        decoration: BoxDecoration(
          color: cs.surface,
          border: Border(bottom: BorderSide(color: cs.outlineVariant, width: 0.5)),
        ),
        child: Center(
          child: Column(
            mainAxisAlignment: MainAxisAlignment.center,
            children: [
              Text('节次', style: ts.labelSmall?.copyWith(color: cs.onSurfaceVariant, fontWeight: FontWeight.w500)),
              Icon(Icons.edit, size: 10, color: cs.onSurfaceVariant.withOpacity(0.5)),
            ],
          ),
        ),
      ),
    );
  }

  /// 固定的时间标签单元格
  Widget _buildTimeLabelCell(BuildContext context, int period) {
    final cs = context.colorScheme;
    final ts = context.textTheme;
    final slot = getTimeSlot(period, schoolType: _schoolType);

    return GestureDetector(
      onTap: _showTimeSlotEditor,
      child: Container(
        width: 60, height: 52,
        decoration: BoxDecoration(
          color: cs.surface,
          border: Border(bottom: BorderSide(color: cs.outlineVariant, width: 0.3)),
        ),
        child: Padding(
          padding: const EdgeInsets.symmetric(vertical: 4, horizontal: 4),
          child: Column(
            mainAxisAlignment: MainAxisAlignment.center,
            children: [
              Text(slot.label, style: ts.labelSmall?.copyWith(fontWeight: FontWeight.w600, fontSize: 11, color: cs.onSurface), maxLines: 1, overflow: TextOverflow.ellipsis),
              const SizedBox(height: 1),
              Text(slot.startTime.formatted, style: ts.labelSmall?.copyWith(fontSize: 9, color: cs.onSurfaceVariant)),
            ],
          ),
        ),
      ),
    );
  }

  /// 可滚动的星期头部
  Widget _buildDayHeaderScrollable(BuildContext context) {
    final cs = context.colorScheme;
    final ts = context.textTheme;
    return Container(
      height: 52,
      decoration: BoxDecoration(
        color: cs.surface,
        border: Border(bottom: BorderSide(color: cs.outlineVariant, width: 0.5)),
      ),
      child: Row(
        children: List.generate(_visibleDays, (col) {
          final date = _dateForColumn(col);
          final today = _isToday(col);
          final dayName = dayNamesShort[col];
          return Container(
            width: 80,
            decoration: BoxDecoration(
              color: today ? cs.primary.withOpacity(0.08) : Colors.transparent,
              border: Border(left: BorderSide(color: cs.outlineVariant, width: 0.3)),
            ),
            child: Column(
              mainAxisAlignment: MainAxisAlignment.center,
              children: [
                Text('周$dayName', style: ts.labelSmall?.copyWith(color: today ? cs.primary : cs.onSurfaceVariant, fontWeight: today ? FontWeight.bold : FontWeight.normal)),
                const SizedBox(height: 2),
                Text('${date.month}/${date.day}', style: ts.labelSmall?.copyWith(color: today ? cs.primary : cs.onSurfaceVariant, fontSize: 10)),
              ],
            ),
          );
        }),
      ),
    );
  }

  /// 可滚动的课程行
  Widget _buildPeriodRowScrollable(BuildContext context, int period) {
    final cs = context.colorScheme;
    final List<Widget> cells = [];

    for (int col = 0; col < _visibleDays; col++) {
      final dayOfWeek = col + 1;
      final course = _allCourses.cast<Course?>().firstWhere(
            (c) => c!.dayOfWeek == dayOfWeek && c.period == period,
            orElse: () => null,
          );
      final today = _isToday(col);

      Color bgColor = Colors.transparent;
      Color borderColor = cs.outlineVariant.withOpacity(0.3);

      if (course != null) {
        final color = getCourseColor(course.color, isDark: context.isDarkMode);
        if (_isCurrentClass(course, col)) {
          bgColor = AppTheme.currentClassColor.withOpacity(0.15);
          borderColor = AppTheme.currentClassColor;
        } else if (_isNextClass(course, col)) {
          bgColor = AppTheme.nextClassColor.withOpacity(0.1);
          borderColor = AppTheme.nextClassColor;
        } else {
          bgColor = color.withOpacity(0.08);
          borderColor = color.withOpacity(0.3);
        }
      } else if (today) {
        bgColor = cs.primary.withOpacity(0.03);
      }

      cells.add(
        GestureDetector(
          onTap: () {
            if (course != null) { _onCourseTapped(course); } else { _onEmptyCellTapped(dayOfWeek, period); }
          },
          child: Container(
            width: 80, height: 52,
            decoration: BoxDecoration(
              color: bgColor,
              border: Border(left: BorderSide(color: cs.outlineVariant, width: 0.3), bottom: BorderSide(color: cs.outlineVariant, width: 0.3)),
            ),
            child: course != null
                ? _buildCourseCell(context, course, col)
                : Center(child: Icon(Icons.add, size: 16, color: cs.onSurfaceVariant.withOpacity(0.2))),
          ),
        ),
      );
    }

    return Row(children: cells);
  }

  /// 时间段编辑器
  void _showTimeSlotEditor() {
    final cs = context.colorScheme;
    final ts = context.textTheme;
    final slots = getDefaultTimeSlots(_schoolType).toList(); // mutable copy

    showModalBottomSheet(
      context: context,
      isScrollControlled: true,
      builder: (ctx) => DraggableScrollableSheet(
        initialChildSize: 0.7,
        maxChildSize: 0.9,
        minChildSize: 0.4,
        expand: false,
        builder: (ctx, scrollController) => StatefulBuilder(
          builder: (ctx, setSheetState) => Column(
            children: [
              Padding(
                padding: const EdgeInsets.all(16),
                child: Row(
                  children: [
                    Icon(Icons.schedule, color: cs.primary),
                    const SizedBox(width: 8),
                    Text('作息时间表（点击编辑）', style: ts.titleMedium?.copyWith(fontWeight: FontWeight.bold)),
                    const Spacer(),
                    TextButton(
                      onPressed: () => Navigator.pop(ctx),
                      child: const Text('关闭'),
                    ),
                  ],
                ),
              ),
              Expanded(
                child: ListView.builder(
                  controller: scrollController,
                  itemCount: slots.length,
                  itemBuilder: (ctx, i) {
                    final slot = slots[i];
                    return ListTile(
                      leading: Container(
                        width: 40, height: 40,
                        decoration: BoxDecoration(color: cs.primary.withOpacity(0.1), borderRadius: BorderRadius.circular(10)),
                        child: Center(child: Text('\${slot.period}', style: TextStyle(color: cs.primary, fontWeight: FontWeight.bold))),
                      ),
                      title: Text(slot.label, style: ts.bodyMedium?.copyWith(fontWeight: FontWeight.w500)),
                      subtitle: Text('\${slot.startTime.formatted} - \${slot.endTime.formatted}', style: ts.bodySmall?.copyWith(color: cs.onSurfaceVariant)),
                      trailing: Icon(Icons.edit, size: 16, color: cs.onSurfaceVariant),
                      onTap: () async {
                        // 编辑开始时间
                        final newStart = await showTimePicker(
                          context: ctx,
                          initialTime: slot.startTime,
                          helpText: '\${slot.label} 开始时间',
                        );
                        if (newStart == null) return;

                        // 编辑结束时间
                        final newEnd = await showTimePicker(
                          context: ctx,
                          initialTime: slot.endTime,
                          helpText: '\${slot.label} 结束时间',
                        );
                        if (newEnd == null) return;

                        // 更新
                        setSheetState(() {
                          slots[i] = TimeSlot(
                            period: slot.period,
                            startTime: newStart,
                            endTime: newEnd,
                            label: slot.label,
                            isSaturdayAfternoon: slot.isSaturdayAfternoon,
                          );
                        });

                        // 保存到本地
                        _saveCustomTimeSlots(slots);
                      },
                    );
                  },
                ),
              ),
              Padding(
                padding: const EdgeInsets.all(16),
                child: Row(
                  children: [
                    Icon(Icons.info_outline, size: 14, color: cs.onSurfaceVariant),
                    const SizedBox(width: 6),
                    Expanded(
                      child: Text(
                        '点击任意行编辑上下课时间，自动保存并同步到提醒',
                        style: ts.bodySmall?.copyWith(color: cs.onSurfaceVariant, fontSize: 12),
                      ),
                    ),
                    TextButton(
                      onPressed: () {
                        setSheetState(() {
                          slots.clear();
                          slots.addAll(getDefaultTimeSlots(_schoolType));
                        });
                        _saveCustomTimeSlots(slots);
                      },
                      child: const Text('恢复默认', style: TextStyle(fontSize: 12)),
                    ),
                  ],
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }

  /// 保存自定义时间表到SharedPreferences
  Future<void> _saveCustomTimeSlots(List<TimeSlot> slots) async {
    try {
      final prefs = await SharedPreferences.getInstance();
      final data = slots.map((s) => '\${s.period}|\${s.startTime.hour}:\${s.startTime.minute}|\${s.endTime.hour}:\${s.endTime.minute}|\${s.label}').join(';');
      final key = _schoolType == SchoolType.university ? 'custom_time_slots_uni' : 'custom_time_slots_hs';
      await prefs.setString(key, data);
      if (mounted) context.showSuccessSnackBar('时间表已保存');
    } catch (e) {
      if (mounted) context.showErrorSnackBar('保存失败: \$e');
    }
  }

  /// Course content inside a timetable cell.
  Widget _buildCourseCell(BuildContext context, Course course, int col) {
    final ts = context.textTheme;
    final color = getCourseColor(course.color, isDark: context.isDarkMode);
    final isCurrent = _isCurrentClass(course, col);
    final isNext = _isNextClass(course, col);

    final Color textColor = isCurrent
        ? AppTheme.currentClassColor
        : isNext
            ? AppTheme.nextClassColor
            : color;

    // 根据角色决定显示内容
    final String mainText;
    final String? subText;

    if (_userRole == UserRole.teacher) {
      // 教师版: 班级名(主) + 科目(副)
      mainText = course.name;
      subText = course.subject;
    } else {
      // 学生版: 科目(主) + 教室(副)
      mainText = course.subject ?? course.name;
      subText = course.location;
    }

    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 4, vertical: 4),
      child: Column(
        mainAxisAlignment: MainAxisAlignment.center,
        children: [
          if (isCurrent || isNext)
            Container(
              width: 6,
              height: 6,
              margin: const EdgeInsets.only(bottom: 2),
              decoration: BoxDecoration(
                color: isCurrent
                    ? AppTheme.currentClassColor
                    : AppTheme.nextClassColor,
                shape: BoxShape.circle,
              ),
            ),
          Flexible(
            child: Text(
              mainText,
              style: ts.labelSmall?.copyWith(
                color: textColor,
                fontWeight: FontWeight.w600,
                fontSize: 10,
              ),
              textAlign: TextAlign.center,
              maxLines: 2,
              overflow: TextOverflow.ellipsis,
            ),
          ),
          if (subText != null && subText.isNotEmpty)
            Text(
              subText,
              style: ts.labelSmall?.copyWith(
                color: textColor.withOpacity(0.7),
                fontSize: 8,
              ),
              maxLines: 1,
              overflow: TextOverflow.ellipsis,
            ),
        ],
      ),
    );
  }

  Widget _detailRow(BuildContext context, IconData icon, String label, String value) {
    final cs = context.colorScheme;
    final ts = context.textTheme;

    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 6),
      child: Row(
        children: [
          Icon(icon, size: 18, color: cs.onSurfaceVariant),
          const SizedBox(width: 8),
          Text(
            '$label: ',
            style: ts.bodyMedium?.copyWith(color: cs.onSurfaceVariant),
          ),
          Expanded(
            child: Text(value, style: ts.bodyMedium),
          ),
        ],
      ),
    );
  }
}

// ═══════════════════════════════════════════════════════════════════
// Course Form Sheet (Add / Edit)
// ═══════════════════════════════════════════════════════════════════

class _CourseFormSheet extends StatefulWidget {
  final String title;
  final Course? initialCourse;
  final int dayOfWeek;
  final int period;
  final String slotLabel;
  final bool isEditing;
  final VoidCallback onSaved;

  const _CourseFormSheet({
    required this.title,
    this.initialCourse,
    required this.dayOfWeek,
    required this.period,
    required this.slotLabel,
    required this.isEditing,
    required this.onSaved,
  });

  @override
  State<_CourseFormSheet> createState() => _CourseFormSheetState();
}

class _CourseFormSheetState extends State<_CourseFormSheet> {
  final _formKey = GlobalKey<FormState>();
  late final TextEditingController _nameController;
  late final TextEditingController _subjectController;
  late final TextEditingController _locationController;
  late int _selectedColor;
  bool _isSaving = false;

  @override
  void initState() {
    super.initState();
    final c = widget.initialCourse;
    _nameController = TextEditingController(text: c?.name ?? '');
    _subjectController = TextEditingController(text: c?.subject ?? '');
    _locationController = TextEditingController(text: c?.location ?? '');
    _selectedColor = c?.color ?? 0;
  }

  @override
  void dispose() {
    _nameController.dispose();
    _subjectController.dispose();
    _locationController.dispose();
    super.dispose();
  }

  Future<void> _save() async {
    if (!_formKey.currentState!.validate()) return;

    setState(() => _isSaving = true);

    final db = DatabaseService.instance;

    try {
      if (widget.isEditing && widget.initialCourse != null) {
        // Update existing course
        final updated = widget.initialCourse!.copyWith(
          name: _nameController.text.trim(),
          subject: _subjectController.text.trim().isEmpty
              ? null
              : _subjectController.text.trim(),
          location: _locationController.text.trim().isEmpty
              ? null
              : _locationController.text.trim(),
          color: _selectedColor,
        );
        await db.updateCourse(updated);
      } else {
        // Insert new course
        final newCourse = Course(
          name: _nameController.text.trim(),
          subject: _subjectController.text.trim().isEmpty
              ? null
              : _subjectController.text.trim(),
          dayOfWeek: widget.dayOfWeek,
          period: widget.period,
          location: _locationController.text.trim().isEmpty
              ? null
              : _locationController.text.trim(),
          color: _selectedColor,
        );
        await db.insertCourse(newCourse);
      }

      widget.onSaved();
      if (mounted) {
        Navigator.pop(context);
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text(widget.isEditing ? '课程已更新' : '课程已添加'),
          ),
        );
      }
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('保存失败: $e')),
        );
      }
    } finally {
      if (mounted) setState(() => _isSaving = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    final cs = context.colorScheme;
    final ts = context.textTheme;

    return Padding(
      padding: EdgeInsets.only(
        left: 24,
        right: 24,
        top: 24,
        bottom: MediaQuery.of(context).viewInsets.bottom + 24,
      ),
      child: SingleChildScrollView(
        child: Form(
          key: _formKey,
          child: Column(
            mainAxisSize: MainAxisSize.min,
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              // Title
              Row(
                children: [
                  Icon(
                    widget.isEditing ? Icons.edit : Icons.add_circle_outline,
                    color: cs.primary,
                  ),
                  const SizedBox(width: 8),
                  Text(
                    widget.title,
                    style: ts.titleLarge?.copyWith(fontWeight: FontWeight.bold),
                  ),
                ],
              ),
              const SizedBox(height: 8),
              // Slot info
              Container(
                padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
                decoration: BoxDecoration(
                  color: cs.primaryContainer.withOpacity(0.3),
                  borderRadius: BorderRadius.circular(8),
                ),
                child: Row(
                  children: [
                    Icon(Icons.schedule, size: 16, color: cs.primary),
                    const SizedBox(width: 8),
                    Text(
                      widget.slotLabel,
                      style: ts.bodySmall?.copyWith(color: cs.primary),
                    ),
                  ],
                ),
              ),
              const SizedBox(height: 20),

              // Course name (required)
              TextFormField(
                controller: _nameController,
                decoration: InputDecoration(
                  labelText: '课程名称 *',
                  hintText: '如: 高一1班',
                  prefixIcon: const Icon(Icons.class_),
                  border: OutlineInputBorder(
                    borderRadius: BorderRadius.circular(12),
                  ),
                ),
                textInputAction: TextInputAction.next,
                validator: (v) {
                  if (v == null || v.trim().isEmpty) return '请输入课程名称';
                  return null;
                },
              ),
              const SizedBox(height: 12),

              // Subject (optional)
              TextFormField(
                controller: _subjectController,
                decoration: InputDecoration(
                  labelText: '科目',
                  hintText: '如: 数学',
                  prefixIcon: const Icon(Icons.book_outlined),
                  border: OutlineInputBorder(
                    borderRadius: BorderRadius.circular(12),
                  ),
                ),
                textInputAction: TextInputAction.next,
              ),
              const SizedBox(height: 12),

              // Location (optional)
              TextFormField(
                controller: _locationController,
                decoration: InputDecoration(
                  labelText: '地点',
                  hintText: '如: 教学楼301',
                  prefixIcon: const Icon(Icons.location_on_outlined),
                  border: OutlineInputBorder(
                    borderRadius: BorderRadius.circular(12),
                  ),
                ),
                textInputAction: TextInputAction.done,
              ),
              const SizedBox(height: 20),

              // Color picker
              Text(
                '颜色',
                style: ts.titleSmall?.copyWith(fontWeight: FontWeight.w600),
              ),
              const SizedBox(height: 10),
              Wrap(
                spacing: 10,
                runSpacing: 10,
                children: List.generate(courseColors.length, (index) {
                  final color = courseColors[index];
                  final isSelected = _selectedColor == index;
                  return GestureDetector(
                    onTap: () => setState(() => _selectedColor = index),
                    child: AnimatedContainer(
                      duration: const Duration(milliseconds: 200),
                      width: 40,
                      height: 40,
                      decoration: BoxDecoration(
                        color: color,
                        shape: BoxShape.circle,
                        border: Border.all(
                          color: isSelected ? cs.onSurface : Colors.transparent,
                          width: isSelected ? 3 : 0,
                        ),
                        boxShadow: isSelected
                            ? [
                                BoxShadow(
                                  color: color.withOpacity(0.4),
                                  blurRadius: 8,
                                  spreadRadius: 1,
                                ),
                              ]
                            : null,
                      ),
                      child: isSelected
                          ? Icon(Icons.check, color: Colors.white, size: 20)
                          : null,
                    ),
                  );
                }),
              ),
              const SizedBox(height: 28),

              // Save button
              SizedBox(
                width: double.infinity,
                height: 48,
                child: ElevatedButton(
                  onPressed: _isSaving ? null : _save,
                  style: ElevatedButton.styleFrom(
                    backgroundColor: cs.primary,
                    foregroundColor: cs.onPrimary,
                    shape: RoundedRectangleBorder(
                      borderRadius: BorderRadius.circular(12),
                    ),
                  ),
                  child: _isSaving
                      ? SizedBox(
                          width: 20,
                          height: 20,
                          child: CircularProgressIndicator(
                            strokeWidth: 2,
                            color: cs.onPrimary,
                          ),
                        )
                      : Text(
                          widget.isEditing ? '保存修改' : '添加课程',
                          style: const TextStyle(
                            fontSize: 16,
                            fontWeight: FontWeight.w600,
                          ),
                        ),
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}
