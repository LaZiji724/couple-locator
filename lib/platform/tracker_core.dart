import 'dart:async';
import 'dart:io';

import 'package:battery_plus/battery_plus.dart';
import 'package:connectivity_plus/connectivity_plus.dart';
import 'package:geolocator/geolocator.dart';
import 'package:uuid/uuid.dart';
import 'package:drift/drift.dart' show Value;

import '../core/log.dart';
import '../data/local/database.dart';
import '../data/remote/backend.dart';
import '../data/repo/channel_factory.dart';
import '../data/repo/key_store.dart';
import '../data/repo/secure_channel.dart';
import '../data/repo/settings_store.dart';
import '../domain/location/sampling.dart';
import '../domain/location/track_tools.dart';
import '../domain/models/loc_point.dart';
import '../domain/models/status.dart';

/// 与 UI 无关的定位上报核心：Android 在前台服务 isolate 中运行，iOS 在主 isolate 中运行。
class TrackerCore {
  TrackerCore({required this.backend, required this.db, required this.keys, required this.settings});
  final Backend backend;
  final AppDb db;
  final KeyStore keys;
  final SettingsStore settings;

  final _battery = Battery();
  final _clientId = const Uuid().v4();
  StreamSubscription<Position>? _posSub;
  SecureChannel? _channel;
  CoupleDto? _couple;
  MoveState _motion = MoveState.still;
  String? _activity;
  SamplingPlan? _activePlan;
  DateTime _lastUpload = DateTime.fromMillisecondsSinceEpoch(0);
  DateTime _lastHeartbeat = DateTime.fromMillisecondsSinceEpoch(0);
  DateTime _lastStatus = DateTime.fromMillisecondsSinceEpoch(0);
  LocPoint? _last;
  bool _running = false;
  bool _flushing = false;
  int _battLevel = 100;
  bool _charging = false;

  /// 供外部（通知栏按钮）切换暂停。
  Future<void> start() async {
    _running = true;
    AppLog.i('tracker', 'start');
    await _ensureChannel();
  }

  Future<void> stop() async {
    _running = false;
    await _posSub?.cancel();
    _posSub = null;
    _activePlan = null;
  }

  void setActivity(String? a) => _activity = a;

  Future<void> _ensureChannel() async {
    if (_channel != null) return;
    try {
      _couple = await backend.getMyCouple();
      _channel = await openChannel(backend, keys, couple: _couple);
    } catch (e) {
      AppLog.w('tracker', '建立加密通道失败：$e');
    }
  }

  /// 每 ~3 秒调用一次：决定是否改变采样、是否上传、是否发心跳。
  Future<void> tick() async {
    if (!_running) return;
    await settings.reload();
    await _readBattery();
    final now = DateTime.now();

    if (settings.isPaused(now) && !settings.sosActive) {
      await _posSub?.cancel();
      _posSub = null;
      _activePlan = null;
      if (now.difference(_lastHeartbeat) >= const Duration(minutes: 5)) {
        await _heartbeat(paused: true);
      }
      return;
    }

    final plan = planFor(
      motion: _motion,
      mode: settings.mode,
      batteryPercent: _battLevel,
      charging: _charging,
      sos: settings.sosActive,
    );
    _applyPlan(plan);

    final due = now.difference(_lastUpload) >= plan.uploadInterval;
    if (due) {
      await flush();
    }
    if (now.difference(_lastHeartbeat) >= (plan.significantOnly ? const Duration(minutes: 5) : const Duration(minutes: 2))) {
      await _heartbeat();
    }
  }

  void _applyPlan(SamplingPlan plan) {
    final old = _activePlan;
    if (old != null && old.sampleInterval == plan.sampleInterval && old.significantOnly == plan.significantOnly && _posSub != null) {
      return;
    }
    _activePlan = plan;
    _posSub?.cancel();
    final LocationSettings ls;
    final distance = plan.significantOnly ? 50 : 5;
    if (Platform.isAndroid) {
      ls = AndroidSettings(
        accuracy: plan.significantOnly ? LocationAccuracy.medium : LocationAccuracy.high,
        distanceFilter: distance,
        intervalDuration: plan.sampleInterval,
      );
    } else if (Platform.isIOS) {
      ls = AppleSettings(
        accuracy: plan.significantOnly ? LocationAccuracy.low : LocationAccuracy.best,
        activityType: ActivityType.otherNavigation,
        distanceFilter: distance,
        pauseLocationUpdatesAutomatically: false,
        showBackgroundLocationIndicator: true,
        allowBackgroundLocationUpdates: true,
      );
    } else {
      ls = LocationSettings(distanceFilter: distance);
    }
    _posSub = Geolocator.getPositionStream(locationSettings: ls).listen(_onPosition, onError: (e) {
      AppLog.e('gps', e);
      AppLog.uploadFail('定位失败：$e');
    });
  }

  Future<void> _onPosition(Position p) async {
    final pt = LocPoint(
      ts: p.timestamp.toLocal(),
      lat: p.latitude,
      lng: p.longitude,
      accuracy: p.accuracy,
      speed: p.speed < 0 ? 0 : p.speed,
    );
    // 过滤低精度与漂移点
    final prev = _last;
    final ok = filterNoisy([if (prev != null) prev, pt]);
    if (ok.length < (prev == null ? 1 : 2)) return;
    _last = pt;
    _motion = classifyMotion(speedMps: pt.speed, activity: _activity);
    final uid = backend.userId;
    if (uid == null) return;
    await db.upsertPoint(PointsCompanion.insert(
      ownerId: uid,
      clientId: _clientId,
      ts: pt.ts.millisecondsSinceEpoch,
      lat: pt.lat,
      lng: pt.lng,
      accuracy: Value(pt.accuracy),
      speed: Value(pt.speed),
    ));
    if (settings.sosActive) await flush();
  }

  /// 按时间顺序批量上传本地未上传的点（断网后自动补传，幂等）。
  Future<void> flush() async {
    if (_flushing) return;
    _flushing = true;
    try {
      await _ensureChannel();
      final ch = _channel;
      final c = _couple;
      final uid = backend.userId;
      if (ch == null || c == null || uid == null) {
        AppLog.uploadFail('尚未配对或对方密钥未就绪');
        return;
      }
      while (true) {
        final pending = await db.pendingUploads(limit: 200);
        if (pending.isEmpty) break;
        final items = <EncLocation>[];
        for (final r in pending) {
          final blob = await ch.sealLocation(
              LocPoint(ts: DateTime.fromMillisecondsSinceEpoch(r.ts), lat: r.lat, lng: r.lng, accuracy: r.accuracy, speed: r.speed).toJson(),
              r.ts);
          items.add(EncLocation(userId: uid, clientId: r.clientId, clientTs: r.ts, blob: blob));
        }
        await backend.uploadLocations(c.id, items);
        await db.markUploaded(pending.map((e) => e.id).toList());
        AppLog.uploadOk();
        if (pending.length < 200) break;
      }
      _lastUpload = DateTime.now();
      await _pushStatus();
      await _heartbeat();
    } catch (e) {
      AppLog.uploadFail(e);
    } finally {
      _flushing = false;
    }
  }

  Future<void> _heartbeat({bool paused = false}) async {
    try {
      final until = settings.pauseUntil;
      await backend.heartbeat(
        paused: paused || settings.isPaused(),
        pausedUntil: until > 0 ? DateTime.fromMillisecondsSinceEpoch(until) : null,
      );
      _lastHeartbeat = DateTime.now();
    } catch (e) {
      AppLog.w('heartbeat', '$e');
    }
  }

  Future<void> _readBattery() async {
    try {
      _battLevel = await _battery.batteryLevel;
      final st = await _battery.batteryState;
      _charging = st == BatteryState.charging || st == BatteryState.full;
    } catch (_) {}
  }

  Future<void> _pushStatus() async {
    final ch = _channel;
    final c = _couple;
    if (ch == null || c == null) return;
    final now = DateTime.now();
    if (now.difference(_lastStatus) < const Duration(seconds: 30) && !settings.sosActive) return;
    try {
      final conn = await Connectivity().checkConnectivity();
      final net = conn.contains(ConnectivityResult.wifi)
          ? 'wifi'
          : conn.contains(ConnectivityResult.mobile)
              ? 'cellular'
              : 'none';
      bool lowPower = false;
      try {
        lowPower = await _battery.isInBatterySaveMode;
      } catch (_) {}
      final st = DeviceStatus(
        battery: _battLevel,
        charging: _charging,
        network: net,
        lowPower: lowPower,
        motion: _motion,
        ts: now,
        sos: settings.sosActive,
      );
      final blob = await ch.seal(st.toJson(), 'status');
      await backend.upsertStatus(c.id, blob);
      _lastStatus = now;
    } catch (e) {
      AppLog.w('status', '$e');
    }
  }

  /// 立即取一次当前位置（到家按钮用）。
  Future<Position?> currentOnce() async {
    try {
      return await Geolocator.getCurrentPosition(
          locationSettings: const LocationSettings(accuracy: LocationAccuracy.high, timeLimit: Duration(seconds: 12)));
    } catch (_) {
      return Geolocator.getLastKnownPosition();
    }
  }
}
