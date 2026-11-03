/// 解密后的位置点（坐标统一存 WGS-84，显示时转 GCJ-02）。
class LocPoint {
  const LocPoint({
    required this.ts,
    required this.lat,
    required this.lng,
    this.accuracy = 0,
    this.speed = 0,
  });
  final DateTime ts;
  final double lat;
  final double lng;
  final double accuracy; // 米
  final double speed; // m/s

  Map<String, dynamic> toJson() => {
        't': ts.millisecondsSinceEpoch,
        'la': lat,
        'ln': lng,
        'ac': accuracy,
        'sp': speed,
      };

  factory LocPoint.fromJson(Map<String, dynamic> j) => LocPoint(
        ts: DateTime.fromMillisecondsSinceEpoch(j['t'] as int, isUtc: false),
        lat: (j['la'] as num).toDouble(),
        lng: (j['ln'] as num).toDouble(),
        accuracy: (j['ac'] as num?)?.toDouble() ?? 0,
        speed: (j['sp'] as num?)?.toDouble() ?? 0,
      );
}
