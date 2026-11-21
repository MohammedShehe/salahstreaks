import 'dart:async';
import 'dart:convert';
import 'dart:math' as math;
import 'package:flutter/widgets.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:salahstreaks/models/leaderboard_models.dart';
import 'package:salahstreaks/providers/app_provider.dart';
import 'package:salahstreaks/services/leaderboard_scoring.dart';
import 'package:salahstreaks/services/leaderboard_service.dart';

/// State + offline-first sync for the Ummah Leaderboard.
///
/// Design goals
///  * Local data stays the source of truth. Nothing here mutates AppProvider,
///    SQLite or the existing SharedPreferences keys — the provider only READS
///    AppProvider (via [attach]) and derives a public snapshot from it.
///  * Opt-in. Nothing is uploaded until the user joins.
///  * Offline-first. The upload is idempotent ("my latest snapshot"), so the
///    queue is just a fingerprint of the last snapshot that reached the
///    server; whenever the current fingerprint differs the app is "pending"
///    and retries with exponential back-off, on app resume, and on a timer.
///    Boards are cached on disk and shown instantly / when offline.
///  * Leaving deletes server data; if that happens offline, the delete is
///    persisted and retried until it succeeds.
class LeaderboardProvider extends ChangeNotifier with WidgetsBindingObserver {
  LeaderboardProvider({LeaderboardService? service})
      : _service = service ?? LeaderboardService() {
    WidgetsBinding.instance.addObserver(this);
    _init();
  }

  final LeaderboardService _service;

  // --- prefs keys (all prefixed lb_ so StorageService.clearAllData keeps them)
  static const _kEnabled = 'lb_enabled';
  static const _kName = 'lb_name';
  static const _kAvatar = 'lb_avatar';
  static const _kFriends = 'lb_friends_v1';
  static const _kLastFp = 'lb_last_fp';
  static const _kPeriods = 'lb_periods';
  static const _kPendingDelete = 'lb_pending_delete';
  static const _kSyncedAt = 'lb_synced_at';
  static const _kCachePrefix = 'lb_cache_';

  static const int maxFriends = 50;
  static const Duration _debounce = Duration(seconds: 12);
  static const Duration _minPushGap = Duration(seconds: 6);
  static const Duration _boardTtl = Duration(seconds: 60);

  AppProvider? _app;

  // --- profile / enrolment
  bool _ready = false;
  bool _configured = false;
  bool _enabled = false;
  String _name = '';
  int _avatar = 0;
  String? _myUid;
  final Map<String, String> _friends = {}; // uid -> last known name
  String _lastFp = '';
  List<String> _periods = [];
  bool _pendingDelete = false;
  DateTime? _syncedAt;

  // --- sync
  LeaderboardSyncState _syncState = LeaderboardSyncState.idle;
  String? _syncError;
  bool _flushing = false;
  bool _flushAgain = false;
  int _retryAttempt = 0;
  DateTime _lastPushAt = DateTime.fromMillisecondsSinceEpoch(0);
  Timer? _debounceTimer;
  Timer? _retryTimer;
  Timer? _periodicTimer;
  ProfileSnapshot? _snapCache;

  // --- view
  LeaderboardPeriod _period = LeaderboardPeriod.global;
  LeaderboardSort _sort = LeaderboardSort.points;
  LeaderboardScope _scope = LeaderboardScope.everyone;
  final Map<String, LeaderboardCache> _boards = {};
  bool _loading = false;
  bool _offline = false;
  String? _error;

  // --- search
  String _searchQuery = '';
  bool _searching = false;
  String? _searchError;
  List<LeaderboardEntry> _searchResults = [];

  // ------------------------------------------------------------- getters

  bool get ready => _ready;
  bool get configured => _configured;
  bool get enrolled => _enabled;
  String get displayName => _name;
  int get avatar => _avatar;
  String? get myUid => _myUid;
  Map<String, String> get friends => Map.unmodifiable(_friends);
  bool isFriend(String uid) => _friends.containsKey(uid);

  LeaderboardSyncState get syncState => _syncState;
  String? get syncError => _syncError;
  DateTime? get lastSyncedAt => _syncedAt;
  bool get hasPendingChanges {
    if (!_enabled) return _pendingDelete;
    final s = _buildSnapshot();
    return s == null ? false : s.fingerprint != _lastFp;
  }

  LeaderboardPeriod get period => _period;
  LeaderboardSort get sort => _sort;
  LeaderboardScope get scope => _scope;
  bool get loading => _loading;
  bool get offline => _offline;
  String? get error => _error;

  String? get periodId {
    switch (_period) {
      case LeaderboardPeriod.global:
        return null;
      case LeaderboardPeriod.weekly:
        return LeaderboardScoring.weekId(DateTime.now());
      case LeaderboardPeriod.monthly:
        return LeaderboardScoring.monthId(DateTime.now());
    }
  }

  String get _currentKey => _keyFor(_period, _sort, _scope);

  String _keyFor(
      LeaderboardPeriod p, LeaderboardSort s, LeaderboardScope sc) {
    final id = p == LeaderboardPeriod.weekly
        ? LeaderboardScoring.weekId(DateTime.now())
        : p == LeaderboardPeriod.monthly
            ? LeaderboardScoring.monthId(DateTime.now())
            : 'all';
    final sortPart = p == LeaderboardPeriod.global ? s.name : 'points';
    return '${p.name}_${sortPart}_${sc.name}_$id';
  }

  LeaderboardCache? get currentBoard => _boards[_currentKey];
  List<LeaderboardEntry> get entries => currentBoard?.entries ?? const [];
  int? get myRank => currentBoard?.myRank;
  DateTime? get boardFetchedAt => currentBoard?.fetchedAt;

  String _searchQ() => _searchQuery;
  String get searchQuery => _searchQ();
  bool get searching => _searching;
  String? get searchError => _searchError;
  List<LeaderboardEntry> get searchResults => _searchResults;

  /// My numbers, computed locally (so they work offline).
  ProfileSnapshot? get mySnapshot => _buildSnapshot();

  /// Name to pre-fill on the join form (null if the user never set one).
  Future<String?> suggestedName() async {
    try {
      final prefs = await SharedPreferences.getInstance();
      final n = prefs.getString('user_name');
      if (n == null || n.trim().isEmpty || n.trim() == 'MO11') return null;
      return n.trim();
    } catch (_) {
      return null;
    }
  }

  // ---------------------------------------------------------------- init

  Future<void> _init() async {
    try {
      final prefs = await SharedPreferences.getInstance();
      _enabled = prefs.getBool(_kEnabled) ?? false;
      _name = prefs.getString(_kName) ?? '';
      _avatar = prefs.getInt(_kAvatar) ?? 0;
      _lastFp = prefs.getString(_kLastFp) ?? '';
      _periods = prefs.getStringList(_kPeriods) ?? [];
      _pendingDelete = prefs.getBool(_kPendingDelete) ?? false;
      final at = prefs.getString(_kSyncedAt);
      _syncedAt = at == null ? null : DateTime.tryParse(at);

      final rawFriends = prefs.getString(_kFriends);
      if (rawFriends != null) {
        try {
          final m = json.decode(rawFriends) as Map;
          m.forEach((k, v) => _friends['$k'] = '$v');
        } catch (_) {}
      }

      _pruneOldCaches(prefs);

      _configured = await _service.isConfigured;
      _myUid = await _service.currentUid();
    } catch (e) {
      debugPrint('Leaderboard init failed: $e');
    }
    _ready = true;
    notifyListeners();

    _periodicTimer =
        Timer.periodic(const Duration(minutes: 15), (_) => _markDirtySoon());
    if (_enabled || _pendingDelete) _markDirtySoon();
  }

  void _pruneOldCaches(SharedPreferences prefs) {
    final week = LeaderboardScoring.weekId(DateTime.now());
    final month = LeaderboardScoring.monthId(DateTime.now());
    for (final k in prefs.getKeys().toList()) {
      if (!k.startsWith(_kCachePrefix)) continue;
      final isWeekly = k.startsWith('${_kCachePrefix}weekly_');
      final isMonthly = k.startsWith('${_kCachePrefix}monthly_');
      if ((isWeekly && !k.endsWith('_$week')) ||
          (isMonthly && !k.endsWith('_$month'))) {
        prefs.remove(k);
      }
    }
  }

  // ----------------------------------------------- hook into AppProvider

  /// Called by ChangeNotifierProxyProvider whenever AppProvider changes.
  /// Cheap by design: it only invalidates caches and arms a debounce timer.
  void attach(AppProvider app) {
    _app = app;
    _snapCache = null;
    if (_ready && (_enabled || _pendingDelete)) _markDirtySoon();
  }

  ProfileSnapshot? _buildSnapshot() {
    final app = _app;
    if (app == null || app.isLoading) return null;
    return _snapCache ??= LeaderboardScoring.buildSnapshot(
      displayName: _name.isEmpty ? 'You' : _name,
      avatar: _avatar,
      logs: app.logs,
      adhkarLogs: app.adhkarLogs,
      streaks: app.streaks,
    );
  }

  // ----------------------------------------------------------- sync queue

  void _markDirtySoon([Duration? after]) {
    if (_debounceTimer?.isActive ?? false) return;
    _debounceTimer = Timer(after ?? _debounce, () => _flush());
  }

  void _setSync(LeaderboardSyncState s, {String? error}) {
    _syncState = s;
    _syncError = error;
    notifyListeners();
  }

  /// Push now (used by the "Sync now" button and after joining).
  Future<void> syncNow() async {
    _retryTimer?.cancel();
    _retryAttempt = 0;
    await _flush();
  }

  Future<void> _flush() async {
    if (_flushing) {
      _flushAgain = true;
      return;
    }
    _flushing = true;
    try {
      await _flushInner();
    } catch (e) {
      debugPrint('Leaderboard flush error: $e');
    } finally {
      _flushing = false;
      if (_flushAgain) {
        _flushAgain = false;
        _markDirtySoon();
      }
    }
  }

  Future<void> _flushInner() async {
    if (!await _service.isConfigured) {
      _configured = false;
      _setSync(LeaderboardSyncState.idle);
      return;
    }
    _configured = true;

    // 1) A "leave" that couldn't reach the server yet.
    if (_pendingDelete) {
      try {
        final uid = await _service.currentUid();
        if (uid != null) {
          await _service.deleteMyData(_periods);
        }
        _pendingDelete = false;
        _periods = [];
        _lastFp = '';
        _syncedAt = null;
        await _persistSyncMeta();
        final prefs = await SharedPreferences.getInstance();
        await prefs.setBool(_kPendingDelete, false);
      } catch (e) {
        _handleSyncError(e);
        return;
      }
    }

    if (!_enabled) {
      _setSync(LeaderboardSyncState.idle);
      return;
    }

    // 2) Publish the latest snapshot if it differs from what the server has.
    final snap = _buildSnapshot();
    if (snap == null) return; // AppProvider still loading; attach() re-arms.
    if (snap.fingerprint == _lastFp) {
      _setSync(LeaderboardSyncState.synced);
      return;
    }

    // Stay under the server-side rate limit (rules: >=5s between writes).
    final gap = DateTime.now().difference(_lastPushAt);
    if (gap < _minPushGap) {
      await Future.delayed(_minPushGap - gap);
    }

    _setSync(LeaderboardSyncState.syncing);
    try {
      final written = await _service.publish(snap);
      _lastPushAt = DateTime.now();
      _lastFp = snap.fingerprint;
      _syncedAt = DateTime.now();
      _periods = {..._periods, ...written}.toList();
      if (_periods.length > 12) {
        _periods = _periods.sublist(_periods.length - 12);
      }
      _retryAttempt = 0;
      _offline = false;
      _myUid = await _service.currentUid();
      await _persistSyncMeta();
      _setSync(LeaderboardSyncState.synced);
    } catch (e) {
      _handleSyncError(e);
    }
  }

  void _handleSyncError(Object e) {
    if (e is LeaderboardNotConfigured) {
      _configured = false;
      _setSync(LeaderboardSyncState.idle);
      return;
    }
    if (e is LeaderboardNetworkException) {
      _offline = true;
      _setSync(LeaderboardSyncState.offline);
    } else if (e is LeaderboardApiException) {
      _setSync(LeaderboardSyncState.error, error: _friendlyApiError(e));
    } else {
      _setSync(LeaderboardSyncState.error, error: '$e');
    }
    _scheduleRetry();
  }

  void _scheduleRetry() {
    _retryTimer?.cancel();
    final secs = math.min(900, 30 * (1 << _retryAttempt));
    _retryAttempt = math.min(_retryAttempt + 1, 5);
    _retryTimer = Timer(Duration(seconds: secs), () => _flush());
  }

  Future<void> _persistSyncMeta() async {
    try {
      final prefs = await SharedPreferences.getInstance();
      await prefs.setString(_kLastFp, _lastFp);
      await prefs.setStringList(_kPeriods, _periods);
      if (_syncedAt == null) {
        await prefs.remove(_kSyncedAt);
      } else {
        await prefs.setString(_kSyncedAt, _syncedAt!.toIso8601String());
      }
    } catch (_) {}
  }

  String _friendlyApiError(LeaderboardApiException e) {
    if (e.isPermissionDenied) {
      return 'The server rejected the request. Make sure firestore.rules '
          'from the project are published in your Firebase console.';
    }
    if (e.status == 400 && e.message.contains('API key')) {
      return 'The Firebase API key looks invalid.';
    }
    if (e.status == 400 && e.message.contains('ADMIN_ONLY_OPERATION')) {
      return 'Enable Anonymous sign-in in Firebase Authentication.';
    }
    if (e.status == 400 && e.message.contains('OPERATION_NOT_ALLOWED')) {
      return 'Enable Anonymous sign-in in Firebase Authentication.';
    }
    if (e.isRateLimited) return 'Too many requests — will retry shortly.';
    return e.message;
  }

  // ------------------------------------------------- enrolment & profile

  Future<void> join({required String name, required int avatar}) async {
    final clean = LeaderboardScoring.sanitizeName(name);
    if (!LeaderboardScoring.isValidName(clean)) return;
    _enabled = true;
    _name = clean;
    _avatar = avatar.clamp(0, leaderboardAvatars.length - 1).toInt();
    _snapCache = null;
    final prefs = await SharedPreferences.getInstance();
    await prefs.setBool(_kEnabled, true);
    await prefs.setString(_kName, _name);
    await prefs.setInt(_kAvatar, _avatar);
    notifyListeners();
    await syncNow();
    unawaited(load(force: true));
  }

  Future<void> updateProfile({required String name, required int avatar}) async {
    final clean = LeaderboardScoring.sanitizeName(name);
    if (!LeaderboardScoring.isValidName(clean)) return;
    _name = clean;
    _avatar = avatar.clamp(0, leaderboardAvatars.length - 1).toInt();
    _snapCache = null;
    final prefs = await SharedPreferences.getInstance();
    await prefs.setString(_kName, _name);
    await prefs.setInt(_kAvatar, _avatar);
    notifyListeners();
    await syncNow();
  }

  /// Leave the leaderboard and delete everything published. If the device is
  /// offline the deletion is queued and retried until it succeeds.
  Future<void> leave() async {
    final hadData = _lastFp.isNotEmpty || _periods.isNotEmpty;
    _enabled = false;
    _pendingDelete = hadData || _pendingDelete;
    _snapCache = null;
    final prefs = await SharedPreferences.getInstance();
    await prefs.setBool(_kEnabled, false);
    await prefs.setBool(_kPendingDelete, _pendingDelete);
    _boards.clear();
    notifyListeners();
    await syncNow();
    unawaited(load(force: true));
  }

  // ------------------------------------------------------------- config

  Future<LeaderboardConfig?> currentConfig() => _service.getConfig();

  Future<void> saveConfig(String projectId, String apiKey) async {
    final cfg = LeaderboardConfig(
        projectId: projectId.trim(), apiKey: apiKey.trim());
    if (!cfg.isValid) {
      throw const FormatException('Project ID or API key looks invalid');
    }
    await _service.saveConfig(cfg);
    _configured = true;
    _myUid = null;
    _lastFp = ''; // new project: nothing has been published there yet
    _periods = [];
    _boards.clear();
    await _persistSyncMeta();
    _error = null;
    notifyListeners();
    if (_enabled) _markDirtySoon(const Duration(seconds: 1));
    unawaited(load(force: true));
  }

  // ------------------------------------------------------------- viewing

  void setPeriod(LeaderboardPeriod p) {
    if (p == _period) return;
    _period = p;
    _error = null;
    notifyListeners();
    unawaited(load());
  }

  void setSort(LeaderboardSort s) {
    if (s == _sort) return;
    _sort = s;
    notifyListeners();
    unawaited(load());
  }

  void setScope(LeaderboardScope s) {
    if (s == _scope) return;
    _scope = s;
    notifyListeners();
    unawaited(load());
  }

  /// Loads the active board: cached copy first, then the network.
  Future<void> load({bool force = false}) async {
    final key = _currentKey;
    final period = _period;
    final sort = _sort;
    final scope = _scope;
    final pid = periodId;

    // 1) instant: memory / disk cache
    if (_boards[key] == null) {
      try {
        final prefs = await SharedPreferences.getInstance();
        final c = LeaderboardCache.decode(
            prefs.getString('$_kCachePrefix$key'),
            myUid: _myUid);
        if (c != null) _boards[key] = c;
      } catch (_) {}
      notifyListeners();
    }

    if (!await _service.isConfigured) {
      _configured = false;
      notifyListeners();
      return;
    }
    _configured = true;

    final cached = _boards[key];
    if (!force &&
        cached != null &&
        DateTime.now().difference(cached.fetchedAt) < _boardTtl) {
      return;
    }

    _loading = true;
    _error = null;
    notifyListeners();

    try {
      _myUid = await _service.ensureSignedIn();

      List<LeaderboardEntry> list;
      int? rank;
      final byStreak =
          period == LeaderboardPeriod.global && sort == LeaderboardSort.streak;
      int valueOf(LeaderboardEntry e) => byStreak ? e.streak : e.points;

      if (scope == LeaderboardScope.friends) {
        final ids = <String>{
          ..._friends.keys,
          if (_enabled && _myUid != null) _myUid!,
        };
        final found = await _service.fetchByUids(
            uids: ids, period: period, periodId: pid);
        final foundIds = found.map((e) => e.uid).toSet();
        list = [
          ...found,
          // Friends with no data for this board still appear (0 points).
          for (final f in _friends.entries)
            if (!foundIds.contains(f.key))
              LeaderboardEntry(
                  uid: f.key, displayName: f.value, avatar: 0, points: 0, streak: 0),
        ];
        list.sort((a, b) {
          final c = valueOf(b).compareTo(valueOf(a));
          return c != 0 ? c : a.displayName.compareTo(b.displayName);
        });
        for (var i = 0; i < list.length; i++) {
          list[i].rank = i + 1;
          if (list[i].isMe) rank = i + 1;
        }
      } else {
        list = await _service.fetchTop(
            period: period, periodId: pid, sort: sort, limit: 50);
        for (final e in list) {
          if (e.isMe) rank = e.rank;
        }
        final snap = _buildSnapshot();
        if (rank == null && _enabled && _lastFp.isNotEmpty && snap != null) {
          final mine = period == LeaderboardPeriod.global
              ? (byStreak ? snap.totalStreak : snap.totalPoints)
              : period == LeaderboardPeriod.weekly
                  ? snap.weeklyPoints
                  : snap.monthlyPoints;
          try {
            rank = await _service.fetchMyRank(
                period: period, periodId: pid, myValue: mine, sort: sort);
          } catch (_) {}
        }
      }

      // keep friend display names fresh
      var namesChanged = false;
      for (final e in list) {
        if (_friends.containsKey(e.uid) &&
            e.displayName.isNotEmpty &&
            _friends[e.uid] != e.displayName) {
          _friends[e.uid] = e.displayName;
          namesChanged = true;
        }
      }
      if (namesChanged) await _saveFriends();

      final board = LeaderboardCache(
          fetchedAt: DateTime.now(), entries: list, myRank: rank);
      _boards[key] = board;
      _offline = false;
      try {
        final prefs = await SharedPreferences.getInstance();
        await prefs.setString('$_kCachePrefix$key', board.encode());
      } catch (_) {}
    } on LeaderboardNetworkException {
      _offline = true;
      if (_boards[key] == null) {
        _error = 'You are offline. Boards will load when you reconnect.';
      }
    } on LeaderboardApiException catch (e) {
      _error = _friendlyApiError(e);
    } catch (e) {
      _error = 'Could not load the leaderboard.';
      debugPrint('Leaderboard load error: $e');
    }

    _loading = false;
    notifyListeners();
  }

  // -------------------------------------------------------------- search

  Future<void> search(String query) async {
    _searchQuery = query;
    final q = query.trim();
    if (q.length < 2) {
      _searchResults = [];
      _searching = false;
      _searchError = null;
      notifyListeners();
      return;
    }
    _searching = true;
    _searchError = null;
    notifyListeners();
    try {
      final r = await _service.searchByName(q);
      if (_searchQuery != query) return; // superseded by a newer query
      _searchResults = r.where((e) => !e.isMe).toList();
    } on LeaderboardNetworkException {
      if (_searchQuery != query) return;
      _searchError = 'Search needs an internet connection.';
      _searchResults = [];
    } on LeaderboardApiException catch (e) {
      if (_searchQuery != query) return;
      _searchError = _friendlyApiError(e);
      _searchResults = [];
    } catch (_) {
      if (_searchQuery != query) return;
      _searchError = 'Search failed.';
      _searchResults = [];
    }
    _searching = false;
    notifyListeners();
  }

  void clearSearch() {
    _searchQuery = '';
    _searchResults = [];
    _searching = false;
    _searchError = null;
    notifyListeners();
  }

  // ------------------------------------------------------------- friends

  /// Returns false when the friends limit has been reached.
  Future<bool> toggleFriend(LeaderboardEntry e) async {
    if (e.isMe || e.uid.isEmpty) return true;
    if (_friends.containsKey(e.uid)) {
      _friends.remove(e.uid);
    } else {
      if (_friends.length >= maxFriends) return false;
      _friends[e.uid] = e.displayName;
    }
    await _saveFriends();
    // The friends board is derived from this set.
    _boards.removeWhere((k, _) => k.contains('_friends_'));
    notifyListeners();
    if (_scope == LeaderboardScope.friends) unawaited(load(force: true));
    return true;
  }

  Future<void> _saveFriends() async {
    try {
      final prefs = await SharedPreferences.getInstance();
      await prefs.setString(_kFriends, json.encode(_friends));
    } catch (_) {}
  }

  // ----------------------------------------------------------- lifecycle

  @override
  void didChangeAppLifecycleState(AppLifecycleState state) {
    if (state == AppLifecycleState.resumed && _ready) {
      _retryAttempt = 0;
      if (_enabled || _pendingDelete) _markDirtySoon(const Duration(seconds: 2));
    }
  }

  @override
  void dispose() {
    WidgetsBinding.instance.removeObserver(this);
    _debounceTimer?.cancel();
    _retryTimer?.cancel();
    _periodicTimer?.cancel();
    _service.dispose();
    super.dispose();
  }
}
