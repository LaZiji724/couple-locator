import 'dart:async';
import 'dart:io';

import 'package:flutter/widgets.dart';
import 'package:flutter_activity_recognition/flutter_activity_recognition.dart';
import 'package:flutter_foreground_task/flutter_foreground_task.dart';

import '../core/log.dart';
import '../data/repo/settings_store.dart';
import 'bootstrap.dart';
import 'tracker_core.dart';

/// 前台服务入口（Android）。必须是顶层函数。
@pragma('vm:entry-point')
void trackerServiceMain() {
  FlutterForegroundTask.setTaskHandler(_TrackerHandler());
}

class _TrackerHandler extends TaskHandler {
  TrackerCore? _core;
  StreamSubscription? _act;
  bool _busy = false;

  @override
  Future<void> onStart(DateTime timestamp, TaskStarter starter) async {
    WidgetsFlutterBinding.ensureInitialized();
    try {
      _core = await buildTrackerCore();
      await _core?.start();
    } catch (e, st) {
      AppLog.e('service', 'onStart 失败：$e\n$st');
    }
    try {
      // 没有「身体活动」权限时订阅会在原生侧抛 SecurityException，所以先检查
      if (await FlutterActivityRecognition.instance.checkPermission() != ActivityPermission.GRANTED) return;
      _act = FlutterActivityRecognition.instance.activityStream.listen((a) {
        _core?.setActivity(a.type.name.toUpperCase().replaceAll('IN_VEHICLE', 'IN_VEHICLE'));
      });
    } catch (_) {}
  }

  @override
  void onRepeatEvent(DateTime timestamp) {
    if (_busy) return;
    _busy = true;
    _core?.tick().whenComplete(() => _busy = false);
  }

  @override
  Future<void> onDestroy(DateTime timestamp, bool isTimeout) async {
    await _act?.cancel();
    await _core?.stop();
  }

  @override
  void onReceiveData(Object data) {
    if (data == 'flush') _core?.flush();
  }

  @override
  void onNotificationButtonPressed(String id) async {
    if (id == 'pause') {
      final s = await SettingsStore.open();
      await s.setPauseUntil(DateTime.now().add(const Duration(hours: 1)).millisecondsSinceEpoch);
      FlutterForegroundTask.updateService(notificationText: '已暂停共享 1 小时');
      FlutterForegroundTask.sendDataToMain('paused');
    } else if (id == 'resume') {
      final s = await SettingsStore.open();
      await s.setPauseUntil(0);
      FlutterForegroundTask.updateService(notificationText: '正在和 TA 共享位置');
      FlutterForegroundTask.sendDataToMain('resumed');
    }
  }
}

/// 统一的启动/停止入口，屏蔽 Android / iOS 差异。
class TrackerService {
  TrackerService._();
  static final instance = TrackerService._();

  TrackerCore? _iosCore; // iOS：在主 isolate 运行
  Timer? _iosTimer;

  void init() {
    if (Platform.isAndroid) {
      FlutterForegroundTask.init(
        androidNotificationOptions: AndroidNotificationOptions(
          channelId: 'sharing_service',
          channelName: '位置共享',
          channelDescription: '保持位置共享在后台运行',
          channelImportance: NotificationChannelImportance.LOW,
          priority: NotificationPriority.LOW,
        ),
        iosNotificationOptions: const IOSNotificationOptions(showNotification: false),
        foregroundTaskOptions: ForegroundTaskOptions(
          eventAction: ForegroundTaskEventAction.repeat(3000),
          autoRunOnBoot: true, // 开机自启动恢复服务（BOOT_COMPLETED）
          autoRunOnMyPackageReplaced: true,
          allowWakeLock: true,
          allowWifiLock: true,
          allowAutoRestart: true,
        ),
      );
    }
  }

  Future<bool> get running async => Platform.isAndroid ? FlutterForegroundTask.isRunningService : _iosCore != null;

  Future<void> start() async {
    try {
      await _start();
    } catch (e, st) {
      AppLog.e('service', '启动失败：$e\n$st');
    }
  }

  Future<void> _start() async {
    final s = await SettingsStore.open();
    await s.setTracking(true);
    if (Platform.isAndroid) {
      if (await FlutterForegroundTask.isRunningService) return;
      final r = await FlutterForegroundTask.startService(
        serviceId: 4201,
        serviceTypes: [ForegroundServiceTypes.location],
        notificationTitle: '甜蜜定位',
        notificationText: '正在和 TA 共享位置',
        notificationButtons: const [
          NotificationButton(id: 'pause', text: '暂停 1 小时'),
          NotificationButton(id: 'resume', text: '恢复共享'),
        ],
        callback: trackerServiceMain,
      );
      if (r is ServiceRequestFailure) AppLog.e('service', r.error);
    } else if (Platform.isIOS) {
      if (_iosCore != null) return;
      _iosCore = await buildTrackerCore();
      await _iosCore?.start();
      _iosTimer = Timer.periodic(const Duration(seconds: 3), (_) => _iosCore?.tick());
    }
  }

  Future<void> stop() async {
    final s = await SettingsStore.open();
    await s.setTracking(false);
    if (Platform.isAndroid) {
      await FlutterForegroundTask.stopService();
    } else {
      _iosTimer?.cancel();
      await _iosCore?.stop();
      _iosCore = null;
    }
  }

  /// 通知后台立即上传（SOS、到家后调用）。
  void flushNow() {
    if (Platform.isAndroid) {
      FlutterForegroundTask.sendDataToTask('flush');
    } else {
      _iosCore?.flush();
    }
  }

  TrackerCore? get iosCore => _iosCore;
}
