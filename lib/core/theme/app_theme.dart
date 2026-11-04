import 'package:flutter/cupertino.dart' show CupertinoPageTransitionsBuilder;
import 'package:flutter/material.dart';

import 'tokens.dart';

/// 业务专用的主题扩展：表面层级、毛玻璃、语义色。
@immutable
class Vibes extends ThemeExtension<Vibes> {
  const Vibes({
    required this.bg,
    required this.surface,
    required this.surfaceHigh,
    required this.glass,
    required this.glassBorder,
    required this.hairline,
    required this.ink,
    required this.inkSoft,
    required this.accentText,
    required this.danger,
    required this.isDark,
  });

  final Color bg;
  final Color surface;
  final Color surfaceHigh;
  final Color glass;
  final Color glassBorder;
  final Color hairline;
  final Color ink;
  final Color inkSoft;
  final Color accentText;
  final Color danger;
  final bool isDark;

  static const light = Vibes(
    bg: AppColors.creamBg,
    surface: Color(0xFFFFFDFA),
    surfaceHigh: AppColors.surfaceHighLight,
    glass: Color(0xD6FFFDFA),
    glassBorder: AppColors.hairlineLight,
    hairline: AppColors.hairlineLight,
    ink: AppColors.inkLight,
    inkSoft: AppColors.inkSoftLight,
    accentText: AppColors.accentTextLight,
    danger: AppColors.dangerLight,
    isDark: false,
  );

  static const dark = Vibes(
    bg: AppColors.nightBg,
    surface: AppColors.nightSurface,
    surfaceHigh: AppColors.nightSurfaceHigh,
    glass: Color(0xD6221E1C),
    glassBorder: AppColors.hairlineDark,
    hairline: AppColors.hairlineDark,
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
      surfaceHigh: Color.lerp(surfaceHigh, other.surfaceHigh, t)!,
      glass: Color.lerp(glass, other.glass, t)!,
      glassBorder: Color.lerp(glassBorder, other.glassBorder, t)!,
      hairline: Color.lerp(hairline, other.hairline, t)!,
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
  static ThemeData light() => _build(Vibes.light, Brightness.light);
  static ThemeData dark() => _build(Vibes.dark, Brightness.dark);

  static ThemeData _build(Vibes v, Brightness b) {
    final scheme = ColorScheme(
      brightness: b,
      primary: AppColors.accent,
      onPrimary: AppColors.onAccent,
      secondary: v.inkSoft,
      onSecondary: v.bg,
      tertiary: AppColors.mint,
      onTertiary: Colors.white,
      error: v.danger,
      onError: Colors.white,
      surface: v.surface,
      onSurface: v.ink,
      onSurfaceVariant: v.inkSoft,
      surfaceContainerHighest: v.surfaceHigh,
      outline: v.hairline,
      outlineVariant: v.hairline,
    );

    // 字号只用 4 档：展示 28 / 标题 20 / 正文 15 / 说明 12。
    TextStyle t(double size, FontWeight w, {double height = 1.35}) =>
        TextStyle(fontSize: size, fontWeight: w, color: v.ink, height: height);

    final base = ThemeData(
      useMaterial3: true,
      colorScheme: scheme,
      brightness: b,
      scaffoldBackgroundColor: v.bg,
      extensions: [v],
      splashFactory: InkRipple.splashFactory,
      dividerColor: v.hairline,
    );

    return base.copyWith(
      textTheme: base.textTheme
          .apply(bodyColor: v.ink, displayColor: v.ink)
          .copyWith(
            displaySmall: t(28, FontWeight.w700, height: 1.2),
            headlineMedium: t(28, FontWeight.w700, height: 1.2),
            headlineSmall: t(20, FontWeight.w700, height: 1.25),
            titleLarge: t(20, FontWeight.w700, height: 1.25),
            titleMedium: t(15, FontWeight.w600),
            titleSmall: t(15, FontWeight.w600),
            bodyLarge: t(15, FontWeight.w400, height: 1.5),
            bodyMedium: t(15, FontWeight.w400, height: 1.5),
            bodySmall: t(12, FontWeight.w400),
            labelLarge: t(15, FontWeight.w600),
            labelMedium: t(12, FontWeight.w500),
            labelSmall: t(12, FontWeight.w500),
          ),
      appBarTheme: AppBarTheme(
        backgroundColor: Colors.transparent,
        elevation: 0,
        scrolledUnderElevation: 0,
        centerTitle: true,
        foregroundColor: v.ink,
        titleTextStyle: t(17, FontWeight.w700),
      ),
      cardTheme: CardThemeData(
        color: v.surface,
        elevation: 0,
        margin: EdgeInsets.zero,
        shape: RoundedRectangleBorder(
          borderRadius: BorderRadius.circular(AppRadii.card),
          side: BorderSide(color: v.hairline, width: 0.5),
        ),
      ),
      inputDecorationTheme: InputDecorationTheme(
        filled: true,
        fillColor: v.surfaceHigh,
        contentPadding:
            const EdgeInsets.symmetric(horizontal: 16, vertical: 16),
        border: OutlineInputBorder(
          borderRadius: BorderRadius.circular(AppRadii.small),
          borderSide: BorderSide.none,
        ),
        enabledBorder: OutlineInputBorder(
          borderRadius: BorderRadius.circular(AppRadii.small),
          borderSide: BorderSide(color: v.hairline, width: 0.5),
        ),
        focusedBorder: OutlineInputBorder(
          borderRadius: BorderRadius.circular(AppRadii.small),
          borderSide: const BorderSide(color: AppColors.accent, width: 1.5),
        ),
        hintStyle: TextStyle(color: v.inkSoft),
        labelStyle: TextStyle(color: v.inkSoft),
      ),
      segmentedButtonTheme: SegmentedButtonThemeData(
        style: ButtonStyle(
          shape: WidgetStateProperty.all(const StadiumBorder()),
          backgroundColor: WidgetStateProperty.resolveWith((s) =>
              s.contains(WidgetState.selected)
                  ? AppColors.accent.withValues(alpha: v.isDark ? 0.28 : 0.12)
                  : Colors.transparent),
          foregroundColor: WidgetStateProperty.resolveWith((s) =>
              s.contains(WidgetState.selected) ? v.accentText : v.ink),
          side: WidgetStateProperty.all(BorderSide(color: v.hairline, width: 0.5)),
        ),
      ),
      sliderTheme: SliderThemeData(
        activeTrackColor: AppColors.accent,
        inactiveTrackColor: AppColors.accent.withValues(alpha: 0.18),
        thumbColor: AppColors.accent,
        overlayColor: AppColors.accent.withValues(alpha: 0.12),
        trackHeight: 4,
      ),
      switchTheme: SwitchThemeData(
        trackColor: WidgetStateProperty.resolveWith((s) =>
            s.contains(WidgetState.selected) ? AppColors.accent : v.surfaceHigh),
        trackOutlineColor: WidgetStateProperty.resolveWith((s) =>
            s.contains(WidgetState.selected) ? Colors.transparent : v.hairline),
        thumbColor: WidgetStateProperty.resolveWith((s) =>
            s.contains(WidgetState.selected) ? Colors.white : v.inkSoft),
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
        shape: RoundedRectangleBorder(
            borderRadius: BorderRadius.circular(AppRadii.small)),
      ),
      pageTransitionsTheme: const PageTransitionsTheme(builders: {
        TargetPlatform.android: _SlideUpTransitionsBuilder(),
        TargetPlatform.iOS: CupertinoPageTransitionsBuilder(),
      }),
    );
  }
}

/// 淡入 + 上移 16px，ease-out 250ms。
class _SlideUpTransitionsBuilder extends PageTransitionsBuilder {
  const _SlideUpTransitionsBuilder();
  @override
  Widget buildTransitions<T>(PageRoute<T> route, BuildContext context,
      Animation<double> animation, Animation<double> secondary, Widget child) {
    final curved = CurvedAnimation(
        parent: animation,
        curve: Curves.easeOutCubic,
        reverseCurve: Curves.easeInCubic);
    return FadeTransition(
      opacity: curved,
      child: AnimatedBuilder(
        animation: curved,
        builder: (_, c) => Transform.translate(
            offset: Offset(0, 16 * (1 - curved.value)), child: c),
        child: child,
      ),
    );
  }
}
