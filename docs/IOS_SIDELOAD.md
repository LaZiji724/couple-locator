# iOS 未签名 IPA 与侧载

## 构建
- 无需自己搭环境：在 GitHub → Actions → build → Run workflow，等待 macOS runner 完成，下载 Artifacts：
  - `ios-ipa-noext` → `CoupleLocator-noext.ipa`（**不含**小组件扩展，侧载最稳）
  - `ios-ipa-widgets` → `CoupleLocator-widgets.ipa`（**含** Widget Extension：桌面小组件 + 锁屏实时活动 + App Group）
- 本机（macOS）：`scripts/build_ipa.sh [--with-widgets] env/prod.json`，流程 `flutter build ios --release --no-codesign` → 把 `Runner.app` 放进 `Payload/` → zip 成 `.ipa`。
- 最低 iOS 14。App 不使用任何需要付费开发者账号的能力（无 APNs、无 Push 权限）。

## 侧载与签名风险（务必阅读）
使用 AltStore / Sideloadly / TrollStore / 其他第三方签名工具重签：

| 组件 | 免费个人 Apple ID | 付费开发者账号 / TrollStore |
|---|---|---|
| 主 App（后台定位、通知、地图） | ✅ 通常可用 | ✅ |
| **Widget Extension** | ⚠️ 每个扩展会额外占用一个 App ID；免费账号 7 天内最多 10 个 App ID，易触顶导致**签名失败** | ✅ |
| **App Groups**（小组件与主 App 共享数据） | ⚠️ 部分重签工具会改写 Bundle ID，导致 App Group 与 `group.com.couple.coupleLocator` 不匹配，小组件拿不到数据；免费账号不支持自定义 App Group 的情况也常见 | ✅（TrollStore 保留原权限） |
| **ActivityKit 实时活动** | ⚠️ 依赖扩展 + `NSSupportsLiveActivities`；扩展签不上则不可用 | ✅ |
| 免费账号有效期 | 7 天，需要刷新 | 1 年 / 永久 |

**降级方案（已内置）**：
1. 优先装 `noext` 包。主 App 完整功能可用，仅没有小组件/实时活动。
2. 想要小组件再试 `widgets` 包；若工具提示签名失败/App ID 超额，换回 `noext` 包即可，数据与账号不受影响。
3. 代码层面 `WidgetBridge`（lib/platform/widget_bridge.dart）对 HomeWidget / LiveActivities 的所有调用都包了 try/catch，缺少扩展时静默跳过，不会崩溃。
4. 若重签工具改了 Bundle ID，需同步把 `ios/CoupleWidgets/CoupleWidgets.entitlements`、`Runner.entitlements.widgets` 与 `widget_bridge.dart` 中的 App Group 改成对应值后重新构建。

## 已知限制
- **没有 APNs**：App 被系统终止（用户上划杀掉、或被系统回收）后，iOS 无法收到 Realtime 实时推送。缓解：
  ① 位置发生显著变化（约 500 米）时系统用 `startMonitoringSignificantLocationChanges` 重新拉起 App，随后恢复连续定位，并自动补拉错过的事件（到家/戳一戳/SOS）并发本地通知；
  ② BGTaskScheduler 后台刷新（时机由系统决定，不保证）；
  ③ 被用户主动上划杀掉后，iOS 不会再用显著位置变化拉起 App——需要手动重新打开一次。
- **iOS SOS** 在 App 被杀时无法 10 秒内到达对方；对方 App 在前台/后台存活时可达。
- 后台定位依赖「始终允许」权限；iOS 会在状态栏显示蓝色定位指示（`showBackgroundLocationIndicator`）。
