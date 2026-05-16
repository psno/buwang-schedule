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
      await db.execute('ALTER TABLE courses ADD COLUMN round INTEGER DEFAULT 0');
    }
  }

  // ═══════════════════════════════════════════
  // Course CRUD
  // ═══════════════════════════════════════════

  Future<int> insertCourse(Course course) async {
    final db = await database;
    return await db.insert('courses', course.toMap());
  }

  Future<int> updateCourse(Course course) async {
    final db = await database;
    return await db.update(
      'courses',
      course.toMap(),
      where: 'id = ?',
      whereArgs: [course.id],
    );
  }

  Future<int> deleteCourse(int id) async {
    final db = await database;
    return await db.delete('courses', where: 'id = ?', whereArgs: [id]);
  }

  Future<int> deleteAllCourses() async {
    final db = await database;
    return await db.delete('courses');
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
    return await db.delete('custom_reminders', where: 'id = ?', whereArgs: [id]);
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
        await txn.insert('courses', course.toMap());
      }
    });
  }

  /// Export all courses as a list.
  Future<List<Course>> exportCourses() => getAllCourses();

  /// Get course count.
  Future<int> get courseCount async {
    final db = await database;
    final result = await db.rawQuery('SELECT COUNT(*) as cnt FROM courses');
    return Sqflite.firstIntValue(result) ?? 0;
  }
}
