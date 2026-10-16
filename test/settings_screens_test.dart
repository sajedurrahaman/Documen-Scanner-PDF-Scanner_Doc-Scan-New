import 'package:doc_scanner/core/local_storage.dart';
import 'package:doc_scanner/l10n/app_localizations.dart';
import 'package:doc_scanner/settings_page/settings_page.dart';
import 'package:doc_scanner/settings_page/language_select_screen.dart';
import 'package:doc_scanner/settings_page/about_app_screen.dart';
import 'package:doc_scanner/utils/app_constant.dart';
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:package_info_plus/package_info_plus.dart';
import 'package:shared_preferences/shared_preferences.dart';

void main() {
  setUp(() async {
    SharedPreferences.setMockInitialValues({});
    await LocalStorage().init();
    PackageInfo.setMockInitialValues(
        appName: 'Doc Scan',
        packageName: 'com.test',
        version: '2.0.8',
        buildNumber: '28',
        buildSignature: 'test');
  });

  Future<void> mount(WidgetTester tester, Widget screen,
      {Locale locale = const Locale('en'), double scale = 1}) async {
    await tester.binding.setSurfaceSize(const Size(393, 852));
    addTearDown(() => tester.binding.setSurfaceSize(null));
    await tester.pumpWidget(MaterialApp(
      locale: locale,
      localizationsDelegates: AppLocalizations.localizationsDelegates,
      supportedLocales: AppLocalizations.supportedLocales,
      builder: (context, child) => MediaQuery(
          data: MediaQuery.of(context)
              .copyWith(textScaler: TextScaler.linear(scale)),
          child: child!),
      home: screen,
    ));
    await tester.pumpAndSettle();
  }

  testWidgets('settings switches persist and new screens open', (tester) async {
    await mount(tester, const SettingsPage());
    await tester.tap(find.byType(Switch).first);
    await tester.pumpAndSettle();
    expect(LocalStorage().getBool(AppConstant.VIBRATION_KEY), isFalse);
    await tester.tap(find.byType(Switch).last);
    await tester.pumpAndSettle();
    expect(LocalStorage().getBool(AppConstant.BEEP_KEY), isFalse);
    await tester.tap(find.byKey(const ValueKey('settings-language')));
    await tester.pumpAndSettle();
    expect(find.byType(LanguageSelectScreen), findsOneWidget);
    await tester.pageBack();
    await tester.pumpAndSettle();
    await tester.scrollUntilVisible(find.text('About App'), 200);
    await tester.tap(find.text('About App'));
    await tester.pumpAndSettle();
    expect(find.byType(AboutAppScreen), findsOneWidget);
    expect(find.text('Version 2.0.8'), findsOneWidget);
    expect(find.text('Version 2.4.1'), findsNothing);
    expect(tester.takeException(), isNull);
  });

  testWidgets(
      'language applies immediately and persists while keeping all 12 choices reachable',
      (tester) async {
    final locale = ValueNotifier(const Locale('en'));
    addTearDown(locale.dispose);
    await tester.pumpWidget(ValueListenableBuilder<Locale>(
        valueListenable: locale,
        builder: (_, value, __) => MaterialApp(
              locale: value,
              localizationsDelegates: AppLocalizations.localizationsDelegates,
              supportedLocales: AppLocalizations.supportedLocales,
              home: LanguageSelectScreen(
                  onLocaleChanged: (value) => locale.value = value),
            )));
    await tester.pumpAndSettle();
    await tester.tap(find.byKey(const ValueKey('language-bn')));
    await tester.pump();
    expect(locale.value.languageCode, 'bn');
    await tester.pumpAndSettle();
    expect((await SharedPreferences.getInstance()).getString('languageCode'),
        'bn');
    expect(find.text('অ্যাপের ভাষা বেছে নিন'), findsOneWidget);
    await tester.scrollUntilVisible(
        find.byKey(const ValueKey('language-tr')), 300);
    await tester.tap(find.byKey(const ValueKey('language-tr')));
    await tester.pumpAndSettle();
    expect(locale.value.languageCode, 'tr');
    expect((await SharedPreferences.getInstance()).getString('languageCode'),
        'tr');
    expect(tester.takeException(), isNull);
  });

  for (final locale in ['en', 'bn', 'ar', 'fr']) {
    testWidgets('$locale settings and about tolerate larger text',
        (tester) async {
      await mount(tester, const SettingsPage(),
          locale: Locale(locale), scale: 1.4);
      expect(tester.takeException(), isNull);
      await mount(tester, const AboutAppScreen(),
          locale: Locale(locale), scale: 1.4);
      await tester.drag(find.byType(ListView), const Offset(0, -500));
      await tester.pumpAndSettle();
      expect(tester.takeException(), isNull);
    });
  }
}
