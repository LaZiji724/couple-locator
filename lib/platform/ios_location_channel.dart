import 'dart:io';

import 'package:flutter/services.dart';

/// iOS 原生 CoreLocation「显著位置变化」通道（见 ios/Runner/AppDelegate.swift）。
/// App 被系统终止后，位置发生显著变化（约 500m 以上）时系统会重新拉起 App。
class IosLocationChannel {
  static const _ch = MethodChannel('couple/location');

  static Future<bool> startSignificant() async {
    if (!Platform.isIOS) return false;
    try {
      return (await _ch.invokeMethod<bool>('startSignificant')) ?? false;
    } catch (_) {
      return false;
    }
  }

  static Future<void> stopSignificant() async {
    if (!Platform.isIOS) return;
    try {
      await _ch.invokeMethod('stopSignificant');
    } catch (_) {}
  }
}
