import 'package:shared_preferences/shared_preferences.dart';

import '../../domain/location/sampling.dart';

/// 设置项存储（主 isolate 与后台 isolate 共用，故每次读取前 reload）。
class SettingsStore {
  SettingsStore(this._p);
  final SharedPreferences _p;

  static Future<SettingsStore> open() async => SettingsStore(await SharedPreferences.getInstance());

  Future<void> reload() => _p.reload();

  static const kMode = 'report_mode';
  static const kLostMin = 'lost_minutes';
  static const kRetention = 'retention_days';
  static const kTheme = 'theme_mode'; // system/light/dark
  static const kPauseUntil = 'pause_until'; // 0=未暂停, -1=直到我打开, 其他=毫秒时间戳
  static const kSos = 'sos_active';
  static const kTracking = 'tracking_enabled';
  static const kOnboarded = 'onboarded';
  static const kLastNotifiedLost = 'last_lost_notified';
  static const kLastEventTs = 'last_event_ts';

  ReportMode get mode =>
      ReportMode.values.firstWhere((m) => m.name == _p.getString(kMode), orElse: () => ReportMode.balanced);
  Future<void> setMode(ReportMode m) => _p.setString(kMode, m.name);

  int get lostMinutes => _p.getInt(kLostMin) ?? 30;
  Future<void> setLostMinutes(int v) => _p.setInt(kLostMin, v);

  int get retentionDays => _p.getInt(kRetention) ?? 30;
  Future<void> setRetentionDays(int v) => _p.setInt(kRetention, v);

  String get themeMode => _p.getString(kTheme) ?? 'system';
  Future<void> setThemeMode(String v) => _p.setString(kTheme, v);

  int get pauseUntil => _p.getInt(kPauseUntil) ?? 0;
  Future<void> setPauseUntil(int v) => _p.setInt(kPauseUntil, v);

  /// 当前是否处于暂停共享。
  bool isPaused([DateTime? now]) {
    final u = pauseUntil;
    if (u == 0) return false;
    if (u == -1) return true;
    return (now ?? DateTime.now()).millisecondsSinceEpoch < u;
  }

  bool get sosActive => _p.getBool(kSos) ?? false;
  Future<void> setSos(bool v) => _p.setBool(kSos, v);

  bool get trackingEnabled => _p.getBool(kTracking) ?? false;
  Future<void> setTracking(bool v) => _p.setBool(kTracking, v);

  bool get onboarded => _p.getBool(kOnboarded) ?? false;
  Future<void> setOnboarded(bool v) => _p.setBool(kOnboarded, v);

  int get lastLostNotified => _p.getInt(kLastNotifiedLost) ?? 0;
  Future<void> setLastLostNotified(int v) => _p.setInt(kLastNotifiedLost, v);

  int get lastEventTs => _p.getInt(kLastEventTs) ?? 0;
  Future<void> setLastEventTs(int v) => _p.setInt(kLastEventTs, v);
}
