import 'dart:convert';

/// Which ranking the user is looking at.
enum LeaderboardPeriod { global, weekly, monthly }

/// Secondary sort for the global board.
enum LeaderboardSort { points, streak }

/// Whose results to show.
enum LeaderboardScope { everyone, friends }

/// Emoji avatars. Only the index (0..N-1) is ever shared — never an image.
const List<String> leaderboardAvatars = [
  '🕌', '📿', '🌙', '⭐', '🌿', '🕋', '📖', '🤲', '🌸', '🦅', '🐪', '☀️',
];

String avatarFor(int index) =>
    leaderboardAvatars[(index < 0 || index >= leaderboardAvatars.length)
        ? 0
        : index];

/// One row of a ranking.
class LeaderboardEntry {
  final String uid;
  final String displayName;
  final int avatar;

  /// Points that the active board is ranked on (lifetime / week / month).
  final int points;

  /// Sum of the user's current per-ibadah streaks.
  final int streak;

  /// Days with at least one point in the period (0 for the global board).
  final int activeDays;

  /// 1-based position. Assigned after sorting.
  int rank;
  final bool isMe;

  LeaderboardEntry({
    required this.uid,
    required this.displayName,
    required this.avatar,
    required this.points,
    required this.streak,
    this.activeDays = 0,
    this.rank = 0,
    this.isMe = false,
  });

  LeaderboardEntry copyWith({int? rank, bool? isMe}) => LeaderboardEntry(
        uid: uid,
        displayName: displayName,
        avatar: avatar,
        points: points,
        streak: streak,
        activeDays: activeDays,
        rank: rank ?? this.rank,
        isMe: isMe ?? this.isMe,
      );

  Map<String, dynamic> toJson() => {
        'uid': uid,
        'n': displayName,
        'a': avatar,
        'p': points,
        's': streak,
        'd': activeDays,
        'r': rank,
      };

  factory LeaderboardEntry.fromJson(Map<String, dynamic> j, {String? myUid}) =>
      LeaderboardEntry(
        uid: (j['uid'] ?? '') as String,
        displayName: (j['n'] ?? '') as String,
        avatar: ((j['a'] ?? 0) as num).toInt(),
        points: ((j['p'] ?? 0) as num).toInt(),
        streak: ((j['s'] ?? 0) as num).toInt(),
        activeDays: ((j['d'] ?? 0) as num).toInt(),
        rank: ((j['r'] ?? 0) as num).toInt(),
        isMe: myUid != null && j['uid'] == myUid,
      );
}

/// A cached board (shown instantly and when offline).
class LeaderboardCache {
  final DateTime fetchedAt;
  final List<LeaderboardEntry> entries;
  final int? myRank;

  LeaderboardCache({
    required this.fetchedAt,
    required this.entries,
    this.myRank,
  });

  String encode() => json.encode({
        't': fetchedAt.toIso8601String(),
        'e': entries.map((e) => e.toJson()).toList(),
        'mr': myRank,
      });

  static LeaderboardCache? decode(String? raw, {String? myUid}) {
    if (raw == null || raw.isEmpty) return null;
    try {
      final m = json.decode(raw) as Map<String, dynamic>;
      return LeaderboardCache(
        fetchedAt: DateTime.parse(m['t'] as String),
        entries: (m['e'] as List)
            .map((e) => LeaderboardEntry.fromJson(
                Map<String, dynamic>.from(e as Map),
                myUid: myUid))
            .toList(),
        myRank: (m['mr'] as num?)?.toInt(),
      );
    } catch (_) {
      return null;
    }
  }
}

/// Everything the app publishes about the user. This is the COMPLETE list of
/// data that ever leaves the device for the leaderboard — no logs, notes,
/// journal text, locations or settings are included.
class ProfileSnapshot {
  final String displayName;
  final int avatar;
  final int totalPoints;
  final int totalStreak;
  final int salahStreak;
  final int sawmStreak;
  final int qiyyamStreak;
  final int quranStreak;
  final int sadaqatStreak;
  final String weekId;
  final int weeklyPoints;
  final int weeklyActiveDays;
  final String monthId;
  final int monthlyPoints;
  final int monthlyActiveDays;

  const ProfileSnapshot({
    required this.displayName,
    required this.avatar,
    required this.totalPoints,
    required this.totalStreak,
    required this.salahStreak,
    required this.sawmStreak,
    required this.qiyyamStreak,
    required this.quranStreak,
    required this.sadaqatStreak,
    required this.weekId,
    required this.weeklyPoints,
    required this.weeklyActiveDays,
    required this.monthId,
    required this.monthlyPoints,
    required this.monthlyActiveDays,
  });

  Map<String, dynamic> toJson() => {
        'displayName': displayName,
        'avatar': avatar,
        'totalPoints': totalPoints,
        'totalStreak': totalStreak,
        'salahStreak': salahStreak,
        'sawmStreak': sawmStreak,
        'qiyyamStreak': qiyyamStreak,
        'quranStreak': quranStreak,
        'sadaqatStreak': sadaqatStreak,
        'weekId': weekId,
        'weeklyPoints': weeklyPoints,
        'weeklyActiveDays': weeklyActiveDays,
        'monthId': monthId,
        'monthlyPoints': monthlyPoints,
        'monthlyActiveDays': monthlyActiveDays,
      };

  factory ProfileSnapshot.fromJson(Map<String, dynamic> j) => ProfileSnapshot(
        displayName: (j['displayName'] ?? '') as String,
        avatar: ((j['avatar'] ?? 0) as num).toInt(),
        totalPoints: ((j['totalPoints'] ?? 0) as num).toInt(),
        totalStreak: ((j['totalStreak'] ?? 0) as num).toInt(),
        salahStreak: ((j['salahStreak'] ?? 0) as num).toInt(),
        sawmStreak: ((j['sawmStreak'] ?? 0) as num).toInt(),
        qiyyamStreak: ((j['qiyyamStreak'] ?? 0) as num).toInt(),
        quranStreak: ((j['quranStreak'] ?? 0) as num).toInt(),
        sadaqatStreak: ((j['sadaqatStreak'] ?? 0) as num).toInt(),
        weekId: (j['weekId'] ?? '') as String,
        weeklyPoints: ((j['weeklyPoints'] ?? 0) as num).toInt(),
        weeklyActiveDays: ((j['weeklyActiveDays'] ?? 0) as num).toInt(),
        monthId: (j['monthId'] ?? '') as String,
        monthlyPoints: ((j['monthlyPoints'] ?? 0) as num).toInt(),
        monthlyActiveDays: ((j['monthlyActiveDays'] ?? 0) as num).toInt(),
      );

  /// Stable fingerprint used to skip uploads when nothing changed.
  String get fingerprint => json.encode(toJson());
}

/// Firebase project the leaderboard talks to (public identifiers only).
class LeaderboardConfig {
  final String projectId;
  final String apiKey;

  const LeaderboardConfig({required this.projectId, required this.apiKey});

  bool get isValid =>
      RegExp(r'^[a-z][a-z0-9-]{3,38}[a-z0-9]$').hasMatch(projectId) &&
      apiKey.length >= 20;

  Map<String, dynamic> toJson() => {'projectId': projectId, 'apiKey': apiKey};

  factory LeaderboardConfig.fromJson(Map<String, dynamic> j) =>
      LeaderboardConfig(
        projectId: (j['projectId'] ?? '') as String,
        apiKey: (j['apiKey'] ?? '') as String,
      );
}

/// Sync state shown in the UI.
enum LeaderboardSyncState { idle, syncing, synced, pending, offline, error }
