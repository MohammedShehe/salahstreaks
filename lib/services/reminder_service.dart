import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:shared_preferences/shared_preferences.dart';

class ReminderService {
  static const MethodChannel _channel = MethodChannel('salahstreaks/reminders');
  
  // Salah times (24-hour format)
  final Map<String, Map<String, int>> salahTimes = {
    'Fajr': {'hour': 5, 'minute': 0},
    'Dhuhr': {'hour': 13, 'minute': 30},
    'Asr': {'hour': 17, 'minute': 0},
    'Maghrib': {'hour': 18, 'minute': 30},
    'Isha': {'hour': 21, 'minute': 0},
    'Qiyyam Layl': {'hour': 1, 'minute': 30},
  };

  List<String> _shownReminders = [];
  String _lastDate = '';

  Future<void> initialize() async {
    // Set up channel for receiving messages from native side
    _channel.setMethodCallHandler(_handleMethodCall);
    
    // Reset daily reminders
    final prefs = await SharedPreferences.getInstance();
    final today = DateTime.now().toIso8601String().split('T')[0];
    _lastDate = prefs.getString('last_reminder_date') ?? '';
    
    if (_lastDate != today) {
      await prefs.setString('last_reminder_date', today);
      await prefs.setStringList('shown_reminders', []);
      _shownReminders = [];
    } else {
      _shownReminders = prefs.getStringList('shown_reminders') ?? [];
    }
  }

  Future<dynamic> _handleMethodCall(MethodCall call) async {
    if (call.method == 'showReminder') {
      final String title = call.arguments['title'];
      final String body = call.arguments['body'];
      // Show a dialog or snackbar when reminder is triggered
      // We'll handle this in the UI
      return true;
    }
    return false;
  }

  Future<void> scheduleAllReminders() async {
    // Schedule daily Quran verse reminder (6:00 AM)
    await _scheduleReminder(
      id: 100,
      title: '📖 Daily Quran Verse',
      body: 'Check your daily Quran verse for reflection today!',
      hour: 6,
      minute: 0,
      recurring: true,
    );
    
    // Schedule Salah reminders
    int id = 1;
    for (final entry in salahTimes.entries) {
      await _scheduleReminder(
        id: id,
        title: '🕌 ${entry.key} Time',
        body: 'It\'s time for ${entry.key} prayer. Don\'t forget!',
        hour: entry.value['hour']!,
        minute: entry.value['minute']!,
        recurring: true,
      );
      id++;
    }
  }

  Future<void> _scheduleReminder({
    required int id,
    required String title,
    required String body,
    required int hour,
    required int minute,
    required bool recurring,
  }) async {
    try {
      await _channel.invokeMethod('scheduleReminder', {
        'id': id,
        'title': title,
        'body': body,
        'hour': hour,
        'minute': minute,
        'recurring': recurring,
      });
    } catch (e) {
      print('Error scheduling reminder: $e');
    }
  }

  Future<void> cancelAllReminders() async {
    try {
      await _channel.invokeMethod('cancelAllReminders');
    } catch (e) {
      print('Error cancelling reminders: $e');
    }
  }

  Future<void> cancelReminder(int id) async {
    try {
      await _channel.invokeMethod('cancelReminder', {'id': id});
    } catch (e) {
      print('Error cancelling reminder: $e');
    }
  }

  // ============ NEW METHODS FOR IN-APP REMINDERS ============

  List<Map<String, String>> checkDueReminders() {
    final now = DateTime.now();
    final dueReminders = <Map<String, String>>[];
    final today = now.toIso8601String().split('T')[0];
    final currentMinute = now.hour * 60 + now.minute;
    
    // Check Quran verse (6:00 AM)
    if (now.hour == 6 && now.minute < 1) {
      final key = 'verse_$today';
      if (!_shownReminders.contains(key)) {
        dueReminders.add({
          'title': '📖 Daily Quran Verse',
          'body': 'Check your daily Quran verse for reflection today!',
          'key': key,
        });
      }
    }
    
    // Check Salah times
    for (final entry in salahTimes.entries) {
      final hour = entry.value['hour']!;
      final minute = entry.value['minute']!;
      final reminderMinute = hour * 60 + minute;
      
      // Check if current time is within 1 minute of prayer time
      if (currentMinute >= reminderMinute && currentMinute < reminderMinute + 1) {
        final key = '${entry.key}_$today';
        if (!_shownReminders.contains(key)) {
          dueReminders.add({
            'title': '🕌 ${entry.key} Time',
            'body': 'It\'s time for ${entry.key} prayer. Don\'t forget!',
            'key': key,
          });
        }
      }
    }
    
    return dueReminders;
  }

  Future<void> markReminderShown(String key) async {
    final prefs = await SharedPreferences.getInstance();
    if (!_shownReminders.contains(key)) {
      _shownReminders.add(key);
      await prefs.setStringList('shown_reminders', _shownReminders);
    }
  }

  void showInAppReminder(BuildContext context, String title, String body) {
    // Check if context is still valid
    if (!context.mounted) return;
    
    try {
      // Show as SnackBar
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Column(
            mainAxisSize: MainAxisSize.min,
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text(
                title,
                style: const TextStyle(
                  fontWeight: FontWeight.bold,
                  fontSize: 14,
                ),
              ),
              const SizedBox(height: 4),
              Text(
                body,
                style: const TextStyle(fontSize: 12),
              ),
            ],
          ),
          backgroundColor: Colors.green[800],
          duration: const Duration(seconds: 10),
          behavior: SnackBarBehavior.floating,
          shape: RoundedRectangleBorder(
            borderRadius: BorderRadius.circular(12),
          ),
          margin: const EdgeInsets.all(16),
        ),
      );
    } catch (e) {
      print('Error showing reminder: $e');
    }
  }
}