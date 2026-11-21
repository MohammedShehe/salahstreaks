import 'dart:convert';
import 'package:flutter_test/flutter_test.dart';
import 'package:http/http.dart' as http;
import 'package:http/testing.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:salahstreaks/models/leaderboard_models.dart';
import 'package:salahstreaks/services/leaderboard_service.dart';

const _cfg = {
  'projectId': 'demo-proj',
  'apiKey': 'AIzaSyFakeKeyFakeKeyFakeKey123',
};

const _snap = ProfileSnapshot(
  displayName: 'Ali',
  avatar: 2,
  totalPoints: 170,
  totalStreak: 4,
  salahStreak: 3,
  sawmStreak: 0,
  qiyyamStreak: 0,
  quranStreak: 1,
  sadaqatStreak: 0,
  weekId: 'w2026-47',
  weeklyPoints: 70,
  weeklyActiveDays: 2,
  monthId: 'm2026-11',
  monthlyPoints: 120,
  monthlyActiveDays: 3,
);

http.Response _json(Object body, [int status = 200]) => http.Response(
    json.encode(body), status,
    headers: {'content-type': 'application/json; charset=utf-8'});

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  setUp(() {
    SharedPreferences.setMockInitialValues({'lb_config_v1': json.encode(_cfg)});
  });

  test('publish signs in anonymously then commits 3 writes atomically',
      () async {
    final calls = <http.Request>[];
    final svc = LeaderboardService(client: MockClient((req) async {
      calls.add(req as http.Request);
      if (req.url.path.contains('accounts:signUp')) {
        return _json({
          'idToken': 'tok',
          'refreshToken': 'ref',
          'localId': 'uid123',
          'expiresIn': '3600',
        });
      }
      return _json({});
    }));

    final periods = await svc.publish(_snap);
    expect(periods, ['w2026-47', 'm2026-11']);

    final commit = calls.firstWhere((c) => c.url.path.endsWith(':commit'));
    expect(commit.headers['Authorization'], 'Bearer tok');
    final writes = (json.decode(commit.body) as Map)['writes'] as List;
    expect(writes.length, 3);
    final names = writes.map((w) => w['update']['name'] as String).toList();
    expect(names[0], endsWith('/documents/profiles/uid123'));
    expect(names[1], endsWith('/documents/periods/w2026-47/entries/uid123'));
    expect(names[2], endsWith('/documents/periods/m2026-11/entries/uid123'));
    final f = writes[0]['update']['fields'] as Map;
    expect(f['totalPoints']['integerValue'], '170');
    expect(f['nameLower']['stringValue'], 'ali');
    expect(writes[0]['updateTransforms'][0]['setToServerValue'],
        'REQUEST_TIME');
    // Only the whitelisted fields are ever sent.
    expect(f.keys.toSet(), {
      'displayName', 'nameLower', 'avatar', 'totalPoints', 'totalStreak',
      'salahStreak', 'sawmStreak', 'qiyyamStreak', 'quranStreak',
      'sadaqatStreak',
    });
  });

  test('fetchTop parses ranked documents and marks me', () async {
    final svc = LeaderboardService(client: MockClient((req) async {
      if (req.url.path.contains('accounts:signUp')) {
        return _json({
          'idToken': 'tok',
          'refreshToken': 'ref',
          'localId': 'me1',
          'expiresIn': '3600',
        });
      }
      return _json([
        {
          'document': {
            'name': 'projects/demo-proj/databases/(default)/documents/profiles/abc',
            'fields': {
              'displayName': {'stringValue': 'Fatima'},
              'avatar': {'integerValue': '3'},
              'totalPoints': {'integerValue': '900'},
              'totalStreak': {'integerValue': '12'},
            }
          }
        },
        {
          'document': {
            'name': 'projects/demo-proj/databases/(default)/documents/profiles/me1',
            'fields': {
              'displayName': {'stringValue': 'Ali'},
              'avatar': {'integerValue': '2'},
              'totalPoints': {'integerValue': '500'},
              'totalStreak': {'integerValue': '4'},
            }
          }
        },
        {'readTime': '2026-11-21T00:00:00Z'},
      ]);
    }));

    final list = await svc.fetchTop(
        period: LeaderboardPeriod.global, periodId: null);
    expect(list.length, 2);
    expect(list[0].displayName, 'Fatima');
    expect(list[0].rank, 1);
    expect(list[0].points, 900);
    expect(list[1].isMe, isTrue);
    expect(list[1].rank, 2);
  });

  test('no connection becomes a retryable network exception', () async {
    final svc = LeaderboardService(
        client: MockClient((req) async => throw Exception('offline')));
    expect(() => svc.publish(_snap),
        throwsA(isA<LeaderboardNetworkException>()));
  });

  test('server errors surface as API exceptions with the status', () async {
    final svc = LeaderboardService(client: MockClient((req) async {
      if (req.url.path.contains('accounts:signUp')) {
        return _json({
          'idToken': 'tok',
          'refreshToken': 'ref',
          'localId': 'u',
          'expiresIn': '3600',
        });
      }
      return _json({
        'error': {'code': 403, 'message': 'Missing or insufficient permissions.'}
      }, 403);
    }));
    try {
      await svc.publish(_snap);
      fail('should throw');
    } on LeaderboardApiException catch (e) {
      expect(e.isPermissionDenied, isTrue);
    }
  });

  test('not configured throws before any network call', () async {
    SharedPreferences.setMockInitialValues({});
    var called = false;
    final svc = LeaderboardService(client: MockClient((req) async {
      called = true;
      return _json({});
    }));
    expect(() => svc.publish(_snap), throwsA(isA<LeaderboardNotConfigured>()));
    expect(called, isFalse);
  });
}
