import 'dart:async';

import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../core/theme/app_theme.dart';
import '../platform/notifications.dart';
import 'router.dart';

/// 一条应用内消息提示。
class AppNotice {
  const AppNotice({required this.emoji, required this.title, required this.body, this.tab, this.urgent = false});
  final String emoji;
  final String title;
  final String body;

  /// 点击后跳到的底部分栏（0 地图 / 1 轨迹 / 2 互动 / 3 我的），null 不跳转。
  final int? tab;
  final bool urgent;
}

/// 底部分栏当前选中项（横幅 / 通知点击后切换分栏用）。
class HomeTabNotifier extends Notifier<int> {
  @override
  int build() => 0;
  void set(int i) => state = i;
}

final homeTabProvider = NotifierProvider<HomeTabNotifier, int>(HomeTabNotifier.new);

/// 消息提示中心：前台弹顶部横幅，后台走本地通知。
class NoticeCenter {
  final _c = StreamController<AppNotice>.broadcast();
  Stream<AppNotice> get stream => _c.stream;

  static bool get _foreground {
    final s = WidgetsBinding.instance.lifecycleState;
    return s == null || s == AppLifecycleState.resumed;
  }

  void push(AppNotice n, {required int notifId}) {
    if (_foreground && !n.urgent) {
      HapticFeedback.mediumImpact();
      _c.add(n);
    } else {
      LocalNotifier.instance.show(notifId, '${n.emoji} ${n.title}', n.body, payload: n.tab == null ? null : 'tab:${n.tab}', sos: n.urgent);
    }
  }
}

final noticeCenterProvider = Provider<NoticeCenter>((ref) => NoticeCenter());

/// 盖在整个应用最上层的横幅；点击跳转，上滑或几秒后自动消失。
class NoticeHost extends ConsumerStatefulWidget {
  const NoticeHost({super.key});
  @override
  ConsumerState<NoticeHost> createState() => _NoticeHostState();
}

class _NoticeHostState extends ConsumerState<NoticeHost> {
  StreamSubscription<AppNotice>? _sub;
  StreamSubscription<String?>? _tap;
  AppNotice? _cur;
  Timer? _timer;
  int _seq = 0;

  @override
  void initState() {
    super.initState();
    _sub = ref.read(noticeCenterProvider).stream.listen(_show);
    _tap = LocalNotifier.tapStream.stream.listen(_onPayload);
  }

  @override
  void dispose() {
    _sub?.cancel();
    _tap?.cancel();
    _timer?.cancel();
    super.dispose();
  }

  void _show(AppNotice n) {
    _timer?.cancel();
    setState(() {
      _cur = n;
      _seq++;
    });
    _timer = Timer(const Duration(seconds: 4), _hide);
  }

  void _hide() {
    if (mounted && _cur != null) setState(() => _cur = null);
  }

  void _goTab(int? tab) {
    if (tab == null) return;
    ref.read(routerProvider).go('/');
    ref.read(homeTabProvider.notifier).set(tab);
  }

  void _onPayload(String? p) {
    if (p == null) return;
    if (p.startsWith('tab:')) return _goTab(int.tryParse(p.substring(4)));
    if (const {'poke', 'arrived', 'ack'}.contains(p)) _goTab(2);
  }

  @override
  Widget build(BuildContext context) {
    final n = _cur;
    final v = context.vibes;
    final top = MediaQuery.of(context).padding.top;
    return Positioned(
      top: 0,
      left: 0,
      right: 0,
      child: IgnorePointer(
        ignoring: n == null,
        child: AnimatedSlide(
          duration: const Duration(milliseconds: 260),
          curve: Curves.easeOutCubic,
          offset: n == null ? const Offset(0, -1.4) : Offset.zero,
          child: AnimatedOpacity(
            duration: const Duration(milliseconds: 200),
            opacity: n == null ? 0 : 1,
            child: Padding(
              padding: EdgeInsets.fromLTRB(16, top + 8, 16, 0),
              child: n == null
                  ? const SizedBox(height: 0)
                  : GestureDetector(
                      key: ValueKey(_seq),
                      onTap: () {
                        _hide();
                        _goTab(n.tab);
                      },
                      onVerticalDragEnd: (d) {
                        if ((d.primaryVelocity ?? 0) < 0) _hide();
                      },
                      child: Material(
                        color: Colors.transparent,
                        child: Container(
                          padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
                          decoration: BoxDecoration(
                            color: v.surfaceHigh,
                            borderRadius: BorderRadius.circular(20),
                            border: Border.all(color: v.hairline),
                            boxShadow: const [BoxShadow(color: Color(0x26000000), blurRadius: 18, offset: Offset(0, 6))],
                          ),
                          child: Row(children: [
                            Text(n.emoji, style: const TextStyle(fontSize: 28)),
                            const SizedBox(width: 12),
                            Expanded(
                              child: Column(crossAxisAlignment: CrossAxisAlignment.start, mainAxisSize: MainAxisSize.min, children: [
                                Text(n.title, maxLines: 1, overflow: TextOverflow.ellipsis, style: TextStyle(fontWeight: FontWeight.w700, color: v.ink)),
                                if (n.body.isNotEmpty) Text(n.body, maxLines: 2, overflow: TextOverflow.ellipsis, style: TextStyle(fontSize: 13, color: v.inkSoft)),
                              ]),
                            ),
                          ]),
                        ),
                      ),
                    ),
            ),
          ),
        ),
      ),
    );
  }
}
