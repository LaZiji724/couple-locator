import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import 'package:phosphor_flutter/phosphor_flutter.dart';
import 'package:url_launcher/url_launcher.dart';

import '../../app/providers.dart';
import '../../core/format.dart';
import '../../core/theme/app_theme.dart';
import '../../core/theme/tokens.dart';
import '../../core/widgets/motion_icon.dart';
import '../../core/widgets/vibe_widgets.dart';
import '../../domain/models/status.dart';

/// 对方详情卡：电量、状态、更新时间、戳一戳、看轨迹、导航。
Future<void> showPartnerSheet(BuildContext context) {
  return showModalBottomSheet(
    context: context,
    isScrollControlled: true,
    builder: (_) => UncontrolledProviderScope(container: ProviderScope.containerOf(context), child: const _PartnerSheet()),
  );
}

class _PartnerSheet extends ConsumerWidget {
  const _PartnerSheet();

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final s = ref.watch(syncProvider);
    final v = context.vibes;
    final pal = PersonalPalette.byId(s.partner?.themeId);
    final st = s.partnerStatus;
    final pt = s.partnerPoint;
    final paused = s.partnerPresence?.isPausedNow(DateTime.now()) ?? false;
    final name = (s.partner?.nickname.isNotEmpty ?? false) ? s.partner!.nickname : 'TA';
    return GlassPanel(
      radius: AppRadii.card,
      padding: EdgeInsets.fromLTRB(20, 14, 20, 20 + MediaQuery.of(context).padding.bottom),
      child: Column(mainAxisSize: MainAxisSize.min, children: [
        Container(width: 40, height: 5, decoration: BoxDecoration(color: v.inkSoft.withValues(alpha: 0.4), borderRadius: BorderRadius.circular(4))),
        const SizedBox(height: 16),
        Row(children: [
          Hero(tag: 'partner-avatar-sheet', child: AvatarBubble(palette: pal, emoji: s.partner?.avatarEmoji, imageUrl: s.partner?.avatarUrl, size: 68, dimmed: paused)),
          const SizedBox(width: 14),
          Expanded(
            child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
              Text(name, style: Theme.of(context).textTheme.headlineSmall),
              const SizedBox(height: 4),
              Text(paused ? '对方暂停了共享' : (pt != null ? agoText(pt.ts) : '暂无位置'), style: TextStyle(color: paused ? v.accentText : v.inkSoft)),
            ]),
          ),
        ]),
        const SizedBox(height: 16),
        if (st != null)
          Row(children: [
            Expanded(child: _Stat(icon: MotionIcon(state: st.motion, size: 24, color: pal.start), label: motionLabel(st.motion))),
            const SizedBox(width: 10),
            Expanded(child: _Stat(icon: Icon(st.charging ? PhosphorIconsFill.batteryCharging : PhosphorIconsFill.batteryHigh, color: st.lowBattery ? v.danger : AppColors.mint, size: 24), label: '${st.battery}%${st.charging ? ' 充电中' : ''}${st.lowBattery ? ' 低电量' : ''}', danger: st.lowBattery)),
            const SizedBox(width: 10),
            Expanded(child: _Stat(icon: Icon(st.network == 'wifi' ? PhosphorIconsFill.wifiHigh : (st.network == 'cellular' ? PhosphorIconsFill.cellSignalHigh : PhosphorIconsFill.wifiSlash), color: context.vibes.inkSoft, size: 24), label: '${st.network == 'wifi' ? 'Wi-Fi' : st.network == 'cellular' ? '蜂窝' : '无网络'}${st.lowPower ? '，省电' : ''}')),
          ])
        else
          Text('还没有收到对方的状态信息', style: TextStyle(color: v.inkSoft)),
        const SizedBox(height: 18),
        Row(children: [
          Expanded(child: PrimaryButton(label: '戳一戳', height: 48, icon: PhosphorIconsFill.handWaving, onTap: () => _poke(context, ref))),
          const SizedBox(width: 10),
          SoftButton(label: '看轨迹', icon: PhosphorIconsRegular.path, onTap: () {
            Navigator.pop(context);
            context.go('/history');
          }),
          const SizedBox(width: 10),
          if (pt != null)
            SoftButton(label: '导航', icon: PhosphorIconsRegular.navigationArrow, onTap: () => _nav(pt.lat, pt.lng)),
        ]),
      ]),
    );
  }

  Future<void> _nav(double lat, double lng) async {
    // 使用高德 URI；需要 GCJ-02
    final uri = Uri.parse('https://uri.amap.com/navigation?to=$lng,$lat,TA&coordinate=wgs84&mode=car&callnative=1');
    await launchUrl(uri, mode: LaunchMode.externalApplication);
  }

  Future<void> _poke(BuildContext context, WidgetRef ref) async {
    final emoji = await showModalBottomSheet<String>(
      context: context,
      builder: (_) => const _PokePicker(),
    );
    if (emoji == null) return;
    try {
      await ref.read(syncProvider.notifier).sendEvent(EventKind.poke, emoji: emoji);
      if (context.mounted) {
        ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text('已戳 TA $emoji')));
        Navigator.pop(context);
      }
    } catch (e) {
      if (context.mounted) ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text('发送失败：$e')));
    }
  }
}

class _PokePicker extends StatelessWidget {
  const _PokePicker();
  @override
  Widget build(BuildContext context) {
    return GlassPanel(
      radius: AppRadii.card,
      padding: EdgeInsets.fromLTRB(20, 20, 20, 24 + MediaQuery.of(context).padding.bottom),
      child: Column(mainAxisSize: MainAxisSize.min, children: [
        Text('选一个表情戳 TA', style: Theme.of(context).textTheme.titleLarge),
        const SizedBox(height: 16),
        GridView.count(
          crossAxisCount: 4,
          shrinkWrap: true,
          physics: const NeverScrollableScrollPhysics(),
          mainAxisSpacing: 12,
          crossAxisSpacing: 12,
          children: [
            for (final (i, e) in pokeEmojis.indexed)
              StaggerIn(
                index: i,
                child: Squish(
                  onTap: () => Navigator.pop(context, e),
                  child: Container(
                    decoration: BoxDecoration(color: context.vibes.surface.withValues(alpha: 0.7), borderRadius: BorderRadius.circular(AppRadii.small)),
                    alignment: Alignment.center,
                    child: Text(e, style: const TextStyle(fontSize: 34)),
                  ),
                ),
              ),
          ],
        ),
      ]),
    );
  }
}

class _Stat extends StatelessWidget {
  const _Stat({required this.icon, required this.label, this.danger = false});
  final Widget icon;
  final String label;
  final bool danger;
  @override
  Widget build(BuildContext context) {
    final v = context.vibes;
    return Container(
      padding: const EdgeInsets.symmetric(vertical: 12, horizontal: 8),
      decoration: BoxDecoration(color: (danger ? v.danger : v.surface).withValues(alpha: danger ? 0.15 : 0.7), borderRadius: BorderRadius.circular(AppRadii.small)),
      child: Column(children: [icon, const SizedBox(height: 6), Text(label, textAlign: TextAlign.center, style: TextStyle(fontSize: 12, color: danger ? v.danger : v.ink, fontWeight: FontWeight.w600))]),
    );
  }
}
