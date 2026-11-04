import 'dart:io';

import 'package:flutter/material.dart';
import 'package:flutter/services.dart';

import 'package:phosphor_flutter/phosphor_flutter.dart';

import '../core/log.dart';
import '../core/theme/app_theme.dart';

/// 地图渲染预检。Android 上通过原生通道试建一次 EGL 上下文（见 MainActivity.kt）；
/// 失败（如部分模拟器选不到 EGL 配置）就不创建地图，避免高德 SDK 在原生层直接崩溃。
class GlSupport {
  static const _ch = MethodChannel('couple/gl');
  static Future<bool>? _cached;

  static Future<bool> get ok => _cached ??= _probe();

  static Future<bool> _probe() async {
    if (!Platform.isAndroid) return true;
    try {
      final r = await _ch.invokeMethod<bool>('eglOk') ?? true;
      if (!r) AppLog.w('map', 'EGL 预检失败：此设备无法渲染地图，已降级为占位页');
      return r;
    } catch (e) {
      AppLog.e('map', 'EGL 预检异常，按支持处理：$e');
      return true;
    }
  }
}

/// 预检通过才显示 [child]（地图），否则显示友好的占位说明。
class GlGate extends StatelessWidget {
  const GlGate({super.key, required this.child});
  final Widget child;

  @override
  Widget build(BuildContext context) {
    return FutureBuilder<bool>(
      future: GlSupport.ok,
      builder: (context, snap) {
        if (!snap.hasData) return const SizedBox.shrink();
        if (snap.data == true) return child;
        final v = context.vibes;
        return Container(
          color: v.bg,
          alignment: Alignment.center,
          padding: const EdgeInsets.all(32),
          child: Column(mainAxisSize: MainAxisSize.min, children: [
            Icon(PhosphorIconsRegular.mapTrifold, size: 48, color: v.inkSoft),
            const SizedBox(height: 12),
            Text('这台设备暂时无法显示地图', style: Theme.of(context).textTheme.titleLarge),
            const SizedBox(height: 8),
            Text('常见于电脑上的安卓模拟器。真机上地图会正常显示，其余功能（互动、统计、定位上报等）不受影响。',
                textAlign: TextAlign.center, style: TextStyle(color: v.inkSoft, height: 1.5)),
          ]),
        );
      },
    );
  }
}
