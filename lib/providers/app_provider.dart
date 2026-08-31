import 'dart:async';
import 'dart:io';
import 'package:flutter/material.dart';
import 'package:path_provider/path_provider.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:salahstreaks/models/ibadat_model.dart';
import 'package:salahstreaks/models/adhkar_model.dart';
import 'package:salahstreaks/models/achievement_model.dart';
import 'package:salahstreaks/models/user_settings_model.dart';
import 'package:salahstreaks/models/quran_progress_model.dart';
import 'package:salahstreaks/services/storage_service.dart';
import 'package:salahstreaks/utils/constants.dart';

class AppProvider extends ChangeNotifier {
  final StorageService _storage = StorageService();

  Map<String, dynamic>? _userData;
  List<IbadatLog> _logs = [];
  Map<String, int> _streaks = {};
  Map<String, double> _points = {};
  UserSettings _settings = UserSettings();
  QuranProgress _quranProgress = QuranProgress(juz: 1, lastRead: DateTime.now());
  List<UserAchievement> _userAchievements = [];
  List<AdhkarLog> _adhkarLogs = [];

  bool _isLoading = true;

  // ============ AUTO BACKUP ============
  // Previously "Auto Backup" was a switch in Settings that saved a bool
  // and nothing ever read it. This timer checks periodically (and once
  // right after load / whenever the setting is turned on) whether a
  // backup has been written today, and if not, writes one to
  // <app documents>/auto_backups/backup_YYYY-MM-DD.json, keeping only the
  // most recent few so storage doesn't grow forever.
  static const String _lastAutoBackupKey = 'last_auto_backup_date';
  static const int _maxAutoBackups = 7;
  Timer? _autoBackupTimer;

  AppProvider() {
    _loadAllData();
  }

  // Getters
  Map<String, dynamic>? get userData => _userData;
  List<IbadatLog> get logs => _logs;
  Map<String, int> get streaks => _streaks;
  Map<String, double> get points => _points;
  UserSettings get settings => _settings;
  QuranProgress get quranProgress => _quranProgress;
  List<UserAchievement> get userAchievements => _userAchievements;
  List<AdhkarLog> get adhkarLogs => _adhkarLogs;
  bool get isLoading => _isLoading;

  @override
  void dispose() {
    _autoBackupTimer?.cancel();
    super.dispose();
  }

  Future<void> _loadAllData() async {
    _isLoading = true;
    notifyListeners();

    try {
      _userData = await _storage.loadUserData();
      _logs = await _storage.loadLogs();
      _streaks = await _storage.loadStreaks();
      _points = await _storage.loadPoints();
      _settings = await _storage.loadSettings();
      _quranProgress = await _storage.loadQuranProgress();
      _userAchievements = await _storage.loadAchievements();
      _adhkarLogs = await _storage.loadAdhkarLogs();

      await _recalculateStreaks();
      await _checkAchievements();

      final totalStreak = _streaks.values.fold(0, (sum, value) => sum + value);
      if (_userData != null) {
        _userData!['streaks'] = totalStreak;
        await _storage.saveUserData(_userData!);
      }
    } catch (e) {
      print('Error loading data: $e');
    }

    _isLoading = false;
    notifyListeners();

    _scheduleAutoBackup();
  }

  void _scheduleAutoBackup() {
    _autoBackupTimer?.cancel();
    if (!_settings.backupAuto) return;

    // Check immediately (covers "just turned it on" and "app just opened
    // on a new day"), then re-check periodically while the app is open.
    _maybeRunAutoBackup();
    _autoBackupTimer = Timer.periodic(const Duration(hours: 6), (_) {
      _maybeRunAutoBackup();
    });
  }

  Future<void> _maybeRunAutoBackup() async {
    if (!_settings.backupAuto) return;

    try {
      final prefs = await SharedPreferences.getInstance();
      final today = DateTime.now().toIso8601String().split('T').first;
      final lastBackupDate = prefs.getString(_lastAutoBackupKey);

      if (lastBackupDate == today) return; // already have today's backup

      final backupJson = await _storage.exportBackup();
      final docsDir = await getApplicationDocumentsDirectory();
      final backupDir = Directory('${docsDir.path}/auto_backups');
      if (!await backupDir.exists()) {
        await backupDir.create(recursive: true);
      }

      final file = File('${backupDir.path}/backup_$today.json');
      await file.writeAsString(backupJson);

      // Prune old auto-backups, keeping only the most recent N.
      final files = backupDir
          .listSync()
          .whereType<File>()
          .where((f) => f.path.endsWith('.json'))
          .toList()
        ..sort((a, b) => b.path.compareTo(a.path));

      for (final oldFile in files.skip(_maxAutoBackups)) {
        try {
          await oldFile.delete();
        } catch (_) {}
      }

      await prefs.setString(_lastAutoBackupKey, today);
    } catch (e) {
      // Never let a background backup crash the app.
      print('Auto backup failed: $e');
    }
  }

  /// Returns the timestamp of the most recent auto-backup, or null if none
  /// exists yet. Handy if you want to surface "Last auto-backup: ..." in
  /// Settings.
  Future<DateTime?> getLastAutoBackupTime() async {
    try {
      final docsDir = await getApplicationDocumentsDirectory();
      final backupDir = Directory('${docsDir.path}/auto_backups');
      if (!await backupDir.exists()) return null;

      final files = backupDir
          .listSync()
          .whereType<File>()
          .where((f) => f.path.endsWith('.json'))
          .toList();
      if (files.isEmpty) return null;

      files.sort((a, b) =>
          b.statSync().modified.compareTo(a.statSync().modified));
      return files.first.statSync().modified;
    } catch (_) {
      return null;
    }
  }

  // ============ SALAH METHODS ============

  bool isLoggedToday(String type) {
    final today = DateTime.now();
    return _logs.any((log) =>
      log.type == type &&
      log.date.year == today.year &&
      log.date.month == today.month &&
      log.date.day == today.day
    );
  }

  IbadatLog? getTodaySalahLog() {
    final today = DateTime.now();
    try {
      return _logs.firstWhere((log) =>
        log.type == 'Salah' &&
        log.date.year == today.year &&
        log.date.month == today.month &&
        log.date.day == today.day
      );
    } catch (e) {
      return null;
    }
  }

  int getTodaySalahCount() {
    final log = getTodaySalahLog();
    return log?.salahCount ?? 0;
  }

  Set<String> getTodayPrayedSalah() {
    final log = getTodaySalahLog();
    if (log == null) return {};

    final prayed = <String>{};

    if (log.note.isNotEmpty && log.note.startsWith('prayed:')) {
      final prayedList = log.note.replaceFirst('prayed:', '').split(',');
      prayed.addAll(prayedList.where((p) => p.isNotEmpty));
    } else {
      final prayerNames = ['Fajr', 'Dhuhr', 'Asr', 'Maghrib', 'Isha'];
      final count = log.salahCount;
      for (int i = 0; i < count && i < prayerNames.length; i++) {
        prayed.add(prayerNames[i]);
      }
    }

    return prayed;
  }

  bool isSalahLogged(String prayerName) {
    final prayed = getTodayPrayedSalah();
    return prayed.contains(prayerName);
  }

  int getTotalStreak() {
    return _streaks.values.fold(0, (sum, value) => sum + value);
  }

  Future<void> toggleSalah(String prayerName) async {
    final today = DateTime.now();
    final day = DateTime(today.year, today.month, today.day);
    final prayed = getTodayPrayedSalah();

    // Capture previous count so we can adjust points on toggle.
    final previousCount = prayed.length;

    if (prayed.contains(prayerName)) {
      prayed.remove(prayerName);
    } else {
      prayed.add(prayerName);
    }

    final count = prayed.length;
    final note = 'prayed:${prayed.join(',')}';

    final log = IbadatLog(
      type: 'Salah',
      date: day,
      salahCount: count,
      sawmType: '',
      rakahCount: 0,
      versesCount: 0,
      surahName: '',
      sadaqatType: '',
      note: note,
      amount: 0.0,
    );

    _logs.removeWhere((l) =>
      l.type == 'Salah' &&
      l.date.year == today.year &&
      l.date.month == today.month &&
      l.date.day == today.day
    );

    // Keep a row only while at least one prayer is marked; otherwise
    // drop the day's Salah entry so streaks / history stay accurate.
    if (count > 0) {
      _logs.add(log);
    }
    await _storage.saveLogs(_logs);

    // 10 points per individual Salah (matches _calculatePoints for Salah).
    final delta = (count - previousCount) * 10.0;
    if (delta != 0) {
      _points['Salah'] = ((_points['Salah'] ?? 0) + delta).clamp(0.0, double.infinity);
      await _storage.savePoints(_points);
    }

    await _recalculateStreaks();
    await _updateTotalStreak();
    await _checkAchievements();

    notifyListeners();
  }

  // ============ IBADAT LOGGING ============

  Future<void> logIbadat(IbadatLog log) async {
    final today = DateTime.now();
    // Normalize to calendar day so UNIQUE(type, date) and day lookups work.
    final normalized = IbadatLog(
      type: log.type,
      date: DateTime(log.date.year, log.date.month, log.date.day),
      salahCount: log.salahCount,
      sawmType: log.sawmType,
      rakahCount: log.rakahCount,
      versesCount: log.versesCount,
      surahName: log.surahName,
      sadaqatType: log.sadaqatType,
      note: log.note,
      amount: log.amount,
      journalNote: log.journalNote,
      quranPagesRead: log.quranPagesRead,
      quranJuz: log.quranJuz,
    );

    if (normalized.type == 'Salah') {
      return;
    } else {
      final alreadyLogged = _logs.any((l) =>
        l.type == normalized.type &&
        l.date.year == today.year &&
        l.date.month == today.month &&
        l.date.day == today.day
      );

      if (alreadyLogged) {
        return;
      }
    }

    _logs.add(normalized);
    await _storage.saveLogs(_logs);

    // Streaks are always fully re-derived from log history rather than
    // incrementally patched — avoids the two calculations drifting apart
    // (e.g. after a deleted or backdated log).
    await _recalculateStreaks();

    final points = _calculatePoints(normalized);
    _points[normalized.type] = (_points[normalized.type] ?? 0) + points;
    await _storage.savePoints(_points);

    // Update Quran progress if applicable. Prefer explicit pages; if the
    // log only has a verse count, approximate pages (≈20 verses/page).
    if (normalized.type == 'Quran') {
      final pages = normalized.quranPagesRead ??
          (normalized.versesCount > 0
              ? (normalized.versesCount / 20).ceil().clamp(1, 600)
              : null);
      if (pages != null && pages > 0) {
        await _updateQuranProgress(pages);
      }
    }

    await _updateTotalStreak();
    await _checkAchievements();

    notifyListeners();
  }

  Future<void> logIbadatWithJournal(IbadatLog log, String journalNote) async {
    final updatedLog = IbadatLog(
      type: log.type,
      date: log.date,
      salahCount: log.salahCount,
      sawmType: log.sawmType,
      rakahCount: log.rakahCount,
      versesCount: log.versesCount,
      surahName: log.surahName,
      sadaqatType: log.sadaqatType,
      note: log.note,
      amount: log.amount,
      journalNote: journalNote,
      quranPagesRead: log.quranPagesRead,
      quranJuz: log.quranJuz,
    );
    await logIbadat(updatedLog);
  }

  // ============ STREAK MANAGEMENT ============
  // Single source of truth for streaks: derive each type's current streak
  // fully from its log history. Called after every log/toggle action and
  // on app load, so there's only one code path to keep correct.

  Future<void> _recalculateStreaks() async {
    final today = DateTime.now();
    final newStreaks = <String, int>{};

    for (final type in ibadatTypes) {
      final typeLogs = _logs
          .where((log) => log.type == type)
          .toList()
        ..sort((a, b) => a.date.compareTo(b.date));

      if (typeLogs.isEmpty) {
        newStreaks[type] = 0;
        continue;
      }

      int streak = 0;
      DateTime? lastDate;

      for (final log in typeLogs) {
        final logDate = DateTime(log.date.year, log.date.month, log.date.day);

        if (lastDate == null) {
          streak = 1;
          lastDate = logDate;
        } else {
          final difference = logDate.difference(lastDate).inDays;
          if (difference == 1) {
            streak++;
            lastDate = logDate;
          } else if (difference > 1) {
            streak = 1;
            lastDate = logDate;
          }
          // difference == 0 (same day, shouldn't normally happen given
          // the unique constraint) leaves streak/lastDate unchanged.
        }
      }

      if (lastDate != null) {
        final daysSinceLast = today.difference(
          DateTime(lastDate.year, lastDate.month, lastDate.day)
        ).inDays;
        if (daysSinceLast > 1) {
          streak = 0;
        }
      }

      newStreaks[type] = streak;
    }

    _streaks = newStreaks;
    await _storage.saveStreaks(_streaks);
  }

  Future<void> _updateTotalStreak() async {
    final totalStreak = _streaks.values.fold(0, (sum, value) => sum + value);
    if (_userData != null) {
      _userData!['streaks'] = totalStreak;
      await _storage.saveUserData(_userData!);
    }
  }

  // ============ POINTS ============

  double _calculatePoints(IbadatLog log) {
    switch (log.type) {
      case 'Salah':
        return log.salahCount * 10.0;
      case 'Sawm':
        return log.sawmType == 'Fardh' ? 50.0 : 25.0;
      case 'Qiyyam':
        return log.rakahCount * 5.0;
      case 'Quran':
        return log.versesCount * 0.5;
      case 'Sadaqat':
        // Previously used a random multiplier, so identical donations
        // earned different points each time. Made deterministic: 1 point
        // per unit donated. Swap in a fixed multiplier here if you want
        // Sadaqat to be worth more than a straight 1:1.
        return log.amount;
      default:
        return 0;
    }
  }

  double getTotalPoints() {
    return _points.values.fold(0.0, (sum, value) => sum + value);
  }

  Map<String, double> getStreakPercentages() {
    final today = DateTime.now();
    final Map<String, double> percentages = {};

    for (final type in ibadatTypes) {
      final todayLogs = _logs.where((log) =>
        log.type == type &&
        log.date.year == today.year &&
        log.date.month == today.month &&
        log.date.day == today.day
      );

      switch (type) {
        case 'Salah':
          final count = todayLogs.fold(0, (sum, log) => sum + log.salahCount);
          percentages[type] = (count / 5) * 100;
          break;
        case 'Sawm':
          percentages[type] = todayLogs.isNotEmpty ? 100.0 : 0.0;
          break;
        case 'Qiyyam':
          percentages[type] = todayLogs.isNotEmpty ? 100.0 : 0.0;
          break;
        case 'Quran':
          final verses = todayLogs.fold(0, (sum, log) => sum + log.versesCount);
          if (verses == 0) {
            percentages[type] = 0.0;
          } else {
            int denominator = 140;
            int multiplier = 1;
            while (verses > denominator * multiplier) {
              multiplier++;
            }
            final maxVerses = denominator * multiplier;
            percentages[type] = (verses / maxVerses) * 100;
          }
          break;
        case 'Sadaqat':
          percentages[type] = todayLogs.isNotEmpty ? 100.0 : 0.0;
          break;
      }
    }
    return percentages;
  }

  // ============ QURAN PROGRESS ============

  Future<void> _updateQuranProgress(int pagesRead) async {
    _quranProgress.pagesRead += pagesRead;
    _quranProgress.lastRead = DateTime.now();

    while (_quranProgress.pagesRead >= _quranProgress.totalPages) {
      _quranProgress.pagesRead -= _quranProgress.totalPages;
      _quranProgress.juz++;
      if (_quranProgress.juz > 30) {
        _quranProgress.juz = 30;
        _quranProgress.pagesRead = _quranProgress.totalPages;
        break;
      }
    }

    await _storage.saveQuranProgress(_quranProgress);
  }

  Future<void> setQuranDailyGoal(int pages) async {
    _quranProgress.dailyGoalPages = pages;
    await _storage.saveQuranProgress(_quranProgress);
    notifyListeners();
  }

  double getQuranCompletionPercentage() {
    final totalPages = 30 * 20; // 30 Juz * 20 pages each
    final pagesRead = (_quranProgress.juz - 1) * 20 + _quranProgress.pagesRead;
    return (pagesRead / totalPages) * 100;
  }

  // ============ ADHKAR ============

  Future<void> logAdhkar(String adhkarId, int count) async {
    final today = DateTime.now();
    final day = DateTime(today.year, today.month, today.day);
    final previous = getAdhkarCount(adhkarId, day);
    final log = AdhkarLog(
      adhkarId: adhkarId,
      date: day,
      count: count,
    );

    _adhkarLogs.removeWhere((l) =>
      l.adhkarId == adhkarId &&
      l.date.year == today.year &&
      l.date.month == today.month &&
      l.date.day == today.day
    );

    _adhkarLogs.add(log);
    await _storage.addAdhkarLog(log);

    // Award points only for newly completed repetitions so re-opening the
    // counter doesn't inflate the score.
    final delta = (count - previous).clamp(0, count);
    if (delta > 0) {
      _points['Adhkar'] = (_points['Adhkar'] ?? 0) + (delta * 0.5);
      await _storage.savePoints(_points);
    }

    await _checkAchievements();
    notifyListeners();
  }

  int getAdhkarCount(String adhkarId, DateTime date) {
    final log = _adhkarLogs.firstWhere(
      (l) => l.adhkarId == adhkarId &&
             l.date.year == date.year &&
             l.date.month == date.month &&
             l.date.day == date.day,
      orElse: () => AdhkarLog(adhkarId: adhkarId, date: date, count: 0),
    );
    return log.count;
  }

  bool isAdhkarCompleted(String adhkarId, int requiredCount, DateTime date) {
    final count = getAdhkarCount(adhkarId, date);
    return count >= requiredCount;
  }

  // ============ ACHIEVEMENTS ============

  Future<void> _checkAchievements() async {
    bool updated = false;

    for (final achievementData in achievements) {
      final id = achievementData['id'] as String;
      var index = _userAchievements.indexWhere((a) => a.achievementId == id);
      // firstWhere(orElse:) previously created a throwaway object that was
      // never inserted into _userAchievements, so unlocked achievements
      // were lost on the next save/reload.
      if (index < 0) {
        _userAchievements.add(UserAchievement(achievementId: id));
        index = _userAchievements.length - 1;
        updated = true;
      }
      final existing = _userAchievements[index];

      if (existing.isUnlocked) continue;

      int progress = 0;
      switch (achievementData['category']) {
        case 'Salah':
          progress = _streaks['Salah'] ?? 0;
          break;
        case 'Quran':
          progress = (_quranProgress.juz - 1) * 20 + _quranProgress.pagesRead;
          break;
        case 'Sawm':
          // Use total logged fasts (not consecutive streak) so "Completed N
          // fasts" achievements match their description.
          progress = _logs.where((l) => l.type == 'Sawm').length;
          break;
        case 'Qiyyam':
          progress = _logs.where((l) => l.type == 'Qiyyam').length;
          break;
        case 'Sadaqat':
          progress = _logs.where((l) => l.type == 'Sadaqat').length;
          break;
        default:
          continue;
      }

      if (progress >= achievementData['requirement']) {
        existing.isUnlocked = true;
        existing.unlockedAt = DateTime.now();
        existing.currentProgress = progress;
        updated = true;

        final bonusPoints = (achievementData['requirement'] as int) * 5;
        _points['Achievements'] = (_points['Achievements'] ?? 0) + bonusPoints.toDouble();
        await _storage.savePoints(_points);
      } else if (existing.currentProgress != progress) {
        existing.currentProgress = progress;
        updated = true;
      }
    }

    if (updated) {
      await _storage.saveAchievements(_userAchievements);
      notifyListeners();
    }
  }

  List<Achievement> getAllAchievements() {
    return achievements.map((data) {
      final userAchievement = _userAchievements.firstWhere(
        (a) => a.achievementId == data['id'],
        orElse: () => UserAchievement(achievementId: data['id']),
      );
      return Achievement(
        id: data['id'],
        title: data['title'],
        description: data['description'],
        icon: data['icon'],
        category: data['category'],
        requirement: data['requirement'],
        isUnlocked: userAchievement.isUnlocked,
        unlockedAt: userAchievement.unlockedAt,
      );
    }).toList();
  }

  int getUnlockedAchievementCount() {
    return _userAchievements.where((a) => a.isUnlocked).length;
  }

  // ============ SETTINGS ============

  Future<void> updateSettings(UserSettings newSettings) async {
    final autoBackupChanged = newSettings.backupAuto != _settings.backupAuto;

    _settings = newSettings;
    await _storage.saveSettings(_settings);

    if (autoBackupChanged) {
      _scheduleAutoBackup();
    }

    notifyListeners();
  }

  // ============ BACKUP ============

  Future<String> exportBackup() async {
    return await _storage.exportBackup();
  }

  Future<void> importBackup(String jsonData) async {
    await _storage.importBackup(jsonData);
    await _loadAllData();
  }

  Future<void> clearAllData() async {
    await _storage.clearAllData();
    await _loadAllData();
  }

  // ============ HELPER METHODS ============

  Map<String, List<IbadatLog>> getLogsByDate() {
    final Map<String, List<IbadatLog>> grouped = {};
    for (final log in _logs) {
      final key = '${log.date.year}-${log.date.month}-${log.date.day}';
      if (!grouped.containsKey(key)) {
        grouped[key] = [];
      }
      grouped[key]!.add(log);
    }
    return grouped;
  }

  List<IbadatLog> getLogsForDate(DateTime date) {
    return _logs.where((log) =>
      log.date.year == date.year &&
      log.date.month == date.month &&
      log.date.day == date.day
    ).toList();
  }
}