import 'package:flutter/material.dart';
import 'package:shared_preferences/shared_preferences.dart';

import '../models/app_mode.dart';
import '../utils/constants.dart';

/// 自定义作息时间服务。
///
/// 编辑器把每节课的起止时间保存到 SharedPreferences（历史格式：
/// "period|H:m|H:m|label"，多条以 ";" 分隔）。本服务在 [load] 时读入内存，
/// [getSlots] 同步返回「覆盖后」的列表；[getDefaultTimeSlots] / [getTimeSlot]
/// 委托到这里，于是首页 / 课表 / 通知 / 日历的时间查询都能拿到用户设置。
/// [timeSlotVersion] 在覆盖变化时自增，常驻页面据此重建、提醒页据此重排通知。
class TimeSlotService {
  TimeSlotService._();
  static final TimeSlotService instance = TimeSlotService._();

  static const String keyHighSchool = 'custom_time_slots_hs';
  static const String keyUniversity = 'custom_time_slots_uni';

  /// 作息数据版本号。
  static final ValueNotifier<int> timeSlotVersion = ValueNotifier<int>(0);

  String? _rawHighSchool;
  String? _rawUniversity;
  List<TimeSlot>? _highSchoolOverride;
  List<TimeSlot>? _universityOverride;

  /// 在 main() 中、runApp 之前调用，保证首帧即为已保存的作息。
  Future<void> load() async {
    try {
      final prefs = await SharedPreferences.getInstance();
      _rawHighSchool = prefs.getString(keyHighSchool);
      _rawUniversity = prefs.getString(keyUniversity);
    } catch (_) {
      _rawHighSchool = null;
      _rawUniversity = null;
    }
    _highSchoolOverride = _decode(_rawHighSchool);
    _universityOverride = _decode(_rawUniversity);
  }

  bool hasCustom(SchoolType type) => _override(type) != null;

  /// 同步返回当前生效的作息列表；无自定义时返回内置常量列表。
  /// 返回只读引用，调用方需要可修改副本时请 .toList()。
  List<TimeSlot> getSlots(SchoolType type) {
    final override = _override(type);
    if (override != null) return override;
    switch (type) {
      case SchoolType.highSchool:
        return defaultTimeSlots;
      case SchoolType.university:
        return universityTimeSlots;
    }
  }

  /// 保存自定义作息：更新内存、落盘、通知各页面刷新 / 重排提醒。
  Future<void> applyCustom(SchoolType type, List<TimeSlot> slots) async {
    final raw = _encode(slots);
    _setRaw(type, raw);
    _setOverride(type, _decode(raw));
    await _writeRaw(type, raw);
    _bump();
  }

  /// 恢复内置默认作息。
  Future<void> resetToDefault(SchoolType type) async {
    _setRaw(type, null);
    _setOverride(type, null);
    await _writeRaw(type, null);
    _bump();
  }

  /// 导出原始自定义字符串，供完整备份使用。
  Map<String, dynamic> exportRaw() => <String, dynamic>{
        'highSchool': _rawHighSchool,
        'university': _rawUniversity,
      };

  /// 从备份恢复自定义作息；缺失 / null 表示恢复内置默认。
  Future<void> importRaw(dynamic raw) async {
    final hs = raw is Map ? raw['highSchool'] : null;
    final uni = raw is Map ? raw['university'] : null;
    final hsRaw = hs is String && hs.isNotEmpty ? hs : null;
    final uniRaw = uni is String && uni.isNotEmpty ? uni : null;
    _setRaw(SchoolType.highSchool, hsRaw);
    _setRaw(SchoolType.university, uniRaw);
    _highSchoolOverride = _decode(hsRaw);
    _universityOverride = _decode(uniRaw);
    await _writeRaw(SchoolType.highSchool, hsRaw);
    await _writeRaw(SchoolType.university, uniRaw);
    _bump();
  }

  List<TimeSlot>? _override(SchoolType type) =>
      type == SchoolType.university ? _universityOverride : _highSchoolOverride;

  void _setOverride(SchoolType type, List<TimeSlot>? value) {
    if (type == SchoolType.university) {
      _universityOverride = value;
    } else {
      _highSchoolOverride = value;
    }
  }

  void _setRaw(SchoolType type, String? value) {
    if (type == SchoolType.university) {
      _rawUniversity = value;
    } else {
      _rawHighSchool = value;
    }
  }

  String _key(SchoolType type) =>
      type == SchoolType.university ? keyUniversity : keyHighSchool;

  Future<void> _writeRaw(SchoolType type, String? raw) async {
    try {
      final prefs = await SharedPreferences.getInstance();
      if (raw == null || raw.isEmpty) {
        await prefs.remove(_key(type));
      } else {
        await prefs.setString(_key(type), raw);
      }
    } catch (_) {}
  }

  static String _encode(List<TimeSlot> slots) => slots
      .map((s) => '${s.period}|${s.startTime.hour}:${s.startTime.minute}|'
          '${s.endTime.hour}:${s.endTime.minute}|${s.label}')
      .join(';');

  static List<TimeSlot>? _decode(String? raw) {
    if (raw == null || raw.trim().isEmpty) return null;
    final result = <TimeSlot>[];
    for (final part in raw.split(';')) {
      final fields = part.split('|');
      if (fields.length < 4) continue;
      final period = int.tryParse(fields[0].trim());
      final start = _parseTime(fields[1]);
      final end = _parseTime(fields[2]);
      if (period == null || start == null || end == null) continue;
      result.add(TimeSlot(
        period: period,
        startTime: start,
        endTime: end,
        label: fields.sublist(3).join('|'),
      ));
    }
    if (result.isEmpty) return null;
    result.sort((a, b) => a.period.compareTo(b.period));
    return List<TimeSlot>.unmodifiable(result);
  }

  static TimeOfDay? _parseTime(String value) {
    final parts = value.trim().split(':');
    if (parts.length != 2) return null;
    final h = int.tryParse(parts[0]);
    final m = int.tryParse(parts[1]);
    if (h == null || m == null || h < 0 || h > 23 || m < 0 || m > 59) {
      return null;
    }
    return TimeOfDay(hour: h, minute: m);
  }

  static void _bump() {
    timeSlotVersion.value = timeSlotVersion.value + 1;
  }
}
