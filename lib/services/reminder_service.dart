import 'package:flutter/material.dart';
import 'package:flutter_local_notifications/flutter_local_notifications.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:timezone/timezone.dart' as tz;
import 'package:timezone/data/latest.dart' as tz;
import 'dart:async';

class ReminderService {
  static final FlutterLocalNotificationsPlugin _notifications = 
      FlutterLocalNotificationsPlugin();
  
  List<String> _shownReminders = [];
  String _lastDate = '';
  bool _isInitialized = false;

  // Salah times (24-hour format)
  final Map<String, Map<String, int>> salahTimes = {
    'Fajr': {'hour': 5, 'minute': 0},
    'Dhuhr': {'hour': 13, 'minute': 30},
    'Asr': {'hour': 17, 'minute': 0},
    'Maghrib': {'hour': 18, 'minute': 30},
    'Isha': {'hour': 21, 'minute': 0},
    'Qiyyam Layl': {'hour': 1, 'minute': 30},
  };

  Future<void> initialize() async {
    if (_isInitialized) return;
    
    tz.initializeTimeZones();
    // Without a local location, tz.TZDateTime.now(tz.local) can throw or
    // schedule against UTC, so notifications fire at the wrong wall-clock time.
    try {
      tz.setLocalLocation(tz.local);
    } catch (_) {
      try {
        tz.setLocalLocation(tz.getLocation('UTC'));
      } catch (_) {}
    }
    
    // Initialize local notifications
    const AndroidInitializationSettings androidSettings = 
        AndroidInitializationSettings('@mipmap/ic_launcher');
    const DarwinInitializationSettings iosSettings = 
        DarwinInitializationSettings();
    const InitializationSettings initSettings = InitializationSettings(
      android: androidSettings,
      iOS: iosSettings,
    );
    
    await _notifications.initialize(initSettings);
    
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
    
    _isInitialized = true;
  }

  Future<void> scheduleAllReminders() async {
    try {
      // Schedule daily Quran verse reminder (6:00 AM)
      await _scheduleNotification(
        id: 100,
        title: '📖 Daily Quran Verse',
        body: 'Check your daily Quran verse for reflection today!',
        hour: 6,
        minute: 0,
      );
      
      // Schedule Salah reminders
      int id = 1;
      for (final entry in salahTimes.entries) {
        await _scheduleNotification(
          id: id,
          title: '🕌 ${entry.key} Time',
          body: 'It\'s time for ${entry.key} prayer. Don\'t forget!',
          hour: entry.value['hour']!,
          minute: entry.value['minute']!,
        );
        id++;
      }
      
      // Schedule Morning Adhkar (7:00 AM)
      await _scheduleNotification(
        id: 200,
        title: '🌅 Morning Adhkar',
        body: 'Start your day with morning remembrances!',
        hour: 7,
        minute: 0,
      );
      
      // Schedule Evening Adhkar (6:00 PM)
      await _scheduleNotification(
        id: 201,
        title: '🌆 Evening Adhkar',
        body: 'End your day with evening remembrances!',
        hour: 18,
        minute: 0,
      );
      
      print('✅ All reminders scheduled successfully');
    } catch (e) {
      print('⚠️ Error scheduling reminders: $e');
    }
  }

  Future<void> _scheduleNotification({
    required int id,
    required String title,
    required String body,
    required int hour,
    required int minute,
  }) async {
    try {
      final tz.TZDateTime scheduledTime = _nextInstanceOfTime(hour, minute);
      
      const AndroidNotificationDetails androidDetails = 
          AndroidNotificationDetails(
            'salah_channel',
            'Salah Reminders',
            channelDescription: 'Notifications for prayer times',
            importance: Importance.high,
            priority: Priority.high,
            icon: '@mipmap/ic_launcher',
          );
      
      const DarwinNotificationDetails iosDetails = 
          DarwinNotificationDetails();
      
      const NotificationDetails details = NotificationDetails(
        android: androidDetails,
        iOS: iosDetails,
      );
      
      await _notifications.zonedSchedule(
        id,
        title,
        body,
        scheduledTime,
        details,
        uiLocalNotificationDateInterpretation:
            UILocalNotificationDateInterpretation.absoluteTime,
        androidScheduleMode: AndroidScheduleMode.inexactAllowWhileIdle,
        matchDateTimeComponents: DateTimeComponents.time,
      );
    } catch (e) {
      print('Error scheduling notification $id: $e');
    }
  }

  tz.TZDateTime _nextInstanceOfTime(int hour, int minute) {
    final tz.TZDateTime now = tz.TZDateTime.now(tz.local);
    tz.TZDateTime scheduledDate = tz.TZDateTime(
      tz.local,
      now.year,
      now.month,
      now.day,
      hour,
      minute,
    );
    
    if (scheduledDate.isBefore(now)) {
      scheduledDate = scheduledDate.add(const Duration(days: 1));
    }
    
    return scheduledDate;
  }

  Future<void> cancelAllReminders() async {
    await _notifications.cancelAll();
  }

  Future<void> cancelReminder(int id) async {
    await _notifications.cancel(id);
  }

  // ============ IN-APP REMINDERS ============

  List<Map<String, String>> checkDueReminders() {
    final now = DateTime.now();
    final dueReminders = <Map<String, String>>[];
    final today = now.toIso8601String().split('T')[0];
    final currentMinute = now.hour * 60 + now.minute;
    
    // Check Quran verse (6:00 AM)
    if (now.hour == 6 && now.minute < 2) {
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
      
      if (currentMinute >= reminderMinute && currentMinute < reminderMinute + 2) {
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
    
    // Check Morning Adhkar (7:00 AM)
    if (now.hour == 7 && now.minute < 2) {
      final key = 'morning_adhkar_$today';
      if (!_shownReminders.contains(key)) {
        dueReminders.add({
          'title': '🌅 Morning Adhkar',
          'body': 'Start your day with morning remembrances!',
          'key': key,
        });
      }
    }
    
    // Check Evening Adhkar (6:00 PM)
    if (now.hour == 18 && now.minute < 2) {
      final key = 'evening_adhkar_$today';
      if (!_shownReminders.contains(key)) {
        dueReminders.add({
          'title': '🌆 Evening Adhkar',
          'body': 'End your day with evening remembrances!',
          'key': key,
        });
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
    if (!context.mounted) return;
    
    try {
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
          backgroundColor: const Color(0xFF1A2F1A),
          duration: const Duration(seconds: 15),
          behavior: SnackBarBehavior.floating,
          shape: RoundedRectangleBorder(
            borderRadius: BorderRadius.circular(12),
            side: BorderSide(
              color: Colors.green[700]!.withOpacity(0.3),
            ),
          ),
          margin: const EdgeInsets.all(16),
          elevation: 6,
        ),
      );
    } catch (e) {
      print('Error showing reminder: $e');
    }
  }
}