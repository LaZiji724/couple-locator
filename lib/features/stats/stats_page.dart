import 'package:fl_chart/fl_chart.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:phosphor_flutter/phosphor_flutter.dart';

import '../../app/providers.dart';
import '../../core/format.dart';
import '../../core/theme/app_theme.dart';
import '../../core/theme/tokens.dart';
import '../../core/widgets/vibe_widgets.dart';
import '../../domain/stats/stats_calc.dart';
import '../../platform/geocode.dart';

class StatsPage extends ConsumerStatefulWidget {
  const StatsPage({super.key});
  @override
  ConsumerState<StatsPage> createState() => _StatsPageState();
}

class _StatsPageState extends ConsumerState<StatsPage> {
  bool _week = true;
  bool _loading = true;
  StatsResult? _r;
  String? _stayName;

  @override
  void initState() {
    super.initState();
    _load();
  }

  Future<void> _load() async {
    setState(() => _loading = true);
    final days = _week ? 7 : 30;
    final s = ref.read(syncProvider);
    final n = ref.read(syncProvider.notifier);
    final now = DateTime.now();
    final from = DateTime(now.year, now.month, now.day).subtract(Duration(days: days - 1));
    final me = ref.read(backendProvider).userId!;
    final mine = await n.loadRange(me, from, now.add(const Duration(minutes: 1)));
    final partner = s.partner == null ? <dynamic>[] : await n.loadRange(s.partner!.id, from, now.add(const Duration(minutes: 1)));
    final r = computeStats(mine: mine, partner: partner.cast(), today: now, days: days);
    String? name;
    final longest = r.longestStayMine ?? r.longestStayPartner;
    if (longest != null) name = await Geocoder.instance.name(longest.lat, longest.lng);
    if (!mounted) return;
    setState(() {
      _r = r;
      _stayName = name;
      _loading = false;
    });
  }

  @override
  Widget build(BuildContext context) {
    final v = context.vibes;
    final s = ref.watch(syncProvider);
    final mp = PersonalPalette.byId(s.me?.themeId), pp = PersonalPalette.byId(s.partner?.themeId);
    final r = _r;
    return Scaffold(
      appBar: AppBar(title: const Text('轨迹统计')),
      body: PaperBackdrop(
        child: SafeArea(
          child: ListView(padding: const EdgeInsets.all(20), children: [
            Center(
              child: SegmentedButton<bool>(
                segments: const [ButtonSegment(value: true, label: Text('本周')), ButtonSegment(value: false, label: Text('本月'))],
                selected: {_week},
                showSelectedIcon: false,
                onSelectionChanged: (x) {
                  _week = x.first;
                  _load();
                },
              ),
            ),
            const SizedBox(height: 16),
            if (_loading || r == null)
              const Padding(padding: EdgeInsets.all(48), child: Center(child: CircularProgressIndicator()))
            else ...[
              Row(children: [
                Expanded(child: _BigCard(gradient: mp.gradient, icon: PhosphorIconsFill.personSimpleWalk, title: '我走了', value: r.totalMine / 1000, suffix: ' km')),
                const SizedBox(width: 12),
                Expanded(child: _BigCard(gradient: pp.gradient, icon: PhosphorIconsFill.personSimpleWalk, title: 'TA 走了', value: r.totalPartner / 1000, suffix: ' km')),
              ]),
              const SizedBox(height: 12),
              Row(children: [
                Expanded(
                  child: VibeCard(
                    child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
                      Row(children: [Icon(PhosphorIconsFill.heart, color: v.accentText, size: 20), const SizedBox(width: 6), Text('在一起', style: TextStyle(color: v.inkSoft, fontWeight: FontWeight.w700))]),
                      const SizedBox(height: 8),
                      RollingNumber(value: r.together.inMinutes / 60, decimals: 1, suffix: ' 小时', style: TextStyle(fontWeight: FontWeight.w700, fontSize: 28, color: v.ink)),
                      Text('两人距离小于 100 米', style: TextStyle(color: v.inkSoft, fontSize: 12)),
                    ]),
                  ),
                ),
                const SizedBox(width: 12),
                Expanded(
                  child: VibeCard(
                    child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
                      Row(children: [Icon(PhosphorIconsFill.mapPin, color: v.accentText, size: 20), const SizedBox(width: 6), Text('停留最久', style: TextStyle(color: v.inkSoft, fontWeight: FontWeight.w700))]),
                      const SizedBox(height: 8),
                      Text(_stayName ?? '暂无', maxLines: 2, overflow: TextOverflow.ellipsis, style: TextStyle(fontWeight: FontWeight.w700, fontSize: 20, color: v.ink)),
                      if ((r.longestStayMine ?? r.longestStayPartner) != null) Text(durationText((r.longestStayMine ?? r.longestStayPartner)!.duration), style: TextStyle(color: v.inkSoft, fontSize: 12)),
                    ]),
                  ),
                ),
              ]),
              const SectionTitle('每日行走距离（km）'),
              VibeCard(
                padding: const EdgeInsets.fromLTRB(8, 20, 16, 8),
                child: SizedBox(
                  height: 220,
                  child: BarChart(
                    BarChartData(
                      alignment: BarChartAlignment.spaceAround,
                      gridData: FlGridData(drawVerticalLine: false, getDrawingHorizontalLine: (_) => FlLine(color: v.inkSoft.withValues(alpha: 0.15), strokeWidth: 0.5)),
                      borderData: FlBorderData(show: false),
                      titlesData: FlTitlesData(
                        topTitles: const AxisTitles(),
                        rightTitles: const AxisTitles(),
                        leftTitles: AxisTitles(sideTitles: SideTitles(showTitles: true, reservedSize: 34, getTitlesWidget: (x, _) => Text(x.toStringAsFixed(x < 10 ? 1 : 0), style: TextStyle(fontSize: 12, color: v.inkSoft)))),
                        bottomTitles: AxisTitles(
                          sideTitles: SideTitles(
                            showTitles: true,
                            interval: _week ? 1 : 5,
                            getTitlesWidget: (x, _) {
                              final i = x.toInt();
                              if (i < 0 || i >= r.perDayMine.length) return const SizedBox.shrink();
                              final d = r.perDayMine[i].day;
                              return Padding(padding: const EdgeInsets.only(top: 6), child: Text('${d.month}/${d.day}', style: TextStyle(fontSize: 12, color: v.inkSoft)));
                            },
                          ),
                        ),
                      ),
                      barGroups: [
                        for (var i = 0; i < r.perDayMine.length; i++)
                          BarChartGroupData(x: i, barsSpace: 2, barRods: [
                            BarChartRodData(toY: r.perDayMine[i].meters / 1000, width: _week ? 12 : 4, gradient: mp.gradient, borderRadius: BorderRadius.circular(6)),
                            BarChartRodData(toY: r.perDayPartner[i].meters / 1000, width: _week ? 12 : 4, gradient: pp.gradient, borderRadius: BorderRadius.circular(6)),
                          ]),
                      ],
                    ),
                    duration: const Duration(milliseconds: 400),
                    curve: Curves.easeOutCubic,
                  ),
                ),
              ),
              const SizedBox(height: 10),
              Row(mainAxisAlignment: MainAxisAlignment.center, children: [
                _Legend(color: mp.start, label: '我'),
                const SizedBox(width: 16),
                _Legend(color: pp.start, label: 'TA'),
              ]),
            ],
          ]),
        ),
      ),
    );
  }
}

class _Legend extends StatelessWidget {
  const _Legend({required this.color, required this.label});
  final Color color;
  final String label;
  @override
  Widget build(BuildContext context) => Row(children: [Container(width: 12, height: 12, decoration: BoxDecoration(color: color, shape: BoxShape.circle)), const SizedBox(width: 6), Text(label)]);
}

class _BigCard extends StatelessWidget {
  const _BigCard({required this.gradient, required this.icon, required this.title, required this.value, required this.suffix});
  final Gradient gradient;
  final IconData icon;
  final String title;
  final double value;
  final String suffix;
  @override
  Widget build(BuildContext context) {
    final v = context.vibes;
    return VibeCard(
      child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
        Row(children: [Icon(icon, color: gradient.colors.first, size: 20), const SizedBox(width: 8), Text(title, style: TextStyle(color: v.inkSoft, fontWeight: FontWeight.w600))]),
        const SizedBox(height: 8),
        RollingNumber(value: value, decimals: 1, suffix: suffix, style: TextStyle(fontWeight: FontWeight.w700, fontSize: 28, color: v.ink)),
      ]),
    );
  }
}
