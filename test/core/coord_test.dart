import 'package:couple_locator/core/geo/coord.dart';
import 'package:flutter_test/flutter_test.dart';

void main() {
  test('WGS84→GCJ02 北京天安门偏移约 500m 量级且在预期值附近', () {
    // 天安门 WGS84 (39.9087, 116.3975)；GCJ-02 约 (39.9100, 116.4038)
    final g = CoordConverter.wgs84ToGcj02(39.9087, 116.3975);
    expect(g.lat, closeTo(39.9100, 0.0015));
    expect(g.lng, closeTo(116.4038, 0.0015));
    final off = haversineMeters(39.9087, 116.3975, g.lat, g.lng);
    expect(off, inInclusiveRange(300, 800));
  });

  test('往返转换误差 < 1m', () {
    for (final p in [(39.9087, 116.3975), (31.2304, 121.4737), (23.1291, 113.2644)]) {
      final g = CoordConverter.wgs84ToGcj02(p.$1, p.$2);
      final w = CoordConverter.gcj02ToWgs84(g.lat, g.lng);
      expect(haversineMeters(p.$1, p.$2, w.lat, w.lng), lessThan(1.0));
    }
  });

  test('境外不偏移', () {
    final g = CoordConverter.wgs84ToGcj02(35.6762, 139.6503);
    expect(g.lat, 35.6762);
    expect(g.lng, 139.6503);
  });

  test('haversine: 赤道 1 度经度约 111.19km', () {
    expect(haversineMeters(0, 0, 0, 1), closeTo(111195, 200));
  });

  test('LatLngD toString 不泄露坐标', () {
    expect(const LatLngD(1.23, 4.56).toString().contains('1.23'), isFalse);
  });
}
