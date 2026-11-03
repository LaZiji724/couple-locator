import 'package:couple_locator/domain/location/track_tools.dart';
import 'package:couple_locator/domain/models/loc_point.dart';
import 'package:flutter_test/flutter_test.dart';

LocPoint p(int min, double lat, double lng, {double acc = 5, int sec = 0}) =>
    LocPoint(ts: DateTime(2026, 11, 3, 8, 0).add(Duration(minutes: min, seconds: sec)), lat: lat, lng: lng, accuracy: acc);

void main() {
  group('Douglas-Peucker', () {
    test('直线中间点被抽掉', () {
      final pts = [for (var i = 0; i < 20; i++) p(i, 30 + i * 0.0001, 120)];
      final r = douglasPeucker(pts, 5);
      expect(r.length, 2);
    });
    test('拐角被保留', () {
      final pts = [
        for (var i = 0; i <= 10; i++) p(i, 30, 120 + i * 0.001),
        for (var i = 1; i <= 10; i++) p(10 + i, 30 + i * 0.001, 120.01),
      ];
      final r = douglasPeucker(pts, 10);
      expect(r.length, 3);
      expect(r[1].lng, closeTo(120.01, 1e-9));
      expect(r[1].lat, closeTo(30, 1e-9));
    });
    test('点数 <3 原样返回', () {
      expect(douglasPeucker([p(0, 1, 1)], 5).length, 1);
    });
  });

  group('停留点', () {
    test('100m 内超过 10 分钟 → 一次停留', () {
      final pts = [for (var i = 0; i <= 12; i++) p(i, 30.0 + (i % 2) * 0.0002, 120.0)];
      final s = detectStayPoints(pts);
      expect(s.length, 1);
      expect(s.first.duration.inMinutes, 12);
    });
    test('不足 10 分钟不算', () {
      final pts = [for (var i = 0; i <= 8; i++) p(i, 30.0, 120.0)];
      expect(detectStayPoints(pts), isEmpty);
    });
    test('移动中不产生停留；停留后离开再停留 = 两次', () {
      final pts = <LocPoint>[
        for (var i = 0; i <= 11; i++) p(i, 30.0, 120.0),
        for (var i = 1; i <= 5; i++) p(11 + i, 30.0 + i * 0.01, 120.0),
        for (var i = 0; i <= 11; i++) p(17 + i, 30.06, 120.0),
      ];
      final s = detectStayPoints(pts);
      expect(s.length, 2);
    });
  });

  group('噪声过滤', () {
    test('精度 >100m 的点被丢弃', () {
      final r = filterNoisy([p(0, 30, 120), p(1, 30, 120, acc: 150), p(2, 30, 120)]);
      expect(r.length, 2);
    });
    test('漂移点（1 秒跳 10km）被丢弃', () {
      final r = filterNoisy([p(0, 30, 120), p(0, 30.1, 120, sec: 1), p(1, 30.0001, 120)]);
      expect(r.length, 2);
    });
  });

  test('总距离与重合时长', () {
    final a = [for (var i = 0; i <= 20; i++) p(i, 30, 120 + i * 0.0001)];
    // B 前 10 分钟与 A 同位置，后 10 分钟远离 5km
    final b = [
      for (var i = 0; i <= 10; i++) p(i, 30.0003, 120 + i * 0.0001),
      for (var i = 11; i <= 20; i++) p(i, 30.05, 120),
    ];
    expect(totalDistance(a), closeTo(20 * 0.0001 * 96300, 20));
    final t = togetherDuration(a, b);
    expect(t.inMinutes, inInclusiveRange(9, 11));
  });
}
