/// 移动状态。
enum MoveState { still, walking, running, cycling, driving }

enum ReportMode { saver, balanced, precise }

extension ReportModeX on ReportMode {
  /// 频率系数：省电 ×2，均衡 ×1，精准 ×0.5（作用于间隔）。
  double get factor => switch (this) { ReportMode.saver => 2.0, ReportMode.balanced => 1.0, ReportMode.precise => 0.5 };
  String get label => switch (this) { ReportMode.saver => '省电', ReportMode.balanced => '均衡', ReportMode.precise => '精准' };
}

class SamplingPlan {
  const SamplingPlan({required this.sampleInterval, required this.uploadInterval, required this.significantOnly});
  final Duration sampleInterval;
  final Duration uploadInterval;

  /// 静止时：只监听显著变化 + 心跳，不连续采样。
  final bool significantOnly;
}

/// 自适应采样表（两端一致）。
SamplingPlan planFor({
  required MoveState motion,
  required ReportMode mode,
  required int batteryPercent,
  required bool charging,
  bool sos = false,
}) {
  if (sos) {
    return const SamplingPlan(
        sampleInterval: Duration(seconds: 3), uploadInterval: Duration.zero, significantOnly: false);
  }
  late int sample;
  late int upload;
  var still = false;
  switch (motion) {
    case MoveState.driving:
    case MoveState.cycling:
      sample = 5;
      upload = 8;
    case MoveState.walking:
    case MoveState.running:
      sample = 12;
      upload = 15;
    case MoveState.still:
      still = true;
      sample = 300;
      upload = 300; // 心跳 5 分钟
  }
  var f = mode.factor;
  // 低电量（<20%，且未充电）自动降一档并延长上传间隔
  if (batteryPercent < 20 && !charging) f *= 2;
  return SamplingPlan(
    sampleInterval: Duration(milliseconds: (sample * 1000 * f).round()),
    uploadInterval: Duration(milliseconds: (upload * 1000 * f * (batteryPercent < 20 && !charging ? 1.5 : 1)).round()),
    significantOnly: still,
  );
}

/// 根据速度（m/s）与系统活动识别结果判断移动状态。
MoveState classifyMotion({required double speedMps, String? activity}) {
  switch (activity) {
    case 'IN_VEHICLE':
    case 'automotive':
      return MoveState.driving;
    case 'ON_BICYCLE':
    case 'cycling':
      return MoveState.cycling;
    case 'RUNNING':
    case 'running':
      return MoveState.running;
    case 'WALKING':
    case 'ON_FOOT':
    case 'walking':
      if (speedMps > 4.5) return speedMps > 8 ? MoveState.driving : MoveState.running;
      return MoveState.walking;
    case 'STILL':
    case 'stationary':
      if (speedMps < 1.0) return MoveState.still;
  }
  if (speedMps < 0.6) return MoveState.still;
  if (speedMps < 2.2) return MoveState.walking;
  if (speedMps < 4.5) return MoveState.running;
  if (speedMps < 8.5) return MoveState.cycling;
  return MoveState.driving;
}
