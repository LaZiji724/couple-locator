import 'dart:async';

import 'package:amap_map/amap_map.dart';
import 'package:flutter/material.dart';
import 'package:flutter/scheduler.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import 'package:phosphor_flutter/phosphor_flutter.dart';
import 'package:table_calendar/table_calendar.dart';
import 'package:x_amap_base/x_amap_base.dart';

import '../../app/providers.dart';
import '../../core/format.dart';
import '../../core/geo/coord.dart';
import '../../core/theme/app_theme.dart';
import '../../core/theme/tokens.dart';
import '../../core/widgets/vibe_widgets.dart';
import '../../domain/location/track_tools.dart';
import '../../domain/models/loc_point.dart';
import '../../platform/geocode.dart';
import '../map/avatar_marker.dart';

LatLng _g(LocPoint p) {
  final g = CoordConverter.wgs84ToGcj02(p.lat, p.lng);
  return LatLng(g.lat, g.lng);
}

class HistoryPage extends ConsumerStatefulWidget {
  const HistoryPage({super.key});
  @override
  ConsumerState<HistoryPage> createState() => _HistoryPageState();
}

class _HistoryPageState extends ConsumerState<HistoryPage> with SingleTickerProviderStateMixin {
  DateTime _day = DateTime.now();
  bool _mine = true;
  bool _monthView = false;
  bool _loading = false;
  List<LocPoint> _raw = const [];
  List<LocPoint> _clean = const [];
  List<LocPoint> _draw = const [];
  List<StayPoint> _stays = const [];
  final _stayNames = <int, String>{};
  AMapController? _ctl;
  late final Ticker _ticker;
  double _progress = 0; // 0..1
  bool _playing = false;
  int _speed = 1;
  Duration _last = Duration.zero;
  BitmapDescriptor? _icon;
  final _stayIcon = <int, BitmapDescriptor>{};

  @override
  void initState() {
    super.initState();
    _ticker = createTicker(_onTick);
    WidgetsBinding.instance.addPostFrameCallback((_) => _load());
  }

  @override
  void dispose() {
    _ticker.dispose();
    super.dispose();
  }

  void _onTick(Duration d) {
    final dt = (d - _last).inMicroseconds / 1e6;
    _last = d;
    if (!_playing || _clean.length < 2) return;
    // 基础速度：整天轨迹 60 秒播完（1x）
    setState(() {
      _progress += dt * _speed / 60.0;
      if (_progress >= 1) {
        _progress = 1;
        _playing = false;
        _ticker.stop();
      }
    });
  }

  void _togglePlay() {
    if (_clean.length < 2) return;
    setState(() {
      _playing = !_playing;
      if (_playing) {
        if (_progress >= 1) _progress = 0;
        _last = Duration.zero;
        _ticker.stop();
        _ticker.start();
      } else {
        _ticker.stop();
      }
    });
  }

  Future<void> _load() async {
    final s = ref.read(syncProvider);
    final uid = _mine ? ref.read(backendProvider).userId : s.partner?.id;
    if (uid == null) return;
    setState(() => _loading = true);
    _ticker.stop();
    _playing = false;
    _progress = 0;
    final raw = await ref.read(syncProvider.notifier).loadDay(uid, _day);
    final clean = filterNoisy(raw);
    // 抽稀（Douglas-Peucker，容差 8 米）仅用于绘制；回放使用清洗后的完整点
    final draw = douglasPeucker(clean, 8);
    final stays = detectStayPoints(clean);
    if (!mounted) return;
    final pal = PersonalPalette.byId(_mine ? s.me?.themeId : s.partner?.themeId);
    _icon = await AvatarMarkerPainter.build(palette: pal, emoji: _mine ? s.me?.avatarEmoji : s.partner?.avatarEmoji, photoDataUri: _mine ? s.me?.avatarUrl : s.partner?.avatarUrl, scale: MediaQuery.devicePixelRatioOf(context));
    setState(() {
      _raw = raw;
      _clean = clean;
      _draw = draw;
      _stays = stays;
      _loading = false;
    });
    _fitTrack();
    for (final (i, st) in stays.indexed) {
      Geocoder.instance.name(st.lat, st.lng).then((n) {
        if (mounted) setState(() => _stayNames[i] = n);
      });
    }
  }

  void _fitTrack() {
    final c = _ctl;
    if (c == null || _draw.isEmpty) return;
    final ps = _draw.map(_g).toList();
    final lat = ps.map((e) => e.latitude), lng = ps.map((e) => e.longitude);
    final sw = LatLng(lat.reduce((a, b) => a < b ? a : b), lng.reduce((a, b) => a < b ? a : b));
    final ne = LatLng(lat.reduce((a, b) => a > b ? a : b), lng.reduce((a, b) => a > b ? a : b));
    if ((ne.latitude - sw.latitude).abs() < 1e-5) {
      c.moveCamera(CameraUpdate.newLatLngZoom(sw, 16), animated: true);
    } else {
      c.moveCamera(CameraUpdate.newLatLngBounds(LatLngBounds(southwest: sw, northeast: ne), 80), animated: true);
    }
  }

  /// 回放位置：按整体时间进度插值。
  (LocPoint?, DateTime?) _replayPos() {
    if (_clean.length < 2) return (_clean.firstOrNull, _clean.firstOrNull?.ts);
    final t0 = _clean.first.ts.millisecondsSinceEpoch, t1 = _clean.last.ts.millisecondsSinceEpoch;
    final t = t0 + ((t1 - t0) * _progress).round();
    var i = _clean.indexWhere((p) => p.ts.millisecondsSinceEpoch >= t);
    if (i <= 0) return (_clean.first, DateTime.fromMillisecondsSinceEpoch(t));
    final a = _clean[i - 1], b = _clean[i];
    final span = b.ts.millisecondsSinceEpoch - a.ts.millisecondsSinceEpoch;
    final f = span == 0 ? 0.0 : (t - a.ts.millisecondsSinceEpoch) / span;
    return (LocPoint(ts: DateTime.fromMillisecondsSinceEpoch(t), lat: a.lat + (b.lat - a.lat) * f, lng: a.lng + (b.lng - a.lng) * f), DateTime.fromMillisecondsSinceEpoch(t));
  }

  Set<Polyline> _lines(PersonalPalette pal) {
    if (_draw.length < 2) return {};
    // 分段渐变：每段按时间进度取色
    final out = <Polyline>{};
    const seg = 24;
    final n = _draw.length - 1;
    final step = (n / seg).ceil().clamp(1, n);
    for (var i = 0; i < n; i += step) {
      final end = (i + step).clamp(0, n);
      out.add(Polyline(
        points: [for (var k = i; k <= end; k++) _g(_draw[k])],
        width: 9,
        color: pal.at(i / n),
        joinType: JoinType.round,
        capType: CapType.round,
      ));
    }
    return out;
  }

  Future<void> _stayIconFor(int i) async {
    if (_stayIcon.containsKey(i)) return;
    _stayIcon[i] = await AvatarMarkerPainter.pin('🕒', scale: MediaQuery.devicePixelRatioOf(context));
    if (mounted) setState(() {});
  }

  @override
  Widget build(BuildContext context) {
    final s = ref.watch(syncProvider);
    final v = context.vibes;
    final pal = PersonalPalette.byId(_mine ? s.me?.themeId : s.partner?.themeId);
    final (rp, rt) = _replayPos();
    for (var i = 0; i < _stays.length; i++) {
      _stayIconFor(i);
    }
    final markers = <Marker>{
      if (_icon != null && rp != null) Marker(position: _g(rp), icon: _icon!, anchor: const Offset(0.5, 0.86), infoWindowEnable: false, zIndex: 5),
      for (final (i, st) in _stays.indexed)
        if (_stayIcon[i] != null)
          Marker(
            position: _g(LocPoint(ts: st.start, lat: st.lat, lng: st.lng)),
            icon: _stayIcon[i]!,
            anchor: const Offset(0.5, 0.95),
            infoWindow: InfoWindow(title: _stayNames[i] ?? '停留点', snippet: '${hm(st.start)}–${hm(st.end)}，${durationText(st.duration)}'),
          ),
    };
    final media = MediaQuery.of(context);
    final km = totalDistance(_clean) / 1000;
    return Stack(children: [
      Positioned.fill(
        child: AMapWidget(
          initialCameraPosition: const CameraPosition(target: LatLng(39.909, 116.397), zoom: 13),
          markers: markers,
          polylines: _lines(pal),
          compassEnabled: false,
          scaleEnabled: false,
          buildingsEnabled: false,
          touchPoiEnabled: false,
          onMapCreated: (c) {
            _ctl = c;
            _fitTrack();
          },
        ),
      ),
      Positioned(
        top: media.padding.top + 8,
        left: 16,
        right: 16,
        child: GlassPanel(
          radius: AppRadii.card,
          padding: const EdgeInsets.all(10),
          child: Column(children: [
            Row(children: [
              SegmentedButton<bool>(
                segments: const [ButtonSegment(value: true, label: Text('我')), ButtonSegment(value: false, label: Text('TA'))],
                selected: {_mine},
                showSelectedIcon: false,
                style: const ButtonStyle(visualDensity: VisualDensity.compact),
                onSelectionChanged: (x) {
                  setState(() => _mine = x.first);
                  _load();
                },
              ),
              const Spacer(),
              IconButton(tooltip: '统计', onPressed: () => context.push('/stats'), icon: const Icon(PhosphorIconsRegular.chartBar)),
              IconButton(
                tooltip: _monthView ? '收起日历' : '展开日历',
                onPressed: () => setState(() => _monthView = !_monthView),
                icon: Icon(_monthView ? PhosphorIconsRegular.caretUp : PhosphorIconsRegular.calendarBlank),
              ),
            ]),
            TableCalendar(
              firstDay: DateTime.now().subtract(const Duration(days: 365)),
              lastDay: DateTime.now(),
              focusedDay: _day,
              locale: 'zh_CN',
              calendarFormat: _monthView ? CalendarFormat.month : CalendarFormat.week,
              availableCalendarFormats: const {CalendarFormat.month: '', CalendarFormat.week: ''},
              headerVisible: _monthView,
              headerStyle: const HeaderStyle(formatButtonVisible: false, titleCentered: true),
              rowHeight: 42,
              daysOfWeekHeight: 22,
              selectedDayPredicate: (d) => isSameDay(d, _day),
              onDaySelected: (d, _) {
                setState(() => _day = d);
                _load();
              },
              calendarStyle: CalendarStyle(
                selectedDecoration: const BoxDecoration(color: AppColors.accent, shape: BoxShape.circle),
                selectedTextStyle: const TextStyle(color: AppColors.onAccent, fontWeight: FontWeight.w600),
                todayDecoration: BoxDecoration(color: pal.start.withValues(alpha: 0.25), shape: BoxShape.circle),
                todayTextStyle: TextStyle(color: v.ink, fontWeight: FontWeight.w700),
                defaultTextStyle: TextStyle(color: v.ink),
                weekendTextStyle: TextStyle(color: v.ink),
                outsideTextStyle: TextStyle(color: v.inkSoft),
              ),
            ),
          ]),
        ),
      ),
      DraggableScrollableSheet(
        initialChildSize: 0.30,
        minChildSize: 0.16,
        maxChildSize: 0.75,
        builder: (context, scroll) => GlassPanel(
          radius: AppRadii.card,
          padding: EdgeInsets.zero,
          child: ListView(controller: scroll, padding: EdgeInsets.fromLTRB(18, 10, 18, 100 + media.padding.bottom), children: [
            Center(child: Container(width: 40, height: 5, decoration: BoxDecoration(color: v.inkSoft.withValues(alpha: 0.4), borderRadius: BorderRadius.circular(4)))),
            const SizedBox(height: 12),
            if (_loading)
              const Padding(padding: EdgeInsets.all(24), child: Center(child: CircularProgressIndicator()))
            else if (_clean.length < 2)
              const CuteEmpty(title: '这一天没有轨迹', subtitle: '换一天看看，或者等 TA 出门走一走', icon: PhosphorIconsRegular.calendarBlank)
            else ...[
              Row(children: [
                IconButton.filled(
                  onPressed: _togglePlay,
                  style: IconButton.styleFrom(backgroundColor: pal.start, foregroundColor: AppColors.onAccent),
                  icon: Icon(_playing ? PhosphorIconsFill.pause : PhosphorIconsFill.play),
                ),
                const SizedBox(width: 8),
                Expanded(
                  child: Slider(
                    value: _progress.clamp(0, 1),
                    onChanged: (x) => setState(() => _progress = x),
                  ),
                ),
                SizedBox(width: 48, child: Text(rt == null ? '' : hm(rt), style: TextStyle(fontWeight: FontWeight.w700, color: v.ink))),
              ]),
              Row(children: [
                for (final sp in const [1, 4, 16])
                  Padding(
                    padding: const EdgeInsets.only(right: 8),
                    child: ChoiceChip(
                      label: Text('${sp}x'),
                      selected: _speed == sp,
                      onSelected: (_) => setState(() => _speed = sp),
                      shape: const StadiumBorder(),
                    ),
                  ),
                const Spacer(),
                Text('${km.toStringAsFixed(1)} km，${_raw.length} 个点', style: TextStyle(color: v.inkSoft, fontSize: 12)),
              ]),
              const SectionTitle('停留点'),
              if (_stays.isEmpty)
                Text('这一天没有超过 10 分钟的停留', style: TextStyle(color: v.inkSoft))
              else
                for (final (i, st) in _stays.indexed)
                  StaggerIn(
                    index: i,
                    child: _StayTile(
                      name: _stayNames[i] ?? '正在识别地点…',
                      st: st,
                      color: pal.at(i / (_stays.length.clamp(1, 99))),
                      isLast: i == _stays.length - 1,
                      onTap: () => _ctl?.moveCamera(CameraUpdate.newLatLngZoom(_g(LocPoint(ts: st.start, lat: st.lat, lng: st.lng)), 17), animated: true),
                    ),
                  ),
            ],
          ]),
        ),
      ),
    ]);
  }
}

class _StayTile extends StatelessWidget {
  const _StayTile({required this.name, required this.st, required this.color, required this.isLast, required this.onTap});
  final String name;
  final StayPoint st;
  final Color color;
  final bool isLast;
  final VoidCallback onTap;
  @override
  Widget build(BuildContext context) {
    final v = context.vibes;
    return Squish(
      onTap: onTap,
      scale: 0.98,
      child: IntrinsicHeight(
        child: Row(crossAxisAlignment: CrossAxisAlignment.stretch, children: [
          SizedBox(
            width: 28,
            child: Column(children: [
              Container(width: 14, height: 14, margin: const EdgeInsets.only(top: 6), decoration: BoxDecoration(color: color, shape: BoxShape.circle, border: Border.all(color: v.surface, width: 2))),
              if (!isLast) Expanded(child: Container(width: 3, margin: const EdgeInsets.symmetric(vertical: 2), decoration: BoxDecoration(gradient: LinearGradient(begin: Alignment.topCenter, end: Alignment.bottomCenter, colors: [color, color.withValues(alpha: 0.2)]), borderRadius: BorderRadius.circular(3)))),
            ]),
          ),
          Expanded(
            child: Padding(
              padding: const EdgeInsets.only(bottom: 14),
              child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
                Text(name, style: const TextStyle(fontWeight: FontWeight.w700, fontSize: 14)),
                const SizedBox(height: 4),
                Row(children: [
                  Text('${hm(st.start)} – ${hm(st.end)}', style: TextStyle(color: v.inkSoft, fontSize: 12)),
                  const SizedBox(width: 8),
                  Container(padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 3), decoration: BoxDecoration(color: color.withValues(alpha: 0.2), borderRadius: BorderRadius.circular(99)), child: Text('待了 ${durationText(st.duration)}', style: TextStyle(fontSize: 12, fontWeight: FontWeight.w700, color: v.ink))),
                ]),
              ]),
            ),
          ),
        ]),
      ),
    );
  }
}
