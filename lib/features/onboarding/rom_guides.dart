import 'package:flutter/material.dart';

import '../../core/theme/app_theme.dart';
import '../../core/theme/tokens.dart';
import '../../core/widgets/vibe_widgets.dart';
import '../../platform/permissions.dart';
import 'onboarding_page.dart' show detectBrand;

class _Rom {
  const _Rom(this.id, this.name, this.emoji, this.steps);
  final String id;
  final String name;
  final String emoji;
  final List<String> steps;
}

/// 各品牌 ROM 保活设置路径（不同系统版本菜单名称可能略有差异）。
const _roms = <_Rom>[
  _Rom('xiaomi', '小米 / 红米 / HyperOS', '🟠', [
    '设置 → 应用设置 → 应用管理 → 甜蜜定位 → 自启动：开启',
    '同一页面 → 省电策略：选择「无限制」',
    '设置 → 电池 → 省电优化/应用省电 → 甜蜜定位 → 无限制',
    '打开多任务（最近任务）界面，长按甜蜜定位卡片 → 点锁形图标锁定',
    '设置 → 权限管理 → 后台弹出界面：允许（用于 SOS 全屏警报）',
  ]),
  _Rom('huawei', '华为 / 荣耀 / HarmonyOS', '🔴', [
    '设置 → 应用和服务 → 应用启动管理 → 甜蜜定位 → 关闭「自动管理」',
    '在弹窗中同时打开：自启动、关联启动、后台活动',
    '设置 → 电池 → 更多电池设置 → 休眠时始终保持网络连接：开启',
    '多任务界面下拉甜蜜定位卡片，出现锁形图标后锁定',
    '设置 → 位置信息 → 应用位置权限 → 甜蜜定位 → 始终允许',
  ]),
  _Rom('oppo', 'OPPO / 一加 / realme（ColorOS）', '🟢', [
    '设置 → 应用管理 → 应用列表 → 甜蜜定位 → 耗电管理：允许后台运行、允许自启动',
    '设置 → 电池 → 更多设置 → 优化电池使用 → 甜蜜定位 → 不优化',
    '多任务界面点击甜蜜定位卡片右上角「⋮」→ 加锁',
    '设置 → 隐私 → 权限管理 → 自启动管理：开启甜蜜定位',
  ]),
  _Rom('vivo', 'vivo / iQOO（OriginOS）', '🔵', [
    '设置 → 电池 → 后台高耗电 → 甜蜜定位：允许',
    '设置 → 应用与权限 → 权限管理 → 自启动 → 开启甜蜜定位',
    'i管家 → 应用管理 → 权限管理 → 后台弹出界面：允许',
    '多任务界面下拉甜蜜定位卡片锁定',
  ]),
  _Rom('samsung', '三星（One UI）', '⚪', [
    '设置 → 应用程序 → 甜蜜定位 → 电池 → 选择「不受限制」',
    '设置 → 电池 → 后台使用限制 → 深度休眠应用：移除甜蜜定位',
    '设置 → 电池 → 后台使用限制 → 从不自动休眠的应用：添加甜蜜定位',
    '多任务界面点击甜蜜定位图标 → 保持打开状态',
  ]),
  _Rom('other', '其他品牌 / 原生 Android', '🤖', [
    '设置 → 应用 → 甜蜜定位 → 电池 → 不受限制',
    '设置 → 应用 → 甜蜜定位 → 权限 → 位置信息 → 始终允许',
    '如系统提供「自启动」「后台弹出界面」，请一并开启',
    '多任务界面锁定应用（长按卡片或下拉卡片）',
  ]),
];

class RomGuidePage extends StatefulWidget {
  const RomGuidePage({super.key});
  @override
  State<RomGuidePage> createState() => _RomGuidePageState();
}

class _RomGuidePageState extends State<RomGuidePage> {
  String _sel = 'other';

  @override
  void initState() {
    super.initState();
    detectBrand().then((b) {
      final id = switch (true) {
        _ when b.contains('xiaomi') || b.contains('redmi') || b.contains('poco') => 'xiaomi',
        _ when b.contains('huawei') || b.contains('honor') => 'huawei',
        _ when b.contains('oppo') || b.contains('oneplus') || b.contains('realme') => 'oppo',
        _ when b.contains('vivo') || b.contains('iqoo') => 'vivo',
        _ when b.contains('samsung') => 'samsung',
        _ => 'other',
      };
      if (mounted) setState(() => _sel = id);
    });
  }

  @override
  Widget build(BuildContext context) {
    final v = context.vibes;
    final rom = _roms.firstWhere((r) => r.id == _sel);
    return Scaffold(
      appBar: AppBar(title: const Text('后台保活设置指引')),
      body: PaperBackdrop(
        child: SafeArea(
          child: ListView(padding: const EdgeInsets.all(20), children: [
            Text('国产安卓系统会主动杀后台。按下面的步骤设置一次，才能锁屏后继续共享位置。', style: TextStyle(color: v.inkSoft, height: 1.5)),
            const SizedBox(height: 14),
            Wrap(spacing: 8, runSpacing: 8, children: [
              for (final r in _roms)
                ChoiceChip(
                  label: Text('${r.emoji} ${r.name.split('（').first.split(' / ').first}'),
                  selected: _sel == r.id,
                  onSelected: (_) => setState(() => _sel = r.id),
                  shape: const StadiumBorder(),
                ),
            ]),
            const SizedBox(height: 16),
            Text(rom.name, style: Theme.of(context).textTheme.titleLarge),
            const SizedBox(height: 10),
            for (final (i, s) in rom.steps.indexed)
              StaggerIn(
                index: i,
                key: ValueKey('${rom.id}$i'),
                child: Padding(
                  padding: const EdgeInsets.only(bottom: 10),
                  child: VibeCard(
                    padding: const EdgeInsets.all(14),
                    child: Row(crossAxisAlignment: CrossAxisAlignment.start, children: [
                      Container(width: 28, height: 28, alignment: Alignment.center, decoration: const BoxDecoration(shape: BoxShape.circle, color: AppColors.accent), child: Text('${i + 1}', style: const TextStyle(fontWeight: FontWeight.w600, color: AppColors.onAccent))),
                      const SizedBox(width: 12),
                      Expanded(child: Text(s, style: const TextStyle(height: 1.45))),
                    ]),
                  ),
                ),
              ),
            const SizedBox(height: 10),
            PrimaryButton(label: '打开系统设置', onTap: PermissionService.openSystemSettings),
            const SizedBox(height: 10),
            SoftButton(label: '我设置好了', onTap: () => Navigator.pop(context)),
          ]),
        ),
      ),
    );
  }
}
