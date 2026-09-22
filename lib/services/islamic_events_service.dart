import 'dart:convert';
import 'package:http/http.dart' as http;
import 'package:shared_preferences/shared_preferences.dart';

class IslamicEventData {
  final String name;
  final DateTime date;
  final String description;
  final String icon;
  final bool isMajor;
  final String hijriDate;

  const IslamicEventData({
    required this.name,
    required this.date,
    required this.description,
    required this.icon,
    required this.isMajor,
    required this.hijriDate,
  });

  Map<String, dynamic> toJson() => {
        'name': name,
        'date': date.toIso8601String(),
        'description': description,
        'icon': icon,
        'isMajor': isMajor,
        'hijriDate': hijriDate,
      };

  factory IslamicEventData.fromJson(Map<String, dynamic> json) => IslamicEventData(
        name: json['name'] ?? '',
        date: DateTime.parse(json['date']).toLocal(),
        description: json['description'] ?? '',
        icon: json['icon'] ?? '🌙',
        isMajor: json['isMajor'] ?? false,
        hijriDate: json['hijriDate'] ?? '',
      );
}

/// Fetches Islamic holy days from AlAdhan using the user's coordinates and
/// local Gregorian date. Results are cached so the Home screen still works
/// when the user is temporarily offline.
class IslamicEventsService {
  static const String _cacheKey = 'islamic_events_v2';
  static const String _cacheUpdatedKey = 'islamic_events_updated_v2';
  static const String _cacheLocationKey = 'islamic_events_location_v2';

  Future<List<IslamicEventData>> loadUpcoming({
    double? latitude,
    double? longitude,
    int calculationMethod = 4,
  }) async {
    final now = DateTime.now();
    final prefs = await SharedPreferences.getInstance();
    final cached = await _readCache();

    // Refresh at most twice a day. The displayed dates are still based on
    // the device's current local date, while avoiding six API calls every
    // time the user returns to Home.
    final updatedRaw = prefs.getString(_cacheUpdatedKey);
    final locationKey = '${latitude ?? 'none'},${longitude ?? 'none'}';
    final cachedLocation = prefs.getString(_cacheLocationKey);
    if (updatedRaw != null && cached.isNotEmpty && cachedLocation == locationKey) {
      final updatedAt = DateTime.tryParse(updatedRaw);
      if (updatedAt != null && now.difference(updatedAt).inHours < 12) {
        return cached
            .where((e) => !e.date.isBefore(DateTime(now.year, now.month, now.day)))
            .take(12)
            .toList();
      }
    }

    try {
      final events = <IslamicEventData>[];
      for (int offset = 0; offset < 6; offset++) {
        final monthDate = DateTime(now.year, now.month + offset, 1);
        final monthEvents = await _fetchMonth(
          monthDate.year,
          monthDate.month,
          latitude,
          longitude,
          calculationMethod,
        );
        events.addAll(monthEvents);
      }

      final unique = <String, IslamicEventData>{};
      for (final event in events) {
        if (!event.date.isBefore(DateTime(now.year, now.month, now.day))) {
          unique['${event.name}|${event.date.year}-${event.date.month}-${event.date.day}'] = event;
        }
      }

      final result = unique.values.toList()
        ..sort((a, b) => a.date.compareTo(b.date));

      if (result.isNotEmpty) {
        await _writeCache(result.take(40).toList());
        await prefs.setString(_cacheUpdatedKey, now.toIso8601String());
        await prefs.setString(_cacheLocationKey, locationKey);
        return result.take(12).toList();
      }
    } catch (_) {
      // Fall through to cache.
    }

    return cached
        .where((e) => !e.date.isBefore(DateTime(now.year, now.month, now.day)))
        .take(12)
        .toList();
  }

  Future<List<IslamicEventData>> _fetchMonth(
    int year,
    int month,
    double? latitude,
    double? longitude,
    int method,
  ) async {
    final query = <String, String>{
      'method': method.toString(),
    };
    if (latitude != null && longitude != null) {
      query['latitude'] = latitude.toString();
      query['longitude'] = longitude.toString();
    }

    final uri = Uri.https(
      'api.aladhan.com',
      '/v1/calendar/$year/${month.toString().padLeft(2, '0')}',
      query,
    );
    final response = await http.get(uri).timeout(const Duration(seconds: 15));
    if (response.statusCode != 200) {
      throw Exception('Islamic calendar API returned ${response.statusCode}');
    }

    final body = jsonDecode(response.body) as Map<String, dynamic>;
    final data = body['data'];
    if (data is! List) throw Exception('Invalid Islamic calendar response');

    final events = <IslamicEventData>[];
    for (final item in data) {
      if (item is! Map<String, dynamic>) continue;
      final date = item['date'] as Map<String, dynamic>?;
      final gregorian = date?['gregorian'] as Map<String, dynamic>?;
      final hijri = date?['hijri'] as Map<String, dynamic>?;
      final holidays = hijri?['holidays'];
      if (gregorian == null || hijri == null || holidays is! List) continue;

      final readable = gregorian['date'] as String?;
      final parsed = _parseDdMmYyyy(readable);
      if (parsed == null) continue;
      final hijriDate = hijri['date'] as String? ?? '';

      for (final rawHoliday in holidays) {
        final holiday = rawHoliday.toString().trim();
        if (holiday.isEmpty) continue;
        final normalized = holiday.toLowerCase();
        if (!_isUserFacingEvent(normalized)) continue;

        final meta = _eventMeta(holiday);
        events.add(IslamicEventData(
          name: meta.$1,
          date: parsed,
          description: meta.$2,
          icon: meta.$3,
          isMajor: meta.$4,
          hijriDate: hijriDate,
        ));
      }
    }
    return events;
  }

  bool _isUserFacingEvent(String value) {
    const keywords = [
      'ramadan',
      'eid',
      'ashura',
      'araf',
      'laylat',
      'qadr',
      'isra',
      'mi\'raj',
      'mawlid',
      '1st day of muharram',
      'hijri new year',
      'new year',
    ];
    return keywords.any(value.contains);
  }

  (String, String, String, bool) _eventMeta(String original) {
    final value = original.toLowerCase();
    if (value.contains('eid-ul-fitr') || value.contains('eid al-fitr')) {
      return ('Eid al-Fitr', 'Festival marking the end of Ramadan.', '🎉', true);
    }
    if (value.contains('eid-ul-adha') || value.contains('eid al-adha')) {
      return ('Eid al-Adha', 'Festival of Sacrifice during Dhul Hijjah.', '🐑', true);
    }
    if (value.contains('araf')) {
      return ('Day of Arafah', 'The blessed Day of Arafah.', '🤲', true);
    }
    if (value.contains('ramadan')) {
      return ('Ramadan', 'Blessed month of fasting, Quran and worship.', '🌙', true);
    }
    if (value.contains('qadr') || value.contains('laylat')) {
      return ('Laylat al-Qadr', 'Night of Power in the last ten nights of Ramadan.', '✨', true);
    }
    if (value.contains('ashura')) {
      return ('Ashura', '10 Muharram — a significant day of worship and fasting.', '🤲', true);
    }
    if (value.contains('isra') || value.contains('mi\'raj')) {
      return ('Isra & Mi\'raj', 'The Night Journey and Ascension of the Prophet ﷺ.', '🕌', true);
    }
    if (value.contains('mawlid')) {
      return ('Mawlid al-Nabi', 'Commemoration of the birth of Prophet Muhammad ﷺ.', '🕌', true);
    }
    if (value.contains('new year') || value.contains('1st day of muharram')) {
      return ('Islamic New Year', 'Beginning of a new Hijri year.', '🌙', true);
    }
    return (original, 'Islamic holy day', '🌙', false);
  }

  DateTime? _parseDdMmYyyy(String? value) {
    if (value == null) return null;
    final parts = value.split('-');
    if (parts.length != 3) return null;
    final day = int.tryParse(parts[0]);
    final month = int.tryParse(parts[1]);
    final year = int.tryParse(parts[2]);
    if (day == null || month == null || year == null) return null;
    return DateTime(year, month, day);
  }

  Future<List<IslamicEventData>> _readCache() async {
    try {
      final prefs = await SharedPreferences.getInstance();
      final raw = prefs.getString(_cacheKey);
      if (raw == null) return [];
      final list = jsonDecode(raw) as List<dynamic>;
      return list
          .whereType<Map<String, dynamic>>()
          .map(IslamicEventData.fromJson)
          .toList()
        ..sort((a, b) => a.date.compareTo(b.date));
    } catch (_) {
      return [];
    }
  }

  Future<void> _writeCache(List<IslamicEventData> events) async {
    final prefs = await SharedPreferences.getInstance();
    await prefs.setString(
      _cacheKey,
      jsonEncode(events.map((e) => e.toJson()).toList()),
    );
  }
}
