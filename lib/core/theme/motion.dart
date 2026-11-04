import 'package:flutter/material.dart';

/// 动效令牌。系统开启「减弱动态效果」时自动简化。
abstract final class Motion {
  static const fast = Duration(milliseconds: 150);
  static const normal = Duration(milliseconds: 250);
  static const slow = Duration(milliseconds: 400);

  /// 统一使用 ease-out，不再回弹过冲。
  static const Curve spring = Curves.easeOutCubic;
  static const Curve emphasized = Curves.easeInOutCubicEmphasized;

  static bool reduced(BuildContext context) =>
      MediaQuery.maybeDisableAnimationsOf(context) ?? false;

  /// 减弱动效时返回 0 时长。
  static Duration of(BuildContext context, Duration d) =>
      reduced(context) ? Duration.zero : d;
}
