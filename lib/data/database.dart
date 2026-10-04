import 'package:path/path.dart' as p;
import 'package:sqflite/sqflite.dart';

import '../logic/dates.dart';
import '../models/day_log.dart';
import '../models/jab.dart';
import '../models/medication.dart';
import '../models/weight_entry.dart';

/// SQLite storage. All data stays on the device.
class AppDatabase {
  final Database db;
  AppDatabase._(this.db);

  static Future<AppDatabase> open({
    String? path,
    bool singleInstance = true,
  }) async {
    final dbPath = path ?? p.join(await getDatabasesPath(), 'plotshot.db');
    final db = await openDatabase(
      dbPath,
      version: 1,
      singleInstance: singleInstance,
      onConfigure: (db) => db.execute('PRAGMA foreign_keys = ON'),
      onCreate: (db, _) async {
        await createSchema(db);
        for (final m in Medication.defaults) {
          await db.insert('medications', m.toMap());
        }
      },
    );
    return AppDatabase._(db);
  }

  static Future<void> createSchema(DatabaseExecutor db) async {
    await db.execute('''
      CREATE TABLE medications (
        id INTEGER PRIMARY KEY AUTOINCREMENT,
        name TEXT NOT NULL,
        half_life_days REAL NOT NULL,
        time_to_peak_days REAL NOT NULL,
        doses TEXT NOT NULL,
        built_in INTEGER NOT NULL DEFAULT 0
      )''');
    await db.execute('''
      CREATE TABLE jabs (
        id INTEGER PRIMARY KEY AUTOINCREMENT,
        medication_id INTEGER NOT NULL REFERENCES medications(id),
        dose_mg REAL NOT NULL,
        taken_at INTEGER NOT NULL,
        site TEXT,
        notes TEXT
      )''');
    await db.execute('CREATE INDEX jabs_taken_at ON jabs(taken_at)');
    await db.execute('''
      CREATE TABLE weights (
        date TEXT PRIMARY KEY,
        kg REAL NOT NULL,
        source TEXT NOT NULL DEFAULT 'manual'
      )''');
    await db.execute('''
      CREATE TABLE day_logs (
        date TEXT PRIMARY KEY,
        calories INTEGER,
        protein_g REAL,
        side_effects TEXT,
        notes TEXT,
        nutrition_from_health INTEGER NOT NULL DEFAULT 0
      )''');
  }

  // Medications
  Future<List<Medication>> medications() async => (await db.query(
    'medications',
    orderBy: 'id',
  )).map(Medication.fromMap).toList();

  Future<Medication> saveMedication(Medication m) async {
    if (m.id == null) {
      final id = await db.insert('medications', m.toMap());
      return m.copyWith(id: id);
    }
    await db.update(
      'medications',
      m.toMap(),
      where: 'id = ?',
      whereArgs: [m.id],
    );
    return m;
  }

  Future<void> deleteMedication(int id) =>
      db.delete('medications', where: 'id = ?', whereArgs: [id]);

  // Jabs
  Future<List<Jab>> jabs() async =>
      (await db.query('jabs', orderBy: 'taken_at')).map(Jab.fromMap).toList();

  Future<Jab> saveJab(Jab j) async {
    if (j.id == null) {
      final id = await db.insert('jabs', j.toMap());
      return j.copyWith(id: id);
    }
    await db.update('jabs', j.toMap(), where: 'id = ?', whereArgs: [j.id]);
    return j;
  }

  Future<void> deleteJab(int id) =>
      db.delete('jabs', where: 'id = ?', whereArgs: [id]);

  // Weights
  Future<List<WeightEntry>> weights() async => (await db.query(
    'weights',
    orderBy: 'date',
  )).map(WeightEntry.fromMap).toList();

  Future<void> saveWeight(WeightEntry w) => db.insert(
    'weights',
    w.toMap(),
    conflictAlgorithm: ConflictAlgorithm.replace,
  );

  Future<void> deleteWeight(DateTime date) =>
      db.delete('weights', where: 'date = ?', whereArgs: [dayKey(date)]);

  // Day logs
  Future<List<DayLog>> dayLogs() async => (await db.query(
    'day_logs',
    orderBy: 'date',
  )).map(DayLog.fromMap).toList();

  Future<void> saveDayLog(DayLog l) async {
    if (l.isEmpty) {
      await db.delete(
        'day_logs',
        where: 'date = ?',
        whereArgs: [dayKey(l.date)],
      );
    } else {
      await db.insert(
        'day_logs',
        l.toMap(),
        conflictAlgorithm: ConflictAlgorithm.replace,
      );
    }
  }

  /// Replaces everything with the contents of a backup, atomically.
  Future<void> replaceAll({
    required List<Medication> medications,
    required List<Jab> jabs,
    required List<WeightEntry> weights,
    required List<DayLog> dayLogs,
  }) => db.transaction((txn) async {
    for (final t in ['jabs', 'weights', 'day_logs', 'medications']) {
      await txn.delete(t);
    }
    for (final m in medications) {
      await txn.insert('medications', m.toMap());
    }
    for (final j in jabs) {
      await txn.insert('jabs', j.toMap());
    }
    for (final w in weights) {
      await txn.insert('weights', w.toMap());
    }
    for (final l in dayLogs) {
      await txn.insert('day_logs', l.toMap());
    }
  });
}
