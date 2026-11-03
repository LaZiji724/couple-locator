import 'dart:async';

import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:mobile_scanner/mobile_scanner.dart';
import 'package:phosphor_flutter/phosphor_flutter.dart';
import 'package:qr_flutter/qr_flutter.dart';

import '../../app/providers.dart';
import '../../core/theme/app_theme.dart';
import '../../core/theme/tokens.dart';
import '../../core/widgets/effects.dart';
import '../../core/widgets/vibe_widgets.dart';

/// 配对页：我来邀请（邀请码 + 二维码 + 10 分钟倒计时）/ 我有邀请码（6 位输入 + 扫码）。
class PairingPage extends ConsumerStatefulWidget {
  const PairingPage({super.key});
  @override
  ConsumerState<PairingPage> createState() => _PairingPageState();
}

class _PairingPageState extends ConsumerState<PairingPage> with SingleTickerProviderStateMixin {
  late final _tab = TabController(length: 2, vsync: this);
  String? _code;
  DateTime? _expires;
  Timer? _tick;
  bool _busy = false;
  final _input = TextEditingController();

  @override
  void dispose() {
    _tick?.cancel();
    _tab.dispose();
    super.dispose();
  }

  Future<void> _create() async {
    setState(() => _busy = true);
    try {
      final c = await ref.read(backendProvider).createInvite();
      setState(() {
        _code = c;
        _expires = DateTime.now().add(const Duration(minutes: 10));
      });
      _tick?.cancel();
      _tick = Timer.periodic(const Duration(seconds: 1), (_) {
        if (mounted) setState(() {});
      });
    } catch (e) {
      _toast('生成失败：$e');
    } finally {
      if (mounted) setState(() => _busy = false);
    }
  }

  void _toast(String m) => ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text(m)));

  Future<void> _redeem(String code) async {
    if (code.length != 6) {
      _toast('请输入 6 位邀请码');
      return;
    }
    setState(() => _busy = true);
    try {
      await ref.read(backendProvider).redeemInvite(code);
      await ref.read(syncProvider.notifier).reload();
    } catch (e) {
      final m = e.toString();
      _toast(m.contains('invalid or expired') ? '邀请码无效或已过期' : m.contains('already paired') ? '你或对方已经配对过了' : m.contains('own code') ? '不能使用自己的邀请码' : '配对失败：$m');
    } finally {
      if (mounted) setState(() => _busy = false);
    }
  }

  Future<void> _scan() async {
    final code = await Navigator.push<String>(context, MaterialPageRoute(builder: (_) => const _ScanPage()));
    if (code != null) {
      _input.text = code;
      _redeem(code);
    }
  }

  @override
  Widget build(BuildContext context) {
    final v = context.vibes;
    // 对方输入了我的邀请码后，couple 出现，由路由门自动跳转到庆祝页
    final remain = _expires == null ? null : _expires!.difference(DateTime.now());
    final expired = remain != null && remain.isNegative;
    return Scaffold(
      body: FlowingBlobs(
        child: SafeArea(
          child: Column(children: [
            Padding(
              padding: const EdgeInsets.fromLTRB(24, 20, 24, 8),
              child: Row(children: [
                Expanded(child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
                  Text('和 TA 配对', style: Theme.of(context).textTheme.headlineMedium),
                  const SizedBox(height: 4),
                  Text('一个账号同一时间只能和一个人配对', style: TextStyle(color: v.inkSoft)),
                ])),
                IconButton(onPressed: () => ref.read(backendProvider).signOut(), icon: const Icon(PhosphorIconsRegular.signOut), tooltip: '退出登录'),
              ]),
            ),
            const SizedBox(height: 8),
            Padding(
              padding: const EdgeInsets.symmetric(horizontal: 24),
              child: Container(
                decoration: BoxDecoration(color: v.surface.withValues(alpha: 0.7), borderRadius: BorderRadius.circular(999)),
                child: TabBar(
                  controller: _tab,
                  dividerColor: Colors.transparent,
                  indicatorSize: TabBarIndicatorSize.tab,
                  indicator: BoxDecoration(gradient: AppColors.sunrise, borderRadius: BorderRadius.circular(999)),
                  labelColor: AppColors.onGradient,
                  unselectedLabelColor: v.inkSoft,
                  labelStyle: const TextStyle(fontWeight: FontWeight.w800),
                  tabs: const [Tab(text: '我来邀请'), Tab(text: '我有邀请码')],
                ),
              ),
            ),
            Expanded(
              child: TabBarView(controller: _tab, children: [
                // 邀请
                ListView(padding: const EdgeInsets.all(24), children: [
                  VibeCard(
                    padding: const EdgeInsets.all(24),
                    child: Column(children: [
                      if (_code == null) ...[
                        const Text('🎟️', style: TextStyle(fontSize: 64)),
                        const SizedBox(height: 8),
                        Text('生成一个 10 分钟有效的一次性邀请码，发给 TA 或让 TA 扫码', textAlign: TextAlign.center, style: TextStyle(color: v.inkSoft)),
                        const SizedBox(height: 20),
                        GradientButton(label: '生成邀请码', busy: _busy, onTap: _busy ? null : _create),
                      ] else ...[
                        Row(mainAxisAlignment: MainAxisAlignment.center, children: [
                          for (final (i, ch) in _code!.split('').indexed)
                            StaggerIn(
                              index: i,
                              child: Container(
                                width: 42,
                                height: 56,
                                margin: const EdgeInsets.symmetric(horizontal: 3),
                                alignment: Alignment.center,
                                decoration: BoxDecoration(gradient: AppColors.sunrise, borderRadius: BorderRadius.circular(16)),
                                child: Text(ch, style: const TextStyle(fontFamily: AppTheme.displayFont, fontSize: 30, color: AppColors.onGradient)),
                              ),
                            ),
                        ]),
                        const SizedBox(height: 18),
                        Container(
                          padding: const EdgeInsets.all(12),
                          decoration: BoxDecoration(color: Colors.white, borderRadius: BorderRadius.circular(20)),
                          child: QrImageView(data: 'couple-locator://pair/$_code', size: 180, eyeStyle: const QrEyeStyle(eyeShape: QrEyeShape.circle, color: Color(0xFF3A1030)), dataModuleStyle: const QrDataModuleStyle(dataModuleShape: QrDataModuleShape.circle, color: Color(0xFF3A1030))),
                        ),
                        const SizedBox(height: 14),
                        Text(expired ? '邀请码已过期' : '剩余 ${remain!.inMinutes}:${(remain.inSeconds % 60).toString().padLeft(2, '0')}', style: TextStyle(color: expired ? v.danger : v.inkSoft, fontWeight: FontWeight.w700)),
                        const SizedBox(height: 14),
                        Row(children: [
                          Expanded(child: SoftButton(label: '复制', icon: PhosphorIconsRegular.copy, onTap: () {
                            Clipboard.setData(ClipboardData(text: _code!));
                            _toast('已复制邀请码');
                          })),
                          const SizedBox(width: 10),
                          Expanded(child: SoftButton(label: '重新生成', icon: PhosphorIconsRegular.arrowsClockwise, onTap: _busy ? null : _create)),
                        ]),
                        const SizedBox(height: 10),
                        Text('等待 TA 输入…配对成功会自动跳转', style: TextStyle(color: v.inkSoft, fontSize: 12.5)),
                      ],
                    ]),
                  ),
                ]),
                // 输入
                ListView(padding: const EdgeInsets.all(24), children: [
                  VibeCard(
                    padding: const EdgeInsets.all(24),
                    child: Column(children: [
                      const Text('💌', style: TextStyle(fontSize: 64)),
                      const SizedBox(height: 12),
                      TextField(
                        controller: _input,
                        keyboardType: TextInputType.number,
                        maxLength: 6,
                        textAlign: TextAlign.center,
                        style: const TextStyle(fontFamily: AppTheme.displayFont, fontSize: 32, letterSpacing: 8),
                        inputFormatters: [FilteringTextInputFormatter.digitsOnly],
                        decoration: const InputDecoration(hintText: '000000', counterText: ''),
                        onSubmitted: _redeem,
                      ),
                      const SizedBox(height: 16),
                      GradientButton(label: '配对', busy: _busy, onTap: _busy ? null : () => _redeem(_input.text.trim())),
                      const SizedBox(height: 12),
                      SoftButton(label: '扫码', icon: PhosphorIconsRegular.qrCode, onTap: _scan),
                    ]),
                  ),
                ]),
              ]),
            ),
          ]),
        ),
      ),
    );
  }
}

class _ScanPage extends StatefulWidget {
  const _ScanPage();
  @override
  State<_ScanPage> createState() => _ScanPageState();
}

class _ScanPageState extends State<_ScanPage> {
  bool _done = false;
  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(title: const Text('扫描 TA 的二维码')),
      body: MobileScanner(onDetect: (cap) {
        if (_done) return;
        final raw = cap.barcodes.firstOrNull?.rawValue ?? '';
        final m = RegExp(r'pair/(\d{6})').firstMatch(raw);
        if (m != null) {
          _done = true;
          Navigator.pop(context, m.group(1));
        }
      }),
    );
  }
}

/// 配对成功庆祝页：两个头像从两侧飞入相撞冒爱心，随后展示安全码供核对（防中间人）。
class PairedCelebrationPage extends ConsumerStatefulWidget {
  const PairedCelebrationPage({super.key, required this.onContinue});
  final VoidCallback onContinue;
  @override
  ConsumerState<PairedCelebrationPage> createState() => _PairedCelebrationPageState();
}

class _PairedCelebrationPageState extends ConsumerState<PairedCelebrationPage> with SingleTickerProviderStateMixin {
  late final _c = AnimationController(vsync: this, duration: const Duration(milliseconds: 1400))..forward();

  @override
  void dispose() {
    _c.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final s = ref.watch(syncProvider);
    final v = context.vibes;
    final w = MediaQuery.sizeOf(context).width;
    return Scaffold(
      body: FlowingBlobs(
        child: SafeArea(
          child: Padding(
            padding: const EdgeInsets.all(24),
            child: Column(children: [
              const Spacer(),
              SizedBox(
                height: 130,
                child: AnimatedBuilder(
                  animation: _c,
                  builder: (_, _) {
                    final t = Curves.elasticOut.transform(_c.value.clamp(0.0, 1.0));
                    final dx = (1 - t) * (w / 2);
                    return Stack(alignment: Alignment.center, children: [
                      Transform.translate(offset: Offset(-52 - dx, 0), child: AvatarBubble(palette: PersonalPalette.byId(s.me?.themeId), emoji: s.me?.avatarEmoji, imageUrl: s.me?.avatarUrl, size: 96)),
                      Transform.translate(offset: Offset(52 + dx, 0), child: AvatarBubble(palette: PersonalPalette.byId(s.partner?.themeId), emoji: s.partner?.avatarEmoji, imageUrl: s.partner?.avatarUrl, size: 96)),
                      if (_c.value > 0.55) const Positioned(top: 0, child: SizedBox(width: 200, height: 120, child: HeartBurst(count: 10))),
                    ]);
                  },
                ),
              ),
              const SizedBox(height: 24),
              Text('配对成功！', style: Theme.of(context).textTheme.headlineMedium),
              const SizedBox(height: 8),
              Text('你们现在可以互相看到位置啦', style: TextStyle(color: v.inkSoft)),
              const SizedBox(height: 28),
              VibeCard(
                child: Column(children: [
                  Text('安全码（请和 TA 当面核对）', style: TextStyle(color: v.inkSoft, fontWeight: FontWeight.w700)),
                  const SizedBox(height: 10),
                  Text(s.channel?.safetyCode ?? '等待对方密钥…', textAlign: TextAlign.center, style: const TextStyle(fontFamily: AppTheme.displayFont, fontSize: 26, letterSpacing: 2)),
                  const SizedBox(height: 8),
                  Text('两部手机上显示的数字完全一致，说明没有被第三方窃听。', textAlign: TextAlign.center, style: TextStyle(color: v.inkSoft, fontSize: 12.5)),
                ]),
              ),
              const Spacer(),
              GradientButton(label: '开始使用', onTap: widget.onContinue),
            ]),
          ),
        ),
      ),
    );
  }
}
