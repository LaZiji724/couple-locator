import 'dart:async';

import 'package:supabase_flutter/supabase_flutter.dart';

import '../../core/log.dart';
import 'backend.dart';

class SupabaseBackend implements Backend {
  SupabaseBackend(this._c);
  final SupabaseClient _c;

  @override
  String? get userId => _c.auth.currentUser?.id;

  @override
  Stream<bool> get authChanges => _c.auth.onAuthStateChange.map((e) => e.session != null);

  @override
  Future<void> signUp(String email, String password) async {
    final r = await _c.auth.signUp(email: email, password: password);
    if (r.session == null) {
      // 若项目开启了邮箱确认，则需要先确认；这里尝试直接登录，失败会抛出友好提示
      await signIn(email, password);
    }
  }

  @override
  Future<void> signIn(String email, String password) async {
    await _c.auth.signInWithPassword(email: email, password: password);
  }

  @override
  Future<void> signOut() => _c.auth.signOut();

  ProfileDto _profile(Map<String, dynamic> m) => ProfileDto(
        id: m['id'] as String,
        nickname: (m['nickname'] as String?) ?? '',
        avatarEmoji: m['avatar_emoji'] as String?,
        avatarUrl: m['avatar_url'] as String?,
        themeId: (m['theme_id'] as String?) ?? 'coral',
        publicKeyB64: m['public_key'] as String?,
      );

  @override
  Future<ProfileDto?> getProfile(String userId) async {
    final m = await _c.from('profiles').select().eq('id', userId).maybeSingle();
    return m == null ? null : _profile(m);
  }

  @override
  Future<void> upsertProfile(ProfileDto p) => _c.from('profiles').upsert({
        'id': p.id,
        'nickname': p.nickname,
        'avatar_emoji': p.avatarEmoji,
        'avatar_url': p.avatarUrl,
        'theme_id': p.themeId,
        if (p.publicKeyB64 != null) 'public_key': p.publicKeyB64,
      });

  @override
  Future<void> saveKeyBackup(String backupJson) =>
      _c.from('profiles').update({'key_backup': backupJson}).eq('id', userId!);

  @override
  Future<String?> loadKeyBackup() async {
    final m = await _c.from('profiles').select('key_backup').eq('id', userId!).maybeSingle();
    return m?['key_backup'] as String?;
  }

  CoupleDto _couple(Map<String, dynamic> m) => CoupleDto(
        id: m['id'] as String,
        userA: m['user_a'] as String,
        userB: m['user_b'] as String,
        retentionA: (m['retention_a'] as num?)?.toInt() ?? 30,
        retentionB: (m['retention_b'] as num?)?.toInt() ?? 30,
      );

  @override
  Future<CoupleDto?> getMyCouple() async {
    final m = await _c.from('couples').select().maybeSingle();
    return m == null ? null : _couple(m);
  }

  @override
  Stream<CoupleDto?> watchCouple() => _c
      .from('couples')
      .stream(primaryKey: ['id'])
      .map((rows) => rows.isEmpty ? null : _couple(rows.first));

  @override
  Future<String> createInvite() async => (await _c.rpc('create_invite')) as String;

  @override
  Future<void> redeemInvite(String code) async {
    await _c.rpc('redeem_invite', params: {'p_code': code});
  }

  @override
  Future<void> unpair({required bool deleteHistory}) async {
    await _c.rpc('unpair', params: {'p_delete_history': deleteHistory});
  }

  @override
  Future<void> setRetention(int days) async {
    await _c.rpc('set_retention', params: {'p_days': days});
  }

  @override
  Future<void> wipeMyData() async {
    await _c.rpc('wipe_my_data');
  }

  @override
  Future<void> uploadLocations(String coupleId, List<EncLocation> items) async {
    if (items.isEmpty) return;
    await _c.from('locations').upsert(
      [
        for (final i in items)
          {
            'couple_id': coupleId,
            'user_id': i.userId,
            'client_id': i.clientId,
            'client_ts': i.clientTs,
            'cipher': i.blob.cipherB64,
            'nonce': i.blob.nonceB64,
          }
      ],
      onConflict: 'user_id,client_id,client_ts',
      ignoreDuplicates: true,
    );
  }

  EncLocation _loc(Map<String, dynamic> m) => EncLocation(
        userId: m['user_id'] as String,
        clientId: m['client_id'] as String,
        clientTs: (m['client_ts'] as num).toInt(),
        blob: EncBlob(m['cipher'] as String, m['nonce'] as String),
      );

  @override
  Future<List<EncLocation>> fetchLocations(String coupleId, String userId, DateTime from, DateTime to) async {
    final out = <EncLocation>[];
    var offset = 0;
    while (true) {
      final rows = await _c
          .from('locations')
          .select()
          .eq('couple_id', coupleId)
          .eq('user_id', userId)
          .gte('client_ts', from.millisecondsSinceEpoch)
          .lt('client_ts', to.millisecondsSinceEpoch)
          .order('client_ts')
          .range(offset, offset + 999);
      out.addAll(rows.map(_loc));
      if (rows.length < 1000) break;
      offset += 1000;
    }
    return out;
  }

  @override
  Stream<EncLocation> watchLocations(String coupleId, String partnerId) =>
      _channel<EncLocation>('loc', 'locations', 'couple_id', coupleId, _loc)
          .where((e) => e.userId == partnerId);

  /// 通用 Realtime 订阅（INSERT/UPDATE）。
  Stream<T> _channel<T>(String name, String table, String col, String val, T Function(Map<String, dynamic>) map) {
    late StreamController<T> ctl;
    RealtimeChannel? ch;
    ctl = StreamController<T>.broadcast(
      onListen: () {
        ch = _c
            .channel('$name-$val-${DateTime.now().microsecondsSinceEpoch}')
            .onPostgresChanges(
              event: PostgresChangeEvent.all,
              schema: 'public',
              table: table,
              filter: PostgresChangeFilter(type: PostgresChangeFilterType.eq, column: col, value: val),
              callback: (payload) {
                final r = payload.newRecord;
                if (r.isNotEmpty) ctl.add(map(r));
              },
            )
            .subscribe();
      },
      onCancel: () async {
        if (ch != null) await _c.removeChannel(ch!);
      },
    );
    return ctl.stream;
  }

  @override
  Future<void> upsertStatus(String coupleId, EncBlob blob) => _c.from('status').upsert({
        'user_id': userId,
        'couple_id': coupleId,
        'cipher': blob.cipherB64,
        'nonce': blob.nonceB64,
        'updated_at': DateTime.now().toUtc().toIso8601String(),
      });

  @override
  Stream<EncBlob> watchStatus(String partnerId) =>
      _channel<EncBlob>('st', 'status', 'user_id', partnerId, (m) => EncBlob(m['cipher'] as String, m['nonce'] as String));

  @override
  Future<void> heartbeat({bool paused = false, DateTime? pausedUntil}) async {
    await _c.rpc('heartbeat', params: {
      'p_paused': paused,
      'p_paused_until': pausedUntil?.toUtc().toIso8601String(),
    });
  }

  PresenceDto _presence(Map<String, dynamic> m) => PresenceDto(
        userId: m['user_id'] as String,
        heartbeatAt: DateTime.parse(m['heartbeat_at'] as String),
        paused: m['paused'] as bool? ?? false,
        pausedUntil: m['paused_until'] == null ? null : DateTime.parse(m['paused_until'] as String),
      );

  @override
  Future<PresenceDto?> getPresence(String userId) async {
    final m = await _c.from('presence').select().eq('user_id', userId).maybeSingle();
    return m == null ? null : _presence(m);
  }

  @override
  Stream<PresenceDto> watchPresence(String userId) =>
      _channel<PresenceDto>('pr', 'presence', 'user_id', userId, _presence);

  @override
  Future<void> sendEvent(String coupleId, String kind, EncBlob blob) => _c.from('events').insert({
        'couple_id': coupleId,
        'user_id': userId,
        'kind': kind,
        'cipher': blob.cipherB64,
        'nonce': blob.nonceB64,
      });

  EncEvent _event(Map<String, dynamic> m) => EncEvent(
        id: m['id'] as String,
        userId: m['user_id'] as String,
        kind: m['kind'] as String,
        createdAt: DateTime.parse(m['created_at'] as String),
        blob: EncBlob(m['cipher'] as String, m['nonce'] as String),
      );

  @override
  Future<List<EncEvent>> fetchEvents(String coupleId, {DateTime? since}) async {
    var q = _c.from('events').select().eq('couple_id', coupleId);
    if (since != null) q = q.gt('created_at', since.toUtc().toIso8601String());
    final rows = await q.order('created_at', ascending: false).limit(200);
    return rows.map(_event).toList();
  }

  @override
  Stream<EncEvent> watchEvents(String coupleId) => _channel<EncEvent>('ev', 'events', 'couple_id', coupleId, _event);

  @override
  Future<void> upsertPin(String coupleId, String? id, EncBlob blob, {bool deleted = false}) => _c.from('pins').upsert({
        if (id != null) 'id': id,
        'couple_id': coupleId,
        'user_id': userId,
        'cipher': blob.cipherB64,
        'nonce': blob.nonceB64,
        'deleted': deleted,
        'updated_at': DateTime.now().toUtc().toIso8601String(),
      });

  EncPin _pin(Map<String, dynamic> m) => EncPin(
        id: m['id'] as String,
        userId: m['user_id'] as String,
        updatedAt: DateTime.parse(m['updated_at'] as String),
        blob: EncBlob(m['cipher'] as String, m['nonce'] as String),
        deleted: m['deleted'] as bool? ?? false,
      );

  @override
  Future<List<EncPin>> fetchPins(String coupleId) async {
    final rows = await _c.from('pins').select().eq('couple_id', coupleId).eq('deleted', false);
    return rows.map(_pin).toList();
  }

  @override
  Stream<EncPin> watchPins(String coupleId) => _channel<EncPin>('pin', 'pins', 'couple_id', coupleId, _pin);

  @override
  Future<void> logRemote(String level, String message) async {
    try {
      await _c.from('diag_logs').insert({'user_id': userId, 'level': level, 'message': message});
    } catch (e) {
      AppLog.w('diag', 'remote log failed');
    }
  }
}
