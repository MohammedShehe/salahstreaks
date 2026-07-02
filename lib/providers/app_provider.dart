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
    notifyListeners();
  }

  // ✅ ADD THIS METHOD - Check if any ibadat type is already logged today
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

  Future<void> logIbadat(IbadatLog log) async {
    final today = DateTime.now();
    
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
    
    // Update streaks
    final yesterday = today.subtract(const Duration(days: 1));
    
    if (_streaks.containsKey(log.type) && 
        _logs.where((l) => 
          l.type == log.type && 
          l.date.year == yesterday.year &&
          l.date.month == yesterday.month &&
          l.date.day == yesterday.day
        ).isNotEmpty) {
      _streaks[log.type] = (_streaks[log.type] ?? 0) + 1;
    } else {
      _streaks[log.type] = 1;
    }
    
    // Calculate points
    final points = _calculatePoints(log);
    _points[log.type] = (_points[log.type] ?? 0) + points;
    
    await _storage.saveStreaks(_streaks);
    await _storage.savePoints(_points);
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