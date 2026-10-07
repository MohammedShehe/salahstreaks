import 'package:flutter/foundation.dart';
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
  bool? _usePrefsForLogs; // null = not probed yet

  static const String _userDataKey = 'user_data';
  static const String _streaksKey = 'streaks';
  static const String _pointsKey = 'points';
  static const String _settingsKey = 'settings';
  static const String _quranProgressKey = 'quran_progress';
  static const String _achievementsKey = 'achievements';
  static const String _logsKey = 'ibadat_logs_v1';
  static const String _adhkarLogsKey = 'adhkar_logs_v1';

  /// Prefer SharedPreferences for log tables on web (no sqflite factory),
  /// or whenever SQLite fails to initialise.
  Future<bool> _shouldUsePrefsForLogs() async {
    if (_usePrefsForLogs != null) return _usePrefsForLogs!;
    if (kIsWeb) {
      _usePrefsForLogs = true;
      return true;
    }
    try {
      await database;
      _usePrefsForLogs = false;
      return false;
    } catch (e) {
      debugPrint('SQLite unavailable, using SharedPreferences for logs: $e');
      _usePrefsForLogs = true;
      return true;
    }
  }

  Future<Database> get database async {
    if (_database != null) return _database!;
    _database = await _initDatabase();
    return _database!;
  }

  Future<Database> _initDatabase() async {
    final path = join(await getDatabasesPath(), 'salahstreaks.db');
    return openDatabase(
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
      try {
        await db.execute('ALTER TABLE logs ADD COLUMN journalNote TEXT');
      } catch (_) {}
      try {
        await db.execute('ALTER TABLE logs ADD COLUMN quranPagesRead INTEGER');
      } catch (_) {}
      try {
        await db.execute('ALTER TABLE logs ADD COLUMN quranJuz INTEGER');
      } catch (_) {}
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

  // ============ LOGS ============

  /// Normalize a DateTime to a stable calendar-day key (midnight local).
  static String dateKey(DateTime date) {
    final d = DateTime(date.year, date.month, date.day);
    return d.toIso8601String();
  }

  Map<String, dynamic> _logToRow(IbadatLog log) {
    final map = log.toJson();
    map['date'] = dateKey(log.date);
    return map;
  }

  Future<List<IbadatLog>> _loadLogsFromPrefs() async {
    final prefs = await SharedPreferences.getInstance();
    final raw = prefs.getString(_logsKey);
    if (raw == null || raw.isEmpty) return [];
    try {
      final list = json.decode(raw) as List<dynamic>;
      return list
          .map((e) => IbadatLog.fromJson(Map<String, dynamic>.from(e as Map)))
          .toList();
    } catch (e) {
      debugPrint('Failed to decode prefs logs: $e');
      return [];
    }
  }

  Future<void> _saveLogsToPrefs(List<IbadatLog> logs) async {
    final prefs = await SharedPreferences.getInstance();
    final encoded = json.encode(logs.map(_logToRow).toList());
    await prefs.setString(_logsKey, encoded);
  }

  Future<List<IbadatLog>> loadLogs() async {
    if (await _shouldUsePrefsForLogs()) {
      return _loadLogsFromPrefs();
    }
    try {
      final db = await database;
      final maps = await db.query('logs');
      return maps.map((map) => IbadatLog.fromJson(map)).toList();
    } catch (e) {
      debugPrint('loadLogs SQLite failed, falling back to prefs: $e');
      _usePrefsForLogs = true;
      return _loadLogsFromPrefs();
    }
  }

  Future<void> saveLogs(List<IbadatLog> logs) async {
    if (await _shouldUsePrefsForLogs()) {
      await _saveLogsToPrefs(logs);
      return;
    }
    try {
      final db = await database;
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
    } catch (e) {
      debugPrint('saveLogs SQLite failed, falling back to prefs: $e');
      _usePrefsForLogs = true;
      await _saveLogsToPrefs(logs);
    }
  }

  Future<void> addLog(IbadatLog log) async {
    if (await _shouldUsePrefsForLogs()) {
      final logs = await _loadLogsFromPrefs();
      final key = dateKey(log.date);
      logs.removeWhere(
        (l) => dateKey(l.date) == key && l.type == log.type,
      );
      logs.add(log);
      await _saveLogsToPrefs(logs);
      return;
    }
    try {
      final db = await database;
      await db.insert(
        'logs',
        _logToRow(log),
        conflictAlgorithm: ConflictAlgorithm.replace,
      );
    } catch (e) {
      debugPrint('addLog SQLite failed, falling back to prefs: $e');
      _usePrefsForLogs = true;
      await addLog(log);
    }
  }

  Future<void> deleteLog(DateTime date, String type) async {
    if (await _shouldUsePrefsForLogs()) {
      final logs = await _loadLogsFromPrefs();
      final key = dateKey(date);
      logs.removeWhere((l) => dateKey(l.date) == key && l.type == type);
      await _saveLogsToPrefs(logs);
      return;
    }
    try {
      final db = await database;
      await db.delete(
        'logs',
        where: 'date = ? AND type = ?',
        whereArgs: [dateKey(date), type],
      );
    } catch (e) {
      debugPrint('deleteLog SQLite failed, falling back to prefs: $e');
      _usePrefsForLogs = true;
      await deleteLog(date, type);
    }
  }

  Future<List<IbadatLog>> getLogsByDate(DateTime date) async {
    final key = dateKey(date);
    final all = await loadLogs();
    return all.where((l) => dateKey(l.date) == key).toList();
  }

  Future<List<IbadatLog>> getLogsByType(String type) async {
    final all = await loadLogs();
    return all.where((l) => l.type == type).toList();
  }

  // ============ STREAKS (SharedPreferences) ============

  Future<Map<String, int>> loadStreaks() async {
    final prefs = await SharedPreferences.getInstance();
    final data = prefs.getString(_streaksKey);
    if (data != null) {
      return Map<String, int>.from(
        (json.decode(data) as Map).map(
          (k, v) => MapEntry(k.toString(), (v as num).toInt()),
        ),
      );
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
      return Map<String, double>.from(
        (json.decode(data) as Map).map(
          (k, v) => MapEntry(k.toString(), (v as num).toDouble()),
        ),
      );
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
    return QuranProgress(juz: 1, lastRead: DateTime.now());
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
      final list = json.decode(data) as List<dynamic>;
      return list
          .map((e) =>
              UserAchievement.fromJson(Map<String, dynamic>.from(e as Map)))
          .toList();
    }
    return [];
  }

  Future<void> saveAchievements(List<UserAchievement> achievements) async {
    final prefs = await SharedPreferences.getInstance();
    await prefs.setString(
      _achievementsKey,
      json.encode(achievements.map((a) => a.toJson()).toList()),
    );
  }

  // ============ ADHKAR LOGS ============

  Future<List<AdhkarLog>> _loadAdhkarFromPrefs() async {
    final prefs = await SharedPreferences.getInstance();
    final raw = prefs.getString(_adhkarLogsKey);
    if (raw == null || raw.isEmpty) return [];
    try {
      final list = json.decode(raw) as List<dynamic>;
      return list
          .map((e) => AdhkarLog.fromJson(Map<String, dynamic>.from(e as Map)))
          .toList();
    } catch (e) {
      debugPrint('Failed to decode prefs adhkar logs: $e');
      return [];
    }
  }

  Future<void> _saveAdhkarToPrefs(List<AdhkarLog> logs) async {
    final prefs = await SharedPreferences.getInstance();
    final encoded = json.encode(logs.map((l) {
      final m = l.toJson();
      m['date'] = dateKey(l.date);
      return m;
    }).toList());
    await prefs.setString(_adhkarLogsKey, encoded);
  }

  Future<void> addAdhkarLog(AdhkarLog log) async {
    if (await _shouldUsePrefsForLogs()) {
      final logs = await _loadAdhkarFromPrefs();
      final key = dateKey(log.date);
      logs.removeWhere(
        (l) => l.adhkarId == log.adhkarId && dateKey(l.date) == key,
      );
      logs.add(log);
      await _saveAdhkarToPrefs(logs);
      return;
    }
    try {
      final db = await database;
      final map = log.toJson();
      map['date'] = dateKey(log.date);
      await db.insert(
        'adhkar_logs',
        map,
        conflictAlgorithm: ConflictAlgorithm.replace,
      );
    } catch (e) {
      debugPrint('addAdhkarLog SQLite failed, falling back to prefs: $e');
      _usePrefsForLogs = true;
      await addAdhkarLog(log);
    }
  }

  Future<List<AdhkarLog>> loadAdhkarLogs() async {
    if (await _shouldUsePrefsForLogs()) {
      return _loadAdhkarFromPrefs();
    }
    try {
      final db = await database;
      final maps = await db.query('adhkar_logs');
      return maps.map((map) => AdhkarLog.fromJson(map)).toList();
    } catch (e) {
      debugPrint('loadAdhkarLogs unavailable: $e');
      _usePrefsForLogs = true;
      return _loadAdhkarFromPrefs();
    }
  }

  Future<AdhkarLog?> getAdhkarLog(String adhkarId, DateTime date) async {
    final key = dateKey(date);
    final all = await loadAdhkarLogs();
    try {
      return all.firstWhere(
        (l) => l.adhkarId == adhkarId && dateKey(l.date) == key,
      );
    } catch (_) {
      return null;
    }
  }

  // ============ BACKUP & RESTORE ============

  Future<String> exportBackup() async {
    final prefs = await SharedPreferences.getInstance();
    final logs = await loadLogs();
    final adhkarLogs = await loadAdhkarLogs();

    final backup = {
      'version': 1,
      'exportDate': DateTime.now().toIso8601String(),
      'userData': prefs.getString(_userDataKey),
      'streaks': prefs.getString(_streaksKey),
      'points': prefs.getString(_pointsKey),
      'settings': prefs.getString(_settingsKey),
      'quranProgress': prefs.getString(_quranProgressKey),
      'achievements': prefs.getString(_achievementsKey),
      'logs': logs.map(_logToRow).toList(),
      'adhkarLogs': adhkarLogs.map((l) {
        final m = l.toJson();
        m['date'] = dateKey(l.date);
        return m;
      }).toList(),
    };
    return json.encode(backup);
  }

  Future<void> importBackup(String jsonData) async {
    final data = json.decode(jsonData) as Map<String, dynamic>;
    final prefs = await SharedPreferences.getInstance();

    if (data['userData'] != null) {
      await prefs.setString(_userDataKey, data['userData']);
    }
    if (data['streaks'] != null) {
      await prefs.setString(_streaksKey, data['streaks']);
    }
    if (data['points'] != null) {
      await prefs.setString(_pointsKey, data['points']);
    }
    if (data['settings'] != null) {
      await prefs.setString(_settingsKey, data['settings']);
    }
    if (data['quranProgress'] != null) {
      await prefs.setString(_quranProgressKey, data['quranProgress']);
    }
    if (data['achievements'] != null) {
      await prefs.setString(_achievementsKey, data['achievements']);
    }

    if (data['logs'] is List) {
      final logs = (data['logs'] as List)
          .map((e) => IbadatLog.fromJson(Map<String, dynamic>.from(e as Map)))
          .toList();
      await saveLogs(logs);
    }
    if (data['adhkarLogs'] is List) {
      final logs = (data['adhkarLogs'] as List)
          .map((e) => AdhkarLog.fromJson(Map<String, dynamic>.from(e as Map)))
          .toList();
      await _saveAdhkarToPrefs(logs);
      if (!(await _shouldUsePrefsForLogs())) {
        try {
          final db = await database;
          await db.delete('adhkar_logs');
          for (final log in logs) {
            final map = log.toJson();
            map['date'] = dateKey(log.date);
            await db.insert(
              'adhkar_logs',
              map,
              conflictAlgorithm: ConflictAlgorithm.replace,
            );
          }
        } catch (_) {}
      }
    }
  }

  Future<void> clearAllData() async {
    final prefs = await SharedPreferences.getInstance();
    await prefs.clear();
    _usePrefsForLogs = null;
    if (!kIsWeb) {
      try {
        final db = await database;
        await db.delete('logs');
        await db.delete('adhkar_logs');
      } catch (_) {}
    }
    _database = null;
  }
}
