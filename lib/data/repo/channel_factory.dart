import 'dart:convert';

import '../remote/backend.dart';
import 'key_store.dart';
import 'secure_channel.dart';

/// 构建与伴侣的加密通道；未配对或对方尚未上传公钥时返回 null。
Future<SecureChannel?> openChannel(Backend backend, KeyStore keys, {CoupleDto? couple}) async {
  final me = backend.userId;
  if (me == null) return null;
  couple ??= await backend.getMyCouple();
  if (couple == null) return null;
  final partnerId = couple.partnerOf(me);
  final partner = await backend.getProfile(partnerId);
  final pub = partner?.publicKeyB64;
  if (pub == null || pub.isEmpty) return null;
  final mine = await keys.load(me);
  if (mine == null) return null;
  return SecureChannel.open(
    myId: me,
    partnerId: partnerId,
    myPriv: mine.priv,
    myPub: mine.pub,
    partnerPub: base64Decode(pub),
  );
}
