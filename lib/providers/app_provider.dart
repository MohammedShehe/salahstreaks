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

  Future<void> logIbadat(IbadatLog log) async {
    _logs.add(log);
    await _storage.saveLogs(_logs);
    
    // Update streaks
    final today = DateTime.now();
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