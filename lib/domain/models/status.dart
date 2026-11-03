import '../location/sampling.dart';

/// 加密同步的状态（电量/网络/移动状态）。
class DeviceStatus {
  const DeviceStatus({
    required this.battery,
    required this.charging,
    required this.network, // wifi / cellular / none
    required this.lowPower,
    required this.motion,
    required this.ts,
    this.sos = false,
  });
  final int battery;
  final bool charging;
  final String network;
  final bool lowPower;
  final MoveState motion;
  final DateTime ts;
  final bool sos;

  bool get lowBattery => battery < 15 && !charging;

  Map<String, dynamic> toJson() => {
        'b': battery,
        'c': charging,
        'n': network,
        'lp': lowPower,
        'm': motion.name,
        't': ts.millisecondsSinceEpoch,
        'sos': sos,
      };

  factory DeviceStatus.fromJson(Map<String, dynamic> j) => DeviceStatus(
        battery: (j['b'] as num).toInt(),
        charging: j['c'] as bool? ?? false,
        network: j['n'] as String? ?? 'none',
        lowPower: j['lp'] as bool? ?? false,
        motion: MoveState.values.firstWhere((e) => e.name == j['m'], orElse: () => MoveState.still),
        ts: DateTime.fromMillisecondsSinceEpoch((j['t'] as num).toInt()),
        sos: j['sos'] as bool? ?? false,
      );
}

enum EventKind { arrived, ack, sos, sosCancel, sosAck, poke }

extension EventKindX on EventKind {
  String get wire => switch (this) {
        EventKind.arrived => 'arrived',
        EventKind.ack => 'ack',
        EventKind.sos => 'sos',
        EventKind.sosCancel => 'sos_cancel',
        EventKind.sosAck => 'sos_ack',
        EventKind.poke => 'poke',
      };
  static EventKind parse(String s) => EventKind.values.firstWhere((e) => e.wire == s, orElse: () => EventKind.poke);
}

/// 解密后的事件。
class CoupleEvent {
  const CoupleEvent({required this.id, required this.userId, required this.kind, required this.at, this.lat, this.lng, this.emoji, this.text});
  final String id;
  final String userId;
  final EventKind kind;
  final DateTime at;
  final double? lat;
  final double? lng;
  final String? emoji;
  final String? text;
}

/// 共同标记。
class MapPin {
  const MapPin({required this.id, required this.lat, required this.lng, required this.name, this.emoji = '📍', this.note = '', this.photoB64, required this.updatedAt, required this.ownerId});
  final String id;
  final double lat; // WGS-84
  final double lng;
  final String name;
  final String emoji;
  final String note;
  final String? photoB64; // 小尺寸缩略图（加密后随标记同步）
  final DateTime updatedAt;
  final String ownerId;

  Map<String, dynamic> toJson() =>
      {'la': lat, 'ln': lng, 'name': name, 'e': emoji, 'note': note, if (photoB64 != null) 'ph': photoB64};
}
