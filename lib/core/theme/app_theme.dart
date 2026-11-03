import 'package:flutter/material.dart';

import 'tokens.dart';

/// 业务专用的主题扩展：渐变、毛玻璃、语义色。
@immutable
class Vibes extends ThemeExtension<Vibes> {
  const Vibes({
    required this.bg,
    required this.surface,
    required this.glass,
    required this.glassBorder,
    required this.ink,
    required this.inkSoft,
    required this.accentText,
    required this.danger,
    required this.isDark,
  });

  final Color bg;
  final Color surface;
  final Color glass;
  final Color glassBorder;
  final Color ink;
  final Color inkSoft;
  final Color accentText;
  final Color danger;
  final bool isDark;

  LinearGradient get sunrise => AppColors.sunrise;

  static const light = Vibes(
    bg: AppColors.creamBg,
    surface: Colors.white,
    glass: Color(0xB8FFFFFF),
    glassBorder: Color(0x66FFFFFF),
    ink: AppColors.inkLight,
    inkSoft: AppColors.inkSoftLight,
    accentText: AppColors.accentTextLight,
    danger: AppColors.dangerLight,
    isDark: false,
  );

  static const dark = Vibes(
    bg: AppColors.nightBg,
    surface: AppColors.nightSurface,
    glass: Color(0xAD2A2340),
    glassBorder: Color(0x33FFFFFF),
    ink: AppColors.inkDark,
    inkSoft: AppColors.inkSoftDark,
    accentText: AppColors.accentTextDark,
    danger: AppColors.dangerDark,
    isDark: true,
  );

  @override
  Vibes copyWith() => this;

  @override
  Vibes lerp(ThemeExtension<Vibes>? other, double t) {
    if (other is! Vibes) return this;
    return Vibes(
      bg: Color.lerp(bg, other.bg, t)!,
      surface: Color.lerp(surface, other.surface, t)!,
      glass: Color.lerp(glass, other.glass, t)!,
      glassBorder: Color.lerp(glassBorder, other.glassBorder, t)!,
      ink: Color.lerp(ink, other.ink, t)!,
      inkSoft: Color.lerp(inkSoft, other.inkSoft, t)!,
      accentText: Color.lerp(accentText, other.accentText, t)!,
      danger: Color.lerp(danger, other.danger, t)!,
      isDark: t < 0.5 ? isDark : other.isDark,
    );
  }
}

extension VibesX on BuildContext {
  Vibes get vibes => Theme.of(this).extension<Vibes>()!;
}

abstract final class AppTheme {
  static const displayFont = 'ZCOOLKuaiLe';

  static ThemeData light() => _build(Vibes.light, Brightness.light);
  static ThemeData dark() => _build(Vibes.dark, Brightness.dark);

  static ThemeData _build(Vibes v, Brightness b) {
    final scheme = ColorScheme(
      brightness: b,
      primary: AppColors.coral,
      onPrimary: AppColors.onGradient,
      secondary: AppColors.peach,
      onSecondary: AppColors.onGradient,
      tertiary: AppColors.mint,
      onTertiary: AppColors.inkLight,
      error: v.danger,
      onError: Colors.white,
      surface: v.surface,
      onSurface: v.ink,
      onSurfaceVariant: v.inkSoft,
      surfaceContainerHighest:
          v.isDark ? AppColors.nightSurfaceHigh : const Color(0xFFFFEFE6),
      outline: v.inkSoft.withValues(alpha: 0.4),
    );

    TextStyle display(double size) => TextStyle(
          fontFamily: displayFont,
          fontSize: size,
          color: v.ink,
          height: 1.2,
        );

    final base = ThemeData(
      useMaterial3: true,
      colorScheme: scheme,
      brightness: b,
      scaffoldBackgroundColor: v.bg,
      extensions: [v],
      splashFactory: InkSparkle.splashFactory,
    );

    return base.copyWith(
      textTheme: base.textTheme
          .apply(bodyColor: v.ink, displayColor: v.ink)
          .copyWith(
            displaySmall: display(34),
            headlineMedium: display(28),
            headlineSmall: display(24),
            titleLarge: display(21),
          ),
      appBarTheme: AppBarTheme(
        backgroundColor: Colors.transparent,
        elevation: 0,
        scrolledUnderElevation: 0,
        centerTitle: true,
        foregroundColor: v.ink,
        titleTextStyle: display(20),
      ),
      cardTheme: CardThemeData(
        color: v.surface,
        elevation: 0,
        margin: EdgeInsets.zero,
        shape: RoundedRectangleBorder(
          borderRadius: BorderRadius.circular(AppRadii.card),
        ),
      ),
      inputDecorationTheme: InputDecorationTheme(
        filled: true,
        fillColor: v.isDark ? AppColors.nightSurfaceHigh : Colors.white,
        contentPadding:
            const EdgeInsets.symmetric(horizontal: 22, vertical: 16),
        border: OutlineInputBorder(
          borderRadius: BorderRadius.circular(AppRadii.pill),
          borderSide: BorderSide.none,
        ),
        focusedBorder: OutlineInputBorder(
          borderRadius: BorderRadius.circular(AppRadii.pill),
          borderSide: const BorderSide(color: AppColors.coral, width: 2),
        ),
        hintStyle: TextStyle(color: v.inkSoft),
        labelStyle: TextStyle(color: v.inkSoft),
      ),
      segmentedButtonTheme: SegmentedButtonThemeData(
        style: ButtonStyle(
          shape: WidgetStateProperty.all(const StadiumBorder()),
          backgroundColor: WidgetStateProperty.resolveWith((s) =>
              s.contains(WidgetState.selected)
                  ? AppColors.coral.withValues(alpha: v.isDark ? 0.35 : 0.18)
                  : Colors.transparent),
          foregroundColor: WidgetStateProperty.all(v.ink),
          side: WidgetStateProperty.all(
              BorderSide(color: v.inkSoft.withValues(alpha: 0.3))),
        ),
      ),
      sliderTheme: SliderThemeData(
        activeTrackColor: AppColors.coral,
        inactiveTrackColor: AppColors.coral.withValues(alpha: 0.2),
        thumbColor: AppColors.peach,
        overlayColor: AppColors.coral.withValues(alpha: 0.12),
        trackHeight: 6,
      ),
      switchTheme: SwitchThemeData(
        trackColor: WidgetStateProperty.resolveWith((s) =>
            s.contains(WidgetState.selected) ? AppColors.mint : null),
        thumbColor: WidgetStateProperty.all(Colors.white),
      ),
      bottomSheetTheme: const BottomSheetThemeData(
        backgroundColor: Colors.transparent,
        elevation: 0,
      ),
      dialogTheme: DialogThemeData(
        backgroundColor: v.surface,
        shape: RoundedRectangleBorder(
            borderRadius: BorderRadius.circular(AppRadii.card)),
      ),
      snackBarTheme: SnackBarThemeData(
        behavior: SnackBarBehavior.floating,
        backgroundColor: v.isDark ? AppColors.nightSurfaceHigh : AppColors.inkLight,
        contentTextStyle: const TextStyle(color: Colors.white),
        shape: const StadiumBorder(),
      ),
      pageTransitionsTheme: const PageTransitionsTheme(builders: {
        TargetPlatform.android: _SpringUpTransitionsBuilder(),
        TargetPlatform.iOS: CupertinoPageTransitionsBuilder(),
      }),
    );
  }
}

/// 淡入 + 上移 24px 的弹簧页面过渡。
class _SpringUpTransitionsBuilder extends PageTransitionsBuilder {
  const _SpringUpTransitionsBuilder();
  @override
  Widget buildTransitions<T>(PageRoute<T> route, BuildContext context,
      Animation<double> animation, Animation<double> secondary, Widget child) {
    final curved = CurvedAnimation(
        parent: animation,
        curve: Curves.easeOutBack,
        reverseCurve: Curves.easeInCubic);
    return FadeTransition(
      opacity: CurvedAnimation(parent: animation, curve: Curves.easeOut),
      child: AnimatedBuilder(
        animation: curved,
        builder: (_, c) => Transform.translate(
            offset: Offset(0, 24 * (1 - curved.value)), child: c),
        child: child,
      ),
    );
  }
}
