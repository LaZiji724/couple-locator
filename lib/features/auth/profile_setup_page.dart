import 'dart:convert';

import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:image_picker/image_picker.dart';
import 'package:phosphor_flutter/phosphor_flutter.dart';

import '../../app/providers.dart';
import '../../core/theme/app_theme.dart';
import '../../core/theme/tokens.dart';
import '../../core/widgets/vibe_widgets.dart';
import '../../data/remote/backend.dart';

const avatarEmojis = ['🐱', '🐶', '🐰', '🐻', '🦊', '🐼', '🐨', '🐯', '🦄', '🐸', '🐧', '🐥', '🌸', '🍓', '🍑', '⭐'];

/// 首次登录：昵称、头像（emoji 或相册图片）、个人主题色。设置页也复用它来编辑资料。
class ProfileSetupPage extends ConsumerStatefulWidget {
  const ProfileSetupPage({super.key, this.editing = false});
  final bool editing;
  @override
  ConsumerState<ProfileSetupPage> createState() => _ProfileSetupPageState();
}

class _ProfileSetupPageState extends ConsumerState<ProfileSetupPage> {
  final _nick = TextEditingController();
  String _emoji = avatarEmojis.first;
  String? _photo; // data URI
  String _theme = 'coral';
  bool _busy = false;
  bool _loaded = false;

  @override
  void initState() {
    super.initState();
    ref.read(myProfileProvider.future).then((p) {
      if (p != null && mounted) {
        setState(() {
          _nick.text = p.nickname;
          _emoji = p.avatarEmoji ?? avatarEmojis.first;
          _photo = p.avatarUrl;
          _theme = p.themeId;
        });
      }
      if (mounted) setState(() => _loaded = true);
    });
  }

  Future<void> _pick() async {
    final x = await ImagePicker().pickImage(source: ImageSource.gallery, maxWidth: 192, maxHeight: 192, imageQuality: 70);
    if (x == null) return;
    final bytes = await x.readAsBytes();
    setState(() => _photo = 'data:image/jpeg;base64,${base64Encode(bytes)}');
  }

  Future<void> _save() async {
    if (_nick.text.trim().isEmpty) {
      ScaffoldMessenger.of(context).showSnackBar(const SnackBar(content: Text('给自己起个昵称吧')));
      return;
    }
    setState(() => _busy = true);
    try {
      final b = ref.read(backendProvider);
      final kp = await ref.read(keyStoreProvider).loadOrCreate(b.userId!);
      await b.upsertProfile(ProfileDto(
        id: b.userId!,
        nickname: _nick.text.trim(),
        avatarEmoji: _photo == null ? _emoji : _emoji,
        avatarUrl: _photo,
        themeId: _theme,
        publicKeyB64: base64Encode(kp.pub),
      ));
      ref.invalidate(myProfileProvider);
      await ref.read(syncProvider.notifier).reload();
      if (widget.editing && mounted) Navigator.pop(context);
    } catch (e) {
      if (mounted) ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text('保存失败：$e')));
    } finally {
      if (mounted) setState(() => _busy = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    final v = context.vibes;
    final pal = PersonalPalette.byId(_theme);
    return Scaffold(
      appBar: widget.editing ? AppBar(title: const Text('编辑资料')) : null,
      body: FlowingBlobs(
        child: SafeArea(
          child: !_loaded
              ? const Center(child: CircularProgressIndicator())
              : ListView(padding: const EdgeInsets.all(24), children: [
                  if (!widget.editing) ...[
                    Text('认识一下你', style: Theme.of(context).textTheme.headlineMedium),
                    const SizedBox(height: 6),
                    Text('这些信息只有 TA 能看到', style: TextStyle(color: v.inkSoft)),
                  ],
                  const SizedBox(height: 22),
                  Center(child: Hero(tag: 'my-avatar', child: AvatarBubble(palette: pal, emoji: _emoji, imageUrl: _photo, size: 110))),
                  const SizedBox(height: 18),
                  Wrap(spacing: 10, runSpacing: 10, alignment: WrapAlignment.center, children: [
                    for (final e in avatarEmojis)
                      Squish(
                        onTap: () => setState(() {
                          _emoji = e;
                          _photo = null;
                        }),
                        child: AnimatedContainer(
                          duration: const Duration(milliseconds: 200),
                          width: 48,
                          height: 48,
                          alignment: Alignment.center,
                          decoration: BoxDecoration(
                            color: v.surface,
                            borderRadius: BorderRadius.circular(16),
                            border: Border.all(color: _emoji == e && _photo == null ? pal.start : Colors.transparent, width: 2.5),
                          ),
                          child: Text(e, style: const TextStyle(fontSize: 26)),
                        ),
                      ),
                  ]),
                  const SizedBox(height: 12),
                  Center(child: SoftButton(label: '从相册选一张', icon: PhosphorIconsRegular.image, onTap: _pick)),
                  const SizedBox(height: 22),
                  TextField(controller: _nick, maxLength: 12, decoration: const InputDecoration(hintText: '昵称', counterText: '')),
                  const SectionTitle('我的专属颜色'),
                  Wrap(spacing: 14, runSpacing: 14, children: [
                    for (final p in PersonalPalette.all)
                      Squish(
                        onTap: () => setState(() => _theme = p.id),
                        child: Column(mainAxisSize: MainAxisSize.min, children: [
                          AnimatedContainer(
                            duration: const Duration(milliseconds: 250),
                            curve: Curves.easeOutBack,
                            width: _theme == p.id ? 58 : 50,
                            height: _theme == p.id ? 58 : 50,
                            decoration: BoxDecoration(shape: BoxShape.circle, gradient: p.gradient, border: Border.all(color: Colors.white, width: _theme == p.id ? 4 : 0), boxShadow: AppShadows.soft(p.start, dark: v.isDark)),
                            child: _theme == p.id ? const Icon(PhosphorIconsBold.check, color: Colors.white) : null,
                          ),
                          const SizedBox(height: 4),
                          Text(p.name, style: TextStyle(fontSize: 11, color: v.inkSoft)),
                        ]),
                      ),
                  ]),
                  const SizedBox(height: 28),
                  GradientButton(label: widget.editing ? '保存' : '完成，去配对', busy: _busy, onTap: _busy ? null : _save),
                ]),
        ),
      ),
    );
  }
}
