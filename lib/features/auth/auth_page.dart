import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:phosphor_flutter/phosphor_flutter.dart';

import '../../app/providers.dart';
import '../../core/theme/app_theme.dart';
import '../../core/theme/tokens.dart';
import '../../core/username.dart';
import '../../core/widgets/vibe_widgets.dart';

class AuthPage extends ConsumerStatefulWidget {
  const AuthPage({super.key});
  @override
  ConsumerState<AuthPage> createState() => _AuthPageState();
}

class _AuthPageState extends ConsumerState<AuthPage> {
  final _user = TextEditingController();
  final _pwd = TextEditingController();
  bool _signup = false;
  bool _busy = false;
  bool _obscure = true;
  String? _err;

  String _friendly(Object e) {
    final m = e.toString();
    if (m.contains('Invalid login')) return '用户名或密码不正确';
    if (m.contains('already registered')) return '这个用户名已经被占用了，换一个或直接登录';
    if (m.contains('Password should')) return '密码至少 6 位';
    if (m.contains('Email not confirmed')) return '后台还开着邮箱确认：请在 Supabase 后台关闭 Confirm email（见 docs/SETUP.md）';
    if (m.contains('SocketException') || m.contains('Failed host lookup')) return '网络不通，请检查网络（Supabase 在国内可能需要稳定的网络环境）';
    return '出错了：$m';
  }

  Future<void> _submit() async {
    final e = _user.text.trim(), p = _pwd.text;
    if (!Username.isValid(e) || p.length < 6) {
      setState(() => _err = '用户名为 3–20 位字母、数字或下划线；密码至少 6 位');
      return;
    }
    setState(() {
      _busy = true;
      _err = null;
    });
    try {
      final b = ref.read(backendProvider);
      _signup ? await b.signUp(e, p) : await b.signIn(e, p);
    } catch (ex) {
      if (mounted) setState(() => _err = _friendly(ex));
    } finally {
      if (mounted) setState(() => _busy = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    final v = context.vibes;
    return Scaffold(
      body: FlowingBlobs(
        child: SafeArea(
          child: Center(
            child: SingleChildScrollView(
              padding: const EdgeInsets.all(24),
              child: ConstrainedBox(
                constraints: const BoxConstraints(maxWidth: 420),
                child: Column(children: [
                  const SizedBox(height: 8),
                  SizedBox(
                    height: 120,
                    child: Stack(alignment: Alignment.center, children: [
                      Positioned(left: 70, child: AvatarBubble(palette: PersonalPalette.all[0], emoji: '🐱', size: 78)),
                      Positioned(right: 70, child: AvatarBubble(palette: PersonalPalette.all[2], emoji: '🐶', size: 78)),
                      const Positioned(top: 8, child: Text('💗', style: TextStyle(fontSize: 34))),
                    ]),
                  ),
                  const SizedBox(height: 12),
                  GradientText('甜蜜定位', style: const TextStyle(fontFamily: AppTheme.displayFont, fontSize: 40)),
                  const SizedBox(height: 6),
                  Text('只属于你们两个人的小世界', style: TextStyle(color: v.inkSoft)),
                  const SizedBox(height: 28),
                  VibeCard(
                    padding: const EdgeInsets.all(20),
                    child: Column(children: [
                      SegmentedButton<bool>(
                        segments: const [ButtonSegment(value: false, label: Text('登录')), ButtonSegment(value: true, label: Text('注册'))],
                        selected: {_signup},
                        showSelectedIcon: false,
                        onSelectionChanged: (s) => setState(() => _signup = s.first),
                      ),
                      const SizedBox(height: 18),
                      TextField(controller: _user, keyboardType: TextInputType.visiblePassword, autocorrect: false, enableSuggestions: false, autofillHints: const [AutofillHints.username], decoration: const InputDecoration(hintText: '用户名（字母/数字/下划线）', prefixIcon: Icon(PhosphorIconsRegular.user))),
                      const SizedBox(height: 12),
                      TextField(
                        controller: _pwd,
                        obscureText: _obscure,
                        autofillHints: const [AutofillHints.password],
                        onSubmitted: (_) => _submit(),
                        decoration: InputDecoration(
                          hintText: '密码（至少 6 位）',
                          prefixIcon: const Icon(PhosphorIconsRegular.lockSimple),
                          suffixIcon: IconButton(icon: Icon(_obscure ? PhosphorIconsRegular.eye : PhosphorIconsRegular.eyeSlash), onPressed: () => setState(() => _obscure = !_obscure)),
                        ),
                      ),
                      if (_signup) ...[
                        const SizedBox(height: 10),
                        Text('无需邮箱。但这也意味着忘记密码无法找回，请牢记并在「设置」里备份密钥。', style: TextStyle(color: v.inkSoft, fontSize: 12.5)),
                      ],
                      if (_err != null) ...[
                        const SizedBox(height: 12),
                        Text(_err!, style: TextStyle(color: v.danger, fontWeight: FontWeight.w600)),
                      ],
                      const SizedBox(height: 20),
                      GradientButton(label: _signup ? '注册并开始' : '登录', busy: _busy, onTap: _busy ? null : _submit),
                    ]),
                  ),
                ]),
              ),
            ),
          ),
        ),
      ),
    );
  }
}
