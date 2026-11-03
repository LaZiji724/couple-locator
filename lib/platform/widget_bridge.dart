import 'dart:io';

import 'package:home_widget/home_widget.dart';
import 'package:live_activities/live_activities.dart';

import '../app/providers.dart';
import '../core/format.dart';
import '../core/geo/coord.dart';

/// F1 桌面小组件 / 锁屏实时活动数据桥。
/// 任何一步失败（例如侧载签名后没有 Widget Extension）都只会被忽略，不影响主 App。
class WidgetBridge {
  WidgetBridge._();
  static final instance = WidgetBridge._();

  static const appGroup = 'group.com.couple.coupleLocator';
  static const androidSmall = 'SmallWidgetProvider';
  static const androidMedium = 'MediumWidgetProvider';
  static const iosWidget = 'CoupleWidget';

  DateTime _last = DateTime.fromMillisecondsSinceEpoch(0);
  bool _ready = false;
  final _live = LiveActivities();
  String? _activityId;
  bool _liveReady = false;

  Future<void> _init() async {
    if (_ready) return;
    try {
      if (Platform.isIOS) await HomeWidget.setAppGroupId(appGroup);
    } catch (_) {}
    _ready = true;
  }

  Future<void> update(SyncState s) async {
    final now = DateTime.now();
    if (now.difference(_last) < const Duration(seconds: 45)) return;
    _last = now;
    await _init();
    final mp = s.myPoint, pp = s.partnerPoint;
    final dist = (mp != null && pp != null) ? haversineMeters(mp.lat, mp.lng, pp.lat, pp.lng) : null;
    final data = {
      'emoji': s.partner?.avatarEmoji ?? '💗',
      'name': s.partner?.nickname ?? 'TA',
      'distance': dist == null ? '--' : distanceText(dist),
      'battery': s.partnerStatus == null ? '电量 --' : '电量 ${s.partnerStatus!.battery}%${s.partnerStatus!.charging ? ' ⚡' : ''}',
      'updated': pp == null ? '等待更新' : agoText(pp.ts),
    };
    try {
      for (final e in data.entries) {
        await HomeWidget.saveWidgetData<String>(e.key, e.value);
      }
      if (Platform.isAndroid) {
        await HomeWidget.updateWidget(qualifiedAndroidName: 'com.couple.couple_locator.$androidSmall');
        await HomeWidget.updateWidget(qualifiedAndroidName: 'com.couple.couple_locator.$androidMedium');
      } else if (Platform.isIOS) {
        await HomeWidget.updateWidget(iOSName: iosWidget);
      }
    } catch (_) {}
    if (Platform.isIOS) await _updateLiveActivity(data);
  }

  Future<void> _updateLiveActivity(Map<String, String> data) async {
    try {
      if (!_liveReady) {
        await _live.init(appGroupId: appGroup);
        _liveReady = true;
      }
      if (_activityId == null) {
        _activityId = await _live.createActivity('partner-live', data, removeWhenAppIsKilled: false, iOSEnableRemoteUpdates: false);
      } else {
        await _live.updateActivity(_activityId!, data);
      }
    } catch (_) {
      // 没有 Widget Extension / 系统不支持实时活动 → 静默降级
    }
  }
}
