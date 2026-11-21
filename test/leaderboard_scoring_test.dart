import 'package:flutter_test/flutter_test.dart';
import 'package:salahstreaks/models/adhkar_model.dart';
import 'package:salahstreaks/models/ibadat_model.dart';
import 'package:salahstreaks/services/leaderboard_scoring.dart';

IbadatLog _log(String type, DateTime d,
        {int salah = 0,
        String sawm = '',
        int rakah = 0,
        int verses = 0,
        double amount = 0}) =>
    IbadatLog(
      type: type,
      date: d,
      salahCount: salah,
      sawmType: sawm,
      rakahCount: rakah,
      versesCount: verses,
      amount: amount,
    );

void main() {
  final day = DateTime(2026, 11, 16);

  group('dailyPoints caps', () {
    test('five prayers = 50', () {
      final r = LeaderboardScoring.dailyPoints(
          [_log('Salah', day, salah: 5)], const []);
      expect(r['2026-11-16'], 50);
    });

    test('sadaqat is capped so big currency amounts cannot dominate', () {
      final r = LeaderboardScoring.dailyPoints(
          [_log('Sadaqat', day, amount: 1000000)], const []);
      expect(r['2026-11-16'], LeaderboardScoring.sadaqatDailyCap);
    });

    test('quran and qiyyam caps', () {
      final r = LeaderboardScoring.dailyPoints([
        _log('Quran', day, verses: 5000),
        _log('Qiyyam', day, rakah: 500),
      ], const []);
      expect(r['2026-11-16'],
          LeaderboardScoring.quranDailyCap + LeaderboardScoring.qiyyamDailyCap);
    });

    test('sawm fardh 50, nafl 25', () {
      expect(
          LeaderboardScoring.dailyPoints(
              [_log('Sawm', day, sawm: 'Fardh')], const [])['2026-11-16'],
          50);
      expect(
          LeaderboardScoring.dailyPoints(
              [_log('Sawm', day, sawm: 'Nafl')], const [])['2026-11-16'],
          25);
    });

    test('adhkar counted at 0.5 and capped', () {
      final r = LeaderboardScoring.dailyPoints(const [], [
        AdhkarLog(adhkarId: 'a', date: day, count: 10),
      ]);
      expect(r['2026-11-16'], 5);
      final big = LeaderboardScoring.dailyPoints(const [], [
        AdhkarLog(adhkarId: 'a', date: day, count: 5000),
      ]);
      expect(big['2026-11-16'], LeaderboardScoring.adhkarDailyCap);
    });

    test('theoretical maximum day equals maxDailyPoints', () {
      final r = LeaderboardScoring.dailyPoints([
        _log('Salah', day, salah: 5),
        _log('Sawm', day, sawm: 'Fardh'),
        _log('Qiyyam', day, rakah: 999),
        _log('Quran', day, verses: 99999),
        _log('Sadaqat', day, amount: 1e9),
      ], [
        AdhkarLog(adhkarId: 'a', date: day, count: 99999),
      ]);
      expect(r['2026-11-16'], LeaderboardScoring.maxDailyPoints);
    });

    test('negative / nonsense values never score', () {
      final r = LeaderboardScoring.dailyPoints(
          [_log('Sadaqat', day, amount: -500)], const []);
      expect(r.containsKey('2026-11-16'), isFalse);
    });
  });

  group('period ids', () {
    test('ISO week ids', () {
      expect(LeaderboardScoring.weekId(DateTime(2026, 11, 21)), 'w2026-47');
      expect(LeaderboardScoring.weekId(DateTime(2026, 11, 16)), 'w2026-47');
      expect(LeaderboardScoring.weekId(DateTime(2021, 1, 3)), 'w2020-53');
      expect(LeaderboardScoring.weekId(DateTime(2024, 12, 30)), 'w2025-01');
    });

    test('month id', () {
      expect(LeaderboardScoring.monthId(DateTime(2026, 3, 9)), 'm2026-03');
    });

    test('week starts Monday', () {
      expect(LeaderboardScoring.weekStart(DateTime(2026, 11, 21)),
          DateTime(2026, 11, 16));
      expect(LeaderboardScoring.weekStart(DateTime(2026, 11, 16)),
          DateTime(2026, 11, 16));
    });
  });

  group('buildSnapshot', () {
    test('splits lifetime / week / month and ignores future logs', () {
      final now = DateTime(2026, 11, 21);
      final logs = [
        _log('Salah', DateTime(2026, 11, 16), salah: 5), // 50 (this week)
        _log('Quran', DateTime(2026, 11, 20), verses: 40), // 20 (this week)
        _log('Salah', DateTime(2026, 11, 2), salah: 5), // 50 (this month)
        _log('Salah', DateTime(2026, 10, 30), salah: 5), // 50 (lifetime only)
        _log('Salah', DateTime(2026, 11, 25), salah: 5), // future: ignored
      ];
      final s = LeaderboardScoring.buildSnapshot(
        displayName: 'Ali',
        avatar: 99, // out of range -> clamped
        logs: logs,
        adhkarLogs: const [],
        streaks: {'Salah': 3, 'Quran': 1},
        now: now,
      );
      expect(s.weeklyPoints, 70);
      expect(s.weeklyActiveDays, 2);
      expect(s.monthlyPoints, 120);
      expect(s.monthlyActiveDays, 3);
      expect(s.totalPoints, 170);
      expect(s.totalStreak, 4);
      expect(s.salahStreak, 3);
      expect(s.weekId, 'w2026-47');
      expect(s.monthId, 'm2026-11');
      expect(s.avatar, 11);
    });

    test('fingerprint changes only when data changes', () {
      LeaderboardScoring.buildSnapshot(
          displayName: 'A', avatar: 0, logs: const [], adhkarLogs: const [],
          streaks: const {}, now: DateTime(2026, 11, 21));
      final a = LeaderboardScoring.buildSnapshot(
          displayName: 'Ali', avatar: 0, logs: const [], adhkarLogs: const [],
          streaks: const {}, now: DateTime(2026, 11, 21));
      final b = LeaderboardScoring.buildSnapshot(
          displayName: 'Ali', avatar: 0, logs: const [], adhkarLogs: const [],
          streaks: const {}, now: DateTime(2026, 11, 21));
      final c = LeaderboardScoring.buildSnapshot(
          displayName: 'Ali', avatar: 1, logs: const [], adhkarLogs: const [],
          streaks: const {}, now: DateTime(2026, 11, 21));
      expect(a.fingerprint, b.fingerprint);
      expect(a.fingerprint, isNot(c.fingerprint));
    });
  });

  group('display names', () {
    test('sanitize strips markup / control chars and collapses spaces', () {
      expect(LeaderboardScoring.sanitizeName('  Ab{c}   d\n'), 'Abc d');
    });

    test('length limits', () {
      expect(LeaderboardScoring.isValidName('A'), isFalse);
      expect(LeaderboardScoring.isValidName('Al'), isTrue);
      expect(LeaderboardScoring.sanitizeName('x' * 40).length, 24);
    });
  });
}
