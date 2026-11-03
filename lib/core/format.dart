import 'package:flutter/widgets.dart';
import 'package:phosphor_flutter/phosphor_flutter.dart';

import '../domain/location/sampling.dart';

String agoText(DateTime t, [DateTime? now]) {
  final d = (now ?? DateTime.now()).difference(t);
  if (d.inSeconds < 45) return '刚刚';
  if (d.inMinutes < 60) return '${d.inMinutes < 1 ? 1 : d.inMinutes} 分钟前更新';
  if (d.inHours < 24) return '${d.inHours} 小时前更新';
  return '${d.inDays} 天前更新';
}

String shortAgo(DateTime t, [DateTime? now]) {
  final d = (now ?? DateTime.now()).difference(t);
  if (d.inSeconds < 45) return '刚刚';
  if (d.inMinutes < 60) return '${d.inMinutes < 1 ? 1 : d.inMinutes} 分钟前';
  if (d.inHours < 24) return '${d.inHours} 小时前';
  return '${d.inDays} 天前';
}

String distanceText(double meters) =>
    meters < 1000 ? '${meters.round()} m' : '${(meters / 1000).toStringAsFixed(meters < 10000 ? 2 : 1)} km';

String durationText(Duration d) {
  if (d.inMinutes < 1) return '不到 1 分钟';
  if (d.inHours < 1) return '${d.inMinutes} 分钟';
  final m = d.inMinutes % 60;
  return m == 0 ? '${d.inHours} 小时' : '${d.inHours} 小时 $m 分';
}

String hm(DateTime t) => '${t.hour.toString().padLeft(2, '0')}:${t.minute.toString().padLeft(2, '0')}';

String motionLabel(MoveState m) => switch (m) {
      MoveState.still => '静止',
      MoveState.walking => '步行中',
      MoveState.running => '跑步中',
      MoveState.cycling => '骑行中',
      MoveState.driving => '驾车中',
    };

IconData motionIcon(MoveState m) => switch (m) {
      MoveState.still => PhosphorIconsFill.coffee,
      MoveState.walking => PhosphorIconsFill.personSimpleWalk,
      MoveState.running => PhosphorIconsFill.personSimpleRun,
      MoveState.cycling => PhosphorIconsFill.personSimpleBike,
      MoveState.driving => PhosphorIconsFill.car,
    };

const pokeEmojis = ['❤️', '😘', '🤗', '👋', '🥺', '😆', '🌹', '🍬'];
