# 甜蜜定位 · 双人私密实时位置

情侣/双人私用的实时位置共享 App（Flutter，Android + iOS）。两人配对后在后台持续上报位置，对方在高德地图上实时看到你的位置、状态与历史轨迹。**不上架、无广告、无统计**；位置/状态/标记内容全部**端到端加密**。

- 地图：高德（GCJ-02 坐标，内置 WGS-84↔GCJ-02 转换），不依赖任何 Google 服务
- 后端：Supabase（Auth / Postgres + RLS / Realtime / RPC / pg_cron），统一封装在 `lib/data/remote/backend.dart`，换腾讯云 CloudBase 只需新增一个实现
- 加密：X25519 + HKDF-SHA256 + XChaCha20-Poly1305（`cryptography` 包），私钥只在 Keychain/Keystore
- 推送：不使用 FCM/APNs，统一 Supabase Realtime 长连接 + 本地通知

## 目录
```
lib/core/       主题(令牌/动效/组件)、坐标转换、格式化、日志
lib/data/       Supabase 后端、Drift 本地库、密钥存储、加密通道
lib/domain/     采样策略、抽稀/停留点/重合时长/统计、加解密（纯 Dart，有单测）
lib/platform/   前台服务/TrackerCore、通知、权限、小组件桥、iOS 显著位置通道
lib/features/   onboarding auth pairing map history stats interact settings
supabase/       migrations/0001_init.sql（表+RLS+RPC+pg_cron）、functions/check-lost
scripts/        build_apk.sh build_ipa.sh gen_keystore.sh add_widget_extension.rb make_icon.py
docs/           DESIGN.md SETUP.md AMAP.md BUILD.md IOS_SIDELOAD.md SECURITY.md STATUS.md
```

## 快速开始
1. 按 [docs/SETUP.md](docs/SETUP.md) 创建 Supabase 项目、执行迁移 SQL；按 [docs/AMAP.md](docs/AMAP.md) 申请高德 Key。
2. `cp env/example.json env/dev.json` 并填写。
3. `flutter pub get && dart run build_runner build --delete-conflicting-outputs`
4. `AMAP_ANDROID_KEY=你的key flutter run --dart-define-from-file=env/dev.json`
5. 构建与安装：[docs/BUILD.md](docs/BUILD.md)（APK）、[docs/IOS_SIDELOAD.md](docs/IOS_SIDELOAD.md)（未签名 IPA 与侧载）。
6. 测试：`flutter test`（坐标转换、抽稀、停留点、统计、加解密、密钥备份、采样、补传去重、配色对比度）。

## 各品牌安卓保活设置（锁屏后持续上报的关键）
App 内「引导页 → 后台保活指引」会按手机品牌给出同样内容。核心三件事：**自启动、后台高耗电/省电策略设为无限制、多任务锁定**。

| 品牌 | 路径 |
|---|---|
| 小米/红米/HyperOS | 设置→应用设置→应用管理→甜蜜定位→自启动开；省电策略「无限制」；多任务长按卡片→锁定 |
| 华为/荣耀 | 设置→应用和服务→应用启动管理→甜蜜定位→关闭自动管理，手动开自启动/关联启动/后台活动；多任务下拉卡片锁定 |
| OPPO/一加/realme | 设置→应用管理→甜蜜定位→耗电管理→允许后台运行/自启动；电池→不优化；多任务卡片加锁 |
| vivo/iQOO | 设置→电池→后台高耗电→允许；权限管理→自启动开；多任务下拉锁定 |
| 三星 | 应用→甜蜜定位→电池→不受限制；电池→后台使用限制→从不自动休眠的应用添加；多任务保持打开 |
| 原生 Android | 应用→电池→不受限制；位置权限选「始终允许」 |

## 常见问题
- **地图空白**：高德 Key 未填/包名不匹配（Android 还要 SHA1），见 docs/AMAP.md。
- **对方一直没位置**：对方需先打开一次 App 上传公钥；双方都要完成资料设置。
- **换手机后看不到历史**：先用「密钥备份与恢复」恢复私钥，再让对方重开一次 App。
- **iOS 被划掉后不再更新**：系统限制，见 docs/IOS_SIDELOAD.md「已知限制」。
- **Supabase 国内偏慢**：选新加坡/东京区域；弱网下位置会先存本地，恢复后按时间顺序幂等补传。

完成度与已知限制见 [docs/STATUS.md](docs/STATUS.md)。
