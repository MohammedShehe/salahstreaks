import 'package:sqflite/sqflite.dart';
import 'package:path/path.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'dart:convert';
import 'package:salahstreaks/models/ibadat_model.dart';
import 'package:salahstreaks/models/adhkar_model.dart';
import 'package:salahstreaks/models/achievement_model.dart';
import 'package:salahstreaks/models/user_settings_model.dart';
import 'package:salahstreaks/models/quran_progress_model.dart';

class StorageService {
  static final StorageService _instance = StorageService._internal();
  factory StorageService() => _instance;
  StorageService._internal();

  Database? _database;
  static const String _userDataKey = 'user_data';
  static const String _streaksKey = 'streaks';
  static const String _pointsKey = 'points';
  static const String _settingsKey = 'settings';
  static const String _quranProgressKey = 'quran_progress';
  static const String _achievementsKey = 'achievements';

  Future<Database> get database async {
    if (_database != null) return _database!;
    _database = await _initDatabase();
    return _database!;
  }

  Future<Database> _initDatabase() async {
    String path = join(await getDatabasesPath(), 'salahstreaks.db');
    return await openDatabase(
      path,
      version: 2,
      onCreate: _onCreate,
      onUpgrade: _onUpgrade,
    );
  }

  Future<void> _onCreate(Database db, int version) async {
    await db.execute('''
      CREATE TABLE logs (
        id INTEGER PRIMARY KEY AUTOINCREMENT,
        type TEXT NOT NULL,
        date TEXT NOT NULL,
        salahCount INTEGER DEFAULT 0,
        sawmType TEXT DEFAULT '',
        rakahCount INTEGER DEFAULT 0,
        versesCount INTEGER DEFAULT 0,
        surahName TEXT DEFAULT '',
        sadaqatType TEXT DEFAULT '',
        note TEXT DEFAULT '',
        amount REAL DEFAULT 0.0,
        journalNote TEXT,
        quranPagesRead INTEGER,
        quranJuz INTEGER,
        UNIQUE(type, date)
      )
    ''');

    await db.execute('''
      CREATE TABLE adhkar_logs (
        id INTEGER PRIMARY KEY AUTOINCREMENT,
        adhkarId TEXT NOT NULL,
        date TEXT NOT NULL,
        count INTEGER DEFAULT 0,
        UNIQUE(adhkarId, date)
      )
    ''');

    await db.execute('''
      CREATE TABLE achievements (
        id TEXT PRIMARY KEY,
        title TEXT NOT NULL,
        description TEXT NOT NULL,
        icon TEXT NOT NULL,
        category TEXT NOT NULL,
        requirement INTEGER NOT NULL,
        isUnlocked INTEGER DEFAULT 0,
        unlockedAt TEXT,
        currentProgress INTEGER DEFAULT 0
      )
    ''');
  }

  Future<void> _onUpgrade(Database db, int oldVersion, int newVersion) async {
    if (oldVersion < 2) {
      // Add new columns if needed
      try {
        await db.execute('ALTER TABLE logs ADD COLUMN journalNote TEXT');
      } catch (e) {}
      try {
        await db.execute('ALTER TABLE logs ADD COLUMN quranPagesRead INTEGER');
      } catch (e) {}
      try {
        await db.execute('ALTER TABLE logs ADD COLUMN quranJuz INTEGER');
      } catch (e) {}
    }
  }

  // ============ USER DATA (SharedPreferences) ============
  
  Future<Map<String, dynamic>> loadUserData() async {
    final prefs = await SharedPreferences.getInstance();
    final data = prefs.getString(_userDataKey);
    if (data != null) {
      return Map<String, dynamic>.from(json.decode(data));
    }
    return {
      'name': 'MO11',
      'streaks': 0,
      'totalPoints': 0,
    };
  }

  Future<void> saveUserData(Map<String, dynamic> data) async {
    final prefs = await SharedPreferences.getInstance();
    await prefs.setString(_userDataKey, json.encode(data));
  }

  // ============ LOGS (SQLite) ============
  
  /// Normalize a DateTime to a stable calendar-day key (midnight local).
  /// Full ISO timestamps include time-of-day, so UNIQUE(type, date) would
  /// never fire when the same ibadat is re-logged later the same day.
  static String dateKey(DateTime date) {
    final d = DateTime(date.year, date.month, date.day);
    return d.toIso8601String();
  }

  Map<String, dynamic> _logToRow(IbadatLog log) {
    final json = log.toJson();
    // Always persist the calendar-day key, not the original timestamp.
    json['date'] = dateKey(log.date);
    return json;
  }

  Future<List<IbadatLog>> loadLogs() async {
    final db = await database;
    final List<Map<String, dynamic>> maps = await db.query('logs');
    return maps.map((map) => IbadatLog.fromJson(map)).toList();
  }

  Future<void> saveLogs(List<IbadatLog> logs) async {
    final db = await database;
    // Replace the full table so removals (e.g. un-ticking the last Salah)
    // are actually reflected in SQLite. Insert-only replace left orphan
    // rows behind whenever the in-memory list shrank.
    await db.transaction((txn) async {
      await txn.delete('logs');
      for (final log in logs) {
        await txn.insert(
          'logs',
          _logToRow(log),
          conflictAlgorithm: ConflictAlgorithm.replace,
        );
      }
    });
  }

  Future<void> addLog(IbadatLog log) async {
    final db = await database;
    await db.insert(
      'logs',
      _logToRow(log),
      conflictAlgorithm: ConflictAlgorithm.replace,
    );
  }

  Future<void> deleteLog(DateTime date, String type) async {
    final db = await database;
    await db.delete(
      'logs',
      where: 'date = ? AND type = ?',
      whereArgs: [dateKey(date), type],
    );
  }

  Future<List<IbadatLog>> getLogsByDate(DateTime date) async {
    final db = await database;
    final List<Map<String, dynamic>> maps = await db.query(
      'logs',
      where: 'date = ?',
      whereArgs: [dateKey(date)],
    );
    return maps.map((map) => IbadatLog.fromJson(map)).toList();
  }

  Future<List<IbadatLog>> getLogsByType(String type) async {
    final db = await database;
    final List<Map<String, dynamic>> maps = await db.query(
      'logs',
      where: 'type = ?',
      whereArgs: [type],
    );
    return maps.map((map) => IbadatLog.fromJson(map)).toList();
  }

  // ============ STREAKS (SharedPreferences) ============
  
  Future<Map<String, int>> loadStreaks() async {
    final prefs = await SharedPreferences.getInstance();
    final data = prefs.getString(_streaksKey);
    if (data != null) {
      return Map<String, int>.from(json.decode(data));
    }
    return {};
  }

  Future<void> saveStreaks(Map<String, int> streaks) async {
    final prefs = await SharedPreferences.getInstance();
    await prefs.setString(_streaksKey, json.encode(streaks));
  }

  // ============ POINTS (SharedPreferences) ============
  
  Future<Map<String, double>> loadPoints() async {
    final prefs = await SharedPreferences.getInstance();
    final data = prefs.getString(_pointsKey);
    if (data != null) {
      final Map<String, dynamic> temp = json.decode(data);
      return temp.map((key, value) => MapEntry(key, value.toDouble()));
    }
    return {};
  }

  Future<void> savePoints(Map<String, double> points) async {
    final prefs = await SharedPreferences.getInstance();
    await prefs.setString(_pointsKey, json.encode(points));
  }

  // ============ SETTINGS (SharedPreferences) ============
  
  Future<UserSettings> loadSettings() async {
    final prefs = await SharedPreferences.getInstance();
    final data = prefs.getString(_settingsKey);
    if (data != null) {
      return UserSettings.fromJson(json.decode(data));
    }
    return UserSettings();
  }

  Future<void> saveSettings(UserSettings settings) async {
    final prefs = await SharedPreferences.getInstance();
    await prefs.setString(_settingsKey, json.encode(settings.toJson()));
  }

  // ============ QURAN PROGRESS (SharedPreferences) ============
  
  Future<QuranProgress> loadQuranProgress() async {
    final prefs = await SharedPreferences.getInstance();
    final data = prefs.getString(_quranProgressKey);
    if (data != null) {
      return QuranProgress.fromJson(json.decode(data));
    }
    return QuranProgress(
      juz: 1,
      lastRead: DateTime.now(),
      dailyGoalPages: 5,
    );
  }

  Future<void> saveQuranProgress(QuranProgress progress) async {
    final prefs = await SharedPreferences.getInstance();
    await prefs.setString(_quranProgressKey, json.encode(progress.toJson()));
  }

  // ============ ACHIEVEMENTS (SharedPreferences) ============
  
  Future<List<UserAchievement>> loadAchievements() async {
    final prefs = await SharedPreferences.getInstance();
    final data = prefs.getString(_achievementsKey);
    if (data != null) {
      final List<dynamic> list = json.decode(data);
      return list.map((item) => UserAchievement.fromJson(item)).toList();
    }
    return [];
  }

  Future<void> saveAchievements(List<UserAchievement> achievements) async {
    final prefs = await SharedPreferences.getInstance();
    final list = achievements.map((a) => a.toJson()).toList();
    await prefs.setString(_achievementsKey, json.encode(list));
  }

  // ============ ADHKAR LOGS (SQLite) ============
  
  Future<void> addAdhkarLog(AdhkarLog log) async {
    final db = await database;
    final json = log.toJson();
    json['date'] = dateKey(log.date);
    await db.insert(
      'adhkar_logs',
      json,
      conflictAlgorithm: ConflictAlgorithm.replace,
    );
  }

  Future<List<AdhkarLog>> loadAdhkarLogs() async {
    final db = await database;
    final List<Map<String, dynamic>> maps = await db.query('adhkar_logs');
    return maps.map((map) => AdhkarLog.fromJson(map)).toList();
  }

  Future<AdhkarLog?> getAdhkarLog(String adhkarId, DateTime date) async {
    final db = await database;
    final List<Map<String, dynamic>> maps = await db.query(
      'adhkar_logs',
      where: 'adhkarId = ? AND date = ?',
      whereArgs: [adhkarId, dateKey(date)],
    );
    if (maps.isNotEmpty) {
      return AdhkarLog.fromJson(maps.first);
    }
    return null;
  }

  // ============ BACKUP & RESTORE ============
  
  Future<String> exportBackup() async {
    final prefs = await SharedPreferences.getInstance();
    final db = await database;
    
    final logs = await db.query('logs');
    final adhkarLogs = await db.query('adhkar_logs');
    
    final backup = {
      'version': 1,
      'exportDate': DateTime.now().toIso8601String(),
      'sharedPreferences': {
        _userDataKey: prefs.getString(_userDataKey),
        _streaksKey: prefs.getString(_streaksKey),
        _pointsKey: prefs.getString(_pointsKey),
        _settingsKey: prefs.getString(_settingsKey),
        _quranProgressKey: prefs.getString(_quranProgressKey),
        _achievementsKey: prefs.getString(_achievementsKey),
      },
      'logs': logs,
      'adhkarLogs': adhkarLogs,
    };
    
    return json.encode(backup);
  }

  Future<void> importBackup(String jsonData) async {
    final data = json.decode(jsonData);
    final prefs = await SharedPreferences.getInstance();
    final db = await database;
    
    // Restore SharedPreferences
    final sharedPrefs = data['sharedPreferences'] as Map<String, dynamic>;
    for (final entry in sharedPrefs.entries) {
      if (entry.value != null) {
        await prefs.setString(entry.key, entry.value);
      }
    }
    
    // Restore logs
    await db.transaction((txn) async {
      await txn.delete('logs');
      for (final log in data['logs'] as List) {
        await txn.insert('logs', log);
      }
    });
    
    // Restore adhkar logs
    await db.transaction((txn) async {
      await txn.delete('adhkar_logs');
      for (final log in data['adhkarLogs'] as List) {
        await txn.insert('adhkar_logs', log);
      }
    });
  }

  Future<void> clearAllData() async {
    final prefs = await SharedPreferences.getInstance();
    await prefs.clear();
    final db = await database;
    await db.delete('logs');
    await db.delete('adhkar_logs');
  }
}