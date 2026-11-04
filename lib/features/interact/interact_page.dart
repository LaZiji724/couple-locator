import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import 'package:phosphor_flutter/phosphor_flutter.dart';

import '../../app/providers.dart';
import '../../core/format.dart';
import '../../core/theme/app_theme.dart';
import '../../core/theme/tokens.dart';
import '../../core/widgets/vibe_widgets.dart';
import '../../domain/models/status.dart';
import '../map/pin_editor.dart';

/// 互动 Tab：戳一戳、事件消息中心、共同标记列表。
class InteractPage extends ConsumerStatefulWidget {
  const InteractPage({super.key});
  @override
  ConsumerState<InteractPage> createState() => _InteractPageState();
}

class _InteractPageState extends ConsumerState<InteractPage> with SingleTickerProviderStateMixin {
  late final _tab = TabController(length: 2, vsync: this);

  @override
  void dispose() {
    _tab.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final v = context.vibes;
    final s = ref.watch(syncProvider);
    return PaperBackdrop(
      child: SafeArea(
        bottom: false,
        child: Column(children: [
          Padding(
            padding: const EdgeInsets.fromLTRB(20, 16, 20, 8),
            child: Row(children: [
              Text('互动', style: Theme.of(context).textTheme.headlineMedium),
              const Spacer(),
              SoftButton(label: '戳一戳', icon: PhosphorIconsFill.handWaving, onTap: () => _poke(context)),
            ]),
          ),
          Padding(
            padding: const EdgeInsets.symmetric(horizontal: 20),
            child: Container(
              decoration: BoxDecoration(color: v.surfaceHigh, borderRadius: BorderRadius.circular(999)),
              child: TabBar(
                controller: _tab,
                dividerColor: Colors.transparent,
                indicatorSize: TabBarIndicatorSize.tab,
                indicator: BoxDecoration(color: AppColors.accent, borderRadius: BorderRadius.circular(999)),
                labelColor: AppColors.onAccent,
                unselectedLabelColor: v.inkSoft,
                labelStyle: const TextStyle(fontWeight: FontWeight.w600),
                tabs: const [Tab(text: '消息'), Tab(text: '共同标记')],
              ),
            ),
          ),
          Expanded(
            child: TabBarView(controller: _tab, children: [
              _EventList(s: s),
              _PinGrid(s: s),
            ]),
          ),
        ]),
      ),
    );
  }

  Future<void> _poke(BuildContext context) async {
    final emoji = await showModalBottomSheet<String>(
      context: context,
      builder: (_) => GlassPanel(
        radius: AppRadii.card,
        padding: EdgeInsets.fromLTRB(20, 20, 20, 24 + MediaQuery.of(context).padding.bottom),
        child: Wrap(spacing: 14, runSpacing: 14, alignment: WrapAlignment.center, children: [
          for (final e in pokeEmojis)
            Squish(onTap: () => Navigator.pop(context, e), child: Container(width: 66, height: 66, alignment: Alignment.center, decoration: BoxDecoration(color: context.vibes.surface.withValues(alpha: 0.7), borderRadius: BorderRadius.circular(AppRadii.small)), child: Text(e, style: const TextStyle(fontSize: 34)))),
        ]),
      ),
    );
    if (emoji == null) return;
    try {
      await ref.read(syncProvider.notifier).sendEvent(EventKind.poke, emoji: emoji);
    } catch (e) {
      if (context.mounted) ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text('发送失败：$e')));
    }
  }
}

class _EventList extends ConsumerWidget {
  const _EventList({required this.s});
  final SyncState s;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final me = ref.read(backendProvider).userId;
    if (s.events.isEmpty) return const CuteEmpty(title: '还没有消息', subtitle: '戳一戳 TA，或者点「我到了」报个平安吧', icon: PhosphorIconsRegular.envelopeSimple);
    final mp = PersonalPalette.byId(s.me?.themeId), pp = PersonalPalette.byId(s.partner?.themeId);
    return ListView.builder(
      padding: const EdgeInsets.fromLTRB(20, 14, 20, 120),
      itemCount: s.events.length,
      itemBuilder: (_, i) {
        final e = s.events[i];
        final mine = e.userId == me;
        final pal = mine ? mp : pp;
        final isSos = e.kind == EventKind.sos;
        final (icon, text) = switch (e.kind) {
          EventKind.arrived => ('🏠', e.text ?? '已安全到达'),
          EventKind.ack => ('✔️', '收到'),
          EventKind.sos => ('🚨', mine ? '你发起了 SOS' : 'TA 发起了 SOS 求助'),
          EventKind.sosCancel => ('🕊️', 'SOS 已取消'),
          EventKind.sosAck => ('🤝', 'SOS 已确认'),
          EventKind.poke => (e.emoji ?? '👋', mine ? '你戳了 TA' : 'TA 戳了你'),
        };
        return StaggerIn(
          index: i,
          child: Align(
            alignment: mine ? Alignment.centerRight : Alignment.centerLeft,
            child: Container(
              margin: const EdgeInsets.only(bottom: 12),
              padding: const EdgeInsets.fromLTRB(14, 10, 14, 10),
              constraints: BoxConstraints(maxWidth: MediaQuery.sizeOf(context).width * 0.78),
              decoration: BoxDecoration(
                gradient: pal.gradient.scale(0.35),
                borderRadius: BorderRadius.only(topLeft: const Radius.circular(16), topRight: const Radius.circular(16), bottomLeft: Radius.circular(mine ? 16 : 4), bottomRight: Radius.circular(mine ? 4 : 16)),
                border: isSos ? Border.all(color: context.vibes.danger, width: 2) : null,
              ),
              child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
                Row(mainAxisSize: MainAxisSize.min, children: [
                  Text(icon, style: const TextStyle(fontSize: 22)),
                  const SizedBox(width: 8),
                  Flexible(child: Text(text, style: const TextStyle(fontWeight: FontWeight.w700))),
                ]),
                const SizedBox(height: 4),
                Text('${e.at.month}/${e.at.day} ${hm(e.at)}', style: TextStyle(fontSize: 12, color: context.vibes.inkSoft)),
                if (e.kind == EventKind.arrived && !mine) ...[
                  const SizedBox(height: 8),
                  SoftButton(label: '收到', height: 36, icon: PhosphorIconsBold.check, onTap: () => ref.read(syncProvider.notifier).sendEvent(EventKind.ack, text: '收到')),
                ],
              ]),
            ),
          ),
        );
      },
    );
  }
}

class _PinGrid extends ConsumerWidget {
  const _PinGrid({required this.s});
  final SyncState s;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final v = context.vibes;
    return Stack(children: [
      if (s.pins.isEmpty)
        const CuteEmpty(title: '还没有共同标记', subtitle: '在地图上长按任意位置，就能留下你们的小秘密', icon: PhosphorIconsRegular.mapPin)
      else
        GridView.builder(
          padding: const EdgeInsets.fromLTRB(20, 14, 20, 120),
          gridDelegate: const SliverGridDelegateWithFixedCrossAxisCount(crossAxisCount: 2, mainAxisSpacing: 14, crossAxisSpacing: 14, childAspectRatio: 0.95),
          itemCount: s.pins.length,
          itemBuilder: (_, i) {
            final p = s.pins[i];
            return StaggerIn(
              index: i,
              child: VibeCard(
                onTap: () => context.go('/'),
                child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
                  Row(children: [
                    Text(p.emoji, style: const TextStyle(fontSize: 34)),
                    const Spacer(),
                    GestureDetector(onTap: () => showPinEditor(context, ref, existing: p), child: Icon(PhosphorIconsRegular.pencilSimple, color: v.inkSoft, size: 20)),
                  ]),
                  const SizedBox(height: 8),
                  Text(p.name, maxLines: 2, overflow: TextOverflow.ellipsis, style: const TextStyle(fontWeight: FontWeight.w600, fontSize: 14)),
                  const SizedBox(height: 4),
                  Expanded(child: Text(p.note.isEmpty ? '没有备注' : p.note, maxLines: 3, overflow: TextOverflow.ellipsis, style: TextStyle(color: v.inkSoft, fontSize: 12))),
                ]),
              ),
            );
          },
        ),
    ]);
  }
}
