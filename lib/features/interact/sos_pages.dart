import 'dart:async';

import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import 'package:phosphor_flutter/phosphor_flutter.dart';
import 'package:url_launcher/url_launcher.dart';

import '../../app/providers.dart';
import '../../core/theme/app_theme.dart';
import '../../core/widgets/effects.dart';
import '../../core/widgets/vibe_widgets.dart';
import '../../domain/models/status.dart';
import '../../platform/notifications.dart';
import '../map/sos_trigger.dart';

/// 接收方：全屏红色警报，震动响铃，直到确认或对方取消。
class SosAlertPage extends ConsumerStatefulWidget {
  const SosAlertPage({super.key});
  @override
  ConsumerState<SosAlertPage> createState() => _SosAlertPageState();
}

class _SosAlertPageState extends ConsumerState<SosAlertPage> {
  Timer? _vib;

  @override
  void initState() {
    super.initState();
    HapticFeedback.heavyImpact();
    // 持续震动 + 系统警报音（SystemSound 提供简单提示音；铃声由通知通道 sos 的 alarm 音频承担）
    _vib = Timer.periodic(const Duration(milliseconds: 900), (_) {
      HapticFeedback.vibrate();
      SystemSound.play(SystemSoundType.alert);
    });
  }

  @override
  void dispose() {
    _vib?.cancel();
    super.dispose();
  }

  Future<void> _ack() async {
    try {
      await ref.read(syncProvider.notifier).sendEvent(EventKind.sosAck, text: '已确认');
    } catch (_) {}
    await LocalNotifier.instance.cancel(NotifIds.sos);
    if (mounted) context.go('/');
  }

  @override
  Widget build(BuildContext context) {
    final s = ref.watch(syncProvider);
    // 对方取消后自动退出
    ref.listen(syncProvider.select((x) => x.pendingSos), (prev, next) {
      if (prev != null && next == null && mounted) context.go('/');
    });
    final name = (s.partner?.nickname.isNotEmpty ?? false) ? s.partner!.nickname : 'TA';
    final p = s.partnerPoint;
    return PopScope(
      canPop: false,
      child: Scaffold(
        backgroundColor: const Color(0xFFB3001F),
        body: Stack(children: [
          const Positioned.fill(child: DecoratedBox(decoration: BoxDecoration(gradient: RadialGradient(center: Alignment(0, -0.2), radius: 1.1, colors: [Color(0xFFFF4D6D), Color(0xFF9B0019)])))),
          const Positioned.fill(child: SosPulse(color: Colors.white)),
          SafeArea(
            child: Padding(
              padding: const EdgeInsets.all(28),
              child: Column(children: [
                const Spacer(),
                const Text('🚨', style: TextStyle(fontSize: 84)),
                const SizedBox(height: 12),
                Text('$name 需要帮助！', textAlign: TextAlign.center, style: const TextStyle(fontFamily: AppTheme.displayFont, fontSize: 38, color: Colors.white)),
                const SizedBox(height: 8),
                Text(p == null ? '正在获取 TA 的位置…' : 'TA 的位置正在每 3 秒更新', style: const TextStyle(color: Colors.white, fontSize: 16)),
                const Spacer(),
                SizedBox(
                  width: double.infinity,
                  height: 60,
                  child: FilledButton.icon(
                    onPressed: _ack,
                    style: FilledButton.styleFrom(backgroundColor: Colors.white, foregroundColor: const Color(0xFF9B0019), shape: const StadiumBorder()),
                    icon: const Icon(PhosphorIconsBold.check),
                    label: const Text('我知道了，马上联系', style: TextStyle(fontSize: 18, fontWeight: FontWeight.w800)),
                  ),
                ),
                const SizedBox(height: 12),
                Row(children: [
                  Expanded(child: _Ghost(label: '查看位置', icon: PhosphorIconsRegular.mapPin, onTap: () async {
                    await _ack();
                  })),
                  const SizedBox(width: 12),
                  Expanded(child: _Ghost(label: '拨打 110', icon: PhosphorIconsRegular.phoneCall, onTap: () => launchUrl(Uri.parse('tel:110')))),
                ]),
              ]),
            ),
          ),
        ]),
      ),
    );
  }
}

class _Ghost extends StatelessWidget {
  const _Ghost({required this.label, required this.icon, required this.onTap});
  final String label;
  final IconData icon;
  final VoidCallback onTap;
  @override
  Widget build(BuildContext context) => Squish(
        onTap: onTap,
        child: Container(
          height: 52,
          decoration: BoxDecoration(color: Colors.white.withValues(alpha: 0.18), borderRadius: BorderRadius.circular(999), border: Border.all(color: Colors.white54)),
          child: Row(mainAxisAlignment: MainAxisAlignment.center, children: [Icon(icon, color: Colors.white), const SizedBox(width: 8), Text(label, style: const TextStyle(color: Colors.white, fontWeight: FontWeight.w700))]),
        ),
      );
}

/// 发送方：SOS 进行中，高频上传，长按取消。
class SosSenderPage extends ConsumerStatefulWidget {
  const SosSenderPage({super.key});
  @override
  ConsumerState<SosSenderPage> createState() => _SosSenderPageState();
}

class _SosSenderPageState extends ConsumerState<SosSenderPage> {
  @override
  Widget build(BuildContext context) {
    final events = ref.watch(syncProvider.select((s) => s.events));
    final acked = events.any((e) => e.kind == EventKind.sosAck && e.userId != ref.read(backendProvider).userId);
    return PopScope(
      canPop: false,
      child: Scaffold(
        backgroundColor: const Color(0xFFB3001F),
        body: Stack(children: [
          const Positioned.fill(child: DecoratedBox(decoration: BoxDecoration(gradient: RadialGradient(center: Alignment(0, -0.2), radius: 1.1, colors: [Color(0xFFFF4D6D), Color(0xFF9B0019)])))),
          const Positioned.fill(child: SosPulse(color: Colors.white)),
          SafeArea(
            child: Padding(
              padding: const EdgeInsets.all(28),
              child: Column(children: [
                const Spacer(),
                const Text('📡', style: TextStyle(fontSize: 76)),
                const SizedBox(height: 12),
                const Text('SOS 进行中', style: TextStyle(fontFamily: AppTheme.displayFont, fontSize: 40, color: Colors.white)),
                const SizedBox(height: 10),
                Text(acked ? 'TA 已确认收到，正在联系你' : '正在每 3 秒向 TA 发送你的位置', textAlign: TextAlign.center, style: const TextStyle(color: Colors.white, fontSize: 16)),
                const Spacer(),
                _HoldToCancel(onCancel: () async {
                  await cancelSos(ref);
                  if (context.mounted) context.go('/');
                }),
                const SizedBox(height: 12),
                const Text('长按 2 秒取消求助', style: TextStyle(color: Colors.white70)),
              ]),
            ),
          ),
        ]),
      ),
    );
  }
}

class _HoldToCancel extends StatefulWidget {
  const _HoldToCancel({required this.onCancel});
  final VoidCallback onCancel;
  @override
  State<_HoldToCancel> createState() => _HoldToCancelState();
}

class _HoldToCancelState extends State<_HoldToCancel> with SingleTickerProviderStateMixin {
  late final _c = AnimationController(vsync: this, duration: const Duration(seconds: 2))
    ..addStatusListener((s) {
      if (s == AnimationStatus.completed) widget.onCancel();
    });

  @override
  void dispose() {
    _c.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return GestureDetector(
      onTapDown: (_) => _c.forward(from: 0),
      onTapUp: (_) => _c.reverse(),
      onTapCancel: () => _c.reverse(),
      child: AnimatedBuilder(
        animation: _c,
        builder: (_, _) => Stack(alignment: Alignment.center, children: [
          Container(
            height: 60,
            width: double.infinity,
            decoration: BoxDecoration(color: Colors.white.withValues(alpha: 0.2), borderRadius: BorderRadius.circular(999), border: Border.all(color: Colors.white)),
            alignment: Alignment.center,
            child: const Text('我安全了，取消求助', style: TextStyle(color: Colors.white, fontWeight: FontWeight.w800, fontSize: 17)),
          ),
          Positioned.fill(child: Align(alignment: Alignment.centerLeft, child: FractionallySizedBox(widthFactor: _c.value, child: Container(decoration: BoxDecoration(color: Colors.white.withValues(alpha: 0.35), borderRadius: BorderRadius.circular(999)))))),
        ]),
      ),
    );
  }
}
