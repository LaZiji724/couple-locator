import 'dart:convert';
import 'dart:typed_data';

import 'package:cryptography/cryptography.dart';

import '../../domain/crypto/e2ee.dart';
import '../remote/backend.dart';

/// 与伴侣之间的加密通道：封装共享密钥与 AAD 规则。
class SecureChannel {
  SecureChannel._(this._key, this.myId, this.partnerId, this.safetyCode);
  final SecretKey _key;
  final String myId;
  final String partnerId;
  final String safetyCode;

  static Future<SecureChannel> open({
    required String myId,
    required String partnerId,
    required Uint8List myPriv,
    required Uint8List myPub,
    required Uint8List partnerPub,
  }) async {
    final key = await E2ee.deriveSharedKey(myPriv: myPriv, myPub: myPub, theirPub: partnerPub);
    final code = await E2ee.safetyCode(myPub, partnerPub);
    return SecureChannel._(key, myId, partnerId, code);
  }

  List<int> _aad(String userId, Object tag) => utf8.encode('$userId|$tag');

  /// 位置：AAD 绑定 user_id 与 client_ts，防止密文被搬运到别的行。
  Future<EncBlob> sealLocation(Map<String, dynamic> json, int clientTs) async {
    final p = await E2ee.encryptJson(_key, json, aad: _aad(myId, clientTs));
    return EncBlob(p.cipherB64, p.nonceB64);
  }

  Future<Map<String, dynamic>> openLocation(EncBlob b, String ownerId, int clientTs) =>
      E2ee.decryptJson(_key, EncPayload.fromB64(b.cipherB64, b.nonceB64), aad: _aad(ownerId, clientTs));

  Future<EncBlob> seal(Map<String, dynamic> json, String scope) async {
    final p = await E2ee.encryptJson(_key, json, aad: _aad(myId, scope));
    return EncBlob(p.cipherB64, p.nonceB64);
  }

  Future<Map<String, dynamic>> open_(EncBlob b, String ownerId, String scope) =>
      E2ee.decryptJson(_key, EncPayload.fromB64(b.cipherB64, b.nonceB64), aad: _aad(ownerId, scope));
}
