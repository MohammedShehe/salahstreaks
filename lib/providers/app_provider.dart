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
    
    // Recalculate streaks based on logs to ensure accuracy
    await _recalculateStreaks();
    
    // Update total streak in user data
    final totalStreak = _streaks.values.fold(0, (sum, value) => sum + value);
    if (_userData != null) {
      _userData!['streaks'] = totalStreak;
      await _storage.saveUserData(_userData!);
    }
    
    notifyListeners();
  }

  // Check if any ibadat type is already logged today
  bool isLoggedToday(String type) {
    final today = DateTime.now();
    return _logs.any((log) => 
      log.type == type &&
      log.date.year == today.year &&
      log.date.month == today.month &&
      log.date.day == today.day
    );
  }

  // Get today's Salah log if exists
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

  // Get the current Salah count for today
  int getTodaySalahCount() {
    final log = getTodaySalahLog();
    return log?.salahCount ?? 0;
  }

  // Check if a specific Salah is already logged for today
  bool isSalahLogged(String prayerName) {
    final log = getTodaySalahLog();
    if (log == null) return false;
    
    // Map prayer name to count
    final prayerIndex = {
      'Fajr': 1,
      'Dhuhr': 2,
      'Asr': 3,
      'Maghrib': 4,
      'Isha': 5,
    };
    
    final index = prayerIndex[prayerName] ?? 0;
    return log.salahCount >= index;
  }

  // Get total streak across all ibadat types
  int getTotalStreak() {
    return _streaks.values.fold(0, (sum, value) => sum + value);
  }

  Future<void> logIbadat(IbadatLog log) async {
    final today = DateTime.now();
    final yesterday = today.subtract(const Duration(days: 1));
    
    // If it's Salah, we need special handling
    if (log.type == 'Salah') {
      final existingLog = getTodaySalahLog();
      
      if (existingLog != null) {
        // Update existing log with new count (only if count is higher)
        if (log.salahCount > existingLog.salahCount) {
          final updatedLog = IbadatLog(
            type: 'Salah',
            date: today,
            salahCount: log.salahCount,
            sawmType: '',
            rakahCount: 0,
            versesCount: 0,
            surahName: '',
            sadaqatType: '',
            note: '',
            amount: 0.0,
          );
          
          // Remove old log and add updated one
          _logs.removeWhere((l) => 
            l.type == 'Salah' &&
            l.date.year == today.year &&
            l.date.month == today.month &&
            l.date.day == today.day
          );
          _logs.add(updatedLog);
          await _storage.saveLogs(_logs);
          
          // Update streaks for Salah
          await _updateStreak('Salah', today, yesterday);
          await _updateTotalStreak();
          notifyListeners();
        }
        return;
      }
    } else {
      // For non-Salah types, check if already logged today
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
    
    // Update streaks for the specific type
    await _updateStreak(log.type, today, yesterday);
    
    // Calculate points
    final points = _calculatePoints(log);
    _points[log.type] = (_points[log.type] ?? 0) + points;
    await _storage.savePoints(_points);
    
    // Update total streak in user data
    await _updateTotalStreak();
    
    notifyListeners();
  }

  // Toggle a specific Salah prayer
  Future<void> toggleSalah(String prayerName) async {
    final today = DateTime.now();
    final currentCount = getTodaySalahCount();
    
    // Map prayer name to count
    final prayerIndex = {
      'Fajr': 1,
      'Dhuhr': 2,
      'Asr': 3,
      'Maghrib': 4,
      'Isha': 5,
    };
    
    final index = prayerIndex[prayerName] ?? 0;
    
    // If already logged, don't do anything (can't unmark)
    if (currentCount >= index) {
      return;
    }
    
    // Log the Salah with updated count
    final log = IbadatLog(
      type: 'Salah',
      date: today,
      salahCount: index,
      sawmType: '',
      rakahCount: 0,
      versesCount: 0,
      surahName: '',
      sadaqatType: '',
      note: '',
      amount: 0.0,
    );
    
    await logIbadat(log);
  }

  // Helper method to update streak for a specific type
  Future<void> _updateStreak(String type, DateTime today, DateTime yesterday) async {
    // Check if there's a log for yesterday
    final hasYesterdayLog = _logs.any((l) => 
      l.type == type && 
      l.date.year == yesterday.year &&
      l.date.month == yesterday.month &&
      l.date.day == yesterday.day
    );
    
    // Check if there's already a log for today
    final hasTodayLog = _logs.any((l) => 
      l.type == type && 
      l.date.year == today.year &&
      l.date.month == today.month &&
      l.date.day == today.day
    );
    
    if (hasYesterdayLog && hasTodayLog) {
      // Continue streak
      _streaks[type] = (_streaks[type] ?? 0) + 1;
    } else if (!hasYesterdayLog && hasTodayLog) {
      // Start new streak or reset
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
          // This is a continuation (today is after yesterday or same day)
          _streaks[type] = (_streaks[type] ?? 0) + 1;
        } else {
          // Gap in streak, reset to 1
          _streaks[type] = 1;
        }
      } else {
        // First time logging this type
        _streaks[type] = 1;
      }
    }
    // If no today log, don't change streak
    
    await _storage.saveStreaks(_streaks);
  }

  // Recalculate all streaks from logs
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

  // Update total streak in user data
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
          percentages[type] = (verses / 140) * 100;
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