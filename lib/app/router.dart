import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';

import '../core/config/app_config.dart';
import '../core/theme/app_theme.dart';
import '../core/widgets/vibe_widgets.dart';
import '../features/auth/auth_page.dart';
import '../features/auth/profile_setup_page.dart';
import '../features/interact/sos_pages.dart';
import '../features/onboarding/onboarding_page.dart';
import '../features/pairing/pairing_page.dart';
import '../features/settings/key_backup_page.dart';
import '../features/settings/settings_page.dart';
import '../features/shell/home_shell.dart';
import '../features/stats/stats_page.dart';
import 'providers.dart';

final routerProvider = Provider<GoRouter>((ref) {
  return GoRouter(
    routes: [
      GoRoute(path: '/', builder: (_, _) => const RootGate()),
      GoRoute(path: '/history', builder: (_, _) => const RootGate()),
      GoRoute(path: '/stats', builder: (_, _) => const StatsPage()),
      GoRoute(path: '/profile', builder: (_, _) => const ProfileSetupPage(editing: true)),
      GoRoute(path: '/key-backup', builder: (_, _) => const KeyBackupPage()),
      GoRoute(path: '/diagnostics', builder: (_, _) => const DiagnosticsPage()),
      GoRoute(path: '/sos-alert', builder: (_, _) => const SosAlertPage()),
      GoRoute(path: '/sos-sender', builder: (_, _) => const SosSenderPage()),
      GoRoute(path: '/onboarding', builder: (ctx, _) => OnboardingPage(onDone: () => ctx.pop())),
    ],
  );
});

/// 根据状态依次决定显示：配置缺失 → 引导 → 登录 → 资料 → 配对 → 庆祝 → 主页。
class RootGate extends ConsumerStatefulWidget {
  const RootGate({super.key});
  @override
  ConsumerState<RootGate> createState() => _RootGateState();
}

class _RootGateState extends ConsumerState<RootGate> {
  bool _celebrated = false;
  String? _lastCoupleId;

  @override
  Widget build(BuildContext context) {
    if (!AppConfig.backendConfigured) return const _SetupRequired();
    final store = ref.watch(settingsProvider);
    if (store == null) return const _Loading();
    if (!store.onboarded) {
      return OnboardingPage(onDone: () => setState(() {}));
    }
    final auth = ref.watch(authProvider);
    if (auth.isLoading) return const _Loading();
    if (auth.value != true) return const AuthPage();
    final profile = ref.watch(myProfileProvider);
    if (profile.isLoading) return const _Loading();
    if (profile.value == null || profile.value!.nickname.isEmpty) return const ProfileSetupPage();
    final sync = ref.watch(syncProvider);
    if (sync.loading) return const _Loading();
    if (!sync.paired) {
      _celebrated = false;
      _lastCoupleId = null;
      return const PairingPage();
    }
    if (_lastCoupleId != sync.couple!.id) {
      _lastCoupleId = sync.couple!.id;
      _celebrated = store.onboarded && _celebratedBefore;
    }
    if (!_celebrated) {
      return PairedCelebrationPage(onContinue: () => setState(() {
            _celebrated = true;
            _celebratedBefore = true;
          }));
    }
    return const HomeShell();
  }
}

// 同一次运行中只庆祝一次（重启后直接进主页）
bool _celebratedBefore = false;

class _Loading extends StatelessWidget {
  const _Loading();
  @override
  Widget build(BuildContext context) => const Scaffold(body: Center(child: CircularProgressIndicator()));
}

class _SetupRequired extends StatelessWidget {
  const _SetupRequired();
  @override
  Widget build(BuildContext context) {
    final v = context.vibes;
    return Scaffold(
      body: PaperBackdrop(
        child: SafeArea(
          child: Center(
            child: Padding(
              padding: const EdgeInsets.all(28),
              child: Column(mainAxisSize: MainAxisSize.min, children: [
                const Text('🔧', style: TextStyle(fontSize: 64)),
                const SizedBox(height: 12),
                Text('还没有配置后端', style: Theme.of(context).textTheme.headlineSmall),
                const SizedBox(height: 10),
                Text('请按 docs/SETUP.md 创建 Supabase 项目，并在构建时通过 --dart-define-from-file=env/dev.json 传入 SUPABASE_URL 与 SUPABASE_ANON_KEY（以及高德 Key）。', textAlign: TextAlign.center, style: TextStyle(color: v.inkSoft, height: 1.5)),
              ]),
            ),
          ),
        ),
      ),
    );
  }
}
