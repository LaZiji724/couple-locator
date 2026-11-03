import '../core/format.dart';
import '../core/log.dart';
import '../data/local/database.dart';
import '../data/remote/backend.dart';
import '../data/repo/channel_factory.dart';
import '../data/repo/key_store.dart';
import '../data/repo/settings_store.dart';
import '../domain/models/loc_point.dart';
import 'geocode.dart';
import 'notifications.dart';

/// B3 失联提醒：依据服务端明文心跳时间戳判断（不含位置）。
/// 前台由 App 每分钟调用；后台由 WorkManager 周期任务（约 15 分钟）调用。
class LostChecker {
  LostChecker({required this.backend, required this.settings, this.db, this.keys});
  final Backend backend;
  final SettingsStore settings;
  final AppDb? db;
  final KeyStore? keys;

  /// 返回是否已发出通知。同一段失联只通知一次（以对方最后心跳时间为键）。
  Future<bool> check({DateTime? now}) async {
    now ??= DateTime.now();
    try {
      await settings.reload();
      final me = backend.userId;
      if (me == null) return false;
      final couple = await backend.getMyCouple();
      if (couple == null) return false;
      final partner = couple.partnerOf(me);
      final p = await backend.getPresence(partner);
      if (p == null) return false;
      final silent = now.difference(p.heartbeatAt);
      if (p.isPausedNow(now)) return false; // 暂停共享不算失联
      if (silent.inMinutes < settings.lostMinutes) return false;
      final key = p.heartbeatAt.millisecondsSinceEpoch;
      if (settings.lastLostNotified == key) return false;

      var where = '';
      if (db != null && keys != null) {
        try {
          final ch = await openChannel(backend, keys!, couple: couple);
          if (ch != null) {
            final locs = await backend.fetchLocations(couple.id, partner, now.subtract(const Duration(hours: 24)), now.add(const Duration(minutes: 5)));
            if (locs.isNotEmpty) {
              final last = locs.last;
              final j = await ch.openLocation(last.blob, last.userId, last.clientTs);
              final pt = LocPoint.fromJson(j);
              where = await Geocoder.instance.name(pt.lat, pt.lng);
            }
          }
        } catch (_) {}
      }
      final name = (await backend.getProfile(partner))?.nickname ?? '对方';
      await LocalNotifier.instance.show(
        NotifIds.lost,
        '$name 失联了',
        '对方已失联 ${silent.inMinutes} 分钟${where.isEmpty ? '' : '，最后位置在 $where'}（${hm(p.heartbeatAt.toLocal())}）',
        payload: 'lost',
      );
      await settings.setLastLostNotified(key);
      return true;
    } catch (e) {
      AppLog.w('lost', '检查失败：$e');
      return false;
    }
  }
}
