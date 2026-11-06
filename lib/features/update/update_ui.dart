import 'dart:async';
import 'dart:io';

import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:url_launcher/url_launcher.dart';

import '../../core/theme/app_theme.dart';
import 'update_models.dart';
import 'update_service.dart';

/// 手动检查更新（「我的」页）。
Future<void> checkForUpdateManually(BuildContext context, WidgetRef ref) async {
  final messenger = ScaffoldMessenger.of(context);
  void say(String text) => messenger
    ..hideCurrentSnackBar()
    ..showSnackBar(SnackBar(content: Text(text)));
  say('正在检查更新…');
  try {
    final current = await ref.read(currentVersionProvider.future);
    final update = await ref.read(updateServiceProvider).check(current: current, ios: isIosPlatform);
    if (!context.mounted) return;
    messenger.hideCurrentSnackBar();
    if (update == null) {
      say('已经是最新版本（$current）');
      return;
    }
    await showUpdateDialog(context, update, current);
  } on UpdateException catch (e) {
    say(e.message);
  } catch (_) {
    say('检查更新失败：连不上 GitHub，换个网络再试');
  }
}

/// 包在主界面外面：进入软件、从后台切回（隔 10 分钟以上）时自动检查更新，有新版就弹窗。
class UpdateAutoCheck extends ConsumerStatefulWidget {
  const UpdateAutoCheck({super.key, required this.child});
  final Widget child;
  @override
  ConsumerState<UpdateAutoCheck> createState() => _UpdateAutoCheckState();
}

class _UpdateAutoCheckState extends ConsumerState<UpdateAutoCheck> with WidgetsBindingObserver {
  static DateTime? _lastCheck;
  static bool _showing = false;
  static const _recheckAfter = Duration(minutes: 10);

  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addObserver(this);
    unawaited(_maybeCheck());
  }

  @override
  void dispose() {
    WidgetsBinding.instance.removeObserver(this);
    super.dispose();
  }

  @override
  void didChangeAppLifecycleState(AppLifecycleState state) {
    if (state == AppLifecycleState.resumed) unawaited(_maybeCheck());
  }

  Future<void> _maybeCheck() async {
    if (_showing || !ref.read(autoUpdateCheckProvider)) return;
    final now = DateTime.now();
    final last = _lastCheck;
    if (last != null && now.difference(last) < _recheckAfter) return;
    _lastCheck = now;
    try {
      final current = await ref.read(currentVersionProvider.future);
      final update = await ref.read(updateServiceProvider).check(current: current, ios: isIosPlatform);
      if (update == null || !mounted || _showing) return;
      _showing = true;
      try {
        await showUpdateDialog(context, update, current);
      } finally {
        _showing = false;
      }
    } catch (_) {
      _lastCheck = null; // 失败不打扰，下次再查
    }
  }

  @override
  Widget build(BuildContext context) => widget.child;
}

Future<void> showUpdateDialog(BuildContext context, AppUpdate update, String current) =>
    showDialog<void>(context: context, barrierDismissible: false, builder: (_) => UpdateDialog(update: update, current: current));

enum _Phase { idle, downloading, ready }

class UpdateDialog extends ConsumerStatefulWidget {
  const UpdateDialog({super.key, required this.update, required this.current});
  final AppUpdate update;
  final String current;
  @override
  ConsumerState<UpdateDialog> createState() => _UpdateDialogState();
}

class _UpdateDialogState extends ConsumerState<UpdateDialog> {
  _Phase _phase = _Phase.idle;
  double? _progress;
  String? _error;
  String? _hint;
  File? _file;
  final _cancel = DownloadCancel();

  bool get _ios => isIosPlatform;

  @override
  void dispose() {
    _cancel.cancelled = true;
    super.dispose();
  }

  String _mb(int bytes) => '${(bytes / 1024 / 1024).toStringAsFixed(1)} MB';

  Future<void> _download() async {
    setState(() {
      _phase = _Phase.downloading;
      _progress = null;
      _error = null;
      _hint = null;
    });
    try {
      final file = await ref.read(updateServiceProvider).download(widget.update, (got, total) {
        if (!mounted || total <= 0) return;
        setState(() => _progress = got / total);
      }, _cancel);
      if (!mounted) return;
      setState(() {
        _file = file;
        _phase = _Phase.ready;
      });
      await _installAndroid();
    } catch (e) {
      if (!mounted) return;
      setState(() {
        _phase = _Phase.idle;
        _error = e is UpdateException ? e.message : '下载失败，请检查网络后重试';
      });
    }
  }

  Future<void> _installAndroid() async {
    final installer = ref.read(apkInstallerProvider);
    try {
      if (!await installer.canInstall()) {
        setState(() => _hint = '需要先在系统设置里打开「允许安装应用」开关（只设置一次），打开后返回本应用再点「安装」。');
        await installer.openInstallSettings();
        return;
      }
      setState(() => _hint = '已调起系统安装界面，点「更新」即可覆盖安装，数据会保留。');
      await installer.install(_file!.path);
    } catch (_) {
      if (!mounted) return;
      setState(() => _error = '调起安装失败，可以点「打开下载页」手动下载安装');
    }
  }

  Future<void> _openPage({bool direct = false}) async {
    final url = direct ? widget.update.assetUrl : widget.update.pageUrl;
    var ok = false;
    try {
      ok = await launchUrl(Uri.parse(url), mode: LaunchMode.externalApplication);
    } catch (_) {}
    if (!ok && mounted) setState(() => _error = '打不开浏览器，请复制链接到浏览器里打开');
  }

  Future<void> _copyLink() async {
    await Clipboard.setData(ClipboardData(text: widget.update.assetUrl));
    if (!mounted) return;
    setState(() => _hint = '下载链接已复制，可以粘贴到浏览器或全能签里下载。');
  }

  String get _notes => widget.update.notes
      .replaceAll(RegExp(r'^#+\s*', multiLine: true), '')
      .replaceAll('**', '')
      .replaceAll('`', '')
      .trim();

  @override
  Widget build(BuildContext context) {
    final v = context.vibes;
    final u = widget.update;
    final size = u.assetSize > 0 ? '，${_mb(u.assetSize)}' : '';
    final downloading = _phase == _Phase.downloading;
    final soft = TextStyle(fontSize: 12, color: v.inkSoft);

    final body = <Widget>[
      Text('当前 ${widget.current} → 新版 ${u.version}$size'),
      if (_notes.isNotEmpty) ...[
        const SizedBox(height: 10),
        ConstrainedBox(constraints: const BoxConstraints(maxHeight: 140), child: SingleChildScrollView(child: Text(_notes, style: soft))),
      ],
      if (_ios) ...[
        const SizedBox(height: 10),
        Text('iPhone 是侧载安装，App 不能自己安装新版。点「前往下载」下载新的 IPA，再用全能签重新签名安装即可覆盖旧版，数据保留。', style: soft),
      ],
      if (downloading) ...[
        const SizedBox(height: 14),
        LinearProgressIndicator(value: _progress),
        const SizedBox(height: 6),
        Text(_progress == null ? '正在连接…' : '正在下载 ${(_progress! * 100).toStringAsFixed(0)}%', style: soft),
      ],
      if (_hint != null) ...[const SizedBox(height: 10), Text(_hint!, style: TextStyle(fontSize: 12, color: v.accentText))],
      if (_error != null) ...[const SizedBox(height: 10), Text(_error!, style: TextStyle(fontSize: 12, color: v.danger))],
    ];

    final actions = <Widget>[
      if (downloading)
        TextButton(
          onPressed: () {
            _cancel.cancelled = true;
            Navigator.pop(context);
          },
          child: const Text('取消'),
        )
      else ...[
        TextButton(onPressed: () => Navigator.pop(context), child: const Text('暂不更新')),
        if (_ios) TextButton(onPressed: _copyLink, child: const Text('复制链接')),
        if (!_ios && _error != null) TextButton(onPressed: () => _openPage(), child: const Text('打开下载页')),
        if (_ios)
          FilledButton(onPressed: () => _openPage(direct: true), child: const Text('前往下载'))
        else if (_phase == _Phase.ready)
          FilledButton(onPressed: _installAndroid, child: const Text('安装'))
        else
          FilledButton(onPressed: _download, child: Text(_error != null ? '重试' : '更新')),
      ],
    ];

    return PopScope(
      canPop: !downloading,
      child: AlertDialog(
        title: const Text('发现新版本'),
        content: SingleChildScrollView(child: Column(mainAxisSize: MainAxisSize.min, crossAxisAlignment: CrossAxisAlignment.start, children: body)),
        actions: actions,
      ),
    );
  }
}
