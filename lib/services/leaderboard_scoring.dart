import 'package:salahstreaks/models/adhkar_model.dart';
import 'package:salahstreaks/models/ibadat_model.dart';
import 'package:salahstreaks/models/leaderboard_models.dart';
import 'package:salahstreaks/utils/constants.dart';

/// Pure, deterministic "fair-play" scoring for the Ummah Leaderboard.
///
/// Leaderboard points are re-derived from the user's logs (never read from
/// a mutable counter) using the same per-action values as the in-app points,
/// with a per-day cap for every ibadah. The caps matter for two reasons:
///   1. Sadaqat is 1 point per currency unit in the app, so without a cap a
///      donation in a weak-value currency would dominate the board.
///   2. The Firestore security rules (firestore.rules) enforce the same
///      ceilings, so a tampered client cannot publish an impossible score.
///
/// KEEP THE CONSTANTS BELOW IN SYNC WITH firestore.rules.
class LeaderboardScoring {
  LeaderboardScoring._();

  static const int salahDailyCap = 50; // 5 prayers x 10
  static const int sawmDailyCap = 50;
  static const int qiyyamDailyCap = 200; // up to 40 rak'ah x 5
  static const int quranDailyCap = 300; // up to 600 verses x 0.5
  static const int sadaqatDailyCap = 50;
  static const int adhkarDailyCap = 100;

  /// 50 + 50 + 200 + 300 + 50 + 100
  static const int maxDailyPoints = 750;
  static const int maxWeeklyPoints = maxDailyPoints * 7; // 5250
  static const int maxMonthlyPoints = maxDailyPoints * 31; // 23250
  static const int maxLifetimePoints = 1000000;
  static const int maxTypeStreak = 5000;

  static DateTime _day(DateTime d) => DateTime(d.year, d.month, d.day);

  static String _key(DateTime d) =>
      '${d.year.toString().padLeft(4, '0')}-'
      '${d.month.toString().padLeft(2, '0')}-'
      '${d.day.toString().padLeft(2, '0')}';

  static int _cap(double v, int cap) {
    if (v.isNaN || v < 0) return 0;
    final r = v.round();
    return r > cap ? cap : r;
  }

  /// Points earned per calendar day (key `yyyy-MM-dd`, local time).
  static Map<String, int> dailyPoints(
    List<IbadatLog> logs,
    List<AdhkarLog> adhkarLogs,
  ) {
    // day -> type -> raw points
    final perDayType = <String, Map<String, double>>{};

    void add(DateTime date, String type, double pts) {
      final k = _key(_day(date));
      final m = perDayType.putIfAbsent(k, () => <String, double>{});
      m[type] = (m[type] ?? 0) + pts;
    }

    for (final l in logs) {
      switch (l.type) {
        case 'Salah':
          final n = l.salahCount.clamp(0, 5);
          add(l.date, 'Salah', n * 10.0);
          break;
        case 'Sawm':
          add(l.date, 'Sawm', l.sawmType == 'Fardh' ? 50.0 : 25.0);
          break;
        case 'Qiyyam':
          add(l.date, 'Qiyyam', l.rakahCount * 5.0);
          break;
        case 'Quran':
          add(l.date, 'Quran', l.versesCount * 0.5);
          break;
        case 'Sadaqat':
          add(l.date, 'Sadaqat', l.amount);
          break;
      }
    }
    for (final a in adhkarLogs) {
      add(a.date, 'Adhkar', a.count * 0.5);
    }

    const caps = <String, int>{
      'Salah': salahDailyCap,
      'Sawm': sawmDailyCap,
      'Qiyyam': qiyyamDailyCap,
      'Quran': quranDailyCap,
      'Sadaqat': sadaqatDailyCap,
      'Adhkar': adhkarDailyCap,
    };

    final out = <String, int>{};
    perDayType.forEach((day, types) {
      var total = 0;
      types.forEach((type, raw) {
        total += _cap(raw, caps[type] ?? 0);
      });
      if (total > 0) out[day] = total > maxDailyPoints ? maxDailyPoints : total;
    });
    return out;
  }

  /// ISO-8601 week id, e.g. `w2026-47` (weeks start on Monday).
  static String weekId(DateTime d) {
    final date = DateTime.utc(d.year, d.month, d.day);
    final thursday = date.add(Duration(days: 4 - date.weekday));
    final yearStart = DateTime.utc(thursday.year, 1, 1);
    final week = (thursday.difference(yearStart).inDays ~/ 7) + 1;
    return 'w${thursday.year.toString().padLeft(4, '0')}-'
        '${week.toString().padLeft(2, '0')}';
  }

  static String monthId(DateTime d) =>
      'm${d.year.toString().padLeft(4, '0')}-${d.month.toString().padLeft(2, '0')}';

  /// Monday of the week containing [d] (local calendar day).
  static DateTime weekStart(DateTime d) {
    final day = _day(d);
    return DateTime(day.year, day.month, day.day - (day.weekday - 1));
  }

  /// First day of the next week / month — for the "resets in" label.
  static DateTime nextWeekStart(DateTime d) {
    final s = weekStart(d);
    return DateTime(s.year, s.month, s.day + 7);
  }

  static DateTime nextMonthStart(DateTime d) => DateTime(d.year, d.month + 1, 1);

  /// Builds the snapshot that gets published.
  static ProfileSnapshot buildSnapshot({
    required String displayName,
    required int avatar,
    required List<IbadatLog> logs,
    required List<AdhkarLog> adhkarLogs,
    required Map<String, int> streaks,
    DateTime? now,
  }) {
    final today = _day(now ?? DateTime.now());
    final daily = dailyPoints(logs, adhkarLogs);

    final wStart = weekStart(today);
    final wEnd = DateTime(wStart.year, wStart.month, wStart.day + 6);
    final mStart = DateTime(today.year, today.month, 1);
    final mEnd = DateTime(today.year, today.month + 1, 0);

    var total = 0;
    var wPts = 0, wDays = 0, mPts = 0, mDays = 0;

    daily.forEach((key, pts) {
      final p = key.split('-');
      final d = DateTime(int.parse(p[0]), int.parse(p[1]), int.parse(p[2]));
      if (d.isAfter(today)) return; // ignore future-dated entries
      total += pts;
      if (!d.isBefore(wStart) && !d.isAfter(wEnd)) {
        wPts += pts;
        wDays++;
      }
      if (!d.isBefore(mStart) && !d.isAfter(mEnd)) {
        mPts += pts;
        mDays++;
      }
    });

    int s(String type) {
      final v = streaks[type] ?? 0;
      return v < 0 ? 0 : (v > maxTypeStreak ? maxTypeStreak : v);
    }

    final totalStreak = ibadatTypes.fold<int>(0, (sum, t) => sum + s(t));

    return ProfileSnapshot(
      displayName: sanitizeName(displayName),
      avatar: avatar.clamp(0, leaderboardAvatars.length - 1).toInt(),
      totalPoints: total > maxLifetimePoints ? maxLifetimePoints : total,
      totalStreak: totalStreak,
      salahStreak: s('Salah'),
      sawmStreak: s('Sawm'),
      qiyyamStreak: s('Qiyyam'),
      quranStreak: s('Quran'),
      sadaqatStreak: s('Sadaqat'),
      weekId: weekId(today),
      weeklyPoints: wPts > maxWeeklyPoints ? maxWeeklyPoints : wPts,
      weeklyActiveDays: wDays,
      monthId: monthId(today),
      monthlyPoints: mPts > maxMonthlyPoints ? maxMonthlyPoints : mPts,
      monthlyActiveDays: mDays,
    );
  }

  /// Trims, collapses whitespace, strips control / markup characters and
  /// limits to 24 characters. Must stay compatible with the rules' check
  /// (2..24 chars, no `<>{}[]\`).
  static String sanitizeName(String raw) {
    var s = raw
        .replaceAll(RegExp(r'[\u0000-\u001F\u007F<>{}\[\]\\]'), '')
        .replaceAll(RegExp(r'\s+'), ' ')
        .trim();
    if (s.runes.length > 24) {
      s = String.fromCharCodes(s.runes.take(24)).trim();
    }
    return s;
  }

  static bool isValidName(String raw) {
    final s = sanitizeName(raw);
    return s.runes.length >= 2 && s.runes.length <= 24;
  }
}
