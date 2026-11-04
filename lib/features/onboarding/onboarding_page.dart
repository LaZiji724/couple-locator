import 'dart:io';
import 'dart:math' as math;

import 'package:device_info_plus/device_info_plus.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:phosphor_flutter/phosphor_flutter.dart';

import '../../app/providers.dart';
import '../../core/theme/app_theme.dart';
import '../../core/theme/motion.dart';
import '../../core/theme/tokens.dart';
import '../../core/widgets/vibe_widgets.dart';
import '../../platform/permissions.dart';
import 'rom_guides.dart';

class _Step {
  const _Step(this.emoji, this.title, this.body, this.button, this.perm, {this.androidOnly = false, this.manual = false});
  final String emoji;
  final String title;
  final String body;
  final String button;
  final PermStep perm;
  final bool androidOnly;
  final bool manual; // 无法自动检测，需用户手动确认（如自启动）
}

const _steps = [
  _Step('📍', '先让我知道你在哪', '开启定位权限，才能把你的位置安全地分享给 TA。位置会端到端加密，服务器也看不懂。', '允许定位', PermStep.location),
  _Step('🌙', '锁屏后也要在线', '请选择「始终允许」，这样即使锁屏、切到后台，TA 也能看到你的最新位置。', '升级为「始终允许」', PermStep.always),
  _Step('🔔', '不错过 TA 的消息', '开启通知，才能收到 TA 的戳一戳、到家提醒和紧急求助。', '开启通知', PermStep.notification),
  _Step('🔋', '别让系统把我睡着', '加入电池优化白名单，后台共享会更稳定，耗电也不会明显增加。', '加入白名单', PermStep.battery, androidOnly: true),
  _Step('🚀', '开机就自动待命', '在系统设置里允许「自启动」和「后台高耗电」，并在多任务里锁定本应用。', '查看设置指引', PermStep.autostart, androidOnly: true, manual: true),
];

class OnboardingPage extends ConsumerStatefulWidget {
  const OnboardingPage({super.key, required this.onDone});
  final VoidCallback onDone;
  @override
  ConsumerState<OnboardingPage> createState() => _OnboardingPageState();
}

class _OnboardingPageState extends ConsumerState<OnboardingPage> with WidgetsBindingObserver {
  final _pc = PageController();
  int _i = 0;
  final _granted = <PermStep>{};
  late final List<_Step> _list = _steps.where((s) => !s.androidOnly || Platform.isAndroid).toList();

  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addObserver(this);
    _refresh();
  }

  @override
  void dispose() {
    WidgetsBinding.instance.removeObserver(this);
    _pc.dispose();
    super.dispose();
  }

  @override
  void didChangeAppLifecycleState(AppLifecycleState state) {
    if (state == AppLifecycleState.resumed) _refresh(); // 从系统设置回来后重新检测
  }

  Future<void> _refresh() async {
    final g = <PermStep>{};
    if (await PermissionService.hasLocation()) g.add(PermStep.location);
    if (await PermissionService.hasAlways()) g.add(PermStep.always);
    if (await PermissionService.hasNotification()) g.add(PermStep.notification);
    if (await PermissionService.hasBatteryWhitelist()) g.add(PermStep.battery);
    if (mounted) setState(() => _granted..clear()..addAll(g));
  }

  Future<void> _act(_Step s) async {
    switch (s.perm) {
      case PermStep.location:
        await PermissionService.requestLocation();
      case PermStep.always:
        await PermissionService.requestAlways();
      case PermStep.notification:
        await PermissionService.requestNotification();
      case PermStep.battery:
        await PermissionService.requestBatteryWhitelist();
      case PermStep.autostart:
        if (!mounted) return;
        await Navigator.push(context, MaterialPageRoute(builder: (_) => const RomGuidePage()));
        _granted.add(PermStep.autostart);
    }
    await _refresh();
    if (_granted.contains(s.perm)) _next();
  }

  void _next() {
    if (_i >= _list.length - 1) {
      _finish();
    } else {
      _pc.nextPage(duration: Motion.of(context, Motion.slow), curve: Motion.spring);
    }
  }

  Future<void> _finish() async {
    await ref.read(settingsProvider)?.setOnboarded(true);
    ref.read(settingsProvider.notifier).touch();
    widget.onDone();
  }

  @override
  Widget build(BuildContext context) {
    final v = context.vibes;
    return Scaffold(
      body: PaperBackdrop(
        child: SafeArea(
          child: Column(children: [
            Align(alignment: Alignment.centerRight, child: TextButton(onPressed: _finish, child: Text('跳过', style: TextStyle(color: v.inkSoft)))),
            Expanded(
              child: PageView.builder(
                controller: _pc,
                itemCount: _list.length,
                onPageChanged: (i) => setState(() => _i = i),
                itemBuilder: (_, i) {
                  final s = _list[i];
                  final done = _granted.contains(s.perm);
                  return Padding(
                    padding: const EdgeInsets.symmetric(horizontal: 28),
                    child: Column(mainAxisAlignment: MainAxisAlignment.center, children: [
                      _Illustration(emoji: s.emoji, active: _i == i, done: done),
                      const SizedBox(height: 36),
                      Text(s.title, textAlign: TextAlign.center, style: Theme.of(context).textTheme.headlineMedium),
                      const SizedBox(height: 12),
                      Text(s.body, textAlign: TextAlign.center, style: TextStyle(color: v.inkSoft, fontSize: 15, height: 1.5)),
                      const SizedBox(height: 32),
                      if (done && !s.manual)
                        const _DoneChip()
                      else
                        PrimaryButton(label: s.button, onTap: () => _act(s)),
                      const SizedBox(height: 12),
                      SoftButton(label: '去系统设置', icon: PhosphorIconsRegular.gearSix, onTap: PermissionService.openSystemSettings),
                    ]),
                  );
                },
              ),
            ),
            Padding(
              padding: const EdgeInsets.fromLTRB(28, 8, 28, 20),
              child: Row(children: [
                Row(children: [
                  for (var i = 0; i < _list.length; i++)
                    AnimatedContainer(
                      duration: Motion.of(context, Motion.normal),
                      curve: Motion.spring,
                      margin: const EdgeInsets.only(right: 6),
                      width: i == _i ? 28 : 8,
                      height: 8,
                      decoration: BoxDecoration(color: i == _i ? AppColors.accent : v.inkSoft.withValues(alpha: 0.3), borderRadius: BorderRadius.circular(4)),
                    ),
                ]),
                const Spacer(),
                SoftButton(label: _i == _list.length - 1 ? '完成' : '下一步', onTap: _next),
              ]),
            ),
          ]),
        ),
      ),
    );
  }
}

class _DoneChip extends StatelessWidget {
  const _DoneChip();
  @override
  Widget build(BuildContext context) => Container(
        height: 52,
        padding: const EdgeInsets.symmetric(horizontal: 24),
        decoration: BoxDecoration(color: AppColors.mint.withValues(alpha: 0.16), borderRadius: BorderRadius.circular(AppRadii.small)),
        child: Row(mainAxisSize: MainAxisSize.min, children: [
          const Icon(PhosphorIconsFill.checkCircle, color: AppColors.mint),
          const SizedBox(width: 8),
          Text('已开启', style: TextStyle(fontWeight: FontWeight.w600, color: context.vibes.ink)),
        ]),
      );
}

/// 动画插图：中性圆底 + 外扩雷达波 + 悬浮 emoji。
class _Illustration extends StatefulWidget {
  const _Illustration({required this.emoji, required this.active, required this.done});
  final String emoji;
  final bool active;
  final bool done;
  @override
  State<_Illustration> createState() => _IllustrationState();
}

class _IllustrationState extends State<_Illustration> with SingleTickerProviderStateMixin {
  late final _c = AnimationController(vsync: this, duration: const Duration(seconds: 3))..repeat();

  @override
  void dispose() {
    _c.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final reduced = Motion.reduced(context);
    return SizedBox(
      width: 240,
      height: 240,
      child: AnimatedBuilder(
        animation: _c,
        builder: (_, _) {
          final t = reduced ? 0.3 : _c.value;
          return Stack(alignment: Alignment.center, children: [
            for (var k = 0; k < 3; k++)
              Builder(builder: (_) {
                final p = (t + k / 3) % 1;
                return Container(
                  width: 120 + 120 * p,
                  height: 120 + 120 * p,
                  decoration: BoxDecoration(shape: BoxShape.circle, border: Border.all(color: AppColors.accent.withValues(alpha: 0.3 * (1 - p)), width: 1)),
                );
              }),
            Container(
              width: 130,
              height: 130,
              decoration: BoxDecoration(shape: BoxShape.circle, color: context.vibes.surface, border: Border.all(color: context.vibes.hairline, width: 0.5)),
              alignment: Alignment.center,
              child: Transform.translate(
                offset: Offset(0, reduced ? 0 : -6 * math.sin(t * 2 * math.pi)),
                child: Text(widget.emoji, style: const TextStyle(fontSize: 62)),
              ),
            ),
            if (widget.done) const Positioned(right: 40, top: 40, child: CircleAvatar(radius: 18, backgroundColor: AppColors.mint, child: Icon(PhosphorIconsBold.check, color: Colors.white))),
          ]);
        },
      ),
    );
  }
}

Future<String> detectBrand() async {
  if (!Platform.isAndroid) return 'other';
  final info = await DeviceInfoPlugin().androidInfo;
  return info.manufacturer.toLowerCase();
}
