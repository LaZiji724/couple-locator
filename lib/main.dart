import 'dart:async';
import 'dart:io';
import 'dart:ui' show PlatformDispatcher;

import 'package:amap_map/amap_map.dart';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_foreground_task/flutter_foreground_task.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:intl/date_symbol_data_local.dart';
import 'package:x_amap_base/x_amap_base.dart';

import 'app/app.dart';
import 'core/config/app_config.dart';
import 'core/log.dart';
import 'platform/background_tasks.dart';
import 'platform/bootstrap.dart';
import 'platform/notifications.dart';
import 'platform/ios_location_channel.dart';
import 'platform/permissions.dart';
import 'platform/tracker_service.dart';
import 'data/repo/settings_store.dart';

Future<void> main() async {
  // 任何未捕获错误都只记日志，不让 App 直接崩溃；启动阶段的致命错误显示错误页（可复制）。
  await runZonedGuarded(_boot, (e, st) => AppLog.e('uncaught', '$e\n$st'));
}

Future<void> _boot() async {
  WidgetsFlutterBinding.ensureInitialized();
  FlutterError.onError = (d) => AppLog.e('flutter', '${d.exceptionAsString()}\n${d.stack}');
  PlatformDispatcher.instance.onError = (e, st) {
    AppLog.e('platform', '$e\n$st');
    return true;
  };

  // 每一步独立 try/catch：单个组件初始化失败只降级，不阻止启动。
  Future<void> step(String name, FutureOr<void> Function() f) async {
    try {
      await f();
      AppLog.i('boot', '$name OK');
    } catch (e, st) {
      AppLog.e('boot', '$name 失败：$e\n$st');
    }
  }

  await step('日期格式', () => initializeDateFormatting('zh_CN'));
  SystemChrome.setSystemUIOverlayStyle(const SystemUiOverlayStyle(statusBarColor: Colors.transparent));
  // 高德隐私合规：必须在使用地图前声明。首次启动已在引导页展示隐私说明。
  await step('高德隐私', () => AMapInitializer.updatePrivacyAgree(const AMapPrivacyStatement(hasContains: true, hasShow: true, hasAgree: true)));
  await step('Supabase', ensureSupabase);
  await step('本地通知', LocalNotifier.instance.init);
  await step('前台任务端口', FlutterForegroundTask.initCommunicationPort);
  await step('定位服务', TrackerService.instance.init);
  if (AppConfig.backendConfigured) {
    await step('后台任务', BackgroundTasks.register);
  }
  // iOS：被「显著位置变化」从终止状态唤醒时，直接恢复连续定位并补传
  if (AppConfig.backendConfigured && Platform.isIOS) {
    await step('iOS 恢复定位', () async {
      final st = await SettingsStore.open();
      if (st.trackingEnabled && await PermissionService.hasLocation()) {
        await TrackerService.instance.start();
        IosLocationChannel.startSignificant();
      }
    });
  }
  ErrorWidget.builder = (d) => Material(
        color: const Color(0xFFFFF8F3),
        child: Center(child: Padding(padding: const EdgeInsets.all(24), child: Text('页面出错了：${d.exceptionAsString()}', style: const TextStyle(color: Color(0xFF2D2238))))),
      );
  runApp(const ProviderScope(child: _AmapInit(child: CoupleApp())));
}

/// 高德 SDK 需要 BuildContext 初始化屏幕密度。
class _AmapInit extends StatelessWidget {
  const _AmapInit({required this.child});
  final Widget child;
  @override
  Widget build(BuildContext context) {
    return Builder(builder: (ctx) {
      try {
        AMapInitializer.init(ctx, apiKey: const AMapApiKey(androidKey: AppConfig.amapAndroidKey, iosKey: AppConfig.amapIosKey));
      } catch (e) {
        AppLog.e('amap', e);
      }
      return child;
    });
  }
}
