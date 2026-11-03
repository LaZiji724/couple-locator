import 'dart:async';

import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import 'package:phosphor_flutter/phosphor_flutter.dart';

import '../../app/providers.dart';
import '../../core/theme/app_theme.dart';
import '../../core/theme/motion.dart';
import '../../core/theme/tokens.dart';
import '../../core/widgets/vibe_widgets.dart';
import '../../platform/lost_checker.dart';
import '../../platform/permissions.dart';
import '../../platform/tracker_service.dart';
import '../history/history_page.dart';
import '../interact/interact_page.dart';
import '../map/map_page.dart';
import '../settings/settings_page.dart';

class HomeShell extends ConsumerStatefulWidget {
  const HomeShell({super.key});
  @override
  ConsumerState<HomeShell> createState() => _HomeShellState();
}

class _HomeShellState extends ConsumerState<HomeShell> {
  int _i = 0;
  Timer? _lost;

  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addPostFrameCallback((_) async {
      // 已配对 + 有定位权限 → 启动后台上报
      if (await PermissionService.hasLocation()) {
        await TrackerService.instance.start();
      }
    });
    _lost = Timer.periodic(const Duration(minutes: 1), (_) => _checkLost());
  }

  Future<void> _checkLost() async {
    final store = ref.read(settingsProvider);
    if (store == null) return;
    await LostChecker(backend: ref.read(backendProvider), settings: store, db: ref.read(dbProvider), keys: ref.read(keyStoreProvider)).check();
  }

  @override
  void dispose() {
    _lost?.cancel();
    super.dispose();
  }

  static const _tabs = [
    (PhosphorIconsRegular.mapTrifold, PhosphorIconsFill.mapTrifold, '地图'),
    (PhosphorIconsRegular.path, PhosphorIconsFill.path, '轨迹'),
    (PhosphorIconsRegular.heart, PhosphorIconsFill.heart, '互动'),
    (PhosphorIconsRegular.userCircle, PhosphorIconsFill.userCircle, '我的'),
  ];

  @override
  Widget build(BuildContext context) {
    // 收到对方 SOS 且未确认 → 全屏警报
    ref.listen(syncProvider.select((s) => s.pendingSos), (prev, next) {
      if (next != null && prev == null) context.push('/sos-alert');
    });
    final v = context.vibes;
    final bottom = MediaQuery.of(context).padding.bottom;
    return Scaffold(
      extendBody: true,
      body: IndexedStack(index: _i, children: [
        const MapPage(),
        _i == 1 ? const HistoryPage() : const SizedBox.shrink(),
        const InteractPage(),
        const SettingsPage(),
      ]),
      bottomNavigationBar: Padding(
        padding: EdgeInsets.fromLTRB(20, 0, 20, bottom + 12),
        child: GlassPanel(
          radius: 999,
          padding: const EdgeInsets.all(6),
          child: Row(children: [
            for (final (idx, t) in _tabs.indexed)
              Expanded(
                child: Squish(
                  onTap: () => setState(() => _i = idx),
                  child: AnimatedContainer(
                    duration: Motion.of(context, Motion.normal),
                    curve: Motion.spring,
                    padding: const EdgeInsets.symmetric(vertical: 10),
                    decoration: BoxDecoration(gradient: _i == idx ? AppColors.sunrise : null, borderRadius: BorderRadius.circular(999)),
                    child: Column(mainAxisSize: MainAxisSize.min, children: [
                      AnimatedScale(scale: _i == idx ? 1.12 : 1, duration: Motion.of(context, Motion.normal), curve: Motion.spring, child: Icon(_i == idx ? t.$2 : t.$1, size: 24, color: _i == idx ? AppColors.onGradient : v.inkSoft)),
                      const SizedBox(height: 2),
                      Text(t.$3, style: TextStyle(fontSize: 11.5, fontWeight: FontWeight.w800, color: _i == idx ? AppColors.onGradient : v.inkSoft)),
                    ]),
                  ),
                ),
              ),
          ]),
        ),
      ),
    );
  }
}
