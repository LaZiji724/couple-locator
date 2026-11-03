import 'dart:math' as math;

import 'package:flutter/material.dart';

/// 动效令牌。系统开启「减弱动态效果」时自动简化。
abstract final class Motion {
  static const fast = Duration(milliseconds: 200);
  static const normal = Duration(milliseconds: 300);
  static const slow = Duration(milliseconds: 400);

  static const Curve spring = SpringOutCurve();
  static const Curve emphasized = Curves.easeInOutCubicEmphasized;

  static bool reduced(BuildContext context) =>
      MediaQuery.maybeDisableAnimationsOf(context) ?? false;

  /// 减弱动效时返回 0 时长。
  static Duration of(BuildContext context, Duration d) =>
      reduced(context) ? Duration.zero : d;
}

/// 轻微回弹的弹簧曲线（阻尼振荡，过冲约 6%）。
class SpringOutCurve extends Curve {
  const SpringOutCurve({this.damping = 6, this.frequency = 10});
  final double damping;
  final double frequency;

  @override
  double transformInternal(double t) {
    double f(double x) => 1 - math.exp(-damping * x) * math.cos(frequency * x);
    return f(t) / f(1);
  }
}
