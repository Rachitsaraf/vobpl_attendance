import 'package:sqflite/sqflite.dart';
import 'package:path/path.dart';
import '../../models/attendance_model.dart';
import '../../models/breadcrumb_model.dart';

class DatabaseHelper {
  static final DatabaseHelper instance = DatabaseHelper._init();
  static Database? _database;

  DatabaseHelper._init();

  Future<Database> get database async {
    if (_database != null) return _database!;
    _database = await _initDB('attendance.db');
    return _database!;
  }

  Future<Database> _initDB(String filePath) async {
    final dbPath = await getDatabasesPath();
    final path = join(dbPath, filePath);

    return await openDatabase(
      path,
      version: 4,
      onCreate: _createDB,
      onUpgrade: _onUpgrade,
    );
  }

  Future _onUpgrade(Database db, int oldVersion, int newVersion) async {
    if (oldVersion < 2) {
      await db.execute('ALTER TABLE attendance ADD COLUMN unit TEXT');
    }
    if (oldVersion < 3) {
      await _createBreadcrumbsTable(db);
    }
    if (oldVersion < 4) {
      await db.execute('ALTER TABLE attendance ADD COLUMN remark TEXT');
    }
  }

  Future _createDB(Database db, int version) async {
    await db.execute('''
      CREATE TABLE attendance (
        id TEXT PRIMARY KEY,
        check_in TEXT NOT NULL,
        check_out TEXT,
        latitude REAL NOT NULL,
        longitude REAL NOT NULL,
        status TEXT NOT NULL,
        unit TEXT,
        selfie_path TEXT,
        remark TEXT,
        is_synced INTEGER DEFAULT 0
      )
    ''');

    await _createBreadcrumbsTable(db);
  }

  Future _createBreadcrumbsTable(Database db) async {
    await db.execute('''
      CREATE TABLE IF NOT EXISTS breadcrumbs (
        id TEXT PRIMARY KEY,
        user_email TEXT NOT NULL,
        latitude REAL NOT NULL,
        longitude REAL NOT NULL,
        timestamp TEXT NOT NULL,
        speed REAL DEFAULT 0.0,
        is_synced INTEGER DEFAULT 0
      )
    ''');
  }

  Future<void> insertAttendance(AttendanceModel attendance, {bool synced = false}) async {
    final db = await instance.database;
    final json = attendance.toJson();
    json['is_synced'] = synced ? 1 : 0;
    
    // We use insert or replace to handle updates (like when checking out)
    await db.insert(
      'attendance', 
      json, 
      conflictAlgorithm: ConflictAlgorithm.replace,
    );
  }

  Future<List<AttendanceModel>> getUnsyncedAttendance() async {
    final db = await instance.database;
    final result = await db.query('attendance', where: 'is_synced = 0');
    return result.map((json) => AttendanceModel.fromJson(json)).toList();
  }

  Future<void> markAsSynced(String id) async {
    final db = await instance.database;
    await db.update(
      'attendance',
      {'is_synced': 1},
      where: 'id = ?',
      whereArgs: [id],
    );
  }

  Future<List<AttendanceModel>> getAllAttendance() async {
    final db = await instance.database;
    final result = await db.query('attendance', orderBy: 'check_in DESC');
    return result.map((json) => AttendanceModel.fromJson(json)).toList();
  }

  Future<AttendanceModel?> getActiveAttendance() async {
    final db = await instance.database;
    final result = await db.query(
      'attendance',
      where: 'check_out IS NULL OR check_out = ""',
      orderBy: 'check_in DESC',
      limit: 1,
    );
    if (result.isNotEmpty) {
      return AttendanceModel.fromJson(result.first);
    }
    return null;
  }

  // --- BREADCRUMBS CRUD ---

  Future<void> insertBreadcrumb(BreadcrumbModel breadcrumb, {bool synced = false}) async {
    final db = await instance.database;
    final json = breadcrumb.toJson();
    json['is_synced'] = synced ? 1 : 0;
    
    await db.insert(
      'breadcrumbs',
      json,
      conflictAlgorithm: ConflictAlgorithm.replace,
    );
  }

  Future<List<BreadcrumbModel>> getUnsyncedBreadcrumbs() async {
    final db = await instance.database;
    final result = await db.query('breadcrumbs', where: 'is_synced = 0');
    return result.map((json) => BreadcrumbModel.fromJson(json)).toList();
  }

  Future<void> markBreadcrumbsSynced(List<String> ids) async {
    if (ids.isEmpty) return;
    final db = await instance.database;
    final placeholders = List.filled(ids.length, '?').join(',');
    await db.rawUpdate(
      'UPDATE breadcrumbs SET is_synced = 1 WHERE id IN ($placeholders)',
      ids,
    );
  }

  Future<List<BreadcrumbModel>> getBreadcrumbsForDate(String userEmail, DateTime date) async {
    final db = await instance.database;
    final startOfDay = DateTime(date.year, date.month, date.day).toIso8601String();
    final endOfDay = DateTime(date.year, date.month, date.day, 23, 59, 59).toIso8601String();

    final result = await db.query(
      'breadcrumbs',
      where: 'user_email = ? AND timestamp >= ? AND timestamp <= ?',
      whereArgs: [userEmail, startOfDay, endOfDay],
      orderBy: 'timestamp ASC',
    );
    return result.map((json) => BreadcrumbModel.fromJson(json)).toList();
  }
}

