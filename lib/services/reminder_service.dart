import 'dart:io';

import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_local_notifications/flutter_local_notifications.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:salahstreaks/models/user_settings_model.dart';
import 'package:timezone/data/latest.dart' as tz;
import 'package:timezone/timezone.dart' as tz;

/// Handles all reminder notifications locally on the device.
///
/// No Firebase, push server, cron server, or backend is required. Android and
/// iOS persist the schedules through their native notification/alarm systems.
class ReminderService {
  ReminderService._internal();

  static final ReminderService _instance = ReminderService._internal();
  factory ReminderService() => _instance;

  static const MethodChannel _platformChannel =
      MethodChannel('salahstreaks/reminders');

  static final FlutterLocalNotificationsPlugin _notifications =
      FlutterLocalNotificationsPlugin();

  static const int _quranReminderId = 100;
  static const int _morningAdhkarId = 200;
  static const int _eveningAdhkarId = 201;

  List<String> _shownReminders = [];
  String _lastDate = '';
  bool _isInitialized = false;
  UserSettings? _activeSettings;

  // Salah times (24-hour format). These are the existing app defaults.
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
    await _setDeviceTimeZone();

    const androidSettings =
        AndroidInitializationSettings('@mipmap/ic_launcher');
    const iosSettings = DarwinInitializationSettings(
      requestAlertPermission: false,
      requestBadgePermission: false,
      requestSoundPermission: false,
    );
    const initSettings = InitializationSettings(
      android: androidSettings,
      iOS: iosSettings,
    );

    await _notifications.initialize(initSettings);

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

  Future<void> _setDeviceTimeZone() async {
    try {
      final zoneName = await _platformChannel.invokeMethod<String>('getTimeZoneName');
      if (zoneName != null && zoneName.isNotEmpty) {
        tz.setLocalLocation(tz.getLocation(zoneName));
        return;
      }
    } catch (e) {
      debugPrint('Could not read native timezone: $e');
    }

    // Safe fallback. Normally Android/iOS return an IANA timezone above.
    try {
      tz.setLocalLocation(tz.getLocation('UTC'));
    } catch (_) {}
  }

  /// Requests notification/exact-alarm access once when the app first needs
  /// reminders. Subsequent launches reuse the existing OS permission state.
  Future<void> ensureInitialPermissionsAndSchedule(UserSettings settings) async {
    await initialize();
    if (!settings.notificationsEnabled) {
      await _notifications.cancelAll();
      return;
    }

    final prefs = await SharedPreferences.getInstance();
    final askedBefore = prefs.getBool('notification_permissions_requested') ?? false;

    if (!askedBefore) {
      final granted = await applySettings(settings, requestPermission: true);
      await prefs.setBool('notification_permissions_requested', true);
      if (!granted) return;
      return;
    }

    // Permission was previously requested. Do not reopen Android system
    // settings on every launch; schedule only when the OS still allows it.
    await applySettings(settings, requestPermission: false);
  }

  /// Applies persisted settings and rebuilds all device schedules.
  /// Returns false only when notification permission was not granted.
  Future<bool> applySettings(
    UserSettings settings, {
    bool requestPermission = true,
  }) async {
    await initialize();
    _activeSettings = settings;

    // Always clear old schedules first so disabling an individual reminder
    // takes effect immediately and doesn't leave a stale daily alarm behind.
    await _notifications.cancelAll();

    if (!settings.notificationsEnabled) return true;

    final granted = requestPermission
        ? await requestPermissions()
        : await _permissionsStillGranted();
    if (!granted) return false;

    await scheduleAllReminders(settings);
    return true;
  }

  Future<bool> _permissionsStillGranted() async {
    if (Platform.isAndroid) {
      final android = _notifications.resolvePlatformSpecificImplementation<
          AndroidFlutterLocalNotificationsPlugin>();
      if (android == null) return false;

      final notificationsGranted = await android.areNotificationsEnabled();
      if (notificationsGranted == false) return false;

      try {
        final exactGranted = await android.canScheduleExactNotifications();
        if (exactGranted == false) return false;
      } catch (_) {
        // Android versions without exact-alarm special access can continue.
      }
      return true;
    }

    if (Platform.isIOS) {
      final ios = _notifications.resolvePlatformSpecificImplementation<
          IOSFlutterLocalNotificationsPlugin>();
      final permissions = await ios?.checkPermissions();
      return permissions?.isEnabled ?? false;
    }

    return true;
  }

  Future<bool> requestPermissions() async {
    if (Platform.isAndroid) {
      final android = _notifications.resolvePlatformSpecificImplementation<
          AndroidFlutterLocalNotificationsPlugin>();
      if (android == null) return false;

      final notificationGranted = await android.requestNotificationsPermission();
      if (notificationGranted == false) return false;

      // Exact reminders are intentionally used because Quran, Adhkar and
      // prayer reminders are user-facing, time-specific notifications.
      // Android 12+ protects exact alarms with a special access permission.
      // Do not silently fall back to an inexact alarm: that could make a
      // reminder appear minutes late.
      try {
        final exactGranted = await android.canScheduleExactNotifications();
        if (exactGranted == false) {
          final requested = await android.requestExactAlarmsPermission();
          return requested ?? false;
        }
      } catch (e) {
        // Devices below Android 12 do not expose the exact-alarm capability.
        debugPrint('Exact alarm permission check unavailable: $e');
      }

      return true;
    }

    if (Platform.isIOS) {
      final ios = _notifications.resolvePlatformSpecificImplementation<
          IOSFlutterLocalNotificationsPlugin>();
      final granted = await ios?.requestPermissions(
        alert: true,
        badge: true,
        sound: true,
      );
      return granted ?? false;
    }

    return true;
  }

  Future<void> scheduleAllReminders(UserSettings settings) async {
    if (!settings.notificationsEnabled) return;

    if (settings.quranReminders) {
      await _scheduleNotification(
        id: _quranReminderId,
        title: '📖 Daily Quran Verse',
        body: 'Your daily Quran reminder is ready — take a moment to read and reflect.',
        hour: 6,
        minute: 0,
        settings: settings,
      );
    }

    if (settings.prayerReminders) {
      var id = 1;
      for (final entry in salahTimes.entries) {
        await _scheduleNotification(
          id: id,
          title: '🕌 ${entry.key} Time',
          body: 'It\'s time for ${entry.key} prayer.',
          hour: entry.value['hour']!,
          minute: entry.value['minute']!,
          settings: settings,
        );
        id++;
      }
    }

    if (settings.adhkarReminders) {
      await _scheduleNotification(
        id: _morningAdhkarId,
        title: '🌅 Morning Adhkar',
        body: 'Start your day with your morning Adhkar.',
        hour: 7,
        minute: 0,
        settings: settings,
      );

      await _scheduleNotification(
        id: _eveningAdhkarId,
        title: '🌆 Evening Adhkar',
        body: 'Take a moment for your evening Adhkar.',
        hour: 18,
        minute: 0,
        settings: settings,
      );
    }
  }

  Future<void> _scheduleNotification({
    required int id,
    required String title,
    required String body,
    required int hour,
    required int minute,
    required UserSettings settings,
  }) async {
    final scheduledTime = _nextInstanceOfTime(hour, minute);

    // Android channel sound/vibration behaviour is immutable after a channel
    // is first created, so use a stable channel per preference combination.
    final channelSuffix =
        '${settings.notificationsSound ? 'sound' : 'silent'}_'
        '${settings.notificationsVibrate ? 'vibrate' : 'novibrate'}';

    final androidDetails = AndroidNotificationDetails(
      'salahstreaks_reminders_$channelSuffix',
      'SalahStreaks Reminders',
      channelDescription: 'Quran, Adhkar and prayer reminders',
      importance: Importance.high,
      priority: Priority.high,
      icon: '@mipmap/ic_launcher',
      playSound: settings.notificationsSound,
      enableVibration: settings.notificationsVibrate,
      enableLights: true,
      category: AndroidNotificationCategory.reminder,
    );

    final iosDetails = DarwinNotificationDetails(
      presentAlert: true,
      presentBadge: true,
      presentSound: settings.notificationsSound,
      interruptionLevel: InterruptionLevel.active,
    );

    await _notifications.zonedSchedule(
      id,
      title,
      body,
      scheduledTime,
      NotificationDetails(android: androidDetails, iOS: iosDetails),
      uiLocalNotificationDateInterpretation:
          UILocalNotificationDateInterpretation.absoluteTime,
      // Exact + allow-while-idle keeps the notification on the requested
      // wall-clock minute even while Android is in Doze/low-power idle.
      // This requires the user's Alarms & reminders special access on
      // Android 12+. We deliberately do not use an inexact schedule because
      // Android may defer an inexact alarm substantially.
      androidScheduleMode: AndroidScheduleMode.exactAllowWhileIdle,
      matchDateTimeComponents: DateTimeComponents.time,
    );
  }

  tz.TZDateTime _nextInstanceOfTime(int hour, int minute) {
    final now = tz.TZDateTime.now(tz.local);
    var scheduledDate = tz.TZDateTime(
      tz.local,
      now.year,
      now.month,
      now.day,
      hour,
      minute,
    );

    if (!scheduledDate.isAfter(now)) {
      scheduledDate = scheduledDate.add(const Duration(days: 1));
    }

    return scheduledDate;
  }

  Future<void> cancelAllReminders() async {
    await initialize();
    await _notifications.cancelAll();
  }

  Future<void> cancelReminder(int id) async {
    await initialize();
    await _notifications.cancel(id);
  }

  // ============ IN-APP REMINDERS ============

  List<Map<String, String>> checkDueReminders() {
    final settings = _activeSettings;
    if (settings == null || !settings.notificationsEnabled) return [];

    final now = DateTime.now();
    final dueReminders = <Map<String, String>>[];
    final today = now.toIso8601String().split('T')[0];
    final currentMinute = now.hour * 60 + now.minute;

    if (settings.quranReminders && now.hour == 6 && now.minute < 2) {
      final key = 'verse_$today';
      if (!_shownReminders.contains(key)) {
        dueReminders.add({
          'title': '📖 Daily Quran Verse',
          'body': 'Your daily Quran reminder is ready — take a moment to read and reflect.',
          'key': key,
        });
      }
    }

    if (settings.prayerReminders) {
      for (final entry in salahTimes.entries) {
        final hour = entry.value['hour']!;
        final minute = entry.value['minute']!;
        final reminderMinute = hour * 60 + minute;

        if (currentMinute >= reminderMinute &&
            currentMinute < reminderMinute + 2) {
          final key = '${entry.key}_$today';
          if (!_shownReminders.contains(key)) {
            dueReminders.add({
              'title': '🕌 ${entry.key} Time',
              'body': 'It\'s time for ${entry.key} prayer.',
              'key': key,
            });
          }
        }
      }
    }

    if (settings.adhkarReminders && now.hour == 7 && now.minute < 2) {
      final key = 'morning_adhkar_$today';
      if (!_shownReminders.contains(key)) {
        dueReminders.add({
          'title': '🌅 Morning Adhkar',
          'body': 'Start your day with your morning Adhkar.',
          'key': key,
        });
      }
    }

    if (settings.adhkarReminders && now.hour == 18 && now.minute < 2) {
      final key = 'evening_adhkar_$today';
      if (!_shownReminders.contains(key)) {
        dueReminders.add({
          'title': '🌆 Evening Adhkar',
          'body': 'Take a moment for your evening Adhkar.',
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
            Text(body, style: const TextStyle(fontSize: 12)),
          ],
        ),
        backgroundColor: const Color(0xFF1A2F1A),
        duration: const Duration(seconds: 15),
        behavior: SnackBarBehavior.floating,
        shape: RoundedRectangleBorder(
          borderRadius: BorderRadius.circular(12),
          side: BorderSide(color: Colors.green[700]!.withOpacity(0.3)),
        ),
        margin: const EdgeInsets.all(16),
        elevation: 6,
      ),
    );
  }
}
