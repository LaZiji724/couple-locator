import 'dart:io';

import 'package:amap_map/amap_map.dart';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_foreground_task/flutter_foreground_task.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:intl/date_symbol_data_local.dart';
import 'package:x_amap_base/x_amap_base.dart';

import 'app/app.dart';
import 'core/config/app_config.dart';
import 'platform/background_tasks.dart';
import 'platform/bootstrap.dart';
import 'platform/notifications.dart';
import 'platform/ios_location_channel.dart';
import 'platform/permissions.dart';
import 'platform/tracker_service.dart';
import 'data/repo/settings_store.dart';

Future<void> main() async {
  WidgetsFlutterBinding.ensureInitialized();
  await initializeDateFormatting('zh_CN');
  SystemChrome.setSystemUIOverlayStyle(const SystemUiOverlayStyle(statusBarColor: Colors.transparent));

  // 高德隐私合规：必须在使用地图前声明。首次启动已在引导页展示隐私说明。
  AMapInitializer.updatePrivacyAgree(const AMapPrivacyStatement(hasContains: true, hasShow: true, hasAgree: true));

  await ensureSupabase();
  await LocalNotifier.instance.init();
  FlutterForegroundTask.initCommunicationPort();
  TrackerService.instance.init();
  if (AppConfig.backendConfigured) {
    try {
      await BackgroundTasks.register();
    } catch (_) {}
  }
  // iOS：被「显著位置变化」从终止状态唤醒时，直接恢复连续定位并补传
  if (AppConfig.backendConfigured && Platform.isIOS) {
    final st = await SettingsStore.open();
    if (st.trackingEnabled && await PermissionService.hasLocation()) {
      await TrackerService.instance.start();
      IosLocationChannel.startSignificant();
    }
  }
  runApp(const ProviderScope(child: _AmapInit(child: CoupleApp())));
}

/// 高德 SDK 需要 BuildContext 初始化屏幕密度。
class _AmapInit extends StatelessWidget {
  const _AmapInit({required this.child});
  final Widget child;
  @override
  Widget build(BuildContext context) {
    return Builder(builder: (ctx) {
      AMapInitializer.init(ctx, apiKey: const AMapApiKey(androidKey: AppConfig.amapAndroidKey, iosKey: AppConfig.amapIosKey));
      return child;
    });
  }
}
