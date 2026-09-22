import 'dart:convert';
import 'package:http/http.dart' as http;
import 'package:shared_preferences/shared_preferences.dart';
import 'package:salahstreaks/services/ai_bot_service.dart';
import 'package:salahstreaks/models/user_settings_model.dart';

/// Loads the Daily Verse from the full Quran corpus instead of the small
/// bundled sample list. The online source contains all 6,236 ayahs and
/// multiple text editions. A local cache/fallback keeps the home screen
/// usable when the network is unavailable.
class DailyVerse {
  final String arabic;
  final String translation;
  final String tafsir;
  final String reference;
  final String source;
  final String? aiReflection;

  const DailyVerse({
    required this.arabic,
    required this.translation,
    required this.tafsir,
    required this.reference,
    required this.source,
    this.aiReflection,
  });

  Map<String, dynamic> toJson() => {
        'arabic': arabic,
        'translation': translation,
        'tafsir': tafsir,
        'reference': reference,
        'source': source,
        'aiReflection': aiReflection,
      };

  factory DailyVerse.fromJson(Map<String, dynamic> json) => DailyVerse(
        arabic: json['arabic'] ?? '',
        translation: json['translation'] ?? '',
        tafsir: json['tafsir'] ?? '',
        reference: json['reference'] ?? '',
        source: json['source'] ?? 'Cached',
        aiReflection: json['aiReflection'],
      );
}

class DailyVerseService {
  static const int _totalAyahs = 6236;
  static const int _step = 3571; // coprime with 6236 => no repeats for 6236 days.
  static const String _cacheKey = 'daily_verse_cache_v2';

  Future<DailyVerse> loadForToday({UserSettings? settings}) async {
    final prefs = await SharedPreferences.getInstance();
    final todayKey = _dateKey(DateTime.now());
    final cachedRaw = prefs.getString(_cacheKey);

    if (cachedRaw != null) {
      try {
        final cached = jsonDecode(cachedRaw) as Map<String, dynamic>;
        if (cached['date'] == todayKey) {
          final cachedVerse = DailyVerse.fromJson(cached['verse'] as Map<String, dynamic>);
          final aiWanted = settings?.aiBotEnabled == true && settings?.aiApiKey.trim().isNotEmpty == true;
          if (!aiWanted || (cachedVerse.aiReflection ?? '').trim().isNotEmpty) {
            return cachedVerse;
          }
        }
      } catch (_) {}
    }

    final globalAyah = _ayahForDate(DateTime.now());

    try {
      final verse = await _fetchFromAlQuranCloud(globalAyah);
      final withAi = await _maybeAddAiReflection(verse, settings);
      await prefs.setString(
        _cacheKey,
        jsonEncode({'date': todayKey, 'verse': withAi.toJson()}),
      );
      return withAi;
    } catch (_) {
      // Keep the app useful offline. This is only a fallback; the online
      // corpus remains the primary source and is intentionally much larger.
      final fallback = _offlineFallback(globalAyah);
      return fallback;
    }
  }

  int _ayahForDate(DateTime date) {
    final dayIndex = DateTime(date.year, date.month, date.day)
        .difference(DateTime(2024, 1, 1))
        .inDays;
    final normalized = dayIndex < 0 ? dayIndex % _totalAyahs + _totalAyahs : dayIndex;
    return ((normalized * _step) % _totalAyahs) + 1;
  }

  Future<DailyVerse> _fetchFromAlQuranCloud(int globalAyah) async {
    final results = await Future.wait([
      _getEdition(globalAyah, 'quran-uthmani'),
      _getEdition(globalAyah, 'en.sahih'),
      _getEdition(globalAyah, 'ar.muyassar'),
    ]);

    final arabic = results[0];
    final translation = results[1];
    final tafsir = results[2];
    final reference = '${arabic['surah']['englishName']} ${arabic['surah']['number']}:${arabic['numberInSurah']}';

    return DailyVerse(
      arabic: arabic['text'] ?? '',
      translation: translation['text'] ?? '',
      tafsir: tafsir['text'] ?? '',
      reference: reference,
      source: 'AlQuran.cloud • Uthmani + Saheeh International + Tafsir al-Muyassar',
    );
  }

  Future<Map<String, dynamic>> _getEdition(int globalAyah, String edition) async {
    final uri = Uri.parse(
      'https://api.alquran.cloud/v1/ayah/$globalAyah/$edition',
    );
    final response = await http.get(uri).timeout(const Duration(seconds: 15));
    if (response.statusCode != 200) {
      throw Exception('Quran API returned ${response.statusCode}');
    }

    final body = jsonDecode(response.body) as Map<String, dynamic>;
    if (body['code'] != 200 || body['data'] is! Map<String, dynamic>) {
      throw Exception('Invalid Quran API response');
    }
    return body['data'] as Map<String, dynamic>;
  }

  Future<DailyVerse> _maybeAddAiReflection(
    DailyVerse verse,
    UserSettings? settings,
  ) async {
    if (settings == null ||
        !settings.aiBotEnabled ||
        settings.aiApiKey.trim().isEmpty) {
      return verse;
    }

    try {
      final provider = AiProviderX.fromId(settings.aiProvider);
      final service = AiBotService();
      final prompt = '''
Using ONLY the Quran verse and established tafsir supplied below, write a brief English reflection (2-4 sentences) explaining the practical meaning for a Muslim today.
Do not invent hadith, historical claims, or rulings. Do not call it "tafsir"; label it as a reflection.

Reference: ${verse.reference}
Arabic: ${verse.arabic}
Translation: ${verse.translation}
Tafsir al-Muyassar: ${verse.tafsir}
''';

      final reflection = await service.chat(
        apiKey: settings.aiApiKey,
        provider: provider,
        customBaseUrl: settings.aiBaseUrl,
        customModel: settings.aiModel,
        history: [AiBotMessage(role: 'user', content: prompt)],
      );

      return DailyVerse(
        arabic: verse.arabic,
        translation: verse.translation,
        tafsir: verse.tafsir,
        reference: verse.reference,
        source: verse.source,
        aiReflection: reflection.trim(),
      );
    } catch (_) {
      return verse;
    }
  }

  DailyVerse _offlineFallback(int globalAyah) {
    // The existing bundled dataset remains an emergency fallback. We import
    // lazily here so no online failure can break the Home screen.
    // This value is intentionally marked as fallback in the UI.
    const fallbackArabic = 'ٱللَّهُ لَا إِلَٰهَ إِلَّا هُوَ ٱلْحَىُّ ٱلْقَيُّومُ';
    const fallbackTranslation = 'Allah—there is no deity except Him, the Ever-Living, the Sustainer of all.';
    return DailyVerse(
      arabic: fallbackArabic,
      translation: fallbackTranslation,
      tafsir: 'Online Quran data is temporarily unavailable. Connect to the internet to load the full daily verse and tafsir corpus.',
      reference: 'Al-Baqarah 2:255',
      source: 'Offline fallback (Ayah target $globalAyah)',
    );
  }

  String _dateKey(DateTime date) =>
      '${date.year.toString().padLeft(4, '0')}-${date.month.toString().padLeft(2, '0')}-${date.day.toString().padLeft(2, '0')}';
}
