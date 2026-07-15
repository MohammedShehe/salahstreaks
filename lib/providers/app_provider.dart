import 'package:flutter/material.dart';
import 'package:salahstreaks/models/ibadat_model.dart';
import 'package:salahstreaks/services/storage_service.dart';
import 'package:salahstreaks/utils/constants.dart';
import 'dart:math';

class AppProvider extends ChangeNotifier {
  final StorageService _storage = StorageService();
  
  Map<String, dynamic>? _userData;
  List<IbadatLog> _logs = [];
  Map<String, int> _streaks = {};
  Map<String, double> _points = {};

  AppProvider() {
    _loadData();
  }

  Map<String, dynamic>? get userData => _userData;
  List<IbadatLog> get logs => _logs;
  Map<String, int> get streaks => _streaks;
  Map<String, double> get points => _points;

  Future<void> _loadData() async {
    _userData = await _storage.loadUserData();
    _logs = await _storage.loadLogs();
    _streaks = await _storage.loadStreaks();
    _points = await _storage.loadPoints();
    
    await _recalculateStreaks();
    
    final totalStreak = _streaks.values.fold(0, (sum, value) => sum + value);
    if (_userData != null) {
      _userData!['streaks'] = totalStreak;
      await _storage.saveUserData(_userData!);
    }
    
    notifyListeners();
  }

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

  // Toggle a specific Salah prayer (mark/unmark)
  Future<void> toggleSalah(String prayerName) async {
    final today = DateTime.now();
    final prayed = getTodayPrayedSalah();
    
    // Toggle the prayer
    if (prayed.contains(prayerName)) {
      prayed.remove(prayerName);
    } else {
      prayed.add(prayerName);
    }
    
    // Update the log
    final count = prayed.length;
    final note = 'prayed:${prayed.join(',')}';
    
    final log = IbadatLog(
      type: 'Salah',
      date: today,
      salahCount: count,
      sawmType: '',
      rakahCount: 0,
      versesCount: 0,
      surahName: '',
      sadaqatType: '',
      note: note,
      amount: 0.0,
    );
    
    // Remove existing log if any
    _logs.removeWhere((l) => 
      l.type == 'Salah' &&
      l.date.year == today.year &&
      l.date.month == today.month &&
      l.date.day == today.day
    );
    
    // Add the updated log
    _logs.add(log);
    await _storage.saveLogs(_logs);
    
    // Recalculate streaks instead of incrementing
    await _recalculateStreaks();
    await _updateTotalStreak();
    
    notifyListeners();
  }

  Future<void> logIbadat(IbadatLog log) async {
    final today = DateTime.now();
    final yesterday = today.subtract(const Duration(days: 1));
    
    if (log.type == 'Salah') {
      // Salah is handled by toggleSalah
      return;
    } else {
      final alreadyLogged = _logs.any((l) => 
        l.type == log.type &&
        l.date.year == today.year &&
        l.date.month == today.month &&
        l.date.day == today.day
      );

      if (alreadyLogged) {
        return;
      }
    }

    _logs.add(log);
    await _storage.saveLogs(_logs);
    
    await _updateStreak(log.type, today, yesterday);
    
    final points = _calculatePoints(log);
    _points[log.type] = (_points[log.type] ?? 0) + points;
    await _storage.savePoints(_points);
    
    await _updateTotalStreak();
    
    notifyListeners();
  }

  Future<void> _updateStreak(String type, DateTime today, DateTime yesterday) async {
    final hasYesterdayLog = _logs.any((l) => 
      l.type == type && 
      l.date.year == yesterday.year &&
      l.date.month == yesterday.month &&
      l.date.day == yesterday.day
    );
    
    final hasTodayLog = _logs.any((l) => 
      l.type == type && 
      l.date.year == today.year &&
      l.date.month == today.month &&
      l.date.day == today.day
    );
    
    if (hasYesterdayLog && hasTodayLog) {
      _streaks[type] = (_streaks[type] ?? 0) + 1;
    } else if (!hasYesterdayLog && hasTodayLog) {
      final typeLogs = _logs
          .where((l) => l.type == type)
          .toList()
        ..sort((a, b) => a.date.compareTo(b.date));
      
      if (typeLogs.isNotEmpty) {
        final lastLog = typeLogs.last;
        final daysSinceLast = today.difference(
          DateTime(lastLog.date.year, lastLog.date.month, lastLog.date.day)
        ).inDays;
        
        if (daysSinceLast <= 1) {
          _streaks[type] = (_streaks[type] ?? 0) + 1;
        } else {
          _streaks[type] = 1;
        }
      } else {
        _streaks[type] = 1;
      }
    }
    
    await _storage.saveStreaks(_streaks);
  }

  Future<void> _recalculateStreaks() async {
    final today = DateTime.now();
    final newStreaks = <String, int>{};
    
    for (final type in ibadatTypes) {
      // Get all logs for this type, sorted by date
      final typeLogs = _logs
          .where((log) => log.type == type)
          .toList()
        ..sort((a, b) => a.date.compareTo(b.date));
      
      if (typeLogs.isEmpty) {
        newStreaks[type] = 0;
        continue;
      }
      
      // Count consecutive days
      int streak = 0;
      DateTime? lastDate;
      
      for (final log in typeLogs) {
        final logDate = DateTime(log.date.year, log.date.month, log.date.day);
        
        if (lastDate == null) {
          // First log
          streak = 1;
          lastDate = logDate;
        } else {
          final difference = logDate.difference(lastDate).inDays;
          if (difference == 1) {
            // Consecutive day
            streak++;
            lastDate = logDate;
          } else if (difference > 1) {
            // Gap in streak
            streak = 1;
            lastDate = logDate;
          }
          // If difference == 0, it's the same day, ignore
        }
      }
      
      // Check if the last streak is still active (logged today or yesterday)
      if (lastDate != null) {
        final daysSinceLast = today.difference(
          DateTime(lastDate.year, lastDate.month, lastDate.day)
        ).inDays;
        if (daysSinceLast > 1) {
          // Streak has expired
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

  double _calculatePoints(IbadatLog log) {
    final random = Random();
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
        final multiplier = [1, 2, 5, 10, 20][random.nextInt(5)];
        return log.amount * multiplier;
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
}