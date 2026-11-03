import 'package:couple_locator/data/remote/backend.dart';
import 'package:couple_locator/data/repo/settings_store.dart';
import 'package:couple_locator/platform/lost_checker.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:shared_preferences/shared_preferences.dart';

class FakeBackend extends Fake implements Backend {
  FakeBackend(this.presence);
  PresenceDto? presence;
  @override
  String? get userId => 'me';
  @override
  Future<CoupleDto?> getMyCouple() async => const CoupleDto(id: 'c', userA: 'me', userB: 'ta');
  @override
  Future<PresenceDto?> getPresence(String userId) async => presence;
  @override
  Future<ProfileDto?> getProfile(String userId) async => const ProfileDto(id: 'ta', nickname: '小宝');
}

void main() {
  final now = DateTime(2026, 11, 3, 12);
  Future<(LostChecker, List<String>, FakeBackend)> make(PresenceDto? p, {int lost = 30}) async {
    SharedPreferences.setMockInitialValues({'lost_minutes': lost});
    final s = await SettingsStore.open();
    final b = FakeBackend(p);
    final sent = <String>[];
    return (LostChecker(backend: b, settings: s, notify: (t, body) async => sent.add('$t|$body')), sent, b);
  }

  test('超过阈值且未暂停 → 通知一次（同一段失联不重复）', () async {
    final (c, sent, _) = await make(PresenceDto(userId: 'ta', heartbeatAt: now.subtract(const Duration(minutes: 45)), paused: false));
    expect(await c.check(now: now), isTrue);
    expect(sent.single, contains('45 分钟'));
    expect(await c.check(now: now.add(const Duration(minutes: 5))), isFalse);
    expect(sent.length, 1);
  });

  test('未超阈值 → 不通知', () async {
    final (c, sent, _) = await make(PresenceDto(userId: 'ta', heartbeatAt: now.subtract(const Duration(minutes: 10)), paused: false));
    expect(await c.check(now: now), isFalse);
    expect(sent, isEmpty);
  });

  test('对方暂停共享 → 不算失联', () async {
    final (c, sent, _) = await make(PresenceDto(userId: 'ta', heartbeatAt: now.subtract(const Duration(hours: 3)), paused: true, pausedUntil: now.add(const Duration(hours: 1))));
    expect(await c.check(now: now), isFalse);
    expect(sent, isEmpty);
  });

  test('暂停已到期且长时间无心跳 → 通知；阈值可调', () async {
    final (c, sent, _) = await make(PresenceDto(userId: 'ta', heartbeatAt: now.subtract(const Duration(minutes: 70)), paused: true, pausedUntil: now.subtract(const Duration(minutes: 5))), lost: 60);
    expect(await c.check(now: now), isTrue);
    expect(sent.length, 1);
  });
}
