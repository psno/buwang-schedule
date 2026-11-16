import 'package:flutter/foundation.dart';

import 'package:sqflite/sqflite.dart';
import 'package:path/path.dart';
import 'package:path_provider/path_provider.dart';

import '../models/course.dart';
import '../models/custom_reminder.dart';
import '../models/time_slot.dart';

/// 不忘课表 - SQLite Database Service
/// Handles all database operations for courses, reminders, and settings.
class DatabaseService {
  DatabaseService._();
  static final DatabaseService instance = DatabaseService._();

  Database? _database;
  static const String _dbName = 'buwang_schedule.db';
  static const int _dbVersion = 2;

  /// 课程数据版本号。MainShell 用 IndexedStack 常驻所有页面，
  /// initState 只执行一次；任何课程写操作后自增，常驻页面据此刷新。
  static final ValueNotifier<int> dataVersion = ValueNotifier<int>(0);

  static void _bump() {
    dataVersion.value = dataVersion.value + 1;
  }

  /// Get the database, creating it if needed.
  Future<Database> get database async {
    if (_database != null) return _database!;
    _database = await _initDatabase();
    return _database!;
  }

  /// Initialize the SQLite database.
  Future<Database> _initDatabase() async {
    final dir = await getApplicationDocumentsDirectory();
    final path = join(dir.path, _dbName);
    return await openDatabase(
      path,
      version: _dbVersion,
      onCreate: _onCreate,
      onUpgrade: _onUpgrade,
    );
  }

  /// Create tables on first install.
  Future<void> _onCreate(Database db, int version) async {
    await db.execute('''
      CREATE TABLE courses (
        id INTEGER PRIMARY KEY AUTOINCREMENT,
        name TEXT NOT NULL,
        subject TEXT,
        dayOfWeek INTEGER NOT NULL,
        period INTEGER NOT NULL,
        location TEXT,
        teacher TEXT,
        color INTEGER DEFAULT 0,
        round INTEGER DEFAULT 0
      )
    ''');

    await db.execute('''
      CREATE TABLE custom_reminders (
        id INTEGER PRIMARY KEY AUTOINCREMENT,
        name TEXT NOT NULL,
        hour INTEGER NOT NULL,
        minute INTEGER NOT NULL,
        repeatType INTEGER DEFAULT 0,
        repeatDays TEXT DEFAULT '',
        method INTEGER DEFAULT 0,
        enabled INTEGER DEFAULT 1,
        note TEXT
      )
    ''');

    await db.execute('''
      CREATE TABLE time_slots (
        period INTEGER PRIMARY KEY,
        startTime TEXT NOT NULL,
        endTime TEXT NOT NULL,
        label TEXT NOT NULL,
        isSaturday INTEGER DEFAULT 0
      )
    ''');

    await db.execute('''
      CREATE TABLE settings (
        key TEXT PRIMARY KEY,
        value TEXT
      )
    ''');

    // Insert default time slots
    for (final slot in defaultModelTimeSlots) {
      await db.insert('time_slots', slot.toMap());
    }
  }

  /// Handle database upgrades.
  Future<void> _onUpgrade(Database db, int oldVersion, int newVersion) async {
    if (oldVersion < 2) {
      // v2: 添加周六轮次字段
      await db
          .execute('ALTER TABLE courses ADD COLUMN round INTEGER DEFAULT 0');
    }
  }

  // ═══════════════════════════════════════════
  // Course CRUD
  // ═══════════════════════════════════════════

  Future<int> insertCourse(Course course) async {
    final db = await database;
    final id = await db.insert('courses', course.toMap());
    _bump();
    return id;
  }

  Future<int> updateCourse(Course course) async {
    final db = await database;
    final count = await db.update(
      'courses',
      course.toMap(),
      where: 'id = ?',
      whereArgs: [course.id],
    );
    _bump();
    return count;
  }

  Future<int> deleteCourse(int id) async {
    final db = await database;
    final count = await db.delete('courses', where: 'id = ?', whereArgs: [id]);
    _bump();
    return count;
  }

  Future<int> deleteAllCourses() async {
    final db = await database;
    final count = await db.delete('courses');
    _bump();
    return count;
  }

  Future<Course?> getCourseById(int id) async {
    final db = await database;
    final maps = await db.query('courses', where: 'id = ?', whereArgs: [id]);
    if (maps.isEmpty) return null;
    return Course.fromMap(maps.first);
  }

  Future<List<Course>> getAllCourses() async {
    final db = await database;
    final maps = await db.query('courses', orderBy: 'dayOfWeek, period');
    return maps.map((m) => Course.fromMap(m)).toList();
  }

  Future<List<Course>> getCoursesForDay(int dayOfWeek) async {
    final db = await database;
    final maps = await db.query(
      'courses',
      where: 'dayOfWeek = ?',
      whereArgs: [dayOfWeek],
      orderBy: 'period',
    );
    return maps.map((m) => Course.fromMap(m)).toList();
  }

  /// 获取周六指定轮次的课程
  Future<List<Course>> getSaturdayCourses(int round) async {
    final db = await database;
    final maps = await db.query(
      'courses',
      where: 'dayOfWeek = 6 AND round = ?',
      whereArgs: [round],
      orderBy: 'period',
    );
    return maps.map((m) => Course.fromMap(m)).toList();
  }

  // ═══════════════════════════════════════════
  // Custom Reminder CRUD
  // ═══════════════════════════════════════════

  Future<int> insertReminder(CustomReminder reminder) async {
    final db = await database;
    return await db.insert('custom_reminders', reminder.toMap());
  }

  Future<int> updateReminder(CustomReminder reminder) async {
    final db = await database;
    return await db.update(
      'custom_reminders',
      reminder.toMap(),
      where: 'id = ?',
      whereArgs: [reminder.id],
    );
  }

  Future<int> deleteReminder(int id) async {
    final db = await database;
    return await db
        .delete('custom_reminders', where: 'id = ?', whereArgs: [id]);
  }

  Future<List<CustomReminder>> getAllReminders() async {
    final db = await database;
    final maps = await db.query('custom_reminders', orderBy: 'hour, minute');
    return maps.map((m) => CustomReminder.fromMap(m)).toList();
  }

  // ═══════════════════════════════════════════
  // Settings (key-value)
  // ═══════════════════════════════════════════

  Future<String?> getSetting(String key) async {
    final db = await database;
    final maps = await db.query('settings', where: 'key = ?', whereArgs: [key]);
    if (maps.isEmpty) return null;
    return maps.first['value'] as String?;
  }

  Future<void> setSetting(String key, String value) async {
    final db = await database;
    await db.insert(
      'settings',
      {'key': key, 'value': value},
      conflictAlgorithm: ConflictAlgorithm.replace,
    );
  }

  Future<int> deleteSetting(String key) async {
    final db = await database;
    return await db.delete('settings', where: 'key = ?', whereArgs: [key]);
  }

  // ═══════════════════════════════════════════
  // Bulk operations
  // ═══════════════════════════════════════════

  /// Import a list of courses, replacing all existing ones.
  Future<void> importCourses(List<Course> courses) async {
    final db = await database;
    await db.transaction((txn) async {
      await txn.delete('courses');
      for (final course in courses) {
        await txn.insert('courses', course.toMap()..remove('id'));
      }
    });
    _bump();
  }

  /// Export all courses as a list.
  Future<List<Course>> exportCourses() => getAllCourses();

  /// Get course count.
  Future<int> get courseCount async {
    final db = await database;
    final result = await db.rawQuery('SELECT COUNT(*) as cnt FROM courses');
    return Sqflite.firstIntValue(result) ?? 0;
  }

  // ═══════════════════════════════════════════
  // Full snapshot (used by BackupService)
  // ═══════════════════════════════════════════

  /// 返回三张业务表的原始行，供 BackupService 生成全量备份。
  /// 统一转成 Map<String, dynamic>，避免 sqflite 的 Object? 泛型差异。
  Future<Map<String, List<Map<String, dynamic>>>> snapshotMaps() async {
    final db = await database;
    return <String, List<Map<String, dynamic>>>{
      'courses': (await db.query('courses'))
          .map((m) => Map<String, dynamic>.from(m))
          .toList(),
      'settings': (await db.query('settings'))
          .map((m) => Map<String, dynamic>.from(m))
          .toList(),
      'reminders': (await db.query('custom_reminders'))
          .map((m) => Map<String, dynamic>.from(m))
          .toList(),
    };
  }

  /// 由备份恢复：事务内清空并重建课程 / 设置 / 自定义提醒三张表。
  /// 只写入当前 schema 已知的列，兼容旧版本备份里多出的字段。
  Future<void> replaceAllFromMaps({
    required List<Map<String, dynamic>> courses,
    required Map<String, dynamic> settings,
    required List<Map<String, dynamic>> reminders,
  }) async {
    final db = await database;
    await db.transaction((txn) async {
      await txn.delete('courses');
      await txn.delete('settings');
      await txn.delete('custom_reminders');

      for (final m in courses) {
        await txn.insert('courses', <String, dynamic>{
          if (m['id'] != null) 'id': m['id'],
          'name': m['name'],
          'subject': m['subject'],
          'dayOfWeek': m['dayOfWeek'],
          'period': m['period'],
          'location': m['location'],
          'teacher': m['teacher'],
          'color': m['color'] ?? 0,
          'round': m['round'] ?? 0,
        });
      }
      for (final entry in settings.entries) {
        await txn.insert(
          'settings',
          <String, dynamic>{'key': entry.key, 'value': entry.value},
          conflictAlgorithm: ConflictAlgorithm.replace,
        );
      }
      for (final m in reminders) {
        await txn.insert('custom_reminders', <String, dynamic>{
          if (m['id'] != null) 'id': m['id'],
          'name': m['name'],
          'hour': m['hour'],
          'minute': m['minute'],
          'repeatType': m['repeatType'] ?? 0,
          'repeatDays': m['repeatDays'] ?? '',
          'method': m['method'] ?? 0,
          'enabled': m['enabled'] ?? 1,
          'note': m['note'],
        });
      }
    });
    _bump();
  }
}
