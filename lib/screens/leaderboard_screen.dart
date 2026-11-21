import 'dart:async';
import 'package:flutter/material.dart';
import 'package:intl/intl.dart';
import 'package:provider/provider.dart';
import 'package:salahstreaks/models/leaderboard_models.dart';
import 'package:salahstreaks/providers/leaderboard_provider.dart';
import 'package:salahstreaks/services/leaderboard_scoring.dart';
import 'package:salahstreaks/utils/app_theme.dart';
import 'package:salahstreaks/widgets/app_background.dart';

/// Ummah Leaderboard: global / weekly / monthly rankings of ibadat points and
/// streaks. All data flows device <-> Firebase (no SalahStreaks server).
class LeaderboardScreen extends StatefulWidget {
  const LeaderboardScreen({super.key});

  @override
  State<LeaderboardScreen> createState() => _LeaderboardScreenState();
}

class _LeaderboardScreenState extends State<LeaderboardScreen> {
  final TextEditingController _searchCtrl = TextEditingController();
  Timer? _searchDebounce;
  bool _searchOpen = false;

  static final NumberFormat _num = NumberFormat('#,###');

  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addPostFrameCallback((_) {
      if (mounted) context.read<LeaderboardProvider>().load();
    });
  }

  @override
  void dispose() {
    _searchDebounce?.cancel();
    _searchCtrl.dispose();
    super.dispose();
  }

  // ------------------------------------------------------------- helpers

  String _ago(DateTime t) {
    final d = DateTime.now().difference(t);
    if (d.inSeconds < 45) return 'just now';
    if (d.inMinutes < 60) return '${d.inMinutes}m ago';
    if (d.inHours < 24) return '${d.inHours}h ago';
    return '${d.inDays}d ago';
  }

  int _myValue(LeaderboardProvider lb) {
    final s = lb.mySnapshot;
    if (s == null) return 0;
    switch (lb.period) {
      case LeaderboardPeriod.global:
        return lb.sort == LeaderboardSort.streak ? s.totalStreak : s.totalPoints;
      case LeaderboardPeriod.weekly:
        return s.weeklyPoints;
      case LeaderboardPeriod.monthly:
        return s.monthlyPoints;
    }
  }

  String _resetLabel(LeaderboardProvider lb) {
    final now = DateTime.now();
    final today = DateTime(now.year, now.month, now.day);
    if (lb.period == LeaderboardPeriod.weekly) {
      final days =
          LeaderboardScoring.nextWeekStart(today).difference(today).inDays;
      return 'Weekly board resets Monday · $days day${days == 1 ? '' : 's'} left';
    }
    if (lb.period == LeaderboardPeriod.monthly) {
      final days =
          LeaderboardScoring.nextMonthStart(today).difference(today).inDays;
      return 'Monthly board resets on the 1st · $days day${days == 1 ? '' : 's'} left';
    }
    return 'Lifetime points since you started tracking';
  }

  void _toast(String msg) {
    if (!mounted) return;
    ScaffoldMessenger.of(context)
        .showSnackBar(SnackBar(content: Text(msg)));
  }

  // --------------------------------------------------------------- build

  @override
  Widget build(BuildContext context) {
    final lb = context.watch<LeaderboardProvider>();

    return Scaffold(
      body: AppBackground(
        child: SafeArea(
          child: Column(
            children: [
              _buildHeader(lb),
              Expanded(
                child: !lb.ready
                    ? const Center(child: CircularProgressIndicator())
                    : !lb.configured
                        ? _buildSetupCard(lb)
                        : _buildBody(lb),
              ),
            ],
          ),
        ),
      ),
    );
  }

  Widget _buildHeader(LeaderboardProvider lb) {
    return Padding(
      padding: const EdgeInsets.fromLTRB(4, 8, 4, 0),
      child: Row(
        children: [
          IconButton(
            icon: Icon(Icons.arrow_back_ios_new_rounded,
                color: AppThemeColors.icon(context), size: 20),
            onPressed: () => Navigator.maybePop(context),
            tooltip: 'Back',
          ),
          Expanded(
            child: Text(
              '🌍 Ummah Leaderboard',
              maxLines: 1,
              overflow: TextOverflow.ellipsis,
              style: TextStyle(
                fontSize: 20,
                fontWeight: FontWeight.bold,
                color: AppThemeColors.textPrimary(context),
              ),
            ),
          ),
          if (lb.configured)
            IconButton(
              icon: Icon(_searchOpen ? Icons.close : Icons.search,
                  color: AppThemeColors.icon(context)),
              tooltip: 'Find people',
              onPressed: () {
                setState(() => _searchOpen = !_searchOpen);
                if (!_searchOpen) {
                  _searchCtrl.clear();
                  lb.clearSearch();
                }
              },
            ),
          PopupMenuButton<String>(
            icon: Icon(Icons.more_vert, color: AppThemeColors.icon(context)),
            color: AppThemeColors.surface(context),
            onSelected: (v) {
              switch (v) {
                case 'profile':
                  _showProfileSheet(lb);
                  break;
                case 'info':
                  _showInfoDialog();
                  break;
                case 'connect':
                  _showConnectSheet(lb);
                  break;
                case 'sync':
                  lb.syncNow();
                  lb.load(force: true);
                  break;
              }
            },
            itemBuilder: (_) => [
              if (lb.configured)
                PopupMenuItem(
                  value: 'profile',
                  child: Text(lb.enrolled ? 'My leaderboard profile' : 'Join leaderboard'),
                ),
              if (lb.configured && lb.enrolled)
                const PopupMenuItem(value: 'sync', child: Text('Sync now')),
              const PopupMenuItem(
                  value: 'info', child: Text('Scoring & privacy')),
              const PopupMenuItem(
                  value: 'connect', child: Text('Firebase connection')),
            ],
          ),
        ],
      ),
    );
  }

  // ------------------------------------------------------- setup (no cfg)

  Widget _buildSetupCard(LeaderboardProvider lb) {
    return Center(
      child: SingleChildScrollView(
        padding: const EdgeInsets.all(20),
        child: Container(
          padding: const EdgeInsets.all(20),
          decoration: _panel(),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              const Text('🔌', style: TextStyle(fontSize: 44)),
              const SizedBox(height: 8),
              Text(
                'Connect the leaderboard',
                style: TextStyle(
                  fontSize: 18,
                  fontWeight: FontWeight.bold,
                  color: AppThemeColors.textPrimary(context),
                ),
              ),
              const SizedBox(height: 8),
              Text(
                'The Ummah Leaderboard runs without any SalahStreaks server. '
                'It stores rankings in your own free Firebase project, protected '
                'by security rules. Follow docs/LEADERBOARD_SETUP.md (about 5 '
                'minutes), then paste your Project ID and Web API key here.\n\n'
                'The rest of the app works fully offline and is unaffected.',
                textAlign: TextAlign.center,
                style: TextStyle(
                    color: AppThemeColors.textSecondary(context), height: 1.4),
              ),
              const SizedBox(height: 16),
              ElevatedButton.icon(
                onPressed: () => _showConnectSheet(lb),
                icon: const Icon(Icons.link),
                label: const Text('Enter Firebase details'),
                style: ElevatedButton.styleFrom(
                  backgroundColor: Colors.green[700],
                  foregroundColor: Colors.white,
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }

  BoxDecoration _panel() => BoxDecoration(
        color: AppThemeColors.panelFill(context, 0.15),
        borderRadius: BorderRadius.circular(16),
        border: Border.all(color: AppThemeColors.cardBorder(context)),
      );

  // ------------------------------------------------------------- body

  Widget _buildBody(LeaderboardProvider lb) {
    return Column(
      children: [
        if (_searchOpen) _buildSearchField(lb),
        Expanded(
          child: _searchOpen && _searchCtrl.text.trim().isNotEmpty
              ? _buildSearchResults(lb)
              : RefreshIndicator(
                  color: Colors.green,
                  onRefresh: () async {
                    unawaited(lb.syncNow());
                    await lb.load(force: true);
                  },
                  child: _buildBoardList(lb),
                ),
        ),
      ],
    );
  }

  Widget _buildBoardList(LeaderboardProvider lb) {
    final entries = lb.entries;

    final children = <Widget>[
      lb.enrolled ? _buildMyCard(lb) : _buildJoinCard(lb),
      const SizedBox(height: 12),
      _buildPeriodSelector(lb),
      const SizedBox(height: 8),
      _buildFilters(lb),
      const SizedBox(height: 4),
      _buildStatusStrip(lb),
    ];

    if (lb.loading && entries.isEmpty) {
      children.add(const Padding(
        padding: EdgeInsets.symmetric(vertical: 40),
        child: Center(child: CircularProgressIndicator()),
      ));
    } else if (lb.error != null && entries.isEmpty) {
      children.add(_emptyState('⚠️', lb.error!));
    } else if (entries.isEmpty) {
      children.add(_emptyState(
        lb.scope == LeaderboardScope.friends ? '🤝' : '🌱',
        lb.scope == LeaderboardScope.friends
            ? 'No friends yet. Tap the search icon to find people and follow '
                'them with the star.'
            : 'Nobody is on this board yet. Be the first — log some ibadat and '
                'join!',
      ));
    } else {
      for (final e in entries) {
        children.add(_buildEntryTile(lb, e));
      }
      // Pin "my" row below the list if I'm ranked but not visible.
      if (lb.enrolled &&
          lb.scope == LeaderboardScope.everyone &&
          !entries.any((e) => e.isMe) &&
          lb.myRank != null) {
        children.add(Padding(
          padding: const EdgeInsets.symmetric(vertical: 6),
          child: Center(
            child: Text('···',
                style: TextStyle(color: AppThemeColors.textHint(context))),
          ),
        ));
        final s = lb.mySnapshot;
        if (s != null) {
          children.add(_buildEntryTile(
            lb,
            LeaderboardEntry(
              uid: lb.myUid ?? 'me',
              displayName: lb.displayName,
              avatar: lb.avatar,
              points: _myValue(lb),
              streak: s.totalStreak,
              rank: lb.myRank!,
              isMe: true,
            ),
          ));
        }
      }
    }

    children.add(Padding(
      padding: const EdgeInsets.fromLTRB(8, 14, 8, 24),
      child: Text(
        _resetLabel(lb),
        textAlign: TextAlign.center,
        style: TextStyle(
            fontSize: 12, color: AppThemeColors.textHint(context)),
      ),
    ));

    return ListView(
      physics: const AlwaysScrollableScrollPhysics(),
      padding: const EdgeInsets.fromLTRB(16, 8, 16, 8),
      children: children,
    );
  }

  Widget _emptyState(String emoji, String text) {
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 36, horizontal: 12),
      child: Column(
        children: [
          Text(emoji, style: const TextStyle(fontSize: 38)),
          const SizedBox(height: 8),
          Text(
            text,
            textAlign: TextAlign.center,
            style: TextStyle(
                color: AppThemeColors.textSecondary(context), height: 1.4),
          ),
        ],
      ),
    );
  }

  // -------------------------------------------------------- my card / join

  Widget _buildMyCard(LeaderboardProvider lb) {
    final s = lb.mySnapshot;
    final rank = lb.myRank;
    final isStreak = lb.period == LeaderboardPeriod.global &&
        lb.sort == LeaderboardSort.streak;

    return Container(
      padding: const EdgeInsets.all(14),
      decoration: BoxDecoration(
        gradient: LinearGradient(colors: AppThemeColors.cardGradient(context)),
        borderRadius: BorderRadius.circular(16),
        border: Border.all(color: AppThemeColors.cardBorder(context)),
      ),
      child: Column(
        children: [
          Row(
            children: [
              _avatarCircle(lb.avatar, 26),
              const SizedBox(width: 12),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      lb.displayName,
                      maxLines: 1,
                      overflow: TextOverflow.ellipsis,
                      style: TextStyle(
                        fontSize: 16,
                        fontWeight: FontWeight.bold,
                        color: AppThemeColors.textPrimary(context),
                      ),
                    ),
                    Text(
                      s == null
                          ? '…'
                          : '🔥 ${s.totalStreak} total streak days',
                      style: TextStyle(
                          fontSize: 12,
                          color: AppThemeColors.textSecondary(context)),
                    ),
                  ],
                ),
              ),
              Column(
                crossAxisAlignment: CrossAxisAlignment.end,
                children: [
                  Text(
                    rank == null ? '#—' : '#${_num.format(rank)}',
                    style: const TextStyle(
                      fontSize: 22,
                      fontWeight: FontWeight.bold,
                      color: Colors.amber,
                    ),
                  ),
                  Text(
                    '${_num.format(_myValue(lb))} ${isStreak ? 'streak' : 'pts'}',
                    style: TextStyle(
                        fontSize: 12,
                        color: AppThemeColors.textSecondary(context)),
                  ),
                ],
              ),
            ],
          ),
          const SizedBox(height: 10),
          _buildSyncChip(lb),
        ],
      ),
    );
  }

  Widget _buildSyncChip(LeaderboardProvider lb) {
    IconData icon;
    Color color;
    String label;
    switch (lb.syncState) {
      case LeaderboardSyncState.syncing:
        icon = Icons.sync;
        color = Colors.blue;
        label = 'Syncing…';
        break;
      case LeaderboardSyncState.offline:
      case LeaderboardSyncState.pending:
        icon = Icons.cloud_off_outlined;
        color = Colors.orange;
        label = 'Offline — your latest progress will sync automatically';
        break;
      case LeaderboardSyncState.error:
        icon = Icons.error_outline;
        color = Colors.redAccent;
        label = lb.syncError ?? 'Sync problem — will retry';
        break;
      default:
        if (lb.hasPendingChanges) {
          icon = Icons.schedule;
          color = Colors.orange;
          label = 'Waiting to sync…';
        } else if (lb.lastSyncedAt != null) {
          icon = Icons.cloud_done_outlined;
          color = Colors.green;
          label = 'Synced ${_ago(lb.lastSyncedAt!)}';
        } else {
          icon = Icons.cloud_queue;
          color = Colors.grey;
          label = 'Not synced yet';
        }
    }
    return Row(
      children: [
        Icon(icon, size: 15, color: color),
        const SizedBox(width: 6),
        Expanded(
          child: Text(
            label,
            maxLines: 2,
            overflow: TextOverflow.ellipsis,
            style: TextStyle(fontSize: 12, color: color),
          ),
        ),
      ],
    );
  }

  Widget _buildJoinCard(LeaderboardProvider lb) {
    final s = lb.mySnapshot;
    return Container(
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        gradient: LinearGradient(colors: AppThemeColors.cardGradient(context)),
        borderRadius: BorderRadius.circular(16),
        border: Border.all(color: AppThemeColors.cardBorder(context)),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(
            'Compete with the Ummah',
            style: TextStyle(
              fontSize: 16,
              fontWeight: FontWeight.bold,
              color: AppThemeColors.textPrimary(context),
            ),
          ),
          const SizedBox(height: 6),
          Text(
            s == null
                ? 'Join to appear on the global, weekly and monthly boards.'
                : 'You have ${_num.format(s.totalPoints)} points and '
                    '${s.totalStreak} streak days ready to share. Joining is '
                    'optional — only your chosen name, avatar, points and '
                    'streak counts are shared.',
            style: TextStyle(
                color: AppThemeColors.textSecondary(context),
                fontSize: 13,
                height: 1.35),
          ),
          const SizedBox(height: 10),
          Row(
            children: [
              ElevatedButton.icon(
                onPressed: () => _showProfileSheet(lb),
                icon: const Icon(Icons.emoji_events_outlined, size: 18),
                label: const Text('Join leaderboard'),
                style: ElevatedButton.styleFrom(
                  backgroundColor: Colors.green[700],
                  foregroundColor: Colors.white,
                ),
              ),
              const SizedBox(width: 8),
              TextButton(
                onPressed: _showInfoDialog,
                child: const Text('What is shared?'),
              ),
            ],
          ),
        ],
      ),
    );
  }

  // ----------------------------------------------------- selectors / chips

  Widget _buildPeriodSelector(LeaderboardProvider lb) {
    return SizedBox(
      width: double.infinity,
      child: SegmentedButton<LeaderboardPeriod>(
        showSelectedIcon: false,
        segments: const [
          ButtonSegment(
              value: LeaderboardPeriod.global,
              label: Text('Global'),
              icon: Icon(Icons.public, size: 16)),
          ButtonSegment(
              value: LeaderboardPeriod.weekly,
              label: Text('Weekly'),
              icon: Icon(Icons.date_range, size: 16)),
          ButtonSegment(
              value: LeaderboardPeriod.monthly,
              label: Text('Monthly'),
              icon: Icon(Icons.calendar_month, size: 16)),
        ],
        selected: {lb.period},
        onSelectionChanged: (s) => lb.setPeriod(s.first),
      ),
    );
  }

  Widget _buildFilters(LeaderboardProvider lb) {
    return Wrap(
      spacing: 8,
      runSpacing: 0,
      children: [
        ChoiceChip(
          label: const Text('Everyone'),
          selected: lb.scope == LeaderboardScope.everyone,
          onSelected: (_) => lb.setScope(LeaderboardScope.everyone),
        ),
        ChoiceChip(
          label: Text('Friends (${lb.friends.length})'),
          selected: lb.scope == LeaderboardScope.friends,
          onSelected: (_) => lb.setScope(LeaderboardScope.friends),
        ),
        if (lb.period == LeaderboardPeriod.global) ...[
          ChoiceChip(
            label: const Text('⭐ Points'),
            selected: lb.sort == LeaderboardSort.points,
            onSelected: (_) => lb.setSort(LeaderboardSort.points),
          ),
          ChoiceChip(
            label: const Text('🔥 Streak'),
            selected: lb.sort == LeaderboardSort.streak,
            onSelected: (_) => lb.setSort(LeaderboardSort.streak),
          ),
        ],
      ],
    );
  }

  Widget _buildStatusStrip(LeaderboardProvider lb) {
    String? text;
    Color color = Colors.orange;
    IconData icon = Icons.cloud_off_outlined;
    if (lb.offline) {
      final t = lb.boardFetchedAt;
      text = t == null
          ? 'Offline'
          : 'Offline — showing saved board from ${_ago(t)}';
    } else if (lb.error != null && lb.entries.isNotEmpty) {
      text = lb.error;
      color = Colors.redAccent;
      icon = Icons.error_outline;
    } else if (lb.loading) {
      text = 'Updating…';
      color = Colors.blue;
      icon = Icons.sync;
    }
    if (text == null) return const SizedBox(height: 6);
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 6),
      child: Row(
        children: [
          Icon(icon, size: 14, color: color),
          const SizedBox(width: 6),
          Expanded(
            child: Text(text,
                style: TextStyle(fontSize: 12, color: color),
                maxLines: 2,
                overflow: TextOverflow.ellipsis),
          ),
        ],
      ),
    );
  }

  // -------------------------------------------------------------- tiles

  Widget _avatarCircle(int avatar, double size) {
    return Container(
      width: size * 1.7,
      height: size * 1.7,
      alignment: Alignment.center,
      decoration: BoxDecoration(
        shape: BoxShape.circle,
        color: AppThemeColors.panelFillStrong(context),
        border: Border.all(color: AppThemeColors.cardBorder(context)),
      ),
      child: Text(avatarFor(avatar), style: TextStyle(fontSize: size)),
    );
  }

  Widget _rankBadge(int rank) {
    const medals = {1: '🥇', 2: '🥈', 3: '🥉'};
    final m = medals[rank];
    return SizedBox(
      width: 40,
      child: Center(
        child: m != null
            ? Text(m, style: const TextStyle(fontSize: 24))
            : Text(
                '#$rank',
                style: TextStyle(
                  fontWeight: FontWeight.bold,
                  color: AppThemeColors.textSecondary(context),
                ),
              ),
      ),
    );
  }

  Widget _buildEntryTile(LeaderboardProvider lb, LeaderboardEntry e,
      {bool showFollow = true, bool showRank = true}) {
    final isStreakSort = lb.period == LeaderboardPeriod.global &&
        lb.sort == LeaderboardSort.streak;
    final primary = isStreakSort ? e.streak : e.points;
    final subtitle = <String>[
      if (!isStreakSort) '🔥 ${e.streak}',
      if (lb.period != LeaderboardPeriod.global && e.activeDays > 0)
        '${e.activeDays} active day${e.activeDays == 1 ? '' : 's'}',
      if (isStreakSort) '⭐ ${_num.format(e.points)} pts',
    ].join('  ·  ');

    return Container(
      margin: const EdgeInsets.only(bottom: 8),
      padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 8),
      decoration: BoxDecoration(
        color: e.isMe
            ? Colors.amber.withOpacity(0.14)
            : AppThemeColors.panelFill(context, 0.1),
        borderRadius: BorderRadius.circular(14),
        border: Border.all(
          color: e.isMe
              ? Colors.amber.withOpacity(0.7)
              : AppThemeColors.cardBorder(context),
        ),
      ),
      child: Row(
        children: [
          if (showRank) _rankBadge(e.rank),
          _avatarCircle(e.avatar, 20),
          const SizedBox(width: 10),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  e.isMe ? '${e.displayName} (you)' : e.displayName,
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis,
                  style: TextStyle(
                    fontWeight: FontWeight.w600,
                    color: AppThemeColors.textPrimary(context),
                  ),
                ),
                if (subtitle.isNotEmpty)
                  Text(
                    subtitle,
                    maxLines: 1,
                    overflow: TextOverflow.ellipsis,
                    style: TextStyle(
                        fontSize: 12,
                        color: AppThemeColors.textSecondary(context)),
                  ),
              ],
            ),
          ),
          Text(
            isStreakSort
                ? '🔥 ${_num.format(primary)}'
                : _num.format(primary),
            style: TextStyle(
              fontWeight: FontWeight.bold,
              fontSize: 16,
              color: AppThemeColors.textPrimary(context),
            ),
          ),
          if (showFollow && !e.isMe)
            IconButton(
              visualDensity: VisualDensity.compact,
              tooltip: lb.isFriend(e.uid) ? 'Unfollow' : 'Follow',
              icon: Icon(
                lb.isFriend(e.uid) ? Icons.star : Icons.star_border,
                color: lb.isFriend(e.uid)
                    ? Colors.amber
                    : AppThemeColors.iconMuted(context),
              ),
              onPressed: () async {
                final ok = await lb.toggleFriend(e);
                if (!ok) {
                  _toast('You can follow up to '
                      '${LeaderboardProvider.maxFriends} people.');
                }
              },
            )
          else
            const SizedBox(width: 8),
        ],
      ),
    );
  }

  // ------------------------------------------------------------- search

  Widget _buildSearchField(LeaderboardProvider lb) {
    return Padding(
      padding: const EdgeInsets.fromLTRB(16, 8, 16, 4),
      child: TextField(
        controller: _searchCtrl,
        autofocus: true,
        textInputAction: TextInputAction.search,
        style: TextStyle(color: AppThemeColors.textPrimary(context)),
        decoration: InputDecoration(
          hintText: 'Search by name (min. 2 letters)',
          hintStyle: TextStyle(color: AppThemeColors.textHint(context)),
          prefixIcon: const Icon(Icons.search),
          filled: true,
          fillColor: AppThemeColors.inputFill(context),
          border: OutlineInputBorder(
            borderRadius: BorderRadius.circular(12),
            borderSide: BorderSide.none,
          ),
          contentPadding: const EdgeInsets.symmetric(vertical: 0),
        ),
        onChanged: (v) {
          setState(() {});
          _searchDebounce?.cancel();
          _searchDebounce =
              Timer(const Duration(milliseconds: 450), () => lb.search(v));
        },
        onSubmitted: (v) => lb.search(v),
      ),
    );
  }

  Widget _buildSearchResults(LeaderboardProvider lb) {
    if (lb.searching) {
      return const Center(child: CircularProgressIndicator());
    }
    if (lb.searchError != null) {
      return _emptyState('⚠️', lb.searchError!);
    }
    if (_searchCtrl.text.trim().length < 2) {
      return _emptyState('🔎', 'Type at least 2 letters of a name.');
    }
    if (lb.searchResults.isEmpty) {
      return _emptyState('🙈', 'No one found with that name.');
    }
    return ListView(
      padding: const EdgeInsets.fromLTRB(16, 8, 16, 24),
      children: [
        for (final e in lb.searchResults)
          _buildEntryTile(lb, e, showRank: false),
      ],
    );
  }

  // ------------------------------------------------------------- sheets

  InputDecoration _fieldDecoration(String label, {String? hint}) =>
      InputDecoration(
        labelText: label,
        hintText: hint,
        labelStyle: TextStyle(color: AppThemeColors.textSecondary(context)),
        hintStyle: TextStyle(color: AppThemeColors.textHint(context)),
        filled: true,
        fillColor: AppThemeColors.inputFill(context),
        border: OutlineInputBorder(
          borderRadius: BorderRadius.circular(10),
          borderSide: BorderSide.none,
        ),
      );

  Future<void> _showProfileSheet(LeaderboardProvider lb) async {
    final suggested = lb.enrolled ? lb.displayName : (await lb.suggestedName()) ?? '';
    if (!mounted) return;

    final nameCtrl = TextEditingController(text: suggested);
    var avatar = lb.enrolled ? lb.avatar : 0;
    var consent = lb.enrolled;
    final joining = !lb.enrolled;

    await showModalBottomSheet<void>(
      context: context,
      isScrollControlled: true,
      backgroundColor: AppThemeColors.surface(context),
      shape: const RoundedRectangleBorder(
        borderRadius: BorderRadius.vertical(top: Radius.circular(20)),
      ),
      builder: (ctx) {
        return StatefulBuilder(builder: (ctx, setSheet) {
          final valid = LeaderboardScoring.isValidName(nameCtrl.text);
          return Padding(
            padding: EdgeInsets.fromLTRB(
                20, 20, 20, 20 + MediaQuery.of(ctx).viewInsets.bottom),
            child: SingleChildScrollView(
              child: Column(
                mainAxisSize: MainAxisSize.min,
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    joining ? 'Join the Ummah Leaderboard' : 'My leaderboard profile',
                    style: TextStyle(
                      fontSize: 18,
                      fontWeight: FontWeight.bold,
                      color: AppThemeColors.textPrimary(ctx),
                    ),
                  ),
                  const SizedBox(height: 14),
                  TextField(
                    controller: nameCtrl,
                    maxLength: 24,
                    style: TextStyle(color: AppThemeColors.textPrimary(ctx)),
                    decoration: _fieldDecoration('Public display name',
                        hint: 'Use a nickname — not your full name'),
                    onChanged: (_) => setSheet(() {}),
                  ),
                  const SizedBox(height: 6),
                  Wrap(
                    spacing: 8,
                    runSpacing: 8,
                    children: [
                      for (var i = 0; i < leaderboardAvatars.length; i++)
                        GestureDetector(
                          onTap: () => setSheet(() => avatar = i),
                          child: Container(
                            width: 46,
                            height: 46,
                            alignment: Alignment.center,
                            decoration: BoxDecoration(
                              shape: BoxShape.circle,
                              color: AppThemeColors.panelFillStrong(ctx),
                              border: Border.all(
                                color: avatar == i
                                    ? Colors.amber
                                    : AppThemeColors.cardBorder(ctx),
                                width: avatar == i ? 2.5 : 1,
                              ),
                            ),
                            child: Text(leaderboardAvatars[i],
                                style: const TextStyle(fontSize: 22)),
                          ),
                        ),
                    ],
                  ),
                  const SizedBox(height: 14),
                  if (joining) ...[
                    CheckboxListTile(
                      value: consent,
                      onChanged: (v) => setSheet(() => consent = v ?? false),
                      activeColor: Colors.green,
                      controlAffinity: ListTileControlAffinity.leading,
                      contentPadding: EdgeInsets.zero,
                      dense: true,
                      title: Text(
                        'I agree to publicly share my display name, avatar, '
                        'points and streak counts. Anyone using the app can '
                        'see and search them. I can leave at any time and '
                        'my data will be deleted.',
                        style: TextStyle(
                            fontSize: 12.5,
                            color: AppThemeColors.textSecondary(ctx)),
                      ),
                    ),
                    const SizedBox(height: 6),
                  ],
                  SizedBox(
                    width: double.infinity,
                    child: ElevatedButton(
                      onPressed: (!valid || !consent)
                          ? null
                          : () async {
                              Navigator.pop(ctx);
                              if (joining) {
                                await lb.join(
                                    name: nameCtrl.text, avatar: avatar);
                                _toast('Welcome to the leaderboard!');
                              } else {
                                await lb.updateProfile(
                                    name: nameCtrl.text, avatar: avatar);
                                _toast('Profile updated');
                              }
                            },
                      style: ElevatedButton.styleFrom(
                        backgroundColor: Colors.green[700],
                        foregroundColor: Colors.white,
                        padding: const EdgeInsets.symmetric(vertical: 14),
                      ),
                      child: Text(joining ? 'Join' : 'Save'),
                    ),
                  ),
                  if (!joining) ...[
                    const SizedBox(height: 8),
                    SizedBox(
                      width: double.infinity,
                      child: TextButton.icon(
                        onPressed: () async {
                          final ok = await _confirmLeave(ctx);
                          if (ok != true) return;
                          if (ctx.mounted) Navigator.pop(ctx);
                          await lb.leave();
                          _toast('You left the leaderboard. Your published '
                              'data is being deleted.');
                        },
                        icon: const Icon(Icons.logout, color: Colors.redAccent),
                        label: const Text('Leave & delete my published data',
                            style: TextStyle(color: Colors.redAccent)),
                      ),
                    ),
                  ],
                ],
              ),
            ),
          );
        });
      },
    );
    nameCtrl.dispose();
  }

  Future<bool?> _confirmLeave(BuildContext ctx) {
    return showDialog<bool>(
      context: ctx,
      builder: (c) => AlertDialog(
        title: const Text('Leave leaderboard?'),
        content: const Text(
          'Your profile and weekly/monthly entries will be deleted from the '
          'leaderboard. Your ibadat history on this device is not touched. '
          'If you are offline, deletion happens as soon as you reconnect.',
        ),
        actions: [
          TextButton(
              onPressed: () => Navigator.pop(c, false),
              child: const Text('Cancel')),
          TextButton(
              onPressed: () => Navigator.pop(c, true),
              child: const Text('Leave',
                  style: TextStyle(color: Colors.redAccent))),
        ],
      ),
    );
  }

  Future<void> _showConnectSheet(LeaderboardProvider lb) async {
    final cfg = await lb.currentConfig();
    if (!mounted) return;
    final projectCtrl = TextEditingController(text: cfg?.projectId ?? '');
    final keyCtrl = TextEditingController(text: cfg?.apiKey ?? '');
    String? err;

    await showModalBottomSheet<void>(
      context: context,
      isScrollControlled: true,
      backgroundColor: AppThemeColors.surface(context),
      shape: const RoundedRectangleBorder(
        borderRadius: BorderRadius.vertical(top: Radius.circular(20)),
      ),
      builder: (ctx) {
        return StatefulBuilder(builder: (ctx, setSheet) {
          return Padding(
            padding: EdgeInsets.fromLTRB(
                20, 20, 20, 20 + MediaQuery.of(ctx).viewInsets.bottom),
            child: SingleChildScrollView(
              child: Column(
                mainAxisSize: MainAxisSize.min,
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    'Firebase connection',
                    style: TextStyle(
                      fontSize: 18,
                      fontWeight: FontWeight.bold,
                      color: AppThemeColors.textPrimary(ctx),
                    ),
                  ),
                  const SizedBox(height: 6),
                  Text(
                    'Both values are public identifiers (not secrets): '
                    'security comes from the Firestore rules you publish. '
                    'See docs/LEADERBOARD_SETUP.md.',
                    style: TextStyle(
                        fontSize: 12.5,
                        color: AppThemeColors.textSecondary(ctx)),
                  ),
                  const SizedBox(height: 12),
                  TextField(
                    controller: projectCtrl,
                    autocorrect: false,
                    style: TextStyle(color: AppThemeColors.textPrimary(ctx)),
                    decoration: _fieldDecoration('Project ID',
                        hint: 'e.g. salahstreaks-ummah'),
                  ),
                  const SizedBox(height: 10),
                  TextField(
                    controller: keyCtrl,
                    autocorrect: false,
                    style: TextStyle(color: AppThemeColors.textPrimary(ctx)),
                    decoration: _fieldDecoration('Web API key',
                        hint: 'AIza…'),
                  ),
                  if (err != null) ...[
                    const SizedBox(height: 8),
                    Text(err!,
                        style: const TextStyle(color: Colors.redAccent)),
                  ],
                  const SizedBox(height: 12),
                  SizedBox(
                    width: double.infinity,
                    child: ElevatedButton(
                      onPressed: () async {
                        try {
                          await lb.saveConfig(
                              projectCtrl.text, keyCtrl.text);
                          if (ctx.mounted) Navigator.pop(ctx);
                          _toast('Connected');
                        } on FormatException {
                          setSheet(() => err =
                              'Check the Project ID and Web API key.');
                        }
                      },
                      style: ElevatedButton.styleFrom(
                        backgroundColor: Colors.green[700],
                        foregroundColor: Colors.white,
                        padding: const EdgeInsets.symmetric(vertical: 14),
                      ),
                      child: const Text('Save & connect'),
                    ),
                  ),
                ],
              ),
            ),
          );
        });
      },
    );
    projectCtrl.dispose();
    keyCtrl.dispose();
  }

  void _showInfoDialog() {
    Widget bullet(String t) => Padding(
          padding: const EdgeInsets.only(bottom: 6),
          child: Row(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              const Text('•  '),
              Expanded(child: Text(t, style: const TextStyle(height: 1.35))),
            ],
          ),
        );

    showDialog<void>(
      context: context,
      builder: (ctx) => AlertDialog(
        title: const Text('Scoring & privacy'),
        content: SingleChildScrollView(
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            mainAxisSize: MainAxisSize.min,
            children: [
              const Text('How points are counted',
                  style: TextStyle(fontWeight: FontWeight.bold)),
              const SizedBox(height: 6),
              bullet('Salah 10 per prayer (max 50/day)'),
              bullet('Sawm 50 Fardh / 25 Nafl'),
              bullet("Qiyyam 5 per rak'ah (max 200/day)"),
              bullet('Quran 0.5 per verse (max 300/day)'),
              bullet('Sadaqat 1 per unit (max 50/day, so everyone competes fairly)'),
              bullet('Adhkar 0.5 per repetition (max 100/day)'),
              const SizedBox(height: 4),
              Text(
                'Leaderboard points are calculated from your logs with these '
                'daily caps, so they can differ from the total on your home '
                'screen (which has no caps and includes achievement bonuses).',
                style: TextStyle(
                    fontSize: 12.5,
                    color: AppThemeColors.textSecondary(ctx)),
              ),
              const SizedBox(height: 12),
              const Text('Weekly & monthly',
                  style: TextStyle(fontWeight: FontWeight.bold)),
              const SizedBox(height: 6),
              bullet('Weeks run Monday–Sunday; months follow the calendar, '
                  'in your device’s local time.'),
              const SizedBox(height: 12),
              const Text('What is shared (only if you join)',
                  style: TextStyle(fontWeight: FontWeight.bold)),
              const SizedBox(height: 6),
              bullet('Display name, emoji avatar'),
              bullet('Lifetime / weekly / monthly points'),
              bullet('Current streak counts per ibadah'),
              bullet('Never shared: logs, journal notes, amounts, location, '
                  'prayer times, phone number or contacts.'),
              const SizedBox(height: 4),
              Text(
                'You are identified by a random anonymous ID, not an account. '
                'Leave from your profile to delete your published data.',
                style: TextStyle(
                    fontSize: 12.5,
                    color: AppThemeColors.textSecondary(ctx)),
              ),
            ],
          ),
        ),
        actions: [
          TextButton(
              onPressed: () => Navigator.pop(ctx), child: const Text('Close')),
        ],
      ),
    );
  }
}
