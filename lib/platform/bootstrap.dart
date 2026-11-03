import 'package:supabase_flutter/supabase_flutter.dart';

import '../core/config/app_config.dart';
import '../data/local/database.dart';
import '../data/remote/backend.dart';
import '../data/remote/supabase_backend.dart';
import '../data/repo/key_store.dart';
import '../data/repo/settings_store.dart';
import 'tracker_core.dart';

bool _supabaseReady = false;

Future<void> ensureSupabase() async {
  if (_supabaseReady || !AppConfig.backendConfigured) return;
  await Supabase.initialize(url: AppConfig.supabaseUrl, anonKey: AppConfig.supabaseAnonKey);
  _supabaseReady = true;
}

/// 在任何 isolate（主 / 前台服务）中构建 TrackerCore。
Future<TrackerCore?> buildTrackerCore() async {
  if (!AppConfig.backendConfigured) return null;
  await ensureSupabase();
  final Backend backend = SupabaseBackend(Supabase.instance.client);
  return TrackerCore(
    backend: backend,
    db: AppDb(),
    keys: KeyStore(),
    settings: await SettingsStore.open(),
  );
}
