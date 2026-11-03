import 'package:flutter/material.dart';

/// 设计令牌：颜色、渐变、圆角、阴影。详见 docs/DESIGN.md。
abstract final class AppColors {
  static const coral = Color(0xFFFF6B8A);
  static const peach = Color(0xFFFF9A6C);
  static const sun = Color(0xFFFFD166);
  static const mint = Color(0xFF4ADEB4);
  static const sky = Color(0xFF5CC8FF);
  static const grape = Color(0xFFA78BFA);

  static const creamBg = Color(0xFFFFF8F3);
  static const nightBg = Color(0xFF1A1625);
  static const nightSurface = Color(0xFF241E33);
  static const nightSurfaceHigh = Color(0xFF2E2742);

  static const inkLight = Color(0xFF2D2238);
  static const inkSoftLight = Color(0xFF6B5E78);
  static const inkDark = Color(0xFFF7F1FF);
  static const inkSoftDark = Color(0xFFC9BEDB);

  static const accentTextLight = Color(0xFFC7365A);
  static const accentTextDark = Color(0xFFFF8FA8);
  static const onGradient = Color(0xFF3A1030);

  static const dangerLight = Color(0xFFFF4D6D);
  static const dangerDark = Color(0xFFFF6B85);

  static const sunrise = LinearGradient(
    begin: Alignment.topLeft,
    end: Alignment.bottomRight,
    colors: [coral, peach, sun],
  );
}

/// 个人专属主题色（预设 8 种渐变）。
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
    PersonalPalette('coral', '珊瑚日落', Color(0xFFFF6B8A), Color(0xFFFF9A6C)),
    PersonalPalette('peach', '蜜桃汽水', Color(0xFFFF9A6C), Color(0xFFFFD166)),
    PersonalPalette('mint', '薄荷清风', Color(0xFF4ADEB4), Color(0xFF5CC8FF)),
    PersonalPalette('sky', '天空气泡', Color(0xFF5CC8FF), Color(0xFFA78BFA)),
    PersonalPalette('grape', '葡萄果冻', Color(0xFFA78BFA), Color(0xFFFF6B8A)),
    PersonalPalette('sakura', '樱花奶昔', Color(0xFFFF8FB1), Color(0xFFFFC4D6)),
    PersonalPalette('lime', '柠檬青提', Color(0xFFB8E86B), Color(0xFF4ADEB4)),
    PersonalPalette('dusk', '晚霞橘紫', Color(0xFFFF7E5F), Color(0xFFA78BFA)),
  ];

  static PersonalPalette byId(String? id) =>
      all.firstWhere((p) => p.id == id, orElse: () => all.first);
}

abstract final class AppRadii {
  static const card = 24.0;
  static const small = 16.0;
  static const pill = 999.0;
}

abstract final class AppShadows {
  static List<BoxShadow> soft(Color tint, {bool dark = false}) => [
        BoxShadow(
          color: tint.withValues(alpha: dark ? 0.18 : 0.28),
          blurRadius: 24,
          offset: const Offset(0, 10),
        ),
      ];
}
