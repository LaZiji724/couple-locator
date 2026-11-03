import 'dart:math' as math;

import '../../core/geo/coord.dart';
import '../models/loc_point.dart';

/// Douglas-Peucker 轨迹抽稀。epsilonMeters 为允许的垂直偏差（米）。
List<LocPoint> douglasPeucker(List<LocPoint> pts, double epsilonMeters) {
  if (pts.length < 3) return List.of(pts);
  final keep = List<bool>.filled(pts.length, false);
  keep[0] = keep[pts.length - 1] = true;
  final stack = <(int, int)>[(0, pts.length - 1)];
  while (stack.isNotEmpty) {
    final (s, e) = stack.removeLast();
    var maxD = 0.0;
    var idx = -1;
    for (var i = s + 1; i < e; i++) {
      final d = _perpDist(pts[i], pts[s], pts[e]);
      if (d > maxD) {
        maxD = d;
        idx = i;
      }
    }
    if (idx != -1 && maxD > epsilonMeters) {
      keep[idx] = true;
      stack.add((s, idx));
      stack.add((idx, e));
    }
  }
  return [for (var i = 0; i < pts.length; i++) if (keep[i]) pts[i]];
}

/// 点到线段的距离（米），用局部等距投影。
double _perpDist(LocPoint p, LocPoint a, LocPoint b) {
  final lat0 = a.lat * math.pi / 180;
  const mPerDeg = 111320.0;
  double x(LocPoint q) => (q.lng - a.lng) * mPerDeg * math.cos(lat0);
  double y(LocPoint q) => (q.lat - a.lat) * mPerDeg;
  final px = x(p), py = y(p), bx = x(b), by = y(b);
  final len2 = bx * bx + by * by;
  if (len2 == 0) return math.sqrt(px * px + py * py);
  final t = ((px * bx + py * by) / len2).clamp(0.0, 1.0);
  final dx = px - t * bx, dy = py - t * by;
  return math.sqrt(dx * dx + dy * dy);
}

/// 过滤低精度点（>100m）与漂移点（相邻速度不合理，默认 > 70 m/s ≈ 250km/h）。
List<LocPoint> filterNoisy(List<LocPoint> pts, {double maxAccuracy = 100, double maxSpeed = 70}) {
  final out = <LocPoint>[];
  for (final p in pts) {
    if (p.accuracy > maxAccuracy) continue;
    if (out.isNotEmpty) {
      final prev = out.last;
      final dt = p.ts.difference(prev.ts).inMilliseconds / 1000;
      if (dt > 0) {
        final v = haversineMeters(prev.lat, prev.lng, p.lat, p.lng) / dt;
        if (v > maxSpeed) continue;
      }
    }
    out.add(p);
  }
  return out;
}

/// 停留点。
class StayPoint {
  const StayPoint({
    required this.lat,
    required this.lng,
    required this.start,
    required this.end,
    required this.pointCount,
  });
  final double lat;
  final double lng;
  final DateTime start;
  final DateTime end;
  final int pointCount;
  Duration get duration => end.difference(start);
}

/// 停留点识别：连续位置在 [radiusMeters] 内且持续超过 [minDuration]。
/// 采用经典的锚点法：以锚点为中心，向后扩展直到某点离锚点超过半径。
List<StayPoint> detectStayPoints(
  List<LocPoint> pts, {
  double radiusMeters = 100,
  Duration minDuration = const Duration(minutes: 10),
}) {
  final sorted = List.of(pts)..sort((a, b) => a.ts.compareTo(b.ts));
  final out = <StayPoint>[];
  var i = 0;
  while (i < sorted.length) {
    var j = i + 1;
    while (j < sorted.length &&
        haversineMeters(sorted[i].lat, sorted[i].lng, sorted[j].lat, sorted[j].lng) <= radiusMeters) {
      j++;
    }
    // 窗口 [i, j-1]
    final last = j - 1;
    if (last > i && sorted[last].ts.difference(sorted[i].ts) >= minDuration) {
      var sLat = 0.0, sLng = 0.0;
      for (var k = i; k <= last; k++) {
        sLat += sorted[k].lat;
        sLng += sorted[k].lng;
      }
      final n = last - i + 1;
      out.add(StayPoint(
        lat: sLat / n,
        lng: sLng / n,
        start: sorted[i].ts,
        end: sorted[last].ts,
        pointCount: n,
      ));
      i = j;
    } else {
      i++;
    }
  }
  return out;
}

/// 总行走距离（米），已跳过相邻 >70m/s 的异常跳变。
double totalDistance(List<LocPoint> pts) {
  var d = 0.0;
  for (var i = 1; i < pts.length; i++) {
    final dt = pts[i].ts.difference(pts[i - 1].ts).inMilliseconds / 1000;
    final seg = haversineMeters(pts[i - 1].lat, pts[i - 1].lng, pts[i].lat, pts[i].lng);
    if (dt > 0 && seg / dt > 70) continue;
    d += seg;
  }
  return d;
}

/// 两人重合时长：对 A 的每个相邻点段，在 B 轨迹上线性插值，距离 < threshold 的时间累加。
Duration togetherDuration(
  List<LocPoint> a,
  List<LocPoint> b, {
  double thresholdMeters = 100,
  Duration maxGap = const Duration(minutes: 10),
}) {
  if (a.length < 2 || b.length < 2) return Duration.zero;
  final sb = List.of(b)..sort((x, y) => x.ts.compareTo(y.ts));
  final sa = List.of(a)..sort((x, y) => x.ts.compareTo(y.ts));
  LocPoint? at(DateTime t) {
    if (t.isBefore(sb.first.ts) || t.isAfter(sb.last.ts)) return null;
    var lo = 0, hi = sb.length - 1;
    while (hi - lo > 1) {
      final mid = (lo + hi) >> 1;
      if (sb[mid].ts.isAfter(t)) {
        hi = mid;
      } else {
        lo = mid;
      }
    }
    final p0 = sb[lo], p1 = sb[hi];
    if (p1.ts.difference(p0.ts) > maxGap) return null;
    final span = p1.ts.difference(p0.ts).inMilliseconds;
    final f = span == 0 ? 0.0 : t.difference(p0.ts).inMilliseconds / span;
    return LocPoint(
      ts: t,
      lat: p0.lat + (p1.lat - p0.lat) * f,
      lng: p0.lng + (p1.lng - p0.lng) * f,
    );
  }

  var total = Duration.zero;
  for (var i = 1; i < sa.length; i++) {
    final gap = sa[i].ts.difference(sa[i - 1].ts);
    if (gap > maxGap || gap.isNegative) continue;
    final mid = sa[i - 1].ts.add(gap ~/ 2);
    final pb = at(mid);
    if (pb == null) continue;
    final ma = LocPoint(
      ts: mid,
      lat: (sa[i - 1].lat + sa[i].lat) / 2,
      lng: (sa[i - 1].lng + sa[i].lng) / 2,
    );
    if (haversineMeters(ma.lat, ma.lng, pb.lat, pb.lng) < thresholdMeters) total += gap;
  }
  return total;
}
