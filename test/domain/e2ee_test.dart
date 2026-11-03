import 'dart:convert';

import 'package:couple_locator/domain/crypto/e2ee.dart';
import 'package:cryptography/cryptography.dart';
import 'package:flutter_test/flutter_test.dart';

void main() {
  test('双方 ECDH 派生同一密钥，可互相解密；密文不含明文', () async {
    final a = await E2ee.generateKeyPair();
    final b = await E2ee.generateKeyPair();
    final ka = await E2ee.deriveSharedKey(myPriv: a.priv, myPub: a.pub, theirPub: b.pub);
    final kb = await E2ee.deriveSharedKey(myPriv: b.priv, myPub: b.pub, theirPub: a.pub);
    expect(await ka.extractBytes(), await kb.extractBytes());

    final msg = {'la': 39.9087, 'ln': 116.3975, 't': 1};
    final enc = await E2ee.encryptJson(ka, msg, aad: utf8.encode('u1|1'));
    expect(utf8.decode(enc.cipher, allowMalformed: true).contains('39.9087'), isFalse);
    final dec = await E2ee.decryptJson(kb, enc, aad: utf8.encode('u1|1'));
    expect(dec['la'], 39.9087);
  });

  test('每条数据 nonce 不同；第三方密钥无法解密；篡改/错误 AAD 失败', () async {
    final a = await E2ee.generateKeyPair();
    final b = await E2ee.generateKeyPair();
    final c = await E2ee.generateKeyPair();
    final k = await E2ee.deriveSharedKey(myPriv: a.priv, myPub: a.pub, theirPub: b.pub);
    final e1 = await E2ee.encrypt(k, [1, 2, 3]);
    final e2 = await E2ee.encrypt(k, [1, 2, 3]);
    expect(e1.nonce, isNot(e2.nonce));
    expect(e1.nonce.length, 24);

    final kc = await E2ee.deriveSharedKey(myPriv: c.priv, myPub: c.pub, theirPub: a.pub);
    expect(() => E2ee.decrypt(kc, e1), throwsA(isA<SecretBoxAuthenticationError>()));
    expect(() => E2ee.decrypt(k, e1, aad: [9]), throwsA(isA<SecretBoxAuthenticationError>()));
  });

  test('安全码两端一致且为 5 组 4 位数字', () async {
    final a = await E2ee.generateKeyPair();
    final b = await E2ee.generateKeyPair();
    final s1 = await E2ee.safetyCode(a.pub, b.pub);
    final s2 = await E2ee.safetyCode(b.pub, a.pub);
    expect(s1, s2);
    expect(RegExp(r'^\d{4}( \d{4}){4}$').hasMatch(s1), isTrue);
  });

  test('密钥备份：口令正确可恢复，错误失败', () async {
    final a = await E2ee.generateKeyPair();
    final backup = await KeyBackup.export(a.priv, '对的口令123', memory: 64, iterations: 1);
    expect(backup.contains(base64Encode(a.priv)), isFalse);
    expect(await KeyBackup.restore(backup, '对的口令123'), a.priv);
    expect(() => KeyBackup.restore(backup, '错的'), throwsA(isA<SecretBoxAuthenticationError>()));
  });
}
