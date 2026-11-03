import 'dart:async';
import 'dart:convert';

import 'package:drift/drift.dart' show Value;
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:supabase_flutter/supabase_flutter.dart';

import '../core/config/app_config.dart';
import '../core/log.dart';
import '../data/local/database.dart';
import '../data/remote/backend.dart';
import '../data/remote/supabase_backend.dart';
import '../data/repo/channel_factory.dart';
import '../data/repo/key_store.dart';
import '../data/repo/secure_channel.dart';
import '../data/repo/settings_store.dart';
import '../domain/models/loc_point.dart';
import '../domain/models/status.dart';
import '../platform/geocode.dart';
import '../platform/notifications.dart';

final backendProvider = Provider<Backend>((ref) {
  return SupabaseBackend(Supabase.instance.client);
});

final dbProvider = Provider<AppDb>((ref) {
  final db = AppDb();
  ref.onDispose(db.close);
  return db;
});

final keyStoreProvider = Provider<KeyStore>((ref) => KeyStore());

final settingsProvider = NotifierProvider<SettingsNotifier, SettingsStore?>(SettingsNotifier.new);

class SettingsNotifier extends Notifier<SettingsStore?> {
  int _rev = 0;
  int get rev => _rev;
  @override
  SettingsStore? build() {
    SettingsStore.open().then((s) => state = s);
    return null;
  }

  /// 修改后触发重建（SettingsStore 本身是可变对象，用版本号通知）。
  void touch() {
    _rev++;
    final s = state;
    state = null;
    state = s;
  }
}

final themeModeProvider = Provider<ThemeMode>((ref) {
  final s = ref.watch(settingsProvider);
  return switch (s?.themeMode) { 'light' => ThemeMode.light, 'dark' => ThemeMode.dark, _ => ThemeMode.system };
});

final authProvider = StreamProvider<bool>((ref) async* {
  if (!AppConfig.backendConfigured) {
    yield false;
    return;
  }
  final b = ref.watch(backendProvider);
  yield b.userId != null;
  yield* b.authChanges;
});

final myProfileProvider = FutureProvider<ProfileDto?>((ref) async {
  final signed = ref.watch(authProvider).value ?? false;
  if (!signed) return null;
  final b = ref.watch(backendProvider);
  return b.getProfile(b.userId!);
});

/// 同步状态（全部为解密后的数据）。
class SyncState {
  const SyncState({
    this.loading = true,
    this.couple,
    this.me,
    this.partner,
    this.channel,
    this.myPoint,
    this.partnerPoint,
    this.myStatus,
    this.partnerStatus,
    this.partnerPresence,
    this.events = const [],
    this.pins = const [],
    this.keyProblem,
    this.pendingSos,
  });
  final bool loading;
  final CoupleDto? couple;
  final ProfileDto? me;
  final ProfileDto? partner;
  final SecureChannel? channel;
  final LocPoint? myPoint;
  final LocPoint? partnerPoint;
  final DeviceStatus? myStatus;
  final DeviceStatus? partnerStatus;
  final PresenceDto? partnerPresence;
  final List<CoupleEvent> events;
  final List<MapPin> pins;
  final String? keyProblem;
  final CoupleEvent? pendingSos; // 对方发起、尚未确认的 SOS

  bool get paired => couple != null;

  SyncState copyWith({
    bool? loading,
    Object? couple = _s,
    Object? me = _s,
    Object? partner = _s,
    Object? channel = _s,
    Object? myPoint = _s,
    Object? partnerPoint = _s,
    Object? myStatus = _s,
    Object? partnerStatus = _s,
    Object? partnerPresence = _s,
    List<CoupleEvent>? events,
    List<MapPin>? pins,
    Object? keyProblem = _s,
    Object? pendingSos = _s,
  }) =>
      SyncState(
        loading: loading ?? this.loading,
        couple: couple == _s ? this.couple : couple as CoupleDto?,
        me: me == _s ? this.me : me as ProfileDto?,
        partner: partner == _s ? this.partner : partner as ProfileDto?,
        channel: channel == _s ? this.channel : channel as SecureChannel?,
        myPoint: myPoint == _s ? this.myPoint : myPoint as LocPoint?,
        partnerPoint: partnerPoint == _s ? this.partnerPoint : partnerPoint as LocPoint?,
        myStatus: myStatus == _s ? this.myStatus : myStatus as DeviceStatus?,
        partnerStatus: partnerStatus == _s ? this.partnerStatus : partnerStatus as DeviceStatus?,
        partnerPresence: partnerPresence == _s ? this.partnerPresence : partnerPresence as PresenceDto?,
        events: events ?? this.events,
        pins: pins ?? this.pins,
        keyProblem: keyProblem == _s ? this.keyProblem : keyProblem as String?,
        pendingSos: pendingSos == _s ? this.pendingSos : pendingSos as CoupleEvent?,
      );
}

const _s = Object();

final syncProvider = NotifierProvider<SyncNotifier, SyncState>(SyncNotifier.new);

class SyncNotifier extends Notifier<SyncState> {
  final _subs = <StreamSubscription>[];
  Timer? _timer;
  final _seenEvents = <String>{};
  bool _disposed = false;
  int _bootGen = 0;

  Backend get _b => ref.read(backendProvider);
  AppDb get _db => ref.read(dbProvider);

  @override
  SyncState build() {
    ref.onDispose(() {
      _disposed = true;
      _cancel();
    });
    ref.listen(authProvider, (_, next) {
      if (next.value == true) {
        _boot();
      } else {
        _cancel();
        state = const SyncState(loading: false);
      }
    }, fireImmediately: true);
    return const SyncState();
  }

  void _cancel() {
    for (final s in _subs) {
      s.cancel();
    }
    _subs.clear();
    _timer?.cancel();
    _timer = null;
  }

  Future<void> reload() => _boot();

  Future<void> _boot() async {
    final gen = ++_bootGen;
    _cancel();
    try {
      final me = await _b.getProfile(_b.userId!);
      if (gen != _bootGen || _disposed) return;
      // 确保设备密钥存在并上传公钥
      final keys = ref.read(keyStoreProvider);
      final kp = await keys.loadOrCreate(_b.userId!);
      if (me != null && me.publicKeyB64 != base64Encode(kp.pub)) {
        await _b.upsertProfile(ProfileDto(
          id: me.id,
          nickname: me.nickname,
          avatarEmoji: me.avatarEmoji,
          avatarUrl: me.avatarUrl,
          themeId: me.themeId,
          publicKeyB64: base64Encode(kp.pub),
        ));
      }
      final couple = await _b.getMyCouple();
      state = state.copyWith(loading: false, me: me, couple: couple);
      _subs.add(_b.watchCouple().listen((c) {
        if ((c?.id) != state.couple?.id) _boot();
      }, onError: (e) => AppLog.w('couple', '$e')));
      if (couple == null) return;
      await _connectPartner(couple, gen);
    } catch (e) {
      AppLog.e('sync', e);
      state = state.copyWith(loading: false);
    }
  }

  Future<void> _connectPartner(CoupleDto couple, int gen) async {
    final me = _b.userId!;
    final partnerId = couple.partnerOf(me);
    final partner = await _b.getProfile(partnerId);
    final ch = await openChannel(_b, ref.read(keyStoreProvider), couple: couple);
    if (gen != _bootGen || _disposed) return;
    state = state.copyWith(partner: partner, channel: ch, keyProblem: ch == null ? '对方的加密密钥还没准备好，请对方先打开一次 App' : null);
    if (ch == null) {
      _timer = Timer(const Duration(seconds: 8), () => _boot());
      return;
    }
    await _catchUp(couple, ch, partnerId);
    // Realtime
    _subs.add(_b.watchLocations(couple.id, partnerId).listen((e) => _onLocation(ch, e), onError: (e) => AppLog.w('rt', '$e')));
    _subs.add(_b.watchStatus(partnerId).listen((e) async {
      try {
        final j = await ch.open_(e, partnerId, 'status');
        state = state.copyWith(partnerStatus: DeviceStatus.fromJson(j));
      } catch (_) {}
    }));
    _subs.add(_b.watchPresence(partnerId).listen((p) => state = state.copyWith(partnerPresence: p)));
    _subs.add(_b.watchEvents(couple.id).listen((e) => _onEvent(ch, e, notify: true)));
    _subs.add(_b.watchPins(couple.id).listen((_) => _loadPins(couple, ch)));
    _timer = Timer.periodic(const Duration(seconds: 30), (_) => _poll(couple, ch, partnerId));
    // 自己最近一个点
    _refreshMine();
  }

  Future<void> _catchUp(CoupleDto couple, SecureChannel ch, String partnerId) async {
    // 对方最近状态与心跳
    state = state.copyWith(partnerPresence: await _b.getPresence(partnerId));
    // 最近 6 小时位置（用于首屏）
    final now = DateTime.now();
    final since = now.subtract(const Duration(hours: 6));
    try {
      final recent = await _b.fetchLocations(couple.id, partnerId, since, now.add(const Duration(minutes: 5)));
      for (final e in recent) {
        await _storeLocation(ch, e);
      }
    } catch (e) {
      AppLog.w('sync', '拉取最近位置失败：$e');
    }
    final latest = await _db.latestPoint(partnerId);
    if (latest != null) state = state.copyWith(partnerPoint: _toPoint(latest));
    // 事件（补拉错过的事件 —— iOS 被杀后唤醒的缓解手段）
    try {
      final evs = await _b.fetchEvents(couple.id);
      final last = ref.read(settingsProvider)?.lastEventTs ?? 0;
      for (final e in evs.reversed) {
        await _onEvent(ch, e, notify: e.createdAt.millisecondsSinceEpoch > last && e.userId != _b.userId);
      }
    } catch (e) {
      AppLog.w('sync', '拉取事件失败：$e');
    }
    await _loadPins(couple, ch);
    // 状态
    // （首次状态通过 realtime 到达；这里无需额外拉取）
  }

  Future<void> _poll(CoupleDto couple, SecureChannel ch, String partnerId) async {
    try {
      state = state.copyWith(partnerPresence: await _b.getPresence(partnerId));
      final last = await _db.latestPoint(partnerId);
      final from = last != null ? DateTime.fromMillisecondsSinceEpoch(last.ts) : DateTime.now().subtract(const Duration(hours: 1));
      final fresh = await _b.fetchLocations(couple.id, partnerId, from, DateTime.now().add(const Duration(minutes: 5)));
      for (final e in fresh) {
        await _storeLocation(ch, e);
      }
      final latest = await _db.latestPoint(partnerId);
      if (latest != null) state = state.copyWith(partnerPoint: _toPoint(latest));
      _refreshMine();
    } catch (_) {}
  }

  LocPoint _toPoint(Point r) => LocPoint(
      ts: DateTime.fromMillisecondsSinceEpoch(r.ts), lat: r.lat, lng: r.lng, accuracy: r.accuracy, speed: r.speed);

  Future<void> _refreshMine() async {
    final p = await _db.latestPoint(_b.userId!);
    if (p != null) state = state.copyWith(myPoint: _toPoint(p));
  }

  void setMyPoint(LocPoint p) => state = state.copyWith(myPoint: p);

  Future<void> _storeLocation(SecureChannel ch, EncLocation e) async {
    try {
      final j = await ch.openLocation(e.blob, e.userId, e.clientTs);
      final p = LocPoint.fromJson(j);
      await _db.upsertPoint(PointsCompanion.insert(
        ownerId: e.userId,
        clientId: e.clientId,
        ts: e.clientTs,
        lat: p.lat,
        lng: p.lng,
        accuracy: Value(p.accuracy),
        speed: Value(p.speed),
        uploaded: const Value(true),
      ));
    } catch (_) {
      AppLog.w('sync', '一条位置解密失败（已忽略）');
    }
  }

  Future<void> _onLocation(SecureChannel ch, EncLocation e) async {
    await _storeLocation(ch, e);
    final latest = await _db.latestPoint(e.userId);
    if (latest != null) state = state.copyWith(partnerPoint: _toPoint(latest));
  }

  Future<void> _onEvent(SecureChannel ch, EncEvent e, {required bool notify}) async {
    if (!_seenEvents.add(e.id)) return;
    try {
      final j = await ch.open_(e.blob, e.userId, 'event');
      final ev = CoupleEvent(
        id: e.id,
        userId: e.userId,
        kind: EventKindX.parse(e.kind),
        at: e.createdAt.toLocal(),
        lat: (j['la'] as num?)?.toDouble(),
        lng: (j['ln'] as num?)?.toDouble(),
        emoji: j['e'] as String?,
        text: j['x'] as String?,
      );
      final list = [...state.events, ev]..sort((a, b) => b.at.compareTo(a.at));
      var pending = state.pendingSos;
      final fromPartner = e.userId != _b.userId;
      if (ev.kind == EventKind.sos && fromPartner) {
        pending = ev;
      } else if ((ev.kind == EventKind.sosCancel || ev.kind == EventKind.sosAck) && pending != null) {
        // 取消(来自对方) / 我已确认
        pending = null;
      }
      state = state.copyWith(events: list, pendingSos: pending);
      if (notify && fromPartner) {
        final name = state.partner?.nickname.isNotEmpty == true ? state.partner!.nickname : 'TA';
        switch (ev.kind) {
          case EventKind.sos:
            LocalNotifier.instance.show(NotifIds.sos, '🚨 $name 需要帮助！', '对方发起了 SOS 紧急求助，请立即查看', sos: true, payload: 'sos');
          case EventKind.arrived:
            LocalNotifier.instance.show(NotifIds.arrived, '🏠 $name 报平安了', ev.text?.isNotEmpty == true ? ev.text! : '已安全到达', payload: 'arrived');
          case EventKind.poke:
            LocalNotifier.instance.show(NotifIds.poke, '$name 戳了你一下', '${ev.emoji ?? '👋'} 点开看看', payload: 'poke');
          case EventKind.ack:
            LocalNotifier.instance.show(NotifIds.arrived, '$name 回复了', '收到 ✔️', payload: 'ack');
          default:
        }
        pokeStream.add(ev);
      }
      final s = ref.read(settingsProvider);
      if (s != null && e.createdAt.millisecondsSinceEpoch > s.lastEventTs) {
        await s.setLastEventTs(e.createdAt.millisecondsSinceEpoch);
      }
    } catch (_) {
      AppLog.w('sync', '一条事件解密失败（已忽略）');
    }
  }

  /// 新到达的对方事件（供页面播放动画）。
  final pokeStream = StreamController<CoupleEvent>.broadcast();

  Future<void> _loadPins(CoupleDto couple, SecureChannel ch) async {
    try {
      final rows = await _b.fetchPins(couple.id);
      final out = <MapPin>[];
      for (final r in rows) {
        try {
          final j = await ch.open_(r.blob, r.userId, 'pin:${r.id}');
          out.add(MapPin(
            id: r.id,
            lat: (j['la'] as num).toDouble(),
            lng: (j['ln'] as num).toDouble(),
            name: j['name'] as String? ?? '',
            emoji: j['e'] as String? ?? '📍',
            note: j['note'] as String? ?? '',
            photoB64: j['ph'] as String?,
            updatedAt: r.updatedAt,
            ownerId: r.userId,
          ));
        } catch (_) {}
      }
      state = state.copyWith(pins: out);
    } catch (_) {}
  }

  Future<void> refreshPins() async {
    final c = state.couple, ch = state.channel;
    if (c != null && ch != null) await _loadPins(c, ch);
  }

  // ── 动作 ──
  Future<void> sendEvent(EventKind kind, {double? lat, double? lng, String? emoji, String? text}) async {
    final c = state.couple, ch = state.channel;
    if (c == null || ch == null) throw StateError('尚未配对或密钥未就绪');
    final blob = await ch.seal({
      if (lat != null) 'la': lat,
      if (lng != null) 'ln': lng,
      if (emoji != null) 'e': emoji,
      if (text != null) 'x': text,
    }, 'event');
    await _b.sendEvent(c.id, kind.wire, blob);
  }

  /// 新建或编辑标记。id 为空表示新建（由客户端生成 uuid，便于 AAD 绑定）。
  Future<void> savePin(MapPin p, {bool delete = false}) async {
    final c = state.couple, ch = state.channel;
    if (c == null || ch == null) throw StateError('尚未配对或密钥未就绪');
    final blob = await ch.seal(p.toJson(), 'pin:${p.id}');
    await _b.upsertPin(c.id, p.id, blob, deleted: delete);
    await _loadPins(c, ch);
  }

  Future<String> placeName(double lat, double lng) => Geocoder.instance.name(lat, lng);

  /// 读取某人某天的轨迹：优先本地，缺失时从服务端拉取解密后缓存。
  Future<List<LocPoint>> loadDay(String ownerId, DateTime day, {bool forceRemote = false}) async {
    final from = DateTime(day.year, day.month, day.day);
    final to = from.add(const Duration(days: 1));
    var rows = await _db.pointsBetween(ownerId, from, to);
    final c = state.couple, ch = state.channel;
    final isToday = DateTime.now().isBefore(to);
    if ((rows.length < 2 || forceRemote || isToday) && c != null && ch != null) {
      try {
        final remote = await _b.fetchLocations(c.id, ownerId, from, to);
        for (final e in remote) {
          await _storeLocation(ch, e);
        }
        rows = await _db.pointsBetween(ownerId, from, to);
      } catch (e) {
        AppLog.w('history', '拉取轨迹失败：$e');
      }
    }
    return rows.map(_toPoint).toList();
  }

  /// 某时间段内两人的全部轨迹（统计用）。
  Future<List<LocPoint>> loadRange(String ownerId, DateTime from, DateTime to) async {
    final c = state.couple, ch = state.channel;
    if (c != null && ch != null) {
      try {
        for (final e in await _b.fetchLocations(c.id, ownerId, from, to)) {
          await _storeLocation(ch, e);
        }
      } catch (_) {}
    }
    return (await _db.pointsBetween(ownerId, from, to)).map(_toPoint).toList();
  }
}
