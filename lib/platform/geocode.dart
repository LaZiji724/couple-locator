import 'dart:convert';

import 'package:http/http.dart' as http;

import '../core/config/app_config.dart';
import '../core/geo/coord.dart';

/// 高德逆地理编码（REST，需 Web 服务 Key）。输入 WGS-84，内部转 GCJ-02。
/// 结果按约 100m 网格缓存，避免重复请求；坐标不写日志。
class Geocoder {
  Geocoder._();
  static final instance = Geocoder._();
  final _cache = <String, String>{};

  Future<String> name(double wgsLat, double wgsLng) async {
    final key = '${(wgsLat * 1000).round()},${(wgsLng * 1000).round()}';
    final hit = _cache[key];
    if (hit != null) return hit;
    if (AppConfig.amapWebKey.isEmpty) return '某个地方';
    try {
      final g = CoordConverter.wgs84ToGcj02(wgsLat, wgsLng);
      final uri = Uri.https('restapi.amap.com', '/v3/geocode/regeo', {
        'key': AppConfig.amapWebKey,
        'location': '${g.lng.toStringAsFixed(6)},${g.lat.toStringAsFixed(6)}',
        'extensions': 'base',
      });
      final res = await http.get(uri).timeout(const Duration(seconds: 8));
      final j = jsonDecode(res.body) as Map<String, dynamic>;
      final r = j['regeocode'] as Map<String, dynamic>?;
      final comp = r?['addressComponent'] as Map<String, dynamic>?;
      final sn = comp?['streetNumber'] as Map<String, dynamic>?;
      String s(Object? v) => (v is String) ? v : '';
      var out = s(r?['formatted_address']);
      if (out.isEmpty) out = '${s(comp?['district'])}${s(sn?['street'])}${s(sn?['number'])}';
      if (out.isEmpty) out = '某个地方';
      // 去掉省市前缀，更简短
      out = out.replaceFirst(RegExp('^${s(comp?['province'])}'), '');
      _cache[key] = out;
      return out;
    } catch (_) {
      return '某个地方';
    }
  }
}
