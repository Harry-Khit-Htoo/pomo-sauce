import 'package:path/path.dart' as p;
import 'package:sqflite/sqflite.dart';

/// Owns the sqflite handle and the schema. Everything the app persists apart
/// from settings (habits, habit logs, session history) lives here, on-device.
class AppDatabase {
  AppDatabase._(this.db);

  final Database db;

  static const _fileName = 'tomato_focus.db';
  static const _version = 1;

  static Future<AppDatabase> open() async {
    final path = p.join(await getDatabasesPath(), _fileName);
    final db = await openDatabase(
      path,
      version: _version,
      onConfigure: (d) => d.execute('PRAGMA foreign_keys = ON'),
      onCreate: _createSchema,
      onUpgrade: _upgrade,
    );
    return AppDatabase._(db);
  }

  static Future<void> _createSchema(Database db, int version) async {
    await db.execute('''
      CREATE TABLE habits (
        id TEXT PRIMARY KEY,
        name TEXT NOT NULL,
        emoji TEXT NOT NULL DEFAULT '🎯',
        color INTEGER NOT NULL,
        schedule TEXT NOT NULL DEFAULT 'daily',
        weekdays TEXT NOT NULL DEFAULT '',
        target_per_week INTEGER NOT NULL DEFAULT 7,
        created_at INTEGER NOT NULL,
        archived INTEGER NOT NULL DEFAULT 0,
        sort_order INTEGER NOT NULL DEFAULT 0
      )
    ''');

    await db.execute('''
      CREATE TABLE habit_logs (
        habit_id TEXT NOT NULL,
        day TEXT NOT NULL,
        completed_at INTEGER NOT NULL,
        source TEXT NOT NULL DEFAULT 'manual',
        PRIMARY KEY (habit_id, day),
        FOREIGN KEY (habit_id) REFERENCES habits (id) ON DELETE CASCADE
      )
    ''');
    await db.execute('CREATE INDEX idx_habit_logs_day ON habit_logs (day)');

    await db.execute('''
      CREATE TABLE sessions (
        id TEXT PRIMARY KEY,
        phase TEXT NOT NULL,
        started_at INTEGER NOT NULL,
        ended_at INTEGER NOT NULL,
        planned_seconds INTEGER NOT NULL,
        actual_seconds INTEGER NOT NULL,
        completed INTEGER NOT NULL DEFAULT 0,
        preset_id TEXT,
        habit_id TEXT,
        day TEXT NOT NULL
      )
    ''');
    await db.execute('CREATE INDEX idx_sessions_day ON sessions (day)');
    await db.execute(
      'CREATE INDEX idx_sessions_started ON sessions (started_at)',
    );
  }

  static Future<void> _upgrade(Database db, int from, int to) async {
    // Schema v1 is the first published version; migrations land here as the
    // app evolves so history is never dropped on update.
  }

  Future<void> close() => db.close();

  /// Used by Settings > Reset data.
  Future<void> wipe() async {
    await db.delete('habit_logs');
    await db.delete('sessions');
    await db.delete('habits');
  }
}
