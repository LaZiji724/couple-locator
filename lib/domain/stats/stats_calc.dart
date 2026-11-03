import '../location/track_tools.dart';
import '../models/loc_point.dart';

class DayDistance {
  const DayDistance(this.day, this.meters);
  final DateTime day;
  final double meters;
}

class StatsResult {
  const StatsResult({required this.perDayMine, required this.perDayPartner, required this.totalMine, required this.totalPartner, required this.together, this.longestStayMine, this.longestStayPartner});
  final List<DayDistance> perDayMine;
  final List<DayDistance> perDayPartner;
  final double totalMine;
  final double totalPartner;
  final Duration together;
  final StayPoint? longestStayMine;
  final StayPoint? longestStayPartner;
}

DateTime _d(DateTime t) => DateTime(t.year, t.month, t.day);

/// 纯函数：由两人在 [days] 天内的点计算统计。
StatsResult computeStats({required List<LocPoint> mine, required List<LocPoint> partner, required DateTime today, required int days}) {
  List<DayDistance> perDay(List<LocPoint> pts) {
    final by = <DateTime, List<LocPoint>>{};
    for (final p in filterNoisy(pts)) {
      by.putIfAbsent(_d(p.ts), () => []).add(p);
    }
    return [
      for (var i = days - 1; i >= 0; i--)
        () {
          final day = _d(today).subtract(Duration(days: i));
          final l = (by[day] ?? [])..sort((a, b) => a.ts.compareTo(b.ts));
          return DayDistance(day, totalDistance(l));
        }()
    ];
  }

  StayPoint? longest(List<LocPoint> pts) {
    final stays = detectStayPoints(filterNoisy(pts));
    if (stays.isEmpty) return null;
    stays.sort((a, b) => b.duration.compareTo(a.duration));
    return stays.first;
  }

  final a = perDay(mine), b = perDay(partner);
  return StatsResult(
    perDayMine: a,
    perDayPartner: b,
    totalMine: a.fold(0.0, (s, e) => s + e.meters),
    totalPartner: b.fold(0.0, (s, e) => s + e.meters),
    together: togetherDuration(filterNoisy(mine), filterNoisy(partner)),
    longestStayMine: longest(mine),
    longestStayPartner: longest(partner),
  );
}
