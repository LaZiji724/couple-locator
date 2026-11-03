# 高德地图 / 定位 / 搜索（不混淆，否则原生 SDK 反射失败）
-keep class com.amap.api.maps.**{*;}
-keep class com.autonavi.**{*;}
-keep class com.amap.api.trace.**{*;}
-keep class com.amap.api.location.**{*;}
-keep class com.amap.api.fence.**{*;}
-keep class com.loc.**{*;}
-keep class com.amap.api.services.**{*;}
-keep class com.amap.api.navi.**{*;}
-dontwarn com.amap.api.**
-dontwarn com.autonavi.**
-dontwarn com.loc.**

# Flutter 高德插件
-keep class com.amap.flutter.** { *; }

# 前台服务 / 定位 / WorkManager / 小组件
-keep class com.pravera.flutter_foreground_task.** { *; }
-keep class com.baseflow.geolocator.** { *; }
-keep class dev.fluttercommunity.workmanager.** { *; }
-keep class es.antonborri.home_widget.** { *; }
-keep class androidx.work.** { *; }

# sqlite / drift
-keep class org.sqlite.** { *; }
-dontwarn org.sqlite.**

# 本项目的小组件
-keep class com.couple.couple_locator.** { *; }
