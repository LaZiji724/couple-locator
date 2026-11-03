import 'dart:math' as math;

import 'package:flutter/material.dart';

import '../../domain/location/sampling.dart';
import '../format.dart';
import '../theme/motion.dart';

/// 移动状态图标 + 动效（静止呼吸、步行摆动、跑步弹跳、骑行/驾车前后位移）。
class MotionIcon extends StatefulWidget {
  const MotionIcon({super.key, required this.state, this.size = 22, this.color});
  final MoveState state;
  final double size;
  final Color? color;
  @override
  State<MotionIcon> createState() => _MotionIconState();
}

class _MotionIconState extends State<MotionIcon> with SingleTickerProviderStateMixin {
  late final _c = AnimationController(vsync: this, duration: const Duration(milliseconds: 900));

  @override
  void didChangeDependencies() {
    super.didChangeDependencies();
    if (Motion.reduced(context)) {
      _c.stop();
    } else if (!_c.isAnimating) {
      _c.repeat(reverse: true);
    }
  }

  @override
  void dispose() {
    _c.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final icon = Icon(motionIcon(widget.state), size: widget.size, color: widget.color);
    return AnimatedBuilder(
      animation: _c,
      builder: (_, _) {
        final t = Curves.easeInOut.transform(_c.value);
        switch (widget.state) {
          case MoveState.still:
            return Transform.scale(scale: 0.94 + 0.1 * t, child: icon);
          case MoveState.walking:
            return Transform.rotate(angle: (t - 0.5) * 0.28, child: icon);
          case MoveState.running:
            return Transform.translate(offset: Offset(0, -4 * math.sin(t * math.pi)), child: icon);
          case MoveState.cycling:
          case MoveState.driving:
            return Transform.translate(offset: Offset((t - 0.5) * 6, 0), child: icon);
        }
      },
    );
  }
}
