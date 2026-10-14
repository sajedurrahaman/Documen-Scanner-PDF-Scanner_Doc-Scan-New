import 'package:doc_scanner/core/local_storage.dart';
import 'package:doc_scanner/l10n/app_localizations.dart';
import 'package:doc_scanner/localaization/language.dart';
import 'package:doc_scanner/settings_page/settings_page.dart';
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:shared_preferences/shared_preferences.dart';

void main() {
  testWidgets('Settings uses active locale on its first frame after tab changes',
      (tester) async {
    SharedPreferences.setMockInitialValues({'languageCode': 'bn'});
    await LocalStorage().init();
    final settingsVisible = ValueNotifier(false);
    final locale = ValueNotifier(const Locale('bn'));
    addTearDown(settingsVisible.dispose);
    addTearDown(locale.dispose);
    await tester.pumpWidget(ValueListenableBuilder<Locale>(
      valueListenable: locale,
      builder: (_, value, __) => MaterialApp(
        locale: value,
        localizationsDelegates: AppLocalizations.localizationsDelegates,
        supportedLocales: AppLocalizations.supportedLocales,
        home: ValueListenableBuilder<bool>(
          valueListenable: settingsVisible,
          builder: (_, visible, __) =>
              visible ? const SettingsPage() : const Scaffold(body: Text('Home')),
        ),
      ),
    ));
    await tester.pumpAndSettle();

    for (var visit = 0; visit < 2; visit++) {
      settingsVisible.value = true;
      // Do not settle: the first frame must already show Bengali.
      await tester.pump();
      final dropdown = tester.widget<DropdownButton<Language>>(
        find.byType(DropdownButton<Language>),
      );
      expect(dropdown.value!.languageCode, 'bn');
      settingsVisible.value = false;
      await tester.pump();
    }

    // The active app locale is authoritative, even if storage still holds bn.
    locale.value = const Locale('fr');
    await tester.pumpAndSettle();
    settingsVisible.value = true;
    await tester.pump();
    expect(
      tester.widget<DropdownButton<Language>>(
        find.byType(DropdownButton<Language>),
      ).value!.languageCode,
      'fr',
    );
    expect(tester.takeException(), isNull);
    await tester.pumpWidget(const SizedBox());
  });
}
