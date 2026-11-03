import 'dart:math' as math;

import 'package:flutter/material.dart';

import '../theme/motion.dart';

/// 头像呼吸光晕（Flutter 覆盖层，位置由外部通过 toScreenCoordinate 提供）。
class BreathingHalo extends StatefulWidget {
  const BreathingHalo({super.key, required this.color, this.radius = 34});
  final Color color;
  final double radius;
  @override
  State<BreathingHalo> createState() => _BreathingHaloState();
}

class _BreathingHaloState extends State<BreathingHalo> with SingleTickerProviderStateMixin {
  late final _c = AnimationController(vsync: this, duration: const Duration(milliseconds: 2400));

  @override
  void didChangeDependencies() {
    super.didChangeDependencies();
    if (Motion.reduced(context)) {
      _c.stop();
      _c.value = 0.3;
    } else if (!_c.isAnimating) {
      _c.repeat();
    }
  }

  @override
  void dispose() {
    _c.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return IgnorePointer(
      child: AnimatedBuilder(
        animation: _c,
        builder: (_, _) {
          final t = Curves.easeOut.transform(_c.value);
          final r = widget.radius * (1 + 0.6 * t);
          return Container(
            width: r * 2,
            height: r * 2,
            decoration: BoxDecoration(
              shape: BoxShape.circle,
              color: widget.color.withValues(alpha: 0.30 * (1 - t)),
            ),
          );
        },
      ),
    );
  }
}

/// 心形粒子小动画（距离 < 100m 时触发）。
class HeartBurst extends StatefulWidget {
  const HeartBurst({super.key, this.count = 14, this.onDone});
  final int count;
  final VoidCallback? onDone;
  @override
  State<HeartBurst> createState() => _HeartBurstState();
}

class _HeartBurstState extends State<HeartBurst> with SingleTickerProviderStateMixin {
  late final _c = AnimationController(vsync: this, duration: const Duration(milliseconds: 1800))
    ..forward().whenComplete(() => widget.onDone?.call());
  late final _rng = math.Random();
  late final _parts = List.generate(widget.count, (i) => (
        dx: (_rng.nextDouble() - 0.5) * 140,
        rise: 80 + _rng.nextDouble() * 120,
        size: 14 + _rng.nextDouble() * 16,
        delay: _rng.nextDouble() * 0.35,
        emoji: ['❤️', '💗', '💖', '💕'][_rng.nextInt(4)],
      ));

  @override
  void dispose() {
    _c.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    if (Motion.reduced(context)) {
      return const IgnorePointer(child: Center(child: Text('💞', style: TextStyle(fontSize: 40))));
    }
    return IgnorePointer(
      child: AnimatedBuilder(
        animation: _c,
        builder: (_, _) => Stack(clipBehavior: Clip.none, children: [
          for (final p in _parts)
            Builder(builder: (_) {
              final t = ((_c.value - p.delay) / (1 - p.delay)).clamp(0.0, 1.0);
              final e = Curves.easeOutCubic.transform(t);
              return Transform.translate(
                offset: Offset(p.dx * e, -p.rise * e),
                child: Opacity(
                  opacity: (1 - t).clamp(0.0, 1.0),
                  child: Transform.scale(scale: 0.6 + 0.6 * e, child: Text(p.emoji, style: TextStyle(fontSize: p.size))),
                ),
              );
            }),
        ]),
      ),
    );
  }
}

/// 戳一戳：emoji 向上漂浮、放大、旋转。
class FloatingEmojis extends StatefulWidget {
  const FloatingEmojis({super.key, required this.emoji, this.onDone});
  final String emoji;
  final VoidCallback? onDone;
  @override
  State<FloatingEmojis> createState() => _FloatingEmojisState();
}

class _FloatingEmojisState extends State<FloatingEmojis> with SingleTickerProviderStateMixin {
  late final _c = AnimationController(vsync: this, duration: const Duration(milliseconds: 1600))
    ..forward().whenComplete(() => widget.onDone?.call());
  final _rng = math.Random();
  late final _items = List.generate(4, (i) => (dx: (_rng.nextDouble() - 0.5) * 80, delay: i * 0.12, rot: (_rng.nextDouble() - 0.5) * 0.8));

  @override
  void dispose() {
    _c.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final reduced = Motion.reduced(context);
    return IgnorePointer(
      child: AnimatedBuilder(
        animation: _c,
        builder: (_, _) => Stack(clipBehavior: Clip.none, alignment: Alignment.center, children: [
          for (final it in _items)
            Builder(builder: (_) {
              final t = ((_c.value - it.delay) / (1 - it.delay)).clamp(0.0, 1.0);
              final e = Curves.easeOut.transform(t);
              return Transform.translate(
                offset: Offset(it.dx * e, reduced ? -30 : -110 * e),
                child: Opacity(
                  opacity: t < 0.15 ? t / 0.15 : (1 - t).clamp(0.0, 1.0),
                  child: Transform.rotate(
                    angle: reduced ? 0 : it.rot * e,
                    child: Transform.scale(scale: reduced ? 1 : 0.6 + 0.9 * Curves.elasticOut.transform(t.clamp(0.0, 1.0)), child: Text(widget.emoji, style: const TextStyle(fontSize: 34))),
                  ),
                ),
              );
            }),
        ]),
      ),
    );
  }
}

/// SOS 红色径向脉冲。
class SosPulse extends StatefulWidget {
  const SosPulse({super.key, this.color = const Color(0xFFFF4D6D)});
  final Color color;
  @override
  State<SosPulse> createState() => _SosPulseState();
}

class _SosPulseState extends State<SosPulse> with SingleTickerProviderStateMixin {
  late final _c = AnimationController(vsync: this, duration: const Duration(milliseconds: 2400))..repeat();

  @override
  void dispose() {
    _c.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return AnimatedBuilder(
      animation: _c,
      builder: (_, _) => CustomPaint(painter: _PulsePainter(_c.value, widget.color, Motion.reduced(context)), size: Size.infinite),
    );
  }
}

class _PulsePainter extends CustomPainter {
  _PulsePainter(this.t, this.color, this.reduced);
  final double t;
  final Color color;
  final bool reduced;

  @override
  void paint(Canvas canvas, Size size) {
    final c = size.center(Offset(0, -size.height * 0.1));
    final maxR = size.longestSide * 0.7;
    for (var i = 0; i < 3; i++) {
      final p = reduced ? 0.5 : (t + i / 3) % 1.0;
      canvas.drawCircle(c, maxR * p, Paint()..color = color.withValues(alpha: 0.35 * (1 - p)));
    }
  }

  @override
  bool shouldRepaint(_PulsePainter old) => old.t != t;
}

/// 彩带（到家庆祝）。
class Confetti extends StatefulWidget {
  const Confetti({super.key});
  @override
  State<Confetti> createState() => _ConfettiState();
}

class _ConfettiState extends State<Confetti> with SingleTickerProviderStateMixin {
  late final _c = AnimationController(vsync: this, duration: const Duration(milliseconds: 2200))..forward();
  final _rng = math.Random(7);
  late final _bits = List.generate(36, (i) => (x: _rng.nextDouble(), v: 0.6 + _rng.nextDouble(), rot: _rng.nextDouble() * 6, c: [const Color(0xFFFF6B8A), const Color(0xFFFF9A6C), const Color(0xFFFFD166), const Color(0xFF4ADEB4), const Color(0xFF5CC8FF), const Color(0xFFA78BFA)][i % 6]));

  @override
  void dispose() {
    _c.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    if (Motion.reduced(context)) return const SizedBox.shrink();
    return IgnorePointer(
      child: AnimatedBuilder(
        animation: _c,
        builder: (_, _) => CustomPaint(painter: _ConfettiPainter(_c.value, _bits), size: Size.infinite),
      ),
    );
  }
}

class _ConfettiPainter extends CustomPainter {
  _ConfettiPainter(this.t, this.bits);
  final double t;
  final List<({double x, double v, double rot, Color c})> bits;
  @override
  void paint(Canvas canvas, Size size) {
    for (final b in bits) {
      final y = -20 + (size.height + 40) * Curves.easeIn.transform(t) * b.v;
      final x = size.width * b.x + math.sin(t * 8 + b.rot) * 16;
      canvas.save();
      canvas.translate(x, y);
      canvas.rotate(b.rot + t * 6);
      canvas.drawRRect(RRect.fromRectAndRadius(const Rect.fromLTWH(-4, -7, 8, 14), const Radius.circular(2)), Paint()..color = b.c.withValues(alpha: (1 - t * 0.6)));
      canvas.restore();
    }
  }

  @override
  bool shouldRepaint(_ConfettiPainter old) => old.t != t;
}
