import 'dart:io';

import 'package:flutter_local_notifications/flutter_local_notifications.dart';

/// 本地通知（不依赖 FCM / APNs）。推送统一用 Supabase Realtime + 本地通知。
class LocalNotifier {
  LocalNotifier._();
  static final instance = LocalNotifier._();
  final _plugin = FlutterLocalNotificationsPlugin();
  bool _ready = false;

  Future<void> init({void Function(String? payload)? onTap}) async {
    if (_ready) return;
    const android = AndroidInitializationSettings('@mipmap/ic_launcher');
    const ios = DarwinInitializationSettings(requestAlertPermission: false, requestBadgePermission: false, requestSoundPermission: false);
    await _plugin.initialize(
      settings: const InitializationSettings(android: android, iOS: ios),
      onDidReceiveNotificationResponse: (r) => onTap?.call(r.payload),
    );
    _ready = true;
  }

  static const _chNormal = AndroidNotificationDetails('events', '互动消息',
      channelDescription: '戳一戳、到家、失联提醒', importance: Importance.high, priority: Priority.high);
  static const _chSos = AndroidNotificationDetails('sos', 'SOS 紧急求助',
      channelDescription: '对方发起的紧急求助', importance: Importance.max, priority: Priority.max,
      fullScreenIntent: true, category: AndroidNotificationCategory.alarm, playSound: true, enableVibration: true,
      audioAttributesUsage: AudioAttributesUsage.alarm);

  Future<void> show(int id, String title, String body, {String? payload, bool sos = false}) async {
    if (!_ready) await init();
    await _plugin.show(
      id: id,
      title: title,
      body: body,
      notificationDetails: NotificationDetails(
        android: sos ? _chSos : _chNormal,
        iOS: DarwinNotificationDetails(
          presentAlert: true,
          presentSound: true,
          interruptionLevel: sos ? InterruptionLevel.timeSensitive : InterruptionLevel.active,
        ),
      ),
      payload: payload,
    );
  }

  Future<void> cancel(int id) async => _plugin.cancel(id: id);

  Future<void> requestPermissionIfNeeded() async {
    if (Platform.isIOS) {
      await _plugin
          .resolvePlatformSpecificImplementation<IOSFlutterLocalNotificationsPlugin>()
          ?.requestPermissions(alert: true, badge: true, sound: true);
    } else if (Platform.isAndroid) {
      await _plugin.resolvePlatformSpecificImplementation<AndroidFlutterLocalNotificationsPlugin>()?.requestNotificationsPermission();
    }
  }
}

abstract final class NotifIds {
  static const lost = 100;
  static const sos = 101;
  static const arrived = 102;
  static const poke = 103;
}
