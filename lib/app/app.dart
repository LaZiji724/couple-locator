import 'dart:ui';

import 'package:flutter/material.dart';
import 'package:flutter_localizations/flutter_localizations.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../core/theme/app_theme.dart';
import 'notice.dart';
import 'providers.dart';
import 'router.dart';

class CoupleApp extends ConsumerStatefulWidget {
  const CoupleApp({super.key});
  @override
  ConsumerState<CoupleApp> createState() => _CoupleAppState();
}

class _CoupleAppState extends ConsumerState<CoupleApp> with WidgetsBindingObserver {
  bool _obscure = false;

  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addObserver(this);
  }

  @override
  void dispose() {
    WidgetsBinding.instance.removeObserver(this);
    super.dispose();
  }

  // 隐私：切到后台时（最近任务预览截图）用模糊遮罩盖住地图
  @override
  void didChangeAppLifecycleState(AppLifecycleState state) {
    final hide = state == AppLifecycleState.inactive || state == AppLifecycleState.paused || state == AppLifecycleState.hidden;
    if (hide != _obscure) setState(() => _obscure = hide);
  }

  @override
  Widget build(BuildContext context) {
    final router = ref.watch(routerProvider);
    final mode = ref.watch(themeModeProvider);
    return MaterialApp.router(
      title: '甜蜜定位',
      debugShowCheckedModeBanner: false,
      theme: AppTheme.light(),
      darkTheme: AppTheme.dark(),
      themeMode: mode,
      routerConfig: router,
      locale: const Locale('zh', 'CN'),
      supportedLocales: const [Locale('zh', 'CN')],
      localizationsDelegates: const [GlobalMaterialLocalizations.delegate, GlobalWidgetsLocalizations.delegate, GlobalCupertinoLocalizations.delegate],
      builder: (context, child) => Stack(children: [
        child ?? const SizedBox.shrink(),
        const NoticeHost(),
        if (_obscure)
          Positioned.fill(
            child: BackdropFilter(
              filter: ImageFilter.blur(sigmaX: 28, sigmaY: 28),
              child: Container(color: Theme.of(context).scaffoldBackgroundColor.withValues(alpha: 0.85), alignment: Alignment.center, child: const Text('💗', style: TextStyle(fontSize: 56))),
            ),
          ),
      ]),
    );
  }
}
