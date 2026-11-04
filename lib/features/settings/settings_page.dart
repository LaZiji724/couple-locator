import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import 'package:phosphor_flutter/phosphor_flutter.dart';

import '../../app/providers.dart';
import '../../core/log.dart';
import '../../core/theme/app_theme.dart';
import '../../core/theme/tokens.dart';
import '../../core/widgets/vibe_widgets.dart';
import '../../domain/location/sampling.dart';
import '../../platform/tracker_service.dart';

/// 「我的」Tab：设置页。
class SettingsPage extends ConsumerWidget {
  const SettingsPage({super.key});

  Future<bool> _confirm(BuildContext context, String title, String body, {String ok = '确定'}) async {
    return await showDialog<bool>(
          context: context,
          builder: (_) => AlertDialog(
            title: Text(title),
            content: Text(body),
            actions: [TextButton(onPressed: () => Navigator.pop(context, false), child: const Text('再想想')), TextButton(onPressed: () => Navigator.pop(context, true), child: Text(ok))],
          ),
        ) ??
        false;
  }

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final v = context.vibes;
    final s = ref.watch(syncProvider);
    final store = ref.watch(settingsProvider);
    final notifier = ref.read(settingsProvider.notifier);
    final pal = PersonalPalette.byId(s.me?.themeId);
    if (store == null) return const Center(child: CircularProgressIndicator());
    final retention = store.retentionDays;

    Future<void> setRetention(int d) async {
      await store.setRetentionDays(d);
      notifier.touch();
      try {
        await ref.read(backendProvider).setRetention(d);
        await ref.read(dbProvider).purgeOlderThan(s.couple?.effectiveRetention ?? d);
      } catch (_) {}
    }

    return PaperBackdrop(
      child: SafeArea(
        bottom: false,
        child: ListView(padding: const EdgeInsets.fromLTRB(20, 16, 20, 120), children: [
          Text('我的', style: Theme.of(context).textTheme.headlineMedium),
          const SizedBox(height: 14),
          VibeCard(
            onTap: () => context.push('/profile'),
            child: Row(children: [
              Hero(tag: 'my-avatar', child: AvatarBubble(palette: pal, emoji: s.me?.avatarEmoji, imageUrl: s.me?.avatarUrl, size: 64)),
              const SizedBox(width: 14),
              Expanded(child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
                Text(s.me?.nickname ?? '', style: Theme.of(context).textTheme.titleLarge),
                Text(s.partner == null ? '未配对' : '和 ${s.partner!.nickname} 在一起', style: TextStyle(color: v.inkSoft)),
              ])),
              Icon(PhosphorIconsRegular.caretRight, color: v.inkSoft),
            ]),
          ),
          const SectionTitle('共享'),
          VibeCard(
            child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
              const Text('上报频率', style: TextStyle(fontWeight: FontWeight.w600)),
              const SizedBox(height: 4),
              Text('省电 ×2 间隔 / 均衡 / 精准 ×0.5 间隔', style: TextStyle(color: v.inkSoft, fontSize: 12)),
              const SizedBox(height: 10),
              SegmentedButton<ReportMode>(
                segments: [for (final m in ReportMode.values) ButtonSegment(value: m, label: Text(m.label))],
                selected: {store.mode},
                showSelectedIcon: false,
                onSelectionChanged: (x) async {
                  await store.setMode(x.first);
                  notifier.touch();
                },
              ),
              const Divider(height: 28),
              Row(children: [
                const Text('失联提醒阈值', style: TextStyle(fontWeight: FontWeight.w600)),
                const Spacer(),
                Text('${store.lostMinutes} 分钟', style: TextStyle(color: v.accentText, fontWeight: FontWeight.w600)),
              ]),
              Slider(
                min: 10,
                max: 180,
                divisions: 17,
                value: store.lostMinutes.toDouble().clamp(10, 180),
                onChanged: (x) async {
                  await store.setLostMinutes(x.round());
                  notifier.touch();
                },
              ),
              Text('TA 超过这个时间没有任何心跳且没有暂停共享，会通知你。心跳时间戳是明文（不含位置）。', style: TextStyle(color: v.inkSoft, fontSize: 12)),
            ]),
          ),
          const SectionTitle('数据保留期'),
          VibeCard(
            child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
              SegmentedButton<int>(
                segments: [for (final d in [7, 30, 90, 180]) ButtonSegment(value: d, label: Text('$d 天'))],
                selected: {retention},
                showSelectedIcon: false,
                onSelectionChanged: (x) => setRetention(x.first),
              ),
              const SizedBox(height: 8),
              Text('服务器每天自动清理过期数据；双方各自设置，取较短者生效${s.couple != null ? '（当前生效：${s.couple!.effectiveRetention} 天）' : ''}。', style: TextStyle(color: v.inkSoft, fontSize: 12)),
            ]),
          ),
          const SectionTitle('外观'),
          VibeCard(
            child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
              SegmentedButton<String>(
                segments: const [ButtonSegment(value: 'system', label: Text('跟随系统')), ButtonSegment(value: 'light', label: Text('浅色')), ButtonSegment(value: 'dark', label: Text('深色'))],
                selected: {store.themeMode},
                showSelectedIcon: false,
                onSelectionChanged: (x) async {
                  await store.setThemeMode(x.first);
                  notifier.touch();
                },
              ),
              const SizedBox(height: 14),
              const Text('我的专属颜色', style: TextStyle(fontWeight: FontWeight.w600)),
              const SizedBox(height: 10),
              Wrap(spacing: 12, runSpacing: 12, children: [
                for (final p in PersonalPalette.all)
                  Squish(
                    onTap: () async {
                      final me = s.me;
                      if (me == null) return;
                      await ref.read(backendProvider).upsertProfile(me.copyWithTheme(p.id));
                      ref.invalidate(myProfileProvider);
                      await ref.read(syncProvider.notifier).reload();
                    },
                    child: Container(width: 40, height: 40, decoration: BoxDecoration(shape: BoxShape.circle, gradient: p.gradient, border: Border.all(color: p.id == pal.id ? v.ink : Colors.transparent, width: 3))),
                  ),
              ]),
            ]),
          ),
          const SectionTitle('后台运行'),
          VibeCard(
            padding: EdgeInsets.zero,
            child: Column(children: [
              _Tile(icon: PhosphorIconsRegular.shieldCheck, title: '权限与保活指引', onTap: () => context.push('/onboarding')),
              _Tile(icon: PhosphorIconsRegular.pulse, title: '上报状态与日志', onTap: () => context.push('/diagnostics')),
            ]),
          ),
          const SectionTitle('隐私与安全'),
          VibeCard(
            padding: EdgeInsets.zero,
            child: Column(children: [
              _Tile(icon: PhosphorIconsRegular.key, title: '密钥备份与恢复', onTap: () => context.push('/key-backup')),
              _Tile(
                icon: PhosphorIconsRegular.fingerprint,
                title: '安全码核对',
                subtitle: s.channel?.safetyCode ?? '未配对',
              ),
              _Tile(
                icon: PhosphorIconsRegular.trash,
                title: '清除所有我的数据',
                danger: true,
                onTap: () async {
                  if (!await _confirm(context, '清除我的所有数据？', '会删除服务器和本机上我的位置、状态、事件、标记，不会解除配对。', ok: '清除')) return;
                  await ref.read(backendProvider).wipeMyData();
                  await ref.read(dbProvider).wipeAll();
                  if (context.mounted) ScaffoldMessenger.of(context).showSnackBar(const SnackBar(content: Text('已清除')));
                },
              ),
            ]),
          ),
          const SectionTitle('账号'),
          VibeCard(
            padding: EdgeInsets.zero,
            child: Column(children: [
              if (s.paired)
                _Tile(
                  icon: PhosphorIconsRegular.heartBreak,
                  title: '解除配对',
                  danger: true,
                  onTap: () async {
                    if (!await _confirm(context, '解除配对并删除历史？', '解除后你们将无法互相看到位置，双方的位置、事件和共同标记都会被删除。此操作无法撤销。', ok: '解除')) return;
                    await ref.read(backendProvider).unpair(deleteHistory: true);
                    await ref.read(dbProvider).wipeAll();
                    await TrackerService.instance.stop();
                    await ref.read(syncProvider.notifier).reload();
                  },
                ),
              _Tile(
                icon: PhosphorIconsRegular.signOut,
                title: '退出登录',
                onTap: () async {
                  await TrackerService.instance.stop();
                  await ref.read(backendProvider).signOut();
                },
              ),
            ]),
          ),
        ]),
      ),
    );
  }
}

class _Tile extends StatelessWidget {
  const _Tile({required this.icon, required this.title, this.subtitle, this.onTap, this.danger = false});
  final IconData icon;
  final String title;
  final String? subtitle;
  final VoidCallback? onTap;
  final bool danger;
  @override
  Widget build(BuildContext context) {
    final v = context.vibes;
    return ListTile(
      leading: Icon(icon, color: danger ? v.danger : v.accentText),
      title: Text(title, style: TextStyle(color: danger ? v.danger : v.ink, fontWeight: FontWeight.w700)),
      subtitle: subtitle == null ? null : Text(subtitle!, style: TextStyle(color: v.inkSoft)),
      trailing: onTap == null ? null : Icon(PhosphorIconsRegular.caretRight, color: v.inkSoft, size: 18),
      onTap: onTap,
    );
  }
}

/// 上报状态与日志页。
class DiagnosticsPage extends StatelessWidget {
  const DiagnosticsPage({super.key});
  @override
  Widget build(BuildContext context) {
    final v = context.vibes;
    return Scaffold(
      appBar: AppBar(title: const Text('上报状态与日志')),
      body: PaperBackdrop(
        child: SafeArea(
          child: ValueListenableBuilder<List<String>>(
            valueListenable: AppLog.entries,
            builder: (_, lines, _) => ListView(padding: const EdgeInsets.all(20), children: [
              VibeCard(
                child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
                  Text('最近一次成功上报', style: TextStyle(color: v.inkSoft)),
                  Text(AppLog.lastUploadOk?.replaceFirst('T', ' ').substring(0, 19) ?? '（本次启动尚无；后台服务的记录在服务端 diag_logs）', style: const TextStyle(fontWeight: FontWeight.w600)),
                  const SizedBox(height: 12),
                  Text('最近一次失败原因', style: TextStyle(color: v.inkSoft)),
                  Text(AppLog.lastUploadError ?? '无', style: TextStyle(fontWeight: FontWeight.w600, color: AppLog.lastUploadError == null ? v.ink : v.danger)),
                ]),
              ),
              const SectionTitle('日志（已隐去坐标）'),
              for (final l in lines.reversed) Padding(padding: const EdgeInsets.only(bottom: 4), child: Text(l, style: TextStyle(fontSize: 12, fontFamily: 'monospace', color: v.inkSoft))),
              if (lines.isEmpty) Text('暂无日志', style: TextStyle(color: v.inkSoft)),
            ]),
          ),
        ),
      ),
    );
  }
}
