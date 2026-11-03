import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:phosphor_flutter/phosphor_flutter.dart';

import '../../app/providers.dart';
import '../../core/theme/app_theme.dart';
import '../../core/widgets/vibe_widgets.dart';

/// A4：共享开关底部面板。暂停期间不采集不上传，对方看到「对方暂停了共享」。
Future<void> showShareControl(BuildContext context, WidgetRef ref) {
  return showModalBottomSheet(
    context: context,
    isScrollControlled: true,
    builder: (_) => UncontrolledProviderScope(container: ProviderScope.containerOf(context), child: const _ShareSheet()),
  );
}

class _ShareSheet extends ConsumerWidget {
  const _ShareSheet();

  Future<void> _pause(BuildContext context, WidgetRef ref, Duration? d) async {
    final s = ref.read(settingsProvider)!;
    final until = d == null ? -1 : DateTime.now().add(d).millisecondsSinceEpoch;
    await s.setPauseUntil(until);
    ref.read(settingsProvider.notifier).touch();
    // 立即告知对方（明文心跳：暂停标记）
    try {
      await ref.read(backendProvider).heartbeat(paused: true, pausedUntil: d == null ? null : DateTime.fromMillisecondsSinceEpoch(until));
    } catch (_) {}
    if (context.mounted) Navigator.pop(context);
  }

  Future<void> _resume(BuildContext context, WidgetRef ref) async {
    final s = ref.read(settingsProvider)!;
    await s.setPauseUntil(0);
    ref.read(settingsProvider.notifier).touch();
    try {
      await ref.read(backendProvider).heartbeat(paused: false);
    } catch (_) {}
    if (context.mounted) Navigator.pop(context);
  }

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final s = ref.watch(settingsProvider);
    final paused = s?.isPaused() ?? false;
    final v = context.vibes;
    return GlassPanel(
      radius: 32,
      padding: EdgeInsets.fromLTRB(20, 14, 20, 20 + MediaQuery.of(context).padding.bottom),
      child: Column(mainAxisSize: MainAxisSize.min, crossAxisAlignment: CrossAxisAlignment.start, children: [
        Center(child: Container(width: 40, height: 5, decoration: BoxDecoration(color: v.inkSoft.withValues(alpha: 0.4), borderRadius: BorderRadius.circular(9)))),
        const SizedBox(height: 16),
        Text(paused ? '共享已暂停' : '暂停共享位置', style: Theme.of(context).textTheme.titleLarge),
        const SizedBox(height: 6),
        Text(paused ? '暂停期间不采集、不上传；TA 会看到「对方暂停了共享」，而不是掉线。' : '暂停期间不采集、不上传。TA 会看到你「暂停了共享」。', style: TextStyle(color: v.inkSoft)),
        const SizedBox(height: 18),
        if (paused)
          GradientButton(label: '恢复共享', icon: PhosphorIconsFill.play, onTap: () => _resume(context, ref))
        else
          Wrap(spacing: 10, runSpacing: 10, children: [
            _Opt('30 分钟', () => _pause(context, ref, const Duration(minutes: 30))),
            _Opt('1 小时', () => _pause(context, ref, const Duration(hours: 1))),
            _Opt('4 小时', () => _pause(context, ref, const Duration(hours: 4))),
            _Opt('直到我打开', () => _pause(context, ref, null)),
          ]),
      ]),
    );
  }
}

class _Opt extends StatelessWidget {
  const _Opt(this.label, this.onTap);
  final String label;
  final VoidCallback onTap;
  @override
  Widget build(BuildContext context) => SoftButton(label: label, onTap: onTap, icon: PhosphorIconsRegular.pause);
}
