import 'dart:convert';
import 'dart:ui';

import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:phosphor_flutter/phosphor_flutter.dart';

import '../theme/app_theme.dart';
import '../theme/motion.dart';
import '../theme/tokens.dart';

/// 按下挤压、松开弹簧回弹并带触感反馈的包装器。
class Squish extends StatefulWidget {
  const Squish({super.key, required this.child, this.onTap, this.onLongPress, this.scale = 0.97});
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

/// 主按钮：纯色强调色 + 极轻的顶部提亮与描边，按下下沉 1px。每屏只放一个。
class PrimaryButton extends StatelessWidget {
  const PrimaryButton({
    super.key,
    required this.label,
    this.onTap,
    this.icon,
    this.height = 52,
    this.expand = true,
    this.busy = false,
  });
  final String label;
  final VoidCallback? onTap;
  final IconData? icon;
  final double height;
  final bool expand;
  final bool busy;

  @override
  Widget build(BuildContext context) {
    final disabled = onTap == null || busy;
    final content = Row(
      mainAxisSize: expand ? MainAxisSize.max : MainAxisSize.min,
      mainAxisAlignment: MainAxisAlignment.center,
      children: [
        if (busy)
          const SizedBox(
            width: 20,
            height: 20,
            child: CircularProgressIndicator(strokeWidth: 2, color: AppColors.onAccent),
          )
        else if (icon != null)
          Icon(icon, color: AppColors.onAccent, size: 20),
        if (busy || icon != null) const SizedBox(width: 8),
        Text(label,
            style: const TextStyle(
                color: AppColors.onAccent, fontSize: 14, fontWeight: FontWeight.w600)),
      ],
    );
    return Squish(
      onTap: disabled ? null : onTap,
      child: AnimatedOpacity(
        opacity: disabled && !busy ? 0.5 : 1,
        duration: Motion.fast,
        child: Container(
          height: height,
          padding: const EdgeInsets.symmetric(horizontal: 24),
          decoration: BoxDecoration(
            gradient: const LinearGradient(
              begin: Alignment.topCenter,
              end: Alignment.bottomCenter,
              colors: [Color(0xFFD14A64), AppColors.accent],
            ),
            borderRadius: BorderRadius.circular(AppRadii.small),
            border: Border.all(color: const Color(0xFFA8304A), width: 1),
            boxShadow: [
              BoxShadow(color: Colors.black.withValues(alpha: 0.12), blurRadius: 2, offset: const Offset(0, 1)),
              BoxShadow(color: AppColors.accent.withValues(alpha: 0.22), blurRadius: 10, spreadRadius: -3, offset: const Offset(0, 4)),
            ],
          ),
          child: content,
        ),
      ),
    );
  }
}

/// 次级按钮：中性浅底 + 细边框，文字用墨色（危险操作可传 [color]）。
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
    final c = color ?? v.ink;
    return Squish(
      onTap: onTap,
      child: AnimatedOpacity(
        opacity: onTap == null ? 0.5 : 1,
        duration: Motion.fast,
        child: Container(
          height: height,
          padding: const EdgeInsets.symmetric(horizontal: 16),
          alignment: Alignment.center,
          decoration: BoxDecoration(
            color: v.surfaceHigh,
            borderRadius: BorderRadius.circular(AppRadii.small),
            border: Border.all(color: v.hairline, width: 0.5),
          ),
          child: Row(mainAxisSize: MainAxisSize.min, mainAxisAlignment: MainAxisAlignment.center, children: [
            if (icon != null) ...[Icon(icon, size: 18, color: c), const SizedBox(width: 8)],
            Text(label, style: TextStyle(color: c, fontWeight: FontWeight.w600, fontSize: 14)),
          ]),
        ),
      ),
    );
  }
}

/// 毛玻璃浮层，叠在地图上使用。这是少数允许投影的容器。
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
        boxShadow: AppShadows.soft(Colors.black, dark: v.isDark),
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
              border: Border.all(color: v.glassBorder, width: 0.5),
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

/// 平铺卡片：纯色底 + 0.5px 细边框，不带阴影。
/// [tint] 与 [gradient] 仅为兼容旧调用，不再使用。
class VibeCard extends StatelessWidget {
  const VibeCard({super.key, required this.child, this.padding = const EdgeInsets.all(16), this.tint, this.gradient, this.onTap});
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
        color: v.surface,
        borderRadius: BorderRadius.circular(AppRadii.card),
        border: Border.all(color: v.hairline, width: 0.5),
      ),
      child: child,
    );
    return onTap == null ? card : Squish(onTap: onTap, child: card);
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

/// 页面底：暖纸色纯色背景，不做动画、不加光斑。
class PaperBackdrop extends StatelessWidget {
  const PaperBackdrop({super.key, required this.child});
  final Widget child;

  @override
  Widget build(BuildContext context) {
    return ColoredBox(color: context.vibes.bg, child: child);
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
        ? ClipOval(
            child: imageUrl!.startsWith('data:')
                ? Image.memory(base64Decode(imageUrl!.split(',').last), fit: BoxFit.cover, width: size, height: size, errorBuilder: (_, _, _) => _emoji())
                : Image.network(imageUrl!, fit: BoxFit.cover, width: size, height: size, errorBuilder: (_, _, _) => _emoji()))
        : _emoji();
    Widget w = Container(
      width: size,
      height: size,
      padding: EdgeInsets.all(size * 0.08),
      decoration: BoxDecoration(shape: BoxShape.circle, gradient: palette.gradient),
      child: Container(
        decoration: BoxDecoration(shape: BoxShape.circle, color: context.vibes.surface),
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

/// 空状态：缩小版的真实界面（占位条 + 图标），只在下一步操作上用强调色。
class CuteEmpty extends StatelessWidget {
  const CuteEmpty({super.key, required this.title, this.subtitle, this.icon = PhosphorIconsRegular.mapPin, this.action});
  final String title;
  final String? subtitle;
  final IconData icon;
  final Widget? action;

  @override
  Widget build(BuildContext context) {
    final v = context.vibes;
    Widget bar(double w) => Container(
        width: w,
        height: 8,
        decoration: BoxDecoration(color: v.hairline, borderRadius: BorderRadius.circular(4)));
    return Center(
      child: Padding(
        padding: const EdgeInsets.all(32),
        child: Column(mainAxisSize: MainAxisSize.min, children: [
          Container(
            width: 160,
            padding: const EdgeInsets.all(16),
            decoration: BoxDecoration(
              color: v.surface,
              borderRadius: BorderRadius.circular(AppRadii.card),
              border: Border.all(color: v.hairline, width: 0.5),
            ),
            child: Row(children: [
              Container(
                width: 40,
                height: 40,
                decoration: BoxDecoration(color: v.surfaceHigh, borderRadius: BorderRadius.circular(AppRadii.small)),
                child: Icon(icon, size: 20, color: v.accentText),
              ),
              const SizedBox(width: 12),
              Column(crossAxisAlignment: CrossAxisAlignment.start, children: [bar(48), const SizedBox(height: 8), bar(32)]),
            ]),
          ),
          const SizedBox(height: 24),
          Text(title, style: Theme.of(context).textTheme.titleLarge, textAlign: TextAlign.center),
          if (subtitle != null) ...[
            const SizedBox(height: 8),
            Text(subtitle!, style: TextStyle(color: v.inkSoft), textAlign: TextAlign.center),
          ],
          if (action != null) ...[const SizedBox(height: 24), action!],
        ]),
      ),
    );
  }
}

/// 分组标题。
class SectionTitle extends StatelessWidget {
  const SectionTitle(this.text, {super.key});
  final String text;
  @override
  Widget build(BuildContext context) => Padding(
        padding: const EdgeInsets.fromLTRB(4, 24, 4, 8),
        child: Text(text, style: TextStyle(color: context.vibes.inkSoft, fontWeight: FontWeight.w600, fontSize: 12)),
      );
}
