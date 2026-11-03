# Android 打包

环境：Flutter 3.47+、JDK 17、Android SDK（compileSdk 由 Flutter 决定，minSdk 26 = Android 8.0）。

```bash
scripts/gen_keystore.sh              # 生成自己保管的 keystore（android/app/upload-keystore.jks + key.properties，均已 .gitignore）
cp env/example.json env/prod.json    # 填好各项 Key
scripts/build_apk.sh env/prod.json   # 产出 dist/*.apk：app-arm64-v8a / armeabi-v7a / x86_64 以及通用大包 app-release.apk
```
- 已开启 R8 混淆与资源压缩，`android/app/proguard-rules.pro` 保留了高德、定位、前台服务、WorkManager、小组件相关类。
- 没有 `key.properties` 时回退为 debug 签名（只能用于试装）。**升级安装必须使用同一把 keystore。**
- GitHub Actions：`.github/workflows/build.yml` 会在 push 时构建；在仓库 Settings → Secrets 添加
  `SUPABASE_URL`、`SUPABASE_ANON_KEY`、`AMAP_ANDROID_KEY`、`AMAP_IOS_KEY`、`AMAP_WEB_KEY`，以及可选的
  `ANDROID_KEYSTORE_B64`（`base64 -w0 upload-keystore.jks`）与 `ANDROID_KEYSTORE_PASSWORD`。产物在 Actions → Artifacts。

## 手机权限清单（引导页会逐项申请）
ACCESS_FINE_LOCATION、ACCESS_BACKGROUND_LOCATION、POST_NOTIFICATIONS、ACTIVITY_RECOGNITION、REQUEST_IGNORE_BATTERY_OPTIMIZATIONS、FOREGROUND_SERVICE(+_LOCATION)、RECEIVE_BOOT_COMPLETED。
开机自启动由 flutter_foreground_task 的 RebootReceiver 恢复前台服务；服务被杀后由 WorkManager（约 15 分钟）拉起。
