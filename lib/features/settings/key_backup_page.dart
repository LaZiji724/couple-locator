import 'dart:convert';

import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:mobile_scanner/mobile_scanner.dart';
import 'package:phosphor_flutter/phosphor_flutter.dart';
import 'package:qr_flutter/qr_flutter.dart';

import '../../app/providers.dart';
import '../../core/theme/app_theme.dart';
import '../../core/theme/tokens.dart';
import '../../core/widgets/vibe_widgets.dart';
import '../../domain/crypto/e2ee.dart';

/// 密钥备份：口令 → Argon2id → 加密私钥，备份到云端或导出二维码。换手机用口令恢复。
class KeyBackupPage extends ConsumerStatefulWidget {
  const KeyBackupPage({super.key});
  @override
  ConsumerState<KeyBackupPage> createState() => _KeyBackupPageState();
}

class _KeyBackupPageState extends ConsumerState<KeyBackupPage> {
  final _p1 = TextEditingController(), _p2 = TextEditingController();
  bool _busy = false;
  String? _qr;
  String? _msg;

  int get _strength {
    final p = _p1.text;
    var s = 0;
    if (p.length >= 8) s++;
    if (p.length >= 12) s++;
    if (RegExp(r'[A-Za-z]').hasMatch(p) && RegExp(r'\d').hasMatch(p)) s++;
    if (RegExp(r'[^A-Za-z0-9]').hasMatch(p)) s++;
    return s;
  }

  Future<String?> _build() async {
    if (_p1.text.length < 8) {
      setState(() => _msg = '口令至少 8 位');
      return null;
    }
    if (_p1.text != _p2.text) {
      setState(() => _msg = '两次输入的口令不一致');
      return null;
    }
    final uid = ref.read(backendProvider).userId!;
    final kp = await ref.read(keyStoreProvider).load(uid);
    if (kp == null) {
      setState(() => _msg = '本机没有密钥');
      return null;
    }
    return KeyBackup.export(kp.priv, _p1.text);
  }

  Future<void> _cloud() async {
    setState(() {
      _busy = true;
      _msg = null;
    });
    try {
      final b = await _build();
      if (b != null) {
        await ref.read(backendProvider).saveKeyBackup(b);
        setState(() => _msg = '已加密备份到云端 ✅ 请牢记口令，忘记口令将无法恢复。');
      }
    } catch (e) {
      setState(() => _msg = '备份失败：$e');
    } finally {
      setState(() => _busy = false);
    }
  }

  Future<void> _export() async {
    setState(() {
      _busy = true;
      _msg = null;
    });
    try {
      final b = await _build();
      if (b != null) setState(() => _qr = b);
    } catch (e) {
      setState(() => _msg = '导出失败：$e');
    } finally {
      setState(() => _busy = false);
    }
  }

  Future<void> _restore({String? json}) async {
    if (_p1.text.isEmpty) {
      setState(() => _msg = '请先在上面输入备份口令');
      return;
    }
    setState(() {
      _busy = true;
      _msg = null;
    });
    try {
      final b = ref.read(backendProvider);
      final data = json ?? await b.loadKeyBackup();
      if (data == null) {
        setState(() => _msg = '云端没有备份');
        return;
      }
      final priv = await KeyBackup.restore(data, _p1.text);
      final pub = await E2ee.publicKeyFromPrivate(priv);
      await ref.read(keyStoreProvider).save(b.userId!, priv, pub);
      final me = await b.getProfile(b.userId!);
      if (me != null) {
        await b.upsertProfile(me.copyWithKey(base64Encode(pub)));
      }
      await ref.read(syncProvider.notifier).reload();
      setState(() => _msg = '密钥已恢复 ✅ 历史数据现在可以解密了。请让 TA 重新打开一次 App 以刷新密钥。');
    } catch (e) {
      setState(() => _msg = '恢复失败：口令不对或备份已损坏');
    } finally {
      setState(() => _busy = false);
    }
  }

  Future<void> _scanRestore() async {
    final raw = await Navigator.push<String>(context, MaterialPageRoute(builder: (_) => Scaffold(appBar: AppBar(title: const Text('扫描备份二维码')), body: MobileScanner(onDetect: (c) {
          final v = c.barcodes.firstOrNull?.rawValue;
          if (v != null && v.contains('argon2id')) Navigator.pop(context, v);
        }))));
    if (raw != null) _restore(json: raw);
  }

  @override
  Widget build(BuildContext context) {
    final v = context.vibes;
    final st = _strength;
    return Scaffold(
      appBar: AppBar(title: const Text('密钥备份')),
      body: PaperBackdrop(
        child: SafeArea(
          child: ListView(padding: const EdgeInsets.all(20), children: [
            const Center(child: Text('🛡️', style: TextStyle(fontSize: 72))),
            const SizedBox(height: 8),
            Text('你的位置只有你们两个人能解密。私钥只保存在本机；如果换手机或重装，没有备份就无法解密历史数据。', style: TextStyle(color: v.inkSoft, height: 1.5)),
            const SizedBox(height: 16),
            TextField(controller: _p1, obscureText: true, onChanged: (_) => setState(() {}), decoration: const InputDecoration(hintText: '备份口令（至少 8 位）')),
            const SizedBox(height: 8),
            Row(children: [for (var i = 0; i < 4; i++) Expanded(child: Container(height: 6, margin: const EdgeInsets.symmetric(horizontal: 3), decoration: BoxDecoration(color: i < st ? [v.danger, Colors.orange, Colors.amber, const Color(0xFF2BBF94)][st - 1] : v.inkSoft.withValues(alpha: 0.2), borderRadius: BorderRadius.circular(4))))]),
            const SizedBox(height: 12),
            TextField(controller: _p2, obscureText: true, decoration: const InputDecoration(hintText: '再输入一次')),
            const SizedBox(height: 18),
            PrimaryButton(label: '备份到云端', icon: PhosphorIconsFill.cloudArrowUp, busy: _busy, onTap: _busy ? null : _cloud),
            const SizedBox(height: 10),
            SoftButton(label: '导出为二维码', icon: PhosphorIconsRegular.qrCode, onTap: _busy ? null : _export),
            if (_qr != null) ...[
              const SizedBox(height: 14),
              Center(child: Container(padding: const EdgeInsets.all(12), decoration: BoxDecoration(color: Colors.white, borderRadius: BorderRadius.circular(AppRadii.small)), child: QrImageView(data: _qr!, size: 240))),
              const SizedBox(height: 6),
              Text('二维码内是口令加密后的密文，请截图或拍照妥善保存，不要发给别人。', textAlign: TextAlign.center, style: TextStyle(color: v.inkSoft, fontSize: 12)),
            ],
            if (_msg != null) ...[const SizedBox(height: 14), Text(_msg!, style: TextStyle(color: _msg!.contains('✅') ? const Color(0xFF0F8A68) : v.danger, fontWeight: FontWeight.w700))],
            const SectionTitle('换手机？恢复密钥'),
            Text('先在上面输入当初设置的口令，再选择恢复来源。', style: TextStyle(color: v.inkSoft)),
            const SizedBox(height: 10),
            Row(children: [
              Expanded(child: SoftButton(label: '从云端恢复', icon: PhosphorIconsRegular.cloudArrowDown, onTap: _busy ? null : _restore)),
              const SizedBox(width: 10),
              Expanded(child: SoftButton(label: '扫二维码恢复', icon: PhosphorIconsRegular.scan, onTap: _busy ? null : _scanRestore)),
            ]),
          ]),
        ),
      ),
    );
  }
}
