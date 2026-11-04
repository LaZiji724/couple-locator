# 高德开放平台 Key 申请与配置

需要**三个** Key（https://console.amap.com → 应用管理 → 创建新应用 → 添加 Key）：

| Key 类型 | 服务平台 | 填写内容 | 用于 |
|---|---|---|---|
| Android Key | Android 平台 | **PackageName** = `com.couple.couple_locator`；**SHA1** = 见下 | 地图 |
| iOS Key | iOS 平台 | **BundleID** = `com.couple.coupleLocator`（重签后若改了 Bundle ID 要同步改） | 地图 |
| Web 服务 Key | Web 服务 | 无需包名 | 逆地理编码（停留点地名） |

## Android SHA1
- 调试：`keytool -list -v -keystore ~/.android/debug.keystore -alias androiddebugkey -storepass android` 取 SHA1
- 发布：`keytool -list -v -keystore android/app/upload-keystore.jks -alias couple` 取 SHA1
- **调试包和发布包 SHA1 不同**：可在同一个 Key 里无法填两个，建议申请两个 Android Key（debug / release），构建时用 `AMAP_ANDROID_KEY` 切换。

## 填到哪里
- `env/dev.json`：`AMAP_ANDROID_KEY` / `AMAP_IOS_KEY` / `AMAP_WEB_KEY`（Dart 端通过 `AMapApiKey` 传给 SDK）。
- Android 原生清单通过 manifestPlaceholders 注入：`scripts/build_apk.sh` 会自动读取 `env/*.json` 的 `AMAP_ANDROID_KEY` 并导出为环境变量；手动构建用 `-PAMAP_ANDROID_KEY=xxx` 或 `export AMAP_ANDROID_KEY=xxx`。
- 隐私合规：高德 SDK 要求在使用前声明隐私政策已展示并同意，`lib/main.dart` 已调用 `AMapInitializer.updatePrivacyAgree`。个人自用无上架要求，如需上架请补充隐私弹窗。

## 自定义地图样式（浅色清新、水体偏青、绿地偏薄荷、少标注）
1. 控制台 → 我的应用 → 自定义地图 → 新建样式；参考配色：水体 `#BDEFF0`，绿地 `#D8F5E6`，道路 `#FFFFFF`，建筑 `#FFF1E8`，隐藏多数 POI/公交/地铁标注。
2. 发布后下载 `style.data`（及 `style_extra.data`）放到 `assets/map_style/`，App 会自动加载（`map_page.dart` 的 `_loadStyle`）。**没有这两个文件时使用高德默认样式**（样式文件需在控制台里生成，仓库内无法代为生成）。

## 坐标
定位原始数据为 WGS-84，存储和加密均用 WGS-84，仅在**显示/交互**时转换为 GCJ-02（`lib/core/geo/coord.dart`，有单元测试）。长按地图得到的 GCJ-02 会反解回 WGS-84 再存。

## 高德控制台需要填的三项
- **Android 包名**：`com.couple.couple_locator`
- **Android SHA1（发布版）**：`FA:A0:3A:05:F5:10:D7:8B:41:4C:3E:73:D6:F3:6E:BB:86:67:00:55`
  - 对应仓库内固定的个人侧载密钥 `android/app/fixed-signing.jks`（别名 `couple`，应用户要求提交，密码见 `android/app/build.gradle.kts`）。**仓库公开，任何人都能用同一把密钥签名，仅适合个人侧载**；正式发布请用 `scripts/gen_keystore.sh` 生成自己的密钥并配置 CI Secrets（Secrets 优先于该固定密钥），再把新 SHA1 绑到高德。
  - 调试版 SHA1 是每台开发机的 `~/.android/debug.keystore`，如需本地 `flutter run` 另行添加。
  - 务必备份这把密钥；丢失后无法覆盖安装升级，且 SHA1 会变化。
- **iOS Bundle ID**：`com.couple.coupleLocator`
