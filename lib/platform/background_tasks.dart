import 'dart:io';

import 'package:flutter/widgets.dart';
import 'package:workmanager/workmanager.dart';

import '../data/local/database.dart';
import '../data/repo/key_store.dart';
import '../data/repo/settings_store.dart';
import 'bootstrap.dart';
import 'lost_checker.dart';
import 'notifications.dart';
import 'tracker_service.dart';

const _taskPeriodic = 'couple.periodic';

/// WorkManager 入口（顶层函数）。Android：约每 15 分钟一次，负责
/// ① 若前台服务被杀则拉起；② 失联检查。iOS：BGTaskScheduler（系统决定时机，不保证）。
@pragma('vm:entry-point')
void workmanagerDispatcher() {
  Workmanager().executeTask((task, input) async {
    WidgetsFlutterBinding.ensureInitialized();
    try {
      await ensureSupabase();
      final settings = await SettingsStore.open();
      final core = await buildTrackerCore();
      if (core == null) return true;
      await LocalNotifier.instance.init();
      if (settings.trackingEnabled && Platform.isAndroid) {
        if (!await TrackerService.instance.running) {
          await TrackerService.instance.start();
        }
      }
      await LostChecker(backend: core.backend, settings: settings, db: AppDb(), keys: KeyStore()).check();
      if (Platform.isIOS && settings.trackingEnabled) {
        // iOS 后台唤醒：补传本地积压并补拉事件
        await core.start();
        await core.flush();
        await core.stop();
      }
    } catch (_) {}
    return true;
  });
}

class BackgroundTasks {
  static Future<void> register() async {
    await Workmanager().initialize(workmanagerDispatcher);
    await Workmanager().registerPeriodicTask(
      _taskPeriodic,
      _taskPeriodic,
      frequency: const Duration(minutes: 15),
      existingWorkPolicy: ExistingPeriodicWorkPolicy.update,
      constraints: Constraints(networkType: NetworkType.connected),
    );
  }

  static Future<void> cancel() => Workmanager().cancelAll();
}
