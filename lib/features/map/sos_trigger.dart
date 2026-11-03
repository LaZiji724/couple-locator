import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';

import '../../app/providers.dart';
import '../../core/theme/app_theme.dart';
import '../../domain/models/status.dart';
import '../../platform/tracker_service.dart';

/// D2：长按 3 秒触发（防误触），环形进度。
class SosButton extends StatefulWidget {
  const SosButton({super.key, required this.onTriggered});
  final VoidCallback onTriggered;
  @override
  State<SosButton> createState() => _SosButtonState();
}

class _SosButtonState extends State<SosButton> with SingleTickerProviderStateMixin {
  late final _c = AnimationController(vsync: this, duration: const Duration(seconds: 3));

  @override
  void initState() {
    super.initState();
    _c.addStatusListener((s) {
      if (s == AnimationStatus.completed) {
        HapticFeedback.heavyImpact();
        widget.onTriggered();
        _c.reset();
      }
    });
  }

  @override
  void dispose() {
    _c.dispose();
    super.dispose();
  }

  void _down() {
    HapticFeedback.mediumImpact();
    _c.forward(from: 0);
  }

  void _up() {
    if (_c.status != AnimationStatus.completed) _c.reverse();
  }

  @override
  Widget build(BuildContext context) {
    final danger = context.vibes.danger;
    return Semantics(
      button: true,
      label: '长按三秒发送 SOS 紧急求助',
      child: GestureDetector(
        onTapDown: (_) => _down(),
        onTapUp: (_) => _up(),
        onTapCancel: _up,
        child: AnimatedBuilder(
          animation: _c,
          builder: (_, _) {
            final p = _c.value;
            return SizedBox(
              width: 64,
              height: 64,
              child: Stack(alignment: Alignment.center, children: [
                Transform.scale(
                  scale: 1 + 0.08 * p,
                  child: Container(
                    width: 56,
                    height: 56,
                    decoration: BoxDecoration(color: danger, shape: BoxShape.circle, boxShadow: [BoxShadow(color: danger.withValues(alpha: 0.45), blurRadius: 18, offset: const Offset(0, 8))]),
                    alignment: Alignment.center,
                    child: const Text('SOS', style: TextStyle(color: Colors.white, fontWeight: FontWeight.w900, fontSize: 16)),
                  ),
                ),
                SizedBox(width: 64, height: 64, child: CircularProgressIndicator(value: p, strokeWidth: 4, color: Colors.white, backgroundColor: Colors.transparent)),
                if (p == 0)
                  Positioned(bottom: -2, child: Text('长按3秒', style: TextStyle(fontSize: 9, color: context.vibes.inkSoft, fontWeight: FontWeight.w700))),
              ]),
            );
          },
        ),
      ),
    );
  }
}

/// 触发 SOS：开启高频上传、通知对方、进入发送方 SOS 页。
Future<void> triggerSos(BuildContext context, WidgetRef ref) async {
  final settings = ref.read(settingsProvider);
  await settings?.setSos(true);
  final s = ref.read(syncProvider);
  try {
    await ref.read(syncProvider.notifier).sendEvent(EventKind.sos, lat: s.myPoint?.lat, lng: s.myPoint?.lng, text: 'SOS');
  } catch (_) {}
  TrackerService.instance.flushNow();
  if (context.mounted) context.push('/sos-sender');
}

Future<void> cancelSos(WidgetRef ref) async {
  await ref.read(settingsProvider)?.setSos(false);
  try {
    await ref.read(syncProvider.notifier).sendEvent(EventKind.sosCancel, text: '已取消');
  } catch (_) {}
}
