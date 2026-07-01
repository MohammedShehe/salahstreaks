import 'package:shared_preferences/shared_preferences.dart';
import 'dart:convert';
import 'package:salahstreaks/models/ibadat_model.dart';

class StorageService {
  static const String _userDataKey = 'user_data';
  static const String _logsKey = 'logs';
  static const String _streaksKey = 'streaks';
  static const String _pointsKey = 'points';

  Future<SharedPreferences> _getPrefs() async {
    return await SharedPreferences.getInstance();
  }

  Future<Map<String, dynamic>> loadUserData() async {
    final prefs = await _getPrefs();
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
    final prefs = await _getPrefs();
    await prefs.setString(_userDataKey, json.encode(data));
  }

  Future<List<IbadatLog>> loadLogs() async {
    final prefs = await _getPrefs();
    final data = prefs.getString(_logsKey);
    if (data != null) {
      final List<dynamic> jsonList = json.decode(data);
      return jsonList.map((json) => IbadatLog.fromJson(json)).toList();
    }
    return [];
  }

  Future<void> saveLogs(List<IbadatLog> logs) async {
    final prefs = await _getPrefs();
    final jsonList = logs.map((log) => log.toJson()).toList();
    await prefs.setString(_logsKey, json.encode(jsonList));
  }

  Future<Map<String, int>> loadStreaks() async {
    final prefs = await _getPrefs();
    final data = prefs.getString(_streaksKey);
    if (data != null) {
      return Map<String, int>.from(json.decode(data));
    }
    return {};
  }

  Future<void> saveStreaks(Map<String, int> streaks) async {
    final prefs = await _getPrefs();
    await prefs.setString(_streaksKey, json.encode(streaks));
  }

  Future<Map<String, double>> loadPoints() async {
    final prefs = await _getPrefs();
    final data = prefs.getString(_pointsKey);
    if (data != null) {
      final Map<String, dynamic> temp = json.decode(data);
      return temp.map((key, value) => MapEntry(key, value.toDouble()));
    }
    return {};
  }

  Future<void> savePoints(Map<String, double> points) async {
    final prefs = await _getPrefs();
    await prefs.setString(_pointsKey, json.encode(points));
  }
}