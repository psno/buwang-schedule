import 'package:flutter/material.dart';
import 'dart:async';

import '../models/course.dart';
import '../models/app_mode.dart';
import '../utils/constants.dart';
import '../utils/extensions.dart';
import '../services/database_service.dart';
import '../theme/app_theme.dart';

/// 不忘课表 - Home Screen (今日)
/// Shows today's schedule with current/next class cards and countdown.
class HomeScreen extends StatefulWidget {
  const HomeScreen({super.key});

  @override
  State<HomeScreen> createState() => _HomeScreenState();
}

class _HomeScreenState extends State<HomeScreen> {
  final DatabaseService _db = DatabaseService.instance;
  List<Course> _todayCourses = [];
  bool _isLoading = true;
  Timer? _timer;
  DateTime _now = DateTime.now();
  SchoolType _schoolType = SchoolType.highSchool;
  UserRole _userRole = UserRole.student;

  @override
  void initState() {
    super.initState();
    _loadTodayCourses();
    _loadSchoolType();
    _loadUserRole();
    // Update every minute for countdown
    _timer = Timer.periodic(const Duration(minutes: 1), (_) {
      setState(() => _now = DateTime.now());
    });
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

  @override
  void dispose() {
    _timer?.cancel();
    super.dispose();
  }

  Future<void> _loadTodayCourses() async {
    setState(() => _isLoading = true);
    try {
      // weekday: 1=Monday..7=Sunday, dayOfWeek in DB: 1=Mon..6=Sat
      final today = DateTime.now().weekday;
      if (today <= 6) {
        _todayCourses = await _db.getCoursesForDay(today);
      } else {
        _todayCourses = [];
      }
    } catch (e) {
      _todayCourses = [];
    }
    if (mounted) setState(() => _isLoading = false);
  }

  @override
  Widget build(BuildContext context) {
    final cs = context.colorScheme;
    final ts = context.textTheme;
    final now = _now;
    final dayName = now.dayOfWeekChinese;
    final dateStr = now.dateFormattedFullChinese;

    return Scaffold(
      appBar: AppBar(
        title: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text('今日课表', style: ts.titleLarge?.copyWith(fontSize: 18)),
            Text(
              '$dayName · $dateStr',
              style: ts.bodySmall?.copyWith(color: cs.onSurfaceVariant),
            ),
          ],
        ),
        actions: [
          IconButton(
            icon: const Icon(Icons.refresh),
            onPressed: _loadTodayCourses,
            tooltip: '刷新',
          ),
        ],
      ),
      body: _isLoading
          ? const Center(child: CircularProgressIndicator())
          : RefreshIndicator(
              onRefresh: _loadTodayCourses,
              child: ListView(
                padding: const EdgeInsets.symmetric(vertical: 8),
                children: [
                  // ─── Status card ───
                  _buildStatusCard(context),
                  const SizedBox(height: 16),
                  // ─── Today's schedule list ───
                  if (_todayCourses.isEmpty)
                    _buildEmptyState(context)
                  else ...[
                    Padding(
                      padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 4),
                      child: Text(
                        '今日课程 (${_todayCourses.length}节)',
                        style: ts.titleSmall?.copyWith(
                          color: cs.onSurfaceVariant,
                          fontWeight: FontWeight.w600,
                        ),
                      ),
                    ),
                    const SizedBox(height: 4),
                    ..._todayCourses.map((c) => _buildCourseTimelineCard(context, c)),
                  ],
                  const SizedBox(height: 16),
                ],
              ),
            ),
    );
  }

  /// Top status card: current class or next class with countdown.
  Widget _buildStatusCard(BuildContext context) {
    final cs = context.colorScheme;
    final ts = context.textTheme;
    final now = _now;

    // Find current and next class
    Course? currentCourse;
    Course? nextCourse;
    TimeSlot? currentTimeSlot;
    TimeSlot? nextTimeSlot;

    for (final course in _todayCourses) {
      final slot = getTimeSlot(course.period, dayOfWeek: now.weekday, schoolType: _schoolType);
      final startMin = slot.startTime.hour * 60 + slot.startTime.minute;
      final endMin = slot.endTime.hour * 60 + slot.endTime.minute;
      final nowMin = now.hour * 60 + now.minute;

      if (nowMin >= startMin && nowMin < endMin) {
        currentCourse = course;
        currentTimeSlot = slot;
      } else if (nowMin < startMin && nextCourse == null) {
        nextCourse = course;
        nextTimeSlot = slot;
      }
    }

    // Build the status display
    final isCurrentlyInClass = currentCourse != null;
    final hasUpcoming = nextCourse != null;

    final Color accentColor = isCurrentlyInClass
        ? AppTheme.currentClassColor
        : hasUpcoming
            ? AppTheme.nextClassColor
            : cs.primary;

    final String statusText;
    final String detailText;

    if (isCurrentlyInClass) {
      final endParts = currentTimeSlot!.endTime;
      final endMin = endParts.hour * 60 + endParts.minute;
      final nowMin = now.hour * 60 + now.minute;
      final remaining = endMin - nowMin;
      statusText = '正在上课';
      final label = _userRole == UserRole.teacher
          ? '${currentCourse.name} · ${currentCourse.subject ?? ''}'
          : '${currentCourse.subject ?? currentCourse.name}';
      detailText = '$label · 还剩$remaining分钟';
    } else if (hasUpcoming) {
      final startParts = nextTimeSlot!.startTime;
      final startMin = startParts.hour * 60 + startParts.minute;
      final nowMin = now.hour * 60 + now.minute;
      final until = startMin - nowMin;
      statusText = '即将上课';
      final label = _userRole == UserRole.teacher
          ? '${nextCourse!.name} · ${nextCourse.subject ?? ''}'
          : '${nextCourse!.subject ?? nextCourse.name}';
      detailText = '$label · ${until}分钟后开始';
    } else if (_todayCourses.isNotEmpty) {
      statusText = '今日课程已结束';
      detailText = '今天共${_todayCourses.length}节课已全部完成';
    } else {
      statusText = '今日无课';
      detailText = now.weekday == 6 || now.weekday == 7 ? '享受周末吧 🎉' : '好好休息吧 😊';
    }

    return Card(
      margin: const EdgeInsets.symmetric(horizontal: 16, vertical: 6),
      color: cs.primaryContainer.withOpacity(0.4),
      shape: RoundedRectangleBorder(
        borderRadius: BorderRadius.circular(16),
        side: BorderSide.none,
      ),
      child: Padding(
        padding: const EdgeInsets.all(20),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(
              children: [
                Container(
                  width: 12,
                  height: 12,
                  decoration: BoxDecoration(
                    color: accentColor,
                    shape: BoxShape.circle,
                  ),
                ),
                const SizedBox(width: 8),
                Text(
                  statusText,
                  style: ts.titleMedium?.copyWith(
                    color: cs.onSurface,
                    fontWeight: FontWeight.bold,
                  ),
                ),
              ],
            ),
            const SizedBox(height: 8),
            Text(
              detailText,
              style: ts.bodyMedium?.copyWith(color: cs.onSurfaceVariant),
            ),
            if (isCurrentlyInClass && currentCourse != null) ...[
              const SizedBox(height: 12),
              _buildCompactCourseInfo(context, currentCourse, currentTimeSlot!),
            ] else if (hasUpcoming && nextCourse != null) ...[
              const SizedBox(height: 12),
              _buildCompactCourseInfo(context, nextCourse, nextTimeSlot!),
            ],
          ],
        ),
      ),
    );
  }

  /// Compact info row for the status card.
  Widget _buildCompactCourseInfo(BuildContext context, Course course, TimeSlot slot) {
    final cs = context.colorScheme;
    final ts = context.textTheme;
    final color = getCourseColor(course.color, isDark: context.isDarkMode);

    // 根据角色决定主标题和副标题
    final String mainTitle;
    final String subTitle;

    if (_userRole == UserRole.teacher) {
      // 教师版: 班级名(主) + 科目(副)
      mainTitle = course.name; // 高一1班
      subTitle = [
        if (course.subject != null && course.subject!.isNotEmpty) course.subject,
        if (course.location != null && course.location!.isNotEmpty) course.location,
      ].join(' · ');
    } else {
      // 学生版: 科目(主) + 老师(副)
      mainTitle = course.subject ?? course.name; // 数学
      subTitle = [
        if (course.teacher != null && course.teacher!.isNotEmpty) course.teacher,
        if (course.location != null && course.location!.isNotEmpty) course.location,
      ].join(' · ');
    }

    return Container(
      padding: const EdgeInsets.all(12),
      decoration: BoxDecoration(
        color: color.withOpacity(0.1),
        borderRadius: BorderRadius.circular(12),
      ),
      child: Row(
        children: [
          Container(
            width: 4,
            height: 40,
            decoration: BoxDecoration(
              color: color,
              borderRadius: BorderRadius.circular(2),
            ),
          ),
          const SizedBox(width: 12),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  mainTitle,
                  style: ts.titleSmall?.copyWith(
                    fontWeight: FontWeight.w600,
                    color: cs.onSurface,
                  ),
                ),
                if (subTitle.isNotEmpty) ...[
                  const SizedBox(height: 2),
                  Text(
                    subTitle,
                    style: ts.bodySmall?.copyWith(color: cs.onSurfaceVariant),
                  ),
                ],
              ],
            ),
          ),
          Text(
            '${slot.startTime.formatted} - ${slot.endTime.formatted}',
            style: ts.labelMedium?.copyWith(
              color: color,
              fontWeight: FontWeight.w600,
            ),
          ),
        ],
      ),
    );
  }

  /// Timeline card for each course in the list.
  Widget _buildCourseTimelineCard(BuildContext context, Course course) {
    final cs = context.colorScheme;
    final ts = context.textTheme;
    final color = getCourseColor(course.color, isDark: context.isDarkMode);
    final slot = getTimeSlot(course.period, dayOfWeek: DateTime.now().weekday, schoolType: _schoolType);
    final now = _now;
    final nowMin = now.hour * 60 + now.minute;
    final startMin = slot.startTime.hour * 60 + slot.startTime.minute;
    final endMin = slot.endTime.hour * 60 + slot.endTime.minute;

    final bool isCurrent = nowMin >= startMin && nowMin < endMin;
    final bool isPast = nowMin >= endMin;

    // 根据角色决定主标题和副标题
    final String mainTitle;
    final String? secondaryLine;

    if (_userRole == UserRole.teacher) {
      // 教师版: 班级名(主) + 科目 · 教室(副)
      mainTitle = course.name;
      final sub = [
        if (course.subject != null && course.subject!.isNotEmpty) course.subject,
        if (course.location != null && course.location!.isNotEmpty) course.location,
      ].join(' · ');
      secondaryLine = sub.isNotEmpty ? sub : null;
    } else {
      // 学生版: 科目(主) + 老师 · 教室(副)
      mainTitle = course.subject ?? course.name;
      final sub = [
        if (course.teacher != null && course.teacher!.isNotEmpty) course.teacher,
        if (course.location != null && course.location!.isNotEmpty) course.location,
      ].join(' · ');
      secondaryLine = sub.isNotEmpty ? sub : null;
    }

    final Color cardColor = isCurrent
        ? AppTheme.currentClassColor.withOpacity(0.08)
        : cs.surface;
    final Color borderColor = isCurrent
        ? AppTheme.currentClassColor
        : isPast
            ? cs.outlineVariant.withOpacity(0.5)
            : cs.outlineVariant;

    return Padding(
      padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 4),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          // Timeline line & dot
          SizedBox(
            width: 40,
            child: Column(
              children: [
                Container(
                  width: 8,
                  height: 8,
                  decoration: BoxDecoration(
                    color: isCurrent
                        ? AppTheme.currentClassColor
                        : isPast
                            ? cs.outlineVariant
                            : color,
                    shape: BoxShape.circle,
                  ),
                ),
                Container(
                  width: 2,
                  height: 60,
                  color: isPast ? cs.outlineVariant : color.withOpacity(0.3),
                ),
              ],
            ),
          ),
          // Course card
          Expanded(
            child: Card(
              color: cardColor,
              shape: RoundedRectangleBorder(
                borderRadius: BorderRadius.circular(14),
                side: BorderSide(color: borderColor, width: isCurrent ? 1.5 : 0.5),
              ),
              child: Padding(
                padding: const EdgeInsets.all(14),
                child: Row(
                  children: [
                    // Color bar
                    Container(
                      width: 4,
                      height: 48,
                      decoration: BoxDecoration(
                        color: color,
                        borderRadius: BorderRadius.circular(2),
                      ),
                    ),
                    const SizedBox(width: 12),
                    Expanded(
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Row(
                            children: [
                              Expanded(
                                child: Text(
                                  mainTitle,
                                  style: ts.titleSmall?.copyWith(
                                    fontWeight: FontWeight.w600,
                                    decoration: isPast
                                        ? TextDecoration.lineThrough
                                        : null,
                                    color: isPast
                                        ? cs.onSurfaceVariant
                                        : cs.onSurface,
                                  ),
                                ),
                              ),
                              if (isCurrent)
                                Container(
                                  padding: const EdgeInsets.symmetric(
                                    horizontal: 8,
                                    vertical: 2,
                                  ),
                                  decoration: BoxDecoration(
                                    color: AppTheme.currentClassColor,
                                    borderRadius: BorderRadius.circular(10),
                                  ),
                                  child: Text(
                                    '进行中',
                                    style: ts.labelSmall?.copyWith(
                                      color: Colors.white,
                                      fontWeight: FontWeight.w600,
                                    ),
                                  ),
                                ),
                            ],
                          ),
                          if (secondaryLine != null) ...[
                            const SizedBox(height: 4),
                            Row(
                              children: [
                                Icon(
                                  Icons.location_on_outlined,
                                  size: 14,
                                  color: cs.onSurfaceVariant,
                                ),
                                const SizedBox(width: 4),
                                Expanded(
                                  child: Text(
                                    secondaryLine,
                                    style: ts.bodySmall?.copyWith(
                                      color: cs.onSurfaceVariant,
                                    ),
                                    overflow: TextOverflow.ellipsis,
                                  ),
                                ),
                              ],
                            ),
                          ],
                          const SizedBox(height: 2),
                          Row(
                            children: [
                              Icon(
                                Icons.access_time,
                                size: 14,
                                color: cs.onSurfaceVariant,
                              ),
                              const SizedBox(width: 4),
                              Text(
                                '${slot.label} ${slot.startTime.formatted} - ${slot.endTime.formatted}',
                                style: ts.bodySmall?.copyWith(
                                  color: cs.onSurfaceVariant,
                                ),
                              ),
                            ],
                          ),
                        ],
                      ),
                    ),
                  ],
                ),
              ),
            ),
          ),
        ],
      ),
    );
  }

  /// Empty state when no courses today.
  Widget _buildEmptyState(BuildContext context) {
    final cs = context.colorScheme;
    final ts = context.textTheme;

    return Center(
      child: Padding(
        padding: const EdgeInsets.symmetric(vertical: 60),
        child: Column(
          children: [
            Icon(
              Icons.event_available,
              size: 64,
              color: cs.onSurfaceVariant.withOpacity(0.4),
            ),
            const SizedBox(height: 16),
            Text(
              '今天没有课程',
              style: ts.titleMedium?.copyWith(
                color: cs.onSurfaceVariant,
              ),
            ),
            const SizedBox(height: 8),
            Text(
              '去「课表」页面添加课程吧',
              style: ts.bodySmall?.copyWith(
                color: cs.onSurfaceVariant.withOpacity(0.7),
              ),
            ),
          ],
        ),
      ),
    );
  }
}
