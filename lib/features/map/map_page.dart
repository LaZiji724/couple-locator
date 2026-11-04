import 'dart:async';
import 'dart:math' as math;
import 'dart:typed_data';

import 'package:amap_map/amap_map.dart';
import 'package:flutter/material.dart';
import 'package:flutter/scheduler.dart';
import 'package:flutter/services.dart';
import 'package:flutter/services.dart' show rootBundle;
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:geolocator/geolocator.dart';
import 'package:phosphor_flutter/phosphor_flutter.dart';
import 'package:x_amap_base/x_amap_base.dart';

import '../../app/providers.dart';
import '../../core/format.dart';
import '../../core/geo/coord.dart';
import '../../core/theme/app_theme.dart';
import '../../core/theme/motion.dart';
import '../../core/theme/tokens.dart';
import '../../core/widgets/effects.dart';
import '../../core/widgets/vibe_widgets.dart';
import '../../domain/models/loc_point.dart';
import '../../domain/models/status.dart';
import '../../platform/tracker_service.dart';
import 'avatar_marker.dart';
import 'partner_sheet.dart';
import 'pin_editor.dart';
import 'share_control.dart';
import 'sos_trigger.dart';

LatLng _gcj(double lat, double lng) {
  final g = CoordConverter.wgs84ToGcj02(lat, lng);
  return LatLng(g.lat, g.lng);
}

/// 平滑插值位置。
class _Smooth {
  LatLng? from, to;
  DateTime start = DateTime.fromMillisecondsSinceEpoch(0);
  static const dur = Duration(milliseconds: 800);

  void moveTo(LatLng p) {
    final now = DateTime.now();
    if (to == null) {
      from = to = p;
    } else if (to!.latitude != p.latitude || to!.longitude != p.longitude) {
      from = current(now);
      to = p;
      start = now;
    }
  }

  bool animating(DateTime now) => to != null && now.difference(start) < dur;

  LatLng? current(DateTime now) {
    if (to == null) return null;
    final t = (now.difference(start).inMilliseconds / dur.inMilliseconds).clamp(0.0, 1.0);
    final e = Curves.easeInOut.transform(t);
    return LatLng(from!.latitude + (to!.latitude - from!.latitude) * e, from!.longitude + (to!.longitude - from!.longitude) * e);
  }
}

class MapPage extends ConsumerStatefulWidget {
  const MapPage({super.key});
  @override
  ConsumerState<MapPage> createState() => _MapPageState();
}

class _MapPageState extends ConsumerState<MapPage> with SingleTickerProviderStateMixin {
  AMapController? _ctl;
  final _me = _Smooth(), _partner = _Smooth();
  late final Ticker _ticker;
  DateTime _lastFrame = DateTime.fromMillisecondsSinceEpoch(0);
  Offset? _meScreen, _partnerScreen;
  BitmapDescriptor? _meIcon, _partnerIcon;
  String? _meIconKey, _partnerIconKey;
  final _pinIcons = <String, BitmapDescriptor>{};
  StreamSubscription<Position>? _pos;
  StreamSubscription<CoupleEvent>? _evSub;
  CustomStyleOptions? _style;
  bool _closeHearts = false;
  final _effects = <Widget>[];
  bool _didInitialFit = false;

  @override
  void initState() {
    super.initState();
    _ticker = createTicker(_onTick)..start();
    _loadStyle();
    _startOwnPosition();
    WidgetsBinding.instance.addPostFrameCallback((_) {
      _evSub = ref.read(syncProvider.notifier).pokeStream.stream.listen(_onPartnerEvent);
    });
  }

  Future<void> _loadStyle() async {
    // 自定义地图样式：在高德控制台生成后放入 assets/map_style/style.data（见 docs/AMAP.md）。没有则使用默认样式。
    try {
      final style = (await rootBundle.load('assets/map_style/style.data')).buffer.asUint8List();
      Uint8List? extra;
      try {
        extra = (await rootBundle.load('assets/map_style/style_extra.data')).buffer.asUint8List();
      } catch (_) {}
      if (mounted) setState(() => _style = CustomStyleOptions(true, styleData: style, styleExtraData: extra));
    } catch (_) {}
  }

  Future<void> _startOwnPosition() async {
    try {
      if (!await Geolocator.isLocationServiceEnabled()) return;
      final perm = await Geolocator.checkPermission();
      if (perm == LocationPermission.denied || perm == LocationPermission.deniedForever) return;
      final last = await Geolocator.getLastKnownPosition();
      if (last != null) _setMine(last);
      _pos = Geolocator.getPositionStream(locationSettings: const LocationSettings(accuracy: LocationAccuracy.high, distanceFilter: 3)).listen(_setMine);
    } catch (_) {}
  }

  void _setMine(Position p) {
    if (p.accuracy > 100) return;
    ref.read(syncProvider.notifier).setMyPoint(LocPoint(ts: p.timestamp.toLocal(), lat: p.latitude, lng: p.longitude, accuracy: p.accuracy, speed: math.max(0, p.speed)));
  }

  void _onPartnerEvent(CoupleEvent e) {
    if (!mounted) return;
    if (e.kind == EventKind.poke) {
      final w = UniqueKey();
      setState(() => _effects.add(Positioned(
            key: w,
            left: (_partnerScreen?.dx ?? MediaQuery.sizeOf(context).width / 2) - 60,
            top: (_partnerScreen?.dy ?? MediaQuery.sizeOf(context).height / 2) - 70,
            width: 120,
            height: 120,
            child: FloatingEmojis(emoji: e.emoji ?? '👋', onDone: () => setState(() => _effects.removeWhere((x) => x.key == w))),
          )));
    } else if (e.kind == EventKind.arrived) {
      final w = UniqueKey();
      setState(() => _effects.add(Positioned.fill(key: w, child: Confetti())));
      Future.delayed(const Duration(milliseconds: 2400), () {
        if (mounted) setState(() => _effects.removeWhere((x) => x.key == w));
      });
    }
  }

  void _onTick(Duration _) {
    final now = DateTime.now();
    final animating = _me.animating(now) || _partner.animating(now);
    if (now.difference(_lastFrame).inMilliseconds < (animating ? 33 : 250)) return;
    _lastFrame = now;
    if (!mounted) return;
    _refreshScreen();
    if (animating) setState(() {});
  }

  Future<void> _refreshScreen() async {
    final c = _ctl;
    if (c == null) return;
    final now = DateTime.now();
    try {
      final m = _me.current(now), p = _partner.current(now);
      Offset toOff(ScreenCoordinate s) => Offset(s.x.toDouble(), s.y.toDouble());
      final dpr = MediaQuery.devicePixelRatioOf(context);
      Offset? mo, po;
      if (m != null) {
        final s = await c.toScreenCoordinate(m);
        mo = toOff(s) / (Theme.of(context).platform == TargetPlatform.android ? dpr : 1);
      }
      if (p != null) {
        final s = await c.toScreenCoordinate(p);
        po = toOff(s) / (Theme.of(context).platform == TargetPlatform.android ? dpr : 1);
      }
      if (mounted && (mo != _meScreen || po != _partnerScreen)) {
        setState(() {
          _meScreen = mo;
          _partnerScreen = po;
        });
      }
    } catch (_) {}
  }

  @override
  void dispose() {
    _ticker.dispose();
    _pos?.cancel();
    _evSub?.cancel();
    super.dispose();
  }

  Future<void> _refreshIcons(SyncState s) async {
    final mp = PersonalPalette.byId(s.me?.themeId);
    final pp = PersonalPalette.byId(s.partner?.themeId);
    final paused = s.partnerPresence?.isPausedNow(DateTime.now()) ?? false;
    final k1 = '${mp.id}|${s.me?.avatarEmoji}|${s.me?.avatarUrl?.hashCode}';
    final k2 = '${pp.id}|${s.partner?.avatarEmoji}|${s.partner?.avatarUrl?.hashCode}|${s.partnerStatus?.lowBattery}|$paused';
    final dpr = MediaQuery.devicePixelRatioOf(context);
    if (k1 != _meIconKey) {
      _meIconKey = k1;
      final ic = await AvatarMarkerPainter.build(palette: mp, emoji: s.me?.avatarEmoji, photoDataUri: s.me?.avatarUrl, scale: dpr);
      if (mounted) setState(() => _meIcon = ic);
    }
    if (k2 != _partnerIconKey) {
      _partnerIconKey = k2;
      final ic = await AvatarMarkerPainter.build(palette: pp, emoji: s.partner?.avatarEmoji, photoDataUri: s.partner?.avatarUrl, lowBattery: s.partnerStatus?.lowBattery ?? false, paused: paused, scale: dpr);
      if (mounted) setState(() => _partnerIcon = ic);
    }
    for (final p in s.pins) {
      if (!_pinIcons.containsKey(p.emoji)) {
        _pinIcons[p.emoji] = await AvatarMarkerPainter.pin(p.emoji, scale: dpr);
        if (mounted) setState(() {});
      }
    }
  }

  void _fit({bool both = true, bool partner = false, bool me = false}) {
    final c = _ctl;
    final s = ref.read(syncProvider);
    if (c == null) return;
    HapticFeedback.selectionClick();
    final mp = s.myPoint, pp = s.partnerPoint;
    if (both && mp != null && pp != null) {
      final a = _gcj(mp.lat, mp.lng), b = _gcj(pp.lat, pp.lng);
      final sw = LatLng(math.min(a.latitude, b.latitude), math.min(a.longitude, b.longitude));
      final ne = LatLng(math.max(a.latitude, b.latitude), math.max(a.longitude, b.longitude));
      if ((ne.latitude - sw.latitude).abs() < 1e-5 && (ne.longitude - sw.longitude).abs() < 1e-5) {
        c.moveCamera(CameraUpdate.newLatLngZoom(a, 17), animated: true);
      } else {
        c.moveCamera(CameraUpdate.newLatLngBounds(LatLngBounds(southwest: sw, northeast: ne), 120), animated: true);
      }
    } else if (partner && pp != null) {
      c.moveCamera(CameraUpdate.newLatLngZoom(_gcj(pp.lat, pp.lng), 16.5), animated: true);
    } else if (me && mp != null) {
      c.moveCamera(CameraUpdate.newLatLngZoom(_gcj(mp.lat, mp.lng), 16.5), animated: true);
    }
  }

  @override
  Widget build(BuildContext context) {
    final s = ref.watch(syncProvider);
    final v = context.vibes;
    final mp = s.myPoint, pp = s.partnerPoint;
    if (mp != null) _me.moveTo(_gcj(mp.lat, mp.lng));
    if (pp != null) _partner.moveTo(_gcj(pp.lat, pp.lng));
    _refreshIcons(s);

    final now = DateTime.now();
    final meLL = _me.current(now), paLL = _partner.current(now);
    final meColor = PersonalPalette.byId(s.me?.themeId);
    final paColor = PersonalPalette.byId(s.partner?.themeId);
    final dist = (mp != null && pp != null) ? haversineMeters(mp.lat, mp.lng, pp.lat, pp.lng) : null;

    final close = dist != null && dist < 100;
    if (close && !_closeHearts) {
      _closeHearts = true;
      final w = UniqueKey();
      _effects.add(Positioned(key: w, left: 0, right: 0, top: MediaQuery.sizeOf(context).height * 0.45, height: 200, child: Center(child: HeartBurst(onDone: () => setState(() => _effects.removeWhere((x) => x.key == w))))));
    } else if (!close && dist != null && dist > 150) {
      _closeHearts = false;
    }

    if (!_didInitialFit && mp != null && pp != null && _ctl != null) {
      _didInitialFit = true;
      Future.delayed(const Duration(milliseconds: 400), () => mounted ? _fit() : null);
    }

    final markers = <Marker>{
      if (meLL != null && _meIcon != null)
        Marker(position: meLL, icon: _meIcon!, anchor: const Offset(0.5, 0.86), zIndex: 2, infoWindowEnable: false),
      if (paLL != null && _partnerIcon != null)
        Marker(
          position: paLL,
          icon: _partnerIcon!,
          anchor: const Offset(0.5, 0.86),
          zIndex: 3,
          infoWindowEnable: false,
          onTap: (_) => showPartnerSheet(context),
        ),
      for (final p in s.pins)
        if (_pinIcons[p.emoji] != null)
          Marker(
            position: _gcj(p.lat, p.lng),
            icon: _pinIcons[p.emoji]!,
            anchor: const Offset(0.5, 0.95),
            infoWindowEnable: false,
            onTap: (_) => showPinEditor(context, ref, existing: p),
          ),
    };
    final lines = <Polyline>{
      if (meLL != null && paLL != null)
        Polyline(points: [meLL, paLL], width: 5, color: meColor.start.withValues(alpha: 0.8), dashLineType: DashLineType.square),
    };

    final paused = s.partnerPresence?.isPausedNow(now) ?? false;
    final media = MediaQuery.of(context);

    return Stack(children: [
      Positioned.fill(
        child: AMapWidget(
          initialCameraPosition: const CameraPosition(target: LatLng(39.909, 116.397), zoom: 14),
          markers: markers,
          polylines: lines,
          customStyleOptions: _style,
          myLocationStyleOptions: MyLocationStyleOptions(false),
          compassEnabled: false,
          scaleEnabled: false,
          labelsEnabled: true,
          touchPoiEnabled: false,
          buildingsEnabled: false,
          onMapCreated: (c) {
            _ctl = c;
            _fit(both: true, me: true);
          },
          onCameraMove: (_) => _refreshScreen(),
          onCameraMoveEnd: (_) => _refreshScreen(),
          onLongPress: (ll) {
            final w = CoordConverter.gcj02ToWgs84(ll.latitude, ll.longitude);
            showPinEditor(context, ref, at: w);
          },
        ),
      ),
      // 呼吸光晕
      if (_meScreen != null) Positioned(left: _meScreen!.dx - 40, top: _meScreen!.dy - 62, child: BreathingHalo(color: meColor.start, radius: 40)),
      if (_partnerScreen != null && !paused) Positioned(left: _partnerScreen!.dx - 40, top: _partnerScreen!.dy - 62, child: BreathingHalo(color: paColor.start, radius: 40)),
      // 距离气泡
      if (_meScreen != null && _partnerScreen != null && dist != null)
        Positioned(
          left: (_meScreen!.dx + _partnerScreen!.dx) / 2 - 44,
          top: (_meScreen!.dy + _partnerScreen!.dy) / 2 - 20 - 30,
          child: IgnorePointer(child: GlassPanel(radius: AppRadii.small, padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 6), blur: 10, child: _DistanceLabel(meters: dist))),
        ),
      ..._effects,
      // 顶部状态条
      Positioned(top: media.padding.top + 8, left: 16, right: 16, child: _TopBar(s: s, paused: paused)),
      // 右侧工具
      Positioned(
        right: 16,
        bottom: media.padding.bottom + 150,
        child: Column(mainAxisSize: MainAxisSize.min, children: [
          GlassIconButton(icon: PhosphorIconsFill.heart, tooltip: '聚焦 TA', color: paColor.start, onTap: () => _fit(both: false, partner: true)),
          const SizedBox(height: 12),
          GlassIconButton(icon: PhosphorIconsRegular.arrowsInSimple, tooltip: '两人都在视野', onTap: () => _fit()),
          const SizedBox(height: 12),
          GlassIconButton(icon: PhosphorIconsRegular.crosshair, tooltip: '回到我的位置', onTap: () => _fit(both: false, me: true)),
        ]),
      ),
      // 底部按钮
      Positioned(
        left: 16,
        right: 16,
        bottom: media.padding.bottom + 84,
        child: Row(children: [
          Expanded(child: PrimaryButton(label: '我到了', icon: PhosphorIconsFill.houseLine, onTap: () => _arrived(context))),
          const SizedBox(width: 14),
          SosButton(onTriggered: () => triggerSos(context, ref)),
        ]),
      ),
      if (s.keyProblem != null)
        Positioned(top: media.padding.top + 76, left: 24, right: 24, child: GlassPanel(radius: AppRadii.small, padding: const EdgeInsets.all(12), child: Text(s.keyProblem!, style: TextStyle(color: v.ink)))),
      if (!AppConfigHint.mapReady)
        Positioned.fill(child: _MapKeyMissing()),
    ]);
  }

  Future<void> _arrived(BuildContext context) async {
    final messenger = ScaffoldMessenger.of(context);
    HapticFeedback.mediumImpact();
    try {
      final p = ref.read(syncProvider).myPoint ?? (await TrackerService.instance.iosCore?.currentOnce().then((e) => e == null ? null : LocPoint(ts: DateTime.now(), lat: e.latitude, lng: e.longitude)));
      final name = p == null ? '' : await ref.read(syncProvider.notifier).placeName(p.lat, p.lng);
      await ref.read(syncProvider.notifier).sendEvent(EventKind.arrived, lat: p?.lat, lng: p?.lng, text: name.isEmpty ? '已安全到达' : '已安全到达（$name）');
      TrackerService.instance.flushNow();
      messenger.showSnackBar(const SnackBar(content: Text('已告诉 TA：你到啦 🏠')));
    } catch (e) {
      messenger.showSnackBar(SnackBar(content: Text('发送失败：$e')));
    }
  }
}

class AppConfigHint {
  static bool mapReady = true;
}

class _MapKeyMissing extends StatelessWidget {
  @override
  Widget build(BuildContext context) => const SizedBox.shrink();
}

class _DistanceLabel extends StatelessWidget {
  const _DistanceLabel({required this.meters});
  final double meters;
  @override
  Widget build(BuildContext context) {
    final km = meters >= 1000;
    return Row(mainAxisSize: MainAxisSize.min, children: [
      Icon(PhosphorIconsFill.heartStraight, size: 14, color: context.vibes.accentText),
      const SizedBox(width: 6),
      RollingNumber(value: km ? meters / 1000 : meters, decimals: km ? 2 : 0, suffix: km ? ' km' : ' m', style: TextStyle(fontWeight: FontWeight.w700, fontSize: 14, color: context.vibes.ink)),
    ]);
  }
}

class _TopBar extends ConsumerWidget {
  const _TopBar({required this.s, required this.paused});
  final SyncState s;
  final bool paused;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final v = context.vibes;
    final pal = PersonalPalette.byId(s.partner?.themeId);
    final name = (s.partner?.nickname.isNotEmpty ?? false) ? s.partner!.nickname : 'TA';
    final pt = s.partnerPoint;
    final hb = s.partnerPresence?.heartbeatAt.toLocal();
    final sub = paused
        ? '对方暂停了共享'
        : pt != null
            ? agoText(pt.ts)
            : hb != null
                ? '${shortAgo(hb)}在线，暂无位置'
                : '等待 TA 的位置…';
    final settings = ref.watch(settingsProvider);
    final myPaused = settings?.isPaused() ?? false;
    return GlassPanel(
      padding: const EdgeInsets.fromLTRB(10, 8, 10, 8),
      radius: AppRadii.card,
      child: Row(children: [
        Hero(tag: 'partner-avatar', child: AvatarBubble(palette: pal, emoji: s.partner?.avatarEmoji, imageUrl: s.partner?.avatarUrl, size: 44, dimmed: paused)),
        const SizedBox(width: 10),
        Expanded(
          child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
            Text(name, style: Theme.of(context).textTheme.titleMedium?.copyWith(fontWeight: FontWeight.w700)),
            Text(sub, style: TextStyle(color: paused ? v.accentText : v.inkSoft, fontSize: 12)),
          ]),
        ),
        if (s.partnerStatus != null) _BatteryChip(st: s.partnerStatus!),
        const SizedBox(width: 8),
        Squish(
          onTap: () => showShareControl(context, ref),
          child: AnimatedContainer(
            duration: Motion.of(context, Motion.normal),
            padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
            decoration: BoxDecoration(
              color: myPaused ? v.surfaceHigh : AppColors.accent.withValues(alpha: v.isDark ? 0.24 : 0.10),
              borderRadius: BorderRadius.circular(999),
            ),
            child: Row(mainAxisSize: MainAxisSize.min, children: [
              Icon(myPaused ? PhosphorIconsFill.pause : PhosphorIconsFill.broadcast, size: 16, color: myPaused ? v.ink : v.accentText),
              const SizedBox(width: 4),
              Text(myPaused ? '已暂停' : '共享中', style: TextStyle(fontWeight: FontWeight.w700, fontSize: 12, color: myPaused ? v.ink : v.accentText)),
            ]),
          ),
        ),
      ]),
    );
  }
}

class _BatteryChip extends StatelessWidget {
  const _BatteryChip({required this.st});
  final DeviceStatus st;
  @override
  Widget build(BuildContext context) {
    final low = st.lowBattery;
    final c = low ? context.vibes.danger : (st.charging ? AppColors.mint : context.vibes.inkSoft);
    return Row(mainAxisSize: MainAxisSize.min, children: [
      Icon(st.charging ? PhosphorIconsFill.batteryCharging : (low ? PhosphorIconsFill.batteryLow : PhosphorIconsFill.batteryHigh), size: 18, color: c),
      Text('${st.battery}%', style: TextStyle(fontSize: 12, color: c, fontWeight: FontWeight.w600)),
    ]);
  }
}
