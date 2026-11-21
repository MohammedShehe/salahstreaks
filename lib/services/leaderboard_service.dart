import 'dart:async';
import 'dart:convert';
import 'package:http/http.dart' as http;
import 'package:shared_preferences/shared_preferences.dart';
import 'package:salahstreaks/models/leaderboard_models.dart';

/// Thrown when no Firebase project has been configured yet.
class LeaderboardNotConfigured implements Exception {
  @override
  String toString() => 'Leaderboard is not connected to a Firebase project.';
}

/// No HTTP response at all (offline, DNS, timeout, CORS...). Retryable.
class LeaderboardNetworkException implements Exception {
  final String message;
  LeaderboardNetworkException(this.message);
  @override
  String toString() => message;
}

/// The server answered with an error.
class LeaderboardApiException implements Exception {
  final int status;
  final String message;
  LeaderboardApiException(this.status, this.message);

  bool get isPermissionDenied => status == 403;
  bool get isAuth => status == 401;
  bool get isRateLimited => status == 429;

  @override
  String toString() => message;
}

/// Serverless leaderboard client.
///
/// Talks DIRECTLY from the device to Google's public Firebase REST APIs:
///   * Identity Toolkit  – anonymous sign-in (gives a per-install uid)
///   * Cloud Firestore   – storage + queries, protected by firestore.rules
///
/// There is no SalahStreaks server. Uses only `package:http` (already a
/// dependency) so no native Firebase plugins / google-services files are
/// needed and it behaves the same on Android, iOS, web and desktop.
///
/// Data layout (see firestore.rules):
///   profiles/{uid}                    global board + search + streaks
///   periods/{w2026-47}/entries/{uid}  weekly board
///   periods/{m2026-11}/entries/{uid}  monthly board
class LeaderboardService {
  LeaderboardService({http.Client? client}) : _http = client ?? http.Client();

  final http.Client _http;

  static const Duration _timeout = Duration(seconds: 15);

  static const String _kConfig = 'lb_config_v1';
  static const String _kSession = 'lb_session_v1';

  /// Compile-time defaults so you can ship a pre-wired build:
  /// flutter build apk --dart-define=LB_FIREBASE_PROJECT_ID=my-proj
  ///                   --dart-define=LB_FIREBASE_API_KEY=AIza...
  static const String _envProject =
      String.fromEnvironment('LB_FIREBASE_PROJECT_ID');
  static const String _envKey = String.fromEnvironment('LB_FIREBASE_API_KEY');

  LeaderboardConfig? _config;
  _Session? _session;
  bool _loaded = false;

  // ---------------------------------------------------------------- config

  Future<void> _ensureLoaded() async {
    if (_loaded) return;
    final prefs = await SharedPreferences.getInstance();

    final rawCfg = prefs.getString(_kConfig);
    if (rawCfg != null) {
      try {
        _config = LeaderboardConfig.fromJson(
            Map<String, dynamic>.from(json.decode(rawCfg) as Map));
      } catch (_) {}
    }
    if (_config == null || !_config!.isValid) {
      final env =
          const LeaderboardConfig(projectId: _envProject, apiKey: _envKey);
      _config = env.isValid ? env : null;
    }

    final rawSession = prefs.getString(_kSession);
    if (rawSession != null) {
      try {
        _session = _Session.fromJson(
            Map<String, dynamic>.from(json.decode(rawSession) as Map));
      } catch (_) {}
    }
    // A session is only valid for the project it was created in.
    if (_session != null &&
        (_config == null || _session!.projectId != _config!.projectId)) {
      _session = null;
    }
    _loaded = true;
  }

  Future<LeaderboardConfig?> getConfig() async {
    await _ensureLoaded();
    return _config;
  }

  Future<bool> get isConfigured async => (await getConfig()) != null;

  Future<void> saveConfig(LeaderboardConfig cfg) async {
    final prefs = await SharedPreferences.getInstance();
    await prefs.setString(_kConfig, json.encode(cfg.toJson()));
    await prefs.remove(_kSession);
    _config = cfg;
    _session = null;
    _loaded = true;
  }

  Future<void> clearConfig() async {
    final prefs = await SharedPreferences.getInstance();
    await prefs.remove(_kConfig);
    await prefs.remove(_kSession);
    _config = null;
    _session = null;
    _loaded = false;
  }

  /// Uid of the current anonymous session, if one exists (no network).
  Future<String?> currentUid() async {
    await _ensureLoaded();
    return _session?.uid;
  }

  // ------------------------------------------------------------------ auth

  Future<void> _saveSession() async {
    final prefs = await SharedPreferences.getInstance();
    if (_session == null) {
      await prefs.remove(_kSession);
    } else {
      await prefs.setString(_kSession, json.encode(_session!.toJson()));
    }
  }

  /// Returns a valid ID token, signing in anonymously / refreshing as needed.
  Future<String> _token({bool forceRefresh = false}) async {
    await _ensureLoaded();
    final cfg = _config;
    if (cfg == null) throw LeaderboardNotConfigured();

    final s = _session;
    if (s != null && !forceRefresh && s.isFresh) return s.idToken;

    if (s != null) {
      try {
        final res = await _send(
          'POST',
          Uri.parse(
              'https://securetoken.googleapis.com/v1/token?key=${cfg.apiKey}'),
          form: {'grant_type': 'refresh_token', 'refresh_token': s.refreshToken},
        );
        final m = json.decode(res.body) as Map<String, dynamic>;
        _session = _Session(
          projectId: cfg.projectId,
          uid: (m['user_id'] ?? s.uid) as String,
          idToken: m['id_token'] as String,
          refreshToken: (m['refresh_token'] ?? s.refreshToken) as String,
          expiresAt: DateTime.now().add(
              Duration(seconds: int.tryParse('${m['expires_in']}') ?? 3600)),
        );
        await _saveSession();
        return _session!.idToken;
      } on LeaderboardApiException catch (e) {
        // Refresh token revoked / user deleted -> fall through to new sign-in.
        if (e.status < 400 || e.status >= 500) rethrow;
      }
    }

    final res = await _send(
      'POST',
      Uri.parse(
          'https://identitytoolkit.googleapis.com/v1/accounts:signUp?key=${cfg.apiKey}'),
      body: {'returnSecureToken': true},
    );
    final m = json.decode(res.body) as Map<String, dynamic>;
    _session = _Session(
      projectId: cfg.projectId,
      uid: m['localId'] as String,
      idToken: m['idToken'] as String,
      refreshToken: m['refreshToken'] as String,
      expiresAt: DateTime.now()
          .add(Duration(seconds: int.tryParse('${m['expiresIn']}') ?? 3600)),
    );
    await _saveSession();
    return _session!.idToken;
  }

  /// Makes sure a session exists and returns its uid.
  Future<String> ensureSignedIn() async {
    await _token();
    return _session!.uid;
  }

  // ------------------------------------------------------------- transport

  Future<http.Response> _send(
    String method,
    Uri url, {
    Map<String, dynamic>? body,
    Map<String, String>? form,
    String? bearer,
  }) async {
    final headers = <String, String>{};
    if (bearer != null) headers['Authorization'] = 'Bearer $bearer';

    http.Response res;
    try {
      if (form != null) {
        headers['Content-Type'] = 'application/x-www-form-urlencoded';
        res = await _http
            .post(url, headers: headers, body: form)
            .timeout(_timeout);
      } else {
        headers['Content-Type'] = 'application/json';
        res = await _http
            .post(url, headers: headers, body: json.encode(body ?? {}))
            .timeout(_timeout);
      }
    } on TimeoutException {
      throw LeaderboardNetworkException('Connection timed out');
    } catch (e) {
      // SocketException / ClientException / web XHR failure: no response.
      throw LeaderboardNetworkException('No connection');
    }

    if (res.statusCode >= 200 && res.statusCode < 300) return res;

    var msg = 'Request failed (${res.statusCode})';
    try {
      final m = json.decode(res.body);
      final err = m is List ? (m.isNotEmpty ? m.first['error'] : null) : m['error'];
      if (err is Map && err['message'] != null) {
        msg = '${err['message']}';
      }
    } catch (_) {}
    throw LeaderboardApiException(res.statusCode, msg);
  }

  /// Authenticated call with one automatic token refresh on 401.
  Future<http.Response> _authed(Uri url, Map<String, dynamic> body) async {
    var token = await _token();
    try {
      return await _send('POST', url, body: body, bearer: token);
    } on LeaderboardApiException catch (e) {
      if (!e.isAuth) rethrow;
      token = await _token(forceRefresh: true);
      return _send('POST', url, body: body, bearer: token);
    }
  }

  String get _dbPath => 'projects/${_config!.projectId}/databases/(default)/documents';
  String get _base => 'https://firestore.googleapis.com/v1/$_dbPath';

  // --------------------------------------------------------- value helpers

  static Map<String, dynamic> _s(String v) => {'stringValue': v};
  static Map<String, dynamic> _i(int v) => {'integerValue': '$v'};

  static String? _readStr(Map f, String k) =>
      (f[k] is Map) ? (f[k] as Map)['stringValue'] as String? : null;

  static int _readInt(Map f, String k) {
    final v = f[k];
    if (v is! Map) return 0;
    if (v['integerValue'] != null) return int.tryParse('${v['integerValue']}') ?? 0;
    if (v['doubleValue'] != null) return (v['doubleValue'] as num).round();
    return 0;
  }

  LeaderboardEntry _entryFromDoc(
    Map doc, {
    required LeaderboardPeriod period,
    required String? myUid,
  }) {
    final name = doc['name'] as String;
    final uid = name.substring(name.lastIndexOf('/') + 1);
    final f = (doc['fields'] as Map?) ?? const {};
    final isGlobal = period == LeaderboardPeriod.global;
    return LeaderboardEntry(
      uid: uid,
      displayName: _readStr(f, 'displayName') ?? 'Anonymous',
      avatar: _readInt(f, 'avatar'),
      points: _readInt(f, isGlobal ? 'totalPoints' : 'points'),
      streak: _readInt(f, isGlobal ? 'totalStreak' : 'streak'),
      activeDays: isGlobal ? 0 : _readInt(f, 'activeDays'),
      isMe: myUid != null && uid == myUid,
    );
  }

  // ----------------------------------------------------------------- write

  Map<String, dynamic> _doc(String path, Map<String, dynamic> fields) => {
        'update': {'name': '$_dbPath/$path', 'fields': fields},
        'updateTransforms': [
          {'fieldPath': 'updatedAt', 'setToServerValue': 'REQUEST_TIME'}
        ],
      };

  /// Atomically writes the profile plus the current weekly and monthly entry.
  /// Returns the period doc ids that were written (for later cleanup).
  Future<List<String>> publish(ProfileSnapshot p) async {
    final uid = await ensureSignedIn();

    final profile = <String, dynamic>{
      'displayName': _s(p.displayName),
      'nameLower': _s(p.displayName.toLowerCase()),
      'avatar': _i(p.avatar),
      'totalPoints': _i(p.totalPoints),
      'totalStreak': _i(p.totalStreak),
      'salahStreak': _i(p.salahStreak),
      'sawmStreak': _i(p.sawmStreak),
      'qiyyamStreak': _i(p.qiyyamStreak),
      'quranStreak': _i(p.quranStreak),
      'sadaqatStreak': _i(p.sadaqatStreak),
    };

    Map<String, dynamic> entry(int points, int days) => {
          'displayName': _s(p.displayName),
          'avatar': _i(p.avatar),
          'points': _i(points),
          'activeDays': _i(days),
          'streak': _i(p.totalStreak),
        };

    final body = {
      'writes': [
        _doc('profiles/$uid', profile),
        _doc('periods/${p.weekId}/entries/$uid',
            entry(p.weeklyPoints, p.weeklyActiveDays)),
        _doc('periods/${p.monthId}/entries/$uid',
            entry(p.monthlyPoints, p.monthlyActiveDays)),
      ],
    };

    await _authed(Uri.parse('$_base:commit'), body);
    return [p.weekId, p.monthId];
  }

  /// Deletes everything this install has published.
  Future<void> deleteMyData(Iterable<String> periodIds) async {
    final uid = await ensureSignedIn();
    final writes = <Map<String, dynamic>>[
      {'delete': '$_dbPath/profiles/$uid'},
      for (final id in periodIds) {'delete': '$_dbPath/periods/$id/entries/$uid'},
    ];
    await _authed(Uri.parse('$_base:commit'), {'writes': writes});
  }

  // ------------------------------------------------------------------ read

  List<Map> _docsFromRunQuery(String body) {
    final decoded = json.decode(body);
    if (decoded is! List) return const [];
    return decoded
        .where((e) => e is Map && e['document'] != null)
        .map<Map>((e) => e['document'] as Map)
        .toList();
  }

  Map<String, dynamic> _collectionRef(LeaderboardPeriod period, String? id) {
    return period == LeaderboardPeriod.global
        ? {'collectionId': 'profiles'}
        : {'collectionId': 'entries'};
  }

  String _queryUrl(LeaderboardPeriod period, String? periodId, String verb) =>
      period == LeaderboardPeriod.global
          ? '$_base:$verb'
          : '$_base/periods/$periodId:$verb';

  String _valueField(LeaderboardPeriod period, LeaderboardSort sort) {
    if (period == LeaderboardPeriod.global) {
      return sort == LeaderboardSort.streak ? 'totalStreak' : 'totalPoints';
    }
    return 'points';
  }

  /// Top [limit] players. Ranks are assigned 1..n.
  Future<List<LeaderboardEntry>> fetchTop({
    required LeaderboardPeriod period,
    required String? periodId,
    LeaderboardSort sort = LeaderboardSort.points,
    int limit = 50,
  }) async {
    await _ensureLoaded();
    final field = _valueField(period, sort);
    final body = {
      'structuredQuery': {
        'from': [_collectionRef(period, periodId)],
        'where': {
          'fieldFilter': {
            'field': {'fieldPath': field},
            'op': 'GREATER_THAN',
            'value': _i(0),
          }
        },
        'orderBy': [
          {'field': {'fieldPath': field}, 'direction': 'DESCENDING'}
        ],
        'limit': limit,
      }
    };
    final res =
        await _authed(Uri.parse(_queryUrl(period, periodId, 'runQuery')), body);
    final myUid = _session?.uid; // read AFTER the call: it may have signed in
    final docs = _docsFromRunQuery(res.body);
    final list = docs
        .map((d) => _entryFromDoc(d, period: period, myUid: myUid))
        .toList();
    for (var i = 0; i < list.length; i++) {
      list[i].rank = i + 1;
    }
    return list;
  }

  /// My exact position when I'm outside the top list: count of players with
  /// a strictly higher score + 1.
  Future<int?> fetchMyRank({
    required LeaderboardPeriod period,
    required String? periodId,
    required int myValue,
    LeaderboardSort sort = LeaderboardSort.points,
  }) async {
    if (myValue <= 0) return null;
    await _ensureLoaded();
    final field = _valueField(period, sort);
    final body = {
      'structuredAggregationQuery': {
        'aggregations': [
          {'alias': 'higher', 'count': {}}
        ],
        'structuredQuery': {
          'from': [_collectionRef(period, periodId)],
          'where': {
            'fieldFilter': {
              'field': {'fieldPath': field},
              'op': 'GREATER_THAN',
              'value': _i(myValue),
            }
          },
        },
      }
    };
    final res = await _authed(
        Uri.parse(_queryUrl(period, periodId, 'runAggregationQuery')), body);
    final decoded = json.decode(res.body);
    if (decoded is List && decoded.isNotEmpty) {
      final r = decoded.first['result'];
      final v = r?['aggregateFields']?['higher']?['integerValue'];
      if (v != null) return (int.tryParse('$v') ?? 0) + 1;
    }
    return null;
  }

  /// Discover players by display-name prefix (case-insensitive).
  Future<List<LeaderboardEntry>> searchByName(String query,
      {int limit = 20}) async {
    final q = query.trim().toLowerCase();
    if (q.length < 2) return const [];
    await _ensureLoaded();
    final body = {
      'structuredQuery': {
        'from': [
          {'collectionId': 'profiles'}
        ],
        'where': {
          'compositeFilter': {
            'op': 'AND',
            'filters': [
              {
                'fieldFilter': {
                  'field': {'fieldPath': 'nameLower'},
                  'op': 'GREATER_THAN_OR_EQUAL',
                  'value': _s(q),
                }
              },
              {
                'fieldFilter': {
                  'field': {'fieldPath': 'nameLower'},
                  'op': 'LESS_THAN_OR_EQUAL',
                  'value': _s('$q'),
                }
              },
            ]
          }
        },
        'orderBy': [
          {'field': {'fieldPath': 'nameLower'}, 'direction': 'ASCENDING'}
        ],
        'limit': limit,
      }
    };
    final res = await _authed(Uri.parse('$_base:runQuery'), body);
    final myUid = _session?.uid;
    return _docsFromRunQuery(res.body)
        .map((d) =>
            _entryFromDoc(d, period: LeaderboardPeriod.global, myUid: myUid))
        .toList();
  }

  /// Looks up specific players (friends) in one round-trip.
  Future<List<LeaderboardEntry>> fetchByUids({
    required Iterable<String> uids,
    required LeaderboardPeriod period,
    required String? periodId,
  }) async {
    final list = uids.toSet().toList();
    if (list.isEmpty) return const [];
    await _ensureLoaded();
    final path = period == LeaderboardPeriod.global
        ? 'profiles'
        : 'periods/$periodId/entries';
    final res = await _authed(Uri.parse('$_base:batchGet'), {
      'documents': [for (final u in list) '$_dbPath/$path/$u'],
    });
    final myUid = _session?.uid;
    final decoded = json.decode(res.body);
    if (decoded is! List) return const [];
    return decoded
        .where((e) => e is Map && e['found'] != null)
        .map<LeaderboardEntry>((e) => _entryFromDoc(e['found'] as Map,
            period: period, myUid: myUid))
        .toList();
  }

  void dispose() => _http.close();
}

class _Session {
  final String projectId;
  final String uid;
  final String idToken;
  final String refreshToken;
  final DateTime expiresAt;

  _Session({
    required this.projectId,
    required this.uid,
    required this.idToken,
    required this.refreshToken,
    required this.expiresAt,
  });

  /// Treat tokens as expired 2 minutes early.
  bool get isFresh =>
      DateTime.now().isBefore(expiresAt.subtract(const Duration(minutes: 2)));

  Map<String, dynamic> toJson() => {
        'projectId': projectId,
        'uid': uid,
        'idToken': idToken,
        'refreshToken': refreshToken,
        'expiresAt': expiresAt.toIso8601String(),
      };

  factory _Session.fromJson(Map<String, dynamic> j) => _Session(
        projectId: j['projectId'] as String,
        uid: j['uid'] as String,
        idToken: j['idToken'] as String,
        refreshToken: j['refreshToken'] as String,
        expiresAt: DateTime.parse(j['expiresAt'] as String),
      );
}
