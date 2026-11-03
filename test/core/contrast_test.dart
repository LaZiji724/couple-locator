import 'dart:math' as math;

import 'package:couple_locator/core/theme/tokens.dart';
import 'package:flutter/painting.dart';
import 'package:flutter_test/flutter_test.dart';

double lum(Color c) {
  double f(double v) => v <= 0.03928 ? v / 12.92 : math.pow((v + 0.055) / 1.055, 2.4).toDouble();
  return 0.2126 * f(c.r) + 0.7152 * f(c.g) + 0.0722 * f(c.b);
}

double ratio(Color a, Color b) {
  final l1 = lum(a), l2 = lum(b);
  return (math.max(l1, l2) + 0.05) / (math.min(l1, l2) + 0.05);
}

void main() {
  test('文字对比度 ≥ WCAG AA (4.5)', () {
    expect(ratio(AppColors.inkLight, AppColors.creamBg), greaterThanOrEqualTo(4.5));
    expect(ratio(AppColors.inkSoftLight, AppColors.creamBg), greaterThanOrEqualTo(4.5));
    expect(ratio(AppColors.accentTextLight, AppColors.creamBg), greaterThanOrEqualTo(4.5));
    expect(ratio(AppColors.inkDark, AppColors.nightBg), greaterThanOrEqualTo(4.5));
    expect(ratio(AppColors.inkSoftDark, AppColors.nightBg), greaterThanOrEqualTo(4.5));
    expect(ratio(AppColors.accentTextDark, AppColors.nightBg), greaterThanOrEqualTo(4.5));
    expect(ratio(AppColors.inkSoftDark, AppColors.nightSurface), greaterThanOrEqualTo(4.5));
    for (final c in [AppColors.coral, AppColors.peach, AppColors.sun]) {
      expect(ratio(AppColors.onGradient, c), greaterThanOrEqualTo(4.5), reason: '$c');
    }
  });
}
