import 'dart:math' as math;

/// WGS-84 <-> GCJ-02 坐标转换（高德使用 GCJ-02）。
/// 算法为公开的 "火星坐标" 近似算法，精度约 1~2 米。
class LatLngD {
  const LatLngD(this.lat, this.lng);
  final double lat;
  final double lng;
  @override
  bool operator ==(Object o) => o is LatLngD && o.lat == lat && o.lng == lng;
  @override
  int get hashCode => Object.hash(lat, lng);
  @override
  String toString() => 'LatLngD(***)'; // 日志里不打印明文坐标
}

abstract final class CoordConverter {
  static const double _a = 6378245.0;
  static const double _ee = 0.00669342162296594323;

  /// 是否在中国大陆范围外（范围外不偏移）。
  static bool outOfChina(double lat, double lng) =>
      lng < 72.004 || lng > 137.8347 || lat < 0.8293 || lat > 55.8271;

  static double _tLat(double x, double y) {
    var r = -100.0 + 2.0 * x + 3.0 * y + 0.2 * y * y + 0.1 * x * y + 0.2 * math.sqrt(x.abs());
    r += (20.0 * math.sin(6.0 * x * math.pi) + 20.0 * math.sin(2.0 * x * math.pi)) * 2.0 / 3.0;
    r += (20.0 * math.sin(y * math.pi) + 40.0 * math.sin(y / 3.0 * math.pi)) * 2.0 / 3.0;
    r += (160.0 * math.sin(y / 12.0 * math.pi) + 320 * math.sin(y * math.pi / 30.0)) * 2.0 / 3.0;
    return r;
  }

  static double _tLng(double x, double y) {
    var r = 300.0 + x + 2.0 * y + 0.1 * x * x + 0.1 * x * y + 0.1 * math.sqrt(x.abs());
    r += (20.0 * math.sin(6.0 * x * math.pi) + 20.0 * math.sin(2.0 * x * math.pi)) * 2.0 / 3.0;
    r += (20.0 * math.sin(x * math.pi) + 40.0 * math.sin(x / 3.0 * math.pi)) * 2.0 / 3.0;
    r += (150.0 * math.sin(x / 12.0 * math.pi) + 300.0 * math.sin(x / 30.0 * math.pi)) * 2.0 / 3.0;
    return r;
  }

  static LatLngD wgs84ToGcj02(double lat, double lng) {
    if (outOfChina(lat, lng)) return LatLngD(lat, lng);
    var dLat = _tLat(lng - 105.0, lat - 35.0);
    var dLng = _tLng(lng - 105.0, lat - 35.0);
    final radLat = lat / 180.0 * math.pi;
    var magic = math.sin(radLat);
    magic = 1 - _ee * magic * magic;
    final sqrtMagic = math.sqrt(magic);
    dLat = (dLat * 180.0) / ((_a * (1 - _ee)) / (magic * sqrtMagic) * math.pi);
    dLng = (dLng * 180.0) / (_a / sqrtMagic * math.cos(radLat) * math.pi);
    return LatLngD(lat + dLat, lng + dLng);
  }

  /// 迭代反解（误差 < 0.5 米）。
  static LatLngD gcj02ToWgs84(double lat, double lng) {
    if (outOfChina(lat, lng)) return LatLngD(lat, lng);
    var wLat = lat, wLng = lng;
    for (var i = 0; i < 6; i++) {
      final g = wgs84ToGcj02(wLat, wLng);
      wLat -= g.lat - lat;
      wLng -= g.lng - lng;
    }
    return LatLngD(wLat, wLng);
  }
}

/// Haversine 距离（米）。
double haversineMeters(double lat1, double lng1, double lat2, double lng2) {
  const r = 6371008.8;
  final p1 = lat1 * math.pi / 180, p2 = lat2 * math.pi / 180;
  final dp = (lat2 - lat1) * math.pi / 180;
  final dl = (lng2 - lng1) * math.pi / 180;
  final h = math.pow(math.sin(dp / 2), 2) + math.cos(p1) * math.cos(p2) * math.pow(math.sin(dl / 2), 2);
  return 2 * r * math.asin(math.min(1, math.sqrt(h)));
}
