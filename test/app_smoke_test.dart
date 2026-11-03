import 'package:couple_locator/app/app.dart';
import 'package:couple_locator/core/theme/app_theme.dart';
import 'package:couple_locator/core/theme/tokens.dart';
import 'package:couple_locator/core/widgets/vibe_widgets.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:shared_preferences/shared_preferences.dart';

void main() {
  setUp(() => SharedPreferences.setMockInitialValues({}));

  testWidgets('未配置后端时显示配置提示页（同时编译整个应用的依赖图）', (t) async {
    await t.pumpWidget(const ProviderScope(child: CoupleApp()));
    await t.pump(const Duration(milliseconds: 300));
    expect(find.text('还没有配置后端'), findsOneWidget);
  });

  for (final dark in [false, true]) {
    testWidgets('通用组件在${dark ? '深色' : '浅色'}主题下可渲染', (t) async {
      await t.pumpWidget(MaterialApp(
        theme: dark ? AppTheme.dark() : AppTheme.light(),
        home: Scaffold(
          body: ListView(children: [
            GradientButton(label: '我到了', onTap: () {}),
            const SoftButton(label: '次要'),
            const GlassPanel(child: Text('毛玻璃')),
            AvatarBubble(palette: PersonalPalette.all[3], emoji: '🐱'),
            const CuteEmpty(title: '空状态'),
            const RollingNumber(value: 12.3, decimals: 1, suffix: ' km'),
          ]),
        ),
      ));
      await t.pump(const Duration(milliseconds: 700));
      expect(find.text('我到了'), findsOneWidget);
      expect(find.text('12.3 km'), findsOneWidget);
    });
  }
}
