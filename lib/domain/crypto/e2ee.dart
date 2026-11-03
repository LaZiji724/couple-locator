import 'dart:convert';
import 'dart:typed_data';

import 'package:cryptography/cryptography.dart';

/// 端到端加密：X25519 ECDH + HKDF-SHA256 → XChaCha20-Poly1305。
/// 只使用 `cryptography` 包提供的成熟实现，不自创算法。
class E2ee {
  E2ee._();
  static final _x25519 = X25519();
  static final _cipher = Xchacha20.poly1305Aead();
  static final _hkdf = Hkdf(hmac: Hmac.sha256(), outputLength: 32);

  /// 生成设备密钥对，返回 (私钥 32 字节, 公钥 32 字节)。
  static Future<({Uint8List priv, Uint8List pub})> generateKeyPair() async {
    final kp = await _x25519.newKeyPair();
    final data = await kp.extract();
    return (
      priv: Uint8List.fromList(await data.extractPrivateKeyBytes()),
      pub: Uint8List.fromList(data.publicKey.bytes),
    );
  }

  /// ECDH + HKDF 派生对称密钥。双方传入顺序无关（info 内部排序公钥）。
  static Future<SecretKey> deriveSharedKey({
    required Uint8List myPriv,
    required Uint8List myPub,
    required Uint8List theirPub,
    String context = 'couple-locator/v1',
  }) async {
    final kp = SimpleKeyPairData(myPriv,
        publicKey: SimplePublicKey(myPub, type: KeyPairType.x25519), type: KeyPairType.x25519);
    final shared = await _x25519.sharedSecretKey(
        keyPair: kp, remotePublicKey: SimplePublicKey(theirPub, type: KeyPairType.x25519));
    final pubs = [myPub, theirPub]..sort(_cmp);
    final info = [...utf8.encode(context), ...pubs[0], ...pubs[1]];
    return _hkdf.deriveKey(secretKey: shared, nonce: utf8.encode('couple-locator-salt'), info: info);
  }

  static int _cmp(Uint8List a, Uint8List b) {
    for (var i = 0; i < a.length && i < b.length; i++) {
      if (a[i] != b[i]) return a[i] - b[i];
    }
    return a.length - b.length;
  }

  /// 加密，返回 (密文+MAC, 24 字节随机 nonce)。每条数据独立 nonce。
  /// [aad] 绑定明文元数据（如 user_id|ts），防止搬运重放。
  static Future<EncPayload> encrypt(SecretKey key, List<int> plain, {List<int> aad = const []}) async {
    final nonce = _cipher.newNonce();
    final box = await _cipher.encrypt(plain, secretKey: key, nonce: nonce, aad: aad);
    return EncPayload(
      Uint8List.fromList([...box.cipherText, ...box.mac.bytes]),
      Uint8List.fromList(nonce),
    );
  }

  static Future<Uint8List> decrypt(SecretKey key, EncPayload p, {List<int> aad = const []}) async {
    if (p.cipher.length < 16) throw const FormatException('密文过短');
    final ct = p.cipher.sublist(0, p.cipher.length - 16);
    final mac = Mac(p.cipher.sublist(p.cipher.length - 16));
    final box = SecretBox(ct, nonce: p.nonce, mac: mac);
    return Uint8List.fromList(await _cipher.decrypt(box, secretKey: key, aad: aad));
  }

  static Future<EncPayload> encryptJson(SecretKey key, Map<String, dynamic> json, {List<int> aad = const []}) =>
      encrypt(key, utf8.encode(jsonEncode(json)), aad: aad);

  static Future<Map<String, dynamic>> decryptJson(SecretKey key, EncPayload p, {List<int> aad = const []}) async =>
      jsonDecode(utf8.decode(await decrypt(key, p, aad: aad))) as Map<String, dynamic>;

  /// 公钥指纹（SHA-256 前 10 字节 → 20 位数字，分 5 组），用于面对面核对安全码。
  /// 双方公钥排序后拼接，因此两端显示一致。
  static Future<String> safetyCode(Uint8List pubA, Uint8List pubB) async {
    final pubs = [pubA, pubB]..sort(_cmp);
    final h = await Sha256().hash([...pubs[0], ...pubs[1]]);
    final b = h.bytes;
    final digits = StringBuffer();
    for (var i = 0; i < 5; i++) {
      final v = (b[i * 2] << 8 | b[i * 2 + 1]) % 10000;
      digits.write(v.toString().padLeft(4, '0'));
      if (i < 4) digits.write(' ');
    }
    return digits.toString();
  }
}

class EncPayload {
  const EncPayload(this.cipher, this.nonce);
  final Uint8List cipher;
  final Uint8List nonce;

  String get cipherB64 => base64Encode(cipher);
  String get nonceB64 => base64Encode(nonce);
  factory EncPayload.fromB64(String c, String n) => EncPayload(base64Decode(c), base64Decode(n));
}

/// 私钥备份：Argon2id(口令) → 密钥 → XChaCha20-Poly1305 加密私钥。
class KeyBackup {
  KeyBackup._();

  static Argon2id _argon({int memory = 19456, int iterations = 2}) =>
      Argon2id(memory: memory, parallelism: 1, iterations: iterations, hashLength: 32);

  /// 返回可存云端/导出二维码的 JSON 字符串。口令不上传。
  static Future<String> export(Uint8List priv, String passphrase,
      {int memory = 19456, int iterations = 2}) async {
    final salt = SecretKeyData.random(length: 16).bytes;
    final key = await _argon(memory: memory, iterations: iterations)
        .deriveKeyFromPassword(password: passphrase, nonce: salt);
    final enc = await E2ee.encrypt(key, priv, aad: utf8.encode('couple-key-backup-v1'));
    return jsonEncode({
      'v': 1,
      'kdf': 'argon2id',
      'm': memory,
      'i': iterations,
      'salt': base64Encode(salt),
      'ct': enc.cipherB64,
      'n': enc.nonceB64,
    });
  }

  /// 口令错误会抛出 [SecretBoxAuthenticationError]。
  static Future<Uint8List> restore(String backup, String passphrase) async {
    final j = jsonDecode(backup) as Map<String, dynamic>;
    final key = await _argon(memory: j['m'] as int, iterations: j['i'] as int)
        .deriveKeyFromPassword(password: passphrase, nonce: base64Decode(j['salt'] as String));
    return E2ee.decrypt(key, EncPayload.fromB64(j['ct'] as String, j['n'] as String),
        aad: utf8.encode('couple-key-backup-v1'));
  }
}
