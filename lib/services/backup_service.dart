import 'dart:convert';

import '../models/course.dart';
import 'database_service.dart';
import 'time_slot_service.dart';

/// 全量备份 / 撤销导入服务。
///
/// 导入课表是破坏性操作（清空 courses 表）。本服务在每次导入/恢复前把
/// 「课程 + 设置 + 自定义提醒 + 作息时间」完整快照写入 settings 表的
/// [backupKey]，并提供 [undoLastImport] 一键回滚，避免用户数据不可恢复。
/// 导出的 .json 文件也是这份全量快照，因此可被再次导入完整还原。
class BackupService {
  BackupService._();
  static final BackupService instance = BackupService._();

  static const String backupKey = 'last_import_backup';
  static const int formatVersion = 1;

  final DatabaseService _db = DatabaseService.instance;

  /// 生成完整快照 JSON（不含备份键自身，避免递归膨胀）。
  Future<String> exportFull() async {
    final snap = await _db.snapshotMaps();
    final settings = <String, dynamic>{};
    for (final m in snap['settings']!) {
      final key = m['key']?.toString();
      if (key == null || key == backupKey) continue;
      settings[key] = m['value'];
    }
    final payload = <String, dynamic>{
      'version': formatVersion,
      'exportedAt': DateTime.now().toIso8601String(),
      'courses': snap['courses'],
      'settings': settings,
      'reminders': snap['reminders'],
      'timeSlots': TimeSlotService.instance.exportRaw(),
    };
    return jsonEncode(payload);
  }

  /// 课程导入入口：先备份，再替换课程表。
  Future<void> importCourses(List<Course> courses) async {
    await saveBackup();
    await _db.importCourses(courses);
  }

  /// 把当前完整状态存为「可撤销」快照。
  Future<void> saveBackup() async {
    final json = await exportFull();
    await _db.setSetting(backupKey, json);
  }

  Future<bool> hasBackup() async => (await _db.getSetting(backupKey)) != null;

  /// 撤销最近一次导入 / 恢复。快照被消费（restore 会清空 settings 表）。
  Future<void> undoLastImport() async {
    final json = await _db.getSetting(backupKey);
    if (json == null) throw Exception('没有可撤销的导入记录');
    await _restore(json);
  }

  /// 从本 App 导出的全量备份文件恢复；恢复前的状态成为新的可撤销快照。
  Future<void> importBackup(String raw) async {
    final undo = await exportFull();
    await _restore(raw);
    await _db.setSetting(backupKey, undo);
  }

  /// 判断文本是否是本 App 导出的全量备份，而非纯课程 JSON。
  static bool looksLikeFullBackup(String raw) {
    try {
      final decoded = jsonDecode(raw);
      return decoded is Map &&
          decoded['version'] != null &&
          decoded['settings'] is Map &&
          decoded['courses'] is List;
    } catch (_) {
      return false;
    }
  }

  static int courseCountIn(String raw) {
    try {
      final decoded = jsonDecode(raw);
      if (decoded is Map && decoded['courses'] is List) {
        return (decoded['courses'] as List).length;
      }
    } catch (_) {}
    return 0;
  }

  Future<void> _restore(String raw) async {
    final dynamic decoded = jsonDecode(raw);
    if (decoded is! Map) throw Exception('备份格式无效：顶层必须是对象');

    final courses = (decoded['courses'] as List? ?? const [])
        .whereType<Map>()
        .map((m) => Map<String, dynamic>.from(m))
        .toList();
    final reminders = (decoded['reminders'] as List? ?? const [])
        .whereType<Map>()
        .map((m) => Map<String, dynamic>.from(m))
        .toList();
    final settings = <String, dynamic>{};
    final s = decoded['settings'];
    if (s is Map) {
      s.forEach((key, value) {
        if (key != backupKey) settings[key.toString()] = value;
      });
    }

    await _db.replaceAllFromMaps(
      courses: courses,
      settings: settings,
      reminders: reminders,
    );
    await TimeSlotService.instance.importRaw(decoded['timeSlots']);
  }
}
