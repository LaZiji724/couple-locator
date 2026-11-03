import 'dart:convert';
import 'dart:typed_data';

import 'package:flutter_secure_storage/flutter_secure_storage.dart';

import '../../domain/crypto/e2ee.dart';

/// 设备密钥：私钥只存 Keychain / Keystore。
class KeyStore {
  KeyStore([FlutterSecureStorage? s])
      : _s = s ?? const FlutterSecureStorage(
            aOptions: AndroidOptions(),
            iOptions: IOSOptions(accessibility: KeychainAccessibility.first_unlock_this_device));
  final FlutterSecureStorage _s;

  String _privKey(String uid) => 'x25519_priv_$uid';
  String _pubKey(String uid) => 'x25519_pub_$uid';

  Future<({Uint8List priv, Uint8List pub})?> load(String uid) async {
    final p = await _s.read(key: _privKey(uid));
    final b = await _s.read(key: _pubKey(uid));
    if (p == null || b == null) return null;
    return (priv: base64Decode(p), pub: base64Decode(b));
  }

  Future<({Uint8List priv, Uint8List pub})> loadOrCreate(String uid) async {
    final existing = await load(uid);
    if (existing != null) return existing;
    final kp = await E2ee.generateKeyPair();
    await save(uid, kp.priv, kp.pub);
    return kp;
  }

  Future<void> save(String uid, Uint8List priv, Uint8List pub) async {
    await _s.write(key: _privKey(uid), value: base64Encode(priv));
    await _s.write(key: _pubKey(uid), value: base64Encode(pub));
  }

  Future<void> clear(String uid) async {
    await _s.delete(key: _privKey(uid));
    await _s.delete(key: _pubKey(uid));
  }
}
