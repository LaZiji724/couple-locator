import 'package:couple_locator/domain/models/loc_point.dart';
import 'package:couple_locator/domain/stats/stats_calc.dart';
import 'package:flutter_test/flutter_test.dart';

LocPoint p(DateTime base, int min, double lat, double lng) => LocPoint(ts: base.add(Duration(minutes: min)), lat: lat, lng: lng, accuracy: 5);

void main() {
  test('周统计：按天距离、总和、最久停留、重合时长', () {
    final today = DateTime(2026, 11, 3);
    final base = DateTime(2026, 11, 3, 9);
    // 我：停留 15 分钟，再向东走 1km（约 0.0105°）
    final mine = [
      for (var i = 0; i <= 15; i++) p(base, i, 30.0, 120.0),
      for (var i = 1; i <= 10; i++) p(base, 15 + i, 30.0, 120.0 + i * 0.00105),
    ];
    // TA：全程在我附近 50m 内
    final ta = [for (var i = 0; i <= 25; i++) p(base, i, 30.0004, 120.0 + (i <= 15 ? 0 : (i - 15) * 0.00105))];
    final r = computeStats(mine: mine, partner: ta, today: today, days: 7);
    expect(r.perDayMine.length, 7);
    expect(r.perDayMine.last.meters, closeTo(1000, 60));
    expect(r.perDayMine.first.meters, 0);
    expect(r.totalMine, closeTo(1000, 60));
    expect(r.longestStayMine, isNotNull);
    expect(r.longestStayMine!.duration.inMinutes, greaterThanOrEqualTo(15));
    expect(r.together.inMinutes, inInclusiveRange(22, 26));
  });
}
