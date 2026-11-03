import 'dart:math' as math;
import 'dart:ui';

import 'package:flutter/material.dart';
import 'package:flutter/services.dart';

import '../theme/app_theme.dart';
import '../theme/motion.dart';
import '../theme/tokens.dart';

/// 按下挤压、松开弹簧回弹并带触感反馈的包装器。
class Squish extends StatefulWidget {
  const Squish({super.key, required this.child, this.onTap, this.onLongPress, this.scale = 0.94});
  final Widget child;
  final VoidCallback? onTap;
  final VoidCallback? onLongPress;
  final double scale;

  @override
  State<Squish> createState() => _SquishState();
}

class _SquishState extends State<Squish> {
  bool _down = false;

  void _set(bool v) => setState(() => _down = v);

  @override
  Widget build(BuildContext context) {
    final enabled = widget.onTap != null || widget.onLongPress != null;
    return GestureDetector(
      behavior: HitTestBehavior.opaque,
      onTapDown: enabled ? (_) => _set(true) : null,
      onTapCancel: enabled ? () => _set(false) : null,
      onTapUp: enabled ? (_) => _set(false) : null,
      onTap: widget.onTap == null
          ? null
          : () {
              HapticFeedback.lightImpact();
              widget.onTap!();
            },
      onLongPress: widget.onLongPress,
      child: AnimatedScale(
        scale: _down ? widget.scale : 1,
        duration: Motion.of(context, _down ? Motion.fast : Motion.normal),
        curve: _down ? Curves.easeOutCubic : Motion.spring,
        child: widget.child,
      ),
    );
  }
}

/// 全胶囊渐变主按钮。
class GradientButton extends StatelessWidget {
  const GradientButton({
    super.key,
    required this.label,
    this.onTap,
    this.icon,
    this.gradient,
    this.height = 56,
    this.expand = true,
    this.busy = false,
  });
  final String label;
  final VoidCallback? onTap;
  final IconData? icon;
  final Gradient? gradient;
  final double height;
  final bool expand;
  final bool busy;

  @override
  Widget build(BuildContext context) {
    final g = gradient ?? AppColors.sunrise;
    final disabled = onTap == null || busy;
    final content = Row(
      mainAxisSize: expand ? MainAxisSize.max : MainAxisSize.min,
      mainAxisAlignment: MainAxisAlignment.center,
      children: [
        if (busy)
          const SizedBox(
            width: 20,
            height: 20,
            child: CircularProgressIndicator(strokeWidth: 2.5, color: AppColors.onGradient),
          )
        else if (icon != null)
          Icon(icon, color: AppColors.onGradient, size: 22),
        if (busy || icon != null) const SizedBox(width: 10),
        Text(label,
            style: const TextStyle(
                color: AppColors.onGradient, fontSize: 17, fontWeight: FontWeight.w700)),
      ],
    );
    return Squish(
      onTap: disabled ? null : onTap,
      child: AnimatedOpacity(
        opacity: disabled && !busy ? 0.5 : 1,
        duration: Motion.fast,
        child: Container(
          height: height,
          padding: const EdgeInsets.symmetric(horizontal: 28),
          decoration: BoxDecoration(
            gradient: g,
            borderRadius: BorderRadius.circular(AppRadii.pill),
            boxShadow: AppShadows.soft(AppColors.coral, dark: context.vibes.isDark),
          ),
          child: content,
        ),
      ),
    );
  }
}

/// 次级胶囊按钮（描边/浅底）。
class SoftButton extends StatelessWidget {
  const SoftButton({super.key, required this.label, this.onTap, this.icon, this.color, this.height = 48});
  final String label;
  final VoidCallback? onTap;
  final IconData? icon;
  final Color? color;
  final double height;

  @override
  Widget build(BuildContext context) {
    final v = context.vibes;
    final c = color ?? v.accentText;
    return Squish(
      onTap: onTap,
      child: Container(
        height: height,
        padding: const EdgeInsets.symmetric(horizontal: 20),
        decoration: BoxDecoration(
          color: c.withValues(alpha: v.isDark ? 0.18 : 0.10),
          borderRadius: BorderRadius.circular(AppRadii.pill),
        ),
        child: Row(mainAxisSize: MainAxisSize.min, children: [
          if (icon != null) ...[Icon(icon, size: 20, color: c), const SizedBox(width: 8)],
          Text(label, style: TextStyle(color: c, fontWeight: FontWeight.w600, fontSize: 15)),
        ]),
      ),
    );
  }
}

/// 毛玻璃面板，叠在地图上使用。
class GlassPanel extends StatelessWidget {
  const GlassPanel({
    super.key,
    required this.child,
    this.padding = const EdgeInsets.all(16),
    this.radius = AppRadii.card,
    this.blur = 18,
  });
  final Widget child;
  final EdgeInsetsGeometry padding;
  final double radius;
  final double blur;

  @override
  Widget build(BuildContext context) {
    final v = context.vibes;
    return Container(
      decoration: BoxDecoration(
        borderRadius: BorderRadius.circular(radius),
        boxShadow: AppShadows.soft(AppColors.coral, dark: v.isDark),
      ),
      child: ClipRRect(
        borderRadius: BorderRadius.circular(radius),
        child: BackdropFilter(
          filter: ImageFilter.blur(sigmaX: blur, sigmaY: blur),
          child: Container(
            padding: padding,
            decoration: BoxDecoration(
              color: v.glass,
              borderRadius: BorderRadius.circular(radius),
              border: Border.all(color: v.glassBorder),
            ),
            child: child,
          ),
        ),
      ),
    );
  }
}

/// 圆形毛玻璃图标按钮（地图右侧工具栏）。
class GlassIconButton extends StatelessWidget {
  const GlassIconButton({super.key, required this.icon, required this.onTap, this.tooltip, this.color});
  final IconData icon;
  final VoidCallback onTap;
  final String? tooltip;
  final Color? color;

  @override
  Widget build(BuildContext context) {
    final btn = Squish(
      onTap: onTap,
      child: GlassPanel(
        padding: const EdgeInsets.all(12),
        radius: AppRadii.pill,
        child: Icon(icon, size: 24, color: color ?? context.vibes.ink),
      ),
    );
    return tooltip == null ? btn : Tooltip(message: tooltip!, child: btn);
  }
}

/// 白/深色卡片，彩色弥散阴影。
class VibeCard extends StatelessWidget {
  const VibeCard({super.key, required this.child, this.padding = const EdgeInsets.all(18), this.tint, this.gradient, this.onTap});
  final Widget child;
  final EdgeInsetsGeometry padding;
  final Color? tint;
  final Gradient? gradient;
  final VoidCallback? onTap;

  @override
  Widget build(BuildContext context) {
    final v = context.vibes;
    final card = Container(
      padding: padding,
      decoration: BoxDecoration(
        color: gradient == null ? v.surface : null,
        gradient: gradient,
        borderRadius: BorderRadius.circular(AppRadii.card),
        boxShadow: AppShadows.soft(tint ?? AppColors.peach, dark: v.isDark),
      ),
      child: child,
    );
    return onTap == null ? card : Squish(onTap: onTap, scale: 0.97, child: card);
  }
}

/// 列表项错峰淡入上移。
class StaggerIn extends StatelessWidget {
  const StaggerIn({super.key, required this.index, required this.child});
  final int index;
  final Widget child;

  @override
  Widget build(BuildContext context) {
    if (Motion.reduced(context)) return child;
    final delay = (index * 40).clamp(0, 400);
    final total = Motion.slow.inMilliseconds + delay;
    return TweenAnimationBuilder<double>(
      tween: Tween(begin: 0, end: 1),
      duration: Duration(milliseconds: total),
      builder: (_, t, c) {
        final local = ((t * total - delay) / Motion.slow.inMilliseconds).clamp(0.0, 1.0);
        final e = Curves.easeOutCubic.transform(local);
        return Opacity(opacity: e, child: Transform.translate(offset: Offset(0, 16 * (1 - e)), child: c));
      },
      child: child,
    );
  }
}

/// 数字滚动计数。
class RollingNumber extends StatelessWidget {
  const RollingNumber({super.key, required this.value, this.decimals = 0, this.suffix = '', this.style});
  final double value;
  final int decimals;
  final String suffix;
  final TextStyle? style;

  @override
  Widget build(BuildContext context) {
    return TweenAnimationBuilder<double>(
      tween: Tween(end: value),
      duration: Motion.of(context, const Duration(milliseconds: 600)),
      curve: Curves.easeOutCubic,
      builder: (_, v, _) => Text('${v.toStringAsFixed(decimals)}$suffix', style: style),
    );
  }
}

/// 首页背景缓慢流动的渐变光斑（地图页不要使用）。
class FlowingBlobs extends StatefulWidget {
  const FlowingBlobs({super.key, required this.child});
  final Widget child;
  @override
  State<FlowingBlobs> createState() => _FlowingBlobsState();
}

class _FlowingBlobsState extends State<FlowingBlobs> with SingleTickerProviderStateMixin {
  late final AnimationController _c =
      AnimationController(vsync: this, duration: const Duration(seconds: 18))..repeat();

  @override
  void dispose() {
    _c.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final v = context.vibes;
    final reduced = Motion.reduced(context);
    if (reduced) _c.stop();
    return Stack(children: [
      Positioned.fill(child: ColoredBox(color: v.bg)),
      Positioned.fill(
        child: RepaintBoundary(
          child: AnimatedBuilder(
            animation: _c,
            builder: (_, _) => CustomPaint(painter: _BlobPainter(_c.value, v.isDark)),
          ),
        ),
      ),
      widget.child,
    ]);
  }
}

class _BlobPainter extends CustomPainter {
  _BlobPainter(this.t, this.dark);
  final double t;
  final bool dark;

  @override
  void paint(Canvas canvas, Size size) {
    final a = dark ? 0.22 : 0.30;
    final blobs = [
      (AppColors.coral, 0.15, 0.10, 0.55),
      (AppColors.sun, 0.85, 0.25, 0.45),
      (AppColors.mint, 0.30, 0.85, 0.50),
    ];
    for (var i = 0; i < blobs.length; i++) {
      final (color, bx, by, r) = blobs[i];
      final ph = t * 2 * math.pi + i * 2.1;
      final c = Offset(size.width * (bx + 0.08 * math.sin(ph)), size.height * (by + 0.05 * math.cos(ph * 0.8)));
      final radius = size.shortestSide * r;
      final paint = Paint()
        ..shader = RadialGradient(colors: [color.withValues(alpha: a), color.withValues(alpha: 0)])
            .createShader(Rect.fromCircle(center: c, radius: radius));
      canvas.drawCircle(c, radius, paint);
    }
  }

  @override
  bool shouldRepaint(_BlobPainter old) => old.t != t || old.dark != dark;
}

/// 渐变文字。
class GradientText extends StatelessWidget {
  const GradientText(this.text, {super.key, this.style, this.gradient});
  final String text;
  final TextStyle? style;
  final Gradient? gradient;

  @override
  Widget build(BuildContext context) {
    return ShaderMask(
      shaderCallback: (r) => (gradient ?? AppColors.sunrise).createShader(r),
      blendMode: BlendMode.srcIn,
      child: Text(text, style: style),
    );
  }
}

/// 头像：emoji 或照片 + 个人渐变外环。
class AvatarBubble extends StatelessWidget {
  const AvatarBubble({super.key, required this.palette, this.emoji, this.imageUrl, this.size = 48, this.dimmed = false});
  final PersonalPalette palette;
  final String? emoji;
  final String? imageUrl;
  final double size;
  final bool dimmed;

  @override
  Widget build(BuildContext context) {
    final inner = imageUrl != null && imageUrl!.isNotEmpty
        ? ClipOval(child: Image.network(imageUrl!, fit: BoxFit.cover, width: size, height: size,
            errorBuilder: (_, _, _) => _emoji()))
        : _emoji();
    Widget w = Container(
      width: size,
      height: size,
      padding: EdgeInsets.all(size * 0.08),
      decoration: BoxDecoration(shape: BoxShape.circle, gradient: palette.gradient,
          boxShadow: AppShadows.soft(palette.start, dark: context.vibes.isDark)),
      child: Container(
        decoration: const BoxDecoration(shape: BoxShape.circle, color: Colors.white),
        padding: EdgeInsets.all(size * 0.03),
        child: ClipOval(child: inner),
      ),
    );
    if (dimmed) {
      w = ColorFiltered(colorFilter: const ColorFilter.matrix(_grey), child: w);
    }
    return w;
  }

  Widget _emoji() => Container(
        color: palette.start.withValues(alpha: 0.15),
        alignment: Alignment.center,
        child: Text(emoji ?? '🙂', style: TextStyle(fontSize: size * 0.5)),
      );

  static const _grey = <double>[
    0.33, 0.33, 0.33, 0, 0,
    0.33, 0.33, 0.33, 0, 0,
    0.33, 0.33, 0.33, 0, 0,
    0, 0, 0, 1, 0,
  ];
}

/// 空状态：可爱的扁平小团子插画 + 文案。
class CuteEmpty extends StatelessWidget {
  const CuteEmpty({super.key, required this.title, this.subtitle, this.emoji = '🌷', this.action});
  final String title;
  final String? subtitle;
  final String emoji;
  final Widget? action;

  @override
  Widget build(BuildContext context) {
    final v = context.vibes;
    return Center(
      child: Padding(
        padding: const EdgeInsets.all(32),
        child: Column(mainAxisSize: MainAxisSize.min, children: [
          SizedBox(width: 160, height: 140, child: CustomPaint(painter: _BuddyPainter(), child: Center(
            child: Padding(padding: const EdgeInsets.only(top: 52), child: Text(emoji, style: const TextStyle(fontSize: 28)))))),
          const SizedBox(height: 16),
          Text(title, style: Theme.of(context).textTheme.titleLarge, textAlign: TextAlign.center),
          if (subtitle != null) ...[
            const SizedBox(height: 8),
            Text(subtitle!, style: TextStyle(color: v.inkSoft), textAlign: TextAlign.center),
          ],
          if (action != null) ...[const SizedBox(height: 20), action!],
        ]),
      ),
    );
  }
}

class _BuddyPainter extends CustomPainter {
  @override
  void paint(Canvas canvas, Size s) {
    final body = Rect.fromCenter(center: Offset(s.width / 2, s.height * 0.58), width: s.width * 0.7, height: s.height * 0.72);
    canvas.drawOval(body.shift(const Offset(0, 8)), Paint()..color = AppColors.coral.withValues(alpha: 0.15));
    canvas.drawOval(body, Paint()..shader = AppColors.sunrise.createShader(body));
    final eye = Paint()..color = AppColors.onGradient;
    canvas.drawCircle(Offset(s.width * 0.42, s.height * 0.48), 4, eye);
    canvas.drawCircle(Offset(s.width * 0.58, s.height * 0.48), 4, eye);
    final blush = Paint()..color = Colors.white.withValues(alpha: 0.55);
    canvas.drawCircle(Offset(s.width * 0.35, s.height * 0.56), 7, blush);
    canvas.drawCircle(Offset(s.width * 0.65, s.height * 0.56), 7, blush);
    final sparkle = Paint()..color = AppColors.mint;
    canvas.drawCircle(Offset(s.width * 0.12, s.height * 0.2), 5, sparkle);
    canvas.drawCircle(Offset(s.width * 0.9, s.height * 0.3), 4, Paint()..color = AppColors.sky);
    canvas.drawCircle(Offset(s.width * 0.82, s.height * 0.08), 3, Paint()..color = AppColors.grape);
  }

  @override
  bool shouldRepaint(covariant CustomPainter oldDelegate) => false;
}

/// 分组标题。
class SectionTitle extends StatelessWidget {
  const SectionTitle(this.text, {super.key});
  final String text;
  @override
  Widget build(BuildContext context) => Padding(
        padding: const EdgeInsets.fromLTRB(8, 20, 8, 10),
        child: Text(text, style: TextStyle(color: context.vibes.inkSoft, fontWeight: FontWeight.w700, fontSize: 13, letterSpacing: 1)),
      );
}
