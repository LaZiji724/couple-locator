import 'package:flutter/material.dart';

/// 设计令牌：暖纸色底 + 单一玫瑰强调色。详见 docs/DESIGN.md。
abstract final class AppColors {
  /// 唯一强调色（玫瑰），只用于主操作与选中态。白字对比度 ≥ 4.5。
  static const accent = Color(0xFFC8405A);
  static const onAccent = Color(0xFFFFFFFF);

  /// 在线、充电等「正常」语义色，仅用作小面积状态点。
  static const mint = Color(0xFF4FA383);

  static const creamBg = Color(0xFFFAF6F1);
  static const nightBg = Color(0xFF181514);
  static const nightSurface = Color(0xFF221E1C);
  static const nightSurfaceHigh = Color(0xFF2C2725);
  static const surfaceHighLight = Color(0xFFF3EDE6);

  static const inkLight = Color(0xFF2B2522);
  static const inkSoftLight = Color(0xFF6B5F57);
  static const inkDark = Color(0xFFF4EEE8);
  static const inkSoftDark = Color(0xFFB8AEA5);

  static const accentTextLight = Color(0xFFB5334D);
  static const accentTextDark = Color(0xFFF0899D);

  static const dangerLight = Color(0xFFD13B4B);
  static const dangerDark = Color(0xFFF2707E);

  static const hairlineLight = Color(0x1F2B2522);
  static const hairlineDark = Color(0x29F4EEE8);
}

/// 个人专属主题色（预设 8 种渐变）。这是用户内容色，用于头像环、轨迹与气泡。
class PersonalPalette {
  const PersonalPalette(this.id, this.name, this.start, this.end);
  final String id;
  final String name;
  final Color start;
  final Color end;

  LinearGradient get gradient => LinearGradient(
        begin: Alignment.topLeft,
        end: Alignment.bottomRight,
        colors: [start, end],
      );

  /// 时间进度 t∈[0,1] 对应的轨迹颜色。
  Color at(double t) => Color.lerp(start, end, t.clamp(0, 1))!;

  static const all = <PersonalPalette>[
    PersonalPalette('coral', '珊瑚日落', Color(0xFFE5667F), Color(0xFFF0936B)),
    PersonalPalette('peach', '蜜桃汽水', Color(0xFFF0936B), Color(0xFFF2C25E)),
    PersonalPalette('mint', '薄荷清风', Color(0xFF4FB596), Color(0xFF59B5DB)),
    PersonalPalette('sky', '天空气泡', Color(0xFF59B5DB), Color(0xFF9B86E8)),
    PersonalPalette('grape', '葡萄果冻', Color(0xFF9B86E8), Color(0xFFE5667F)),
    PersonalPalette('sakura', '樱花奶昔', Color(0xFFF08CAD), Color(0xFFF7BCD0)),
    PersonalPalette('lime', '柠檬青提', Color(0xFFABD65E), Color(0xFF4FB596)),
    PersonalPalette('dusk', '晚霞橘紫', Color(0xFFF07B5D), Color(0xFF9B86E8)),
  ];

  static PersonalPalette byId(String? id) =>
      all.firstWhere((p) => p.id == id, orElse: () => all.first);
}

/// 同心圆角三档：卡片 24 → 内部控件 16（内边距 8）→ 小标签 8。
abstract final class AppRadii {
  static const card = 24.0;
  static const small = 16.0;
  static const tiny = 8.0;
  static const pill = 999.0;
}

abstract final class AppShadows {
  /// 只给浮层用的中性阴影。[tint] 仅为兼容旧调用，不再着色。
  static List<BoxShadow> soft(Color tint, {bool dark = false}) => [
        BoxShadow(
          color: Colors.black.withValues(alpha: dark ? 0.32 : 0.08),
          blurRadius: 24,
          offset: const Offset(0, 8),
        ),
        BoxShadow(
          color: Colors.black.withValues(alpha: dark ? 0.2 : 0.04),
          blurRadius: 4,
          offset: const Offset(0, 1),
        ),
      ];
}
