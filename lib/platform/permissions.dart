import 'dart:io';

import 'package:flutter_foreground_task/flutter_foreground_task.dart';
import 'package:geolocator/geolocator.dart';
import 'package:permission_handler/permission_handler.dart';

/// 引导页各步骤的权限状态与申请动作。
enum PermStep { location, always, notification, battery, autostart }

class PermissionService {
  static Future<bool> hasLocation() async {
    final p = await Geolocator.checkPermission();
    return p == LocationPermission.whileInUse || p == LocationPermission.always;
  }

  static Future<bool> hasAlways() async => (await Geolocator.checkPermission()) == LocationPermission.always;

  static Future<bool> requestLocation() async {
    var p = await Geolocator.checkPermission();
    if (p == LocationPermission.denied) p = await Geolocator.requestPermission();
    return p == LocationPermission.whileInUse || p == LocationPermission.always;
  }

  /// 升级到「始终允许」。Android 11+ 必须先有前台权限，再单独请求后台权限（会跳转系统设置）。
  static Future<bool> requestAlways() async {
    if (!await hasLocation()) await requestLocation();
    if (Platform.isAndroid) {
      final s = await Permission.locationAlways.request();
      return s.isGranted;
    }
    final p = await Geolocator.requestPermission();
    return p == LocationPermission.always;
  }

  static Future<bool> hasNotification() async => (await Permission.notification.status).isGranted;
  static Future<bool> requestNotification() async {
    final r = await Permission.notification.request();
    if (Platform.isAndroid) {
      await Permission.activityRecognition.request();
    }
    return r.isGranted;
  }

  static Future<bool> hasBatteryWhitelist() async =>
      Platform.isAndroid ? await FlutterForegroundTask.isIgnoringBatteryOptimizations : true;
  static Future<bool> requestBatteryWhitelist() async =>
      Platform.isAndroid ? await FlutterForegroundTask.requestIgnoreBatteryOptimization() : true;

  static Future<void> openSystemSettings() => openAppSettings();
}
