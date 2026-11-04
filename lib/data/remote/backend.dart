import 'dart:typed_data';

/// 统一数据层接口。所有后端访问都经过它，日后可替换为腾讯云 CloudBase 实现。
abstract class Backend {
  // ── 认证 ──
  String? get userId;
  Stream<bool> get authChanges; // true=已登录
  Future<void> signUp(String username, String password);
  Future<void> signIn(String username, String password);
  Future<void> signOut();

  // ── 资料 ──
  Future<ProfileDto?> getProfile(String userId);
  Future<void> upsertProfile(ProfileDto p);
  Future<void> saveKeyBackup(String backupJson);
  Future<String?> loadKeyBackup();

  // ── 配对 ──
  Future<CoupleDto?> getMyCouple();
  Stream<CoupleDto?> watchCouple();
  Future<String> createInvite();
  Future<void> redeemInvite(String code);
  Future<void> unpair({required bool deleteHistory});
  Future<void> setRetention(int days);
  Future<void> wipeMyData();

  // ── 位置 / 状态 / 心跳 ──
  /// 批量上传，服务端 (user_id, client_id, client_ts) 唯一，重复提交安全。
  Future<void> uploadLocations(String coupleId, List<EncLocation> items);
  Future<List<EncLocation>> fetchLocations(String coupleId, String userId, DateTime from, DateTime to);
  Stream<EncLocation> watchLocations(String coupleId, String partnerId);
  Future<void> upsertStatus(String coupleId, EncBlob blob);
  Stream<EncBlob> watchStatus(String partnerId);
  Future<void> heartbeat({bool paused = false, DateTime? pausedUntil});
  Future<PresenceDto?> getPresence(String userId);
  Stream<PresenceDto> watchPresence(String userId);

  // ── 事件 / 标记 ──
  Future<void> sendEvent(String coupleId, String kind, EncBlob blob);
  Future<List<EncEvent>> fetchEvents(String coupleId, {DateTime? since});
  Stream<EncEvent> watchEvents(String coupleId);
  Future<void> upsertPin(String coupleId, String? id, EncBlob blob, {bool deleted = false});
  Future<List<EncPin>> fetchPins(String coupleId);
  Stream<EncPin> watchPins(String coupleId);

  // ── 诊断 ──
  Future<void> logRemote(String level, String message);
}

class ProfileDto {
  const ProfileDto({required this.id, required this.nickname, this.avatarEmoji, this.avatarUrl, this.themeId = 'coral', this.publicKeyB64});
  final String id;
  final String nickname;
  final String? avatarEmoji;
  final String? avatarUrl;
  final String themeId;
  final String? publicKeyB64;

  ProfileDto copyWithTheme(String t) => ProfileDto(id: id, nickname: nickname, avatarEmoji: avatarEmoji, avatarUrl: avatarUrl, themeId: t, publicKeyB64: publicKeyB64);

  ProfileDto copyWithKey(String key) => ProfileDto(id: id, nickname: nickname, avatarEmoji: avatarEmoji, avatarUrl: avatarUrl, themeId: themeId, publicKeyB64: key);
}

class CoupleDto {
  const CoupleDto({required this.id, required this.userA, required this.userB, this.retentionA = 30, this.retentionB = 30});
  final String id;
  final String userA;
  final String userB;
  final int retentionA;
  final int retentionB;
  String partnerOf(String me) => me == userA ? userB : userA;
  int get effectiveRetention => retentionA < retentionB ? retentionA : retentionB;
}

class PresenceDto {
  const PresenceDto({required this.userId, required this.heartbeatAt, required this.paused, this.pausedUntil});
  final String userId;
  final DateTime heartbeatAt;
  final bool paused;
  final DateTime? pausedUntil;

  bool isPausedNow(DateTime now) => paused && (pausedUntil == null || pausedUntil!.isAfter(now));
}

class EncBlob {
  const EncBlob(this.cipherB64, this.nonceB64);
  final String cipherB64;
  final String nonceB64;
}

class EncLocation {
  const EncLocation({required this.userId, required this.clientId, required this.clientTs, required this.blob});
  final String userId;
  final String clientId;
  final int clientTs;
  final EncBlob blob;
}

class EncEvent {
  const EncEvent({required this.id, required this.userId, required this.kind, required this.createdAt, required this.blob});
  final String id;
  final String userId;
  final String kind;
  final DateTime createdAt;
  final EncBlob blob;
}

class EncPin {
  const EncPin({required this.id, required this.userId, required this.updatedAt, required this.blob, required this.deleted});
  final String id;
  final String userId;
  final DateTime updatedAt;
  final EncBlob blob;
  final bool deleted;
}

typedef Bytes = Uint8List;
