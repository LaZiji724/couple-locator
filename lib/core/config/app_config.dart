/// 配置通过 --dart-define 注入，源码中不放任何密钥。
/// 例：flutter run --dart-define-from-file=env/dev.json
/// 详见 docs/SETUP.md 与 env/example.json。
abstract final class AppConfig {
  static const supabaseUrl = String.fromEnvironment('SUPABASE_URL', defaultValue: '');
  static const supabaseAnonKey = String.fromEnvironment('SUPABASE_ANON_KEY', defaultValue: '');
  // 高德 Key（Android/iOS 的 Key 同时需写入原生配置，见 docs/AMAP.md）
  static const amapAndroidKey = String.fromEnvironment('AMAP_ANDROID_KEY', defaultValue: '');
  static const amapIosKey = String.fromEnvironment('AMAP_IOS_KEY', defaultValue: '');
  // 高德 Web 服务 Key（逆地理编码 REST）
  static const amapWebKey = String.fromEnvironment('AMAP_WEB_KEY', defaultValue: '');

  static bool get backendConfigured => supabaseUrl.isNotEmpty && supabaseAnonKey.isNotEmpty;
  static bool get amapConfigured => amapAndroidKey.isNotEmpty || amapIosKey.isNotEmpty;
}
