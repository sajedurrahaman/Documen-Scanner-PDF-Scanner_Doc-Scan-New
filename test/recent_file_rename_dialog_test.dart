import 'package:doc_scanner/home_page/recent_file_rename_dialog.dart';
import 'package:doc_scanner/l10n/app_localizations.dart';
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';

void main() {
  for (final action in ['Cancel', 'Save', 'barrier']) {
    testWidgets('rename survives $action dismissal and reopening', (tester) async {
      await tester.pumpWidget(MaterialApp(
        localizationsDelegates: AppLocalizations.localizationsDelegates,
        supportedLocales: AppLocalizations.supportedLocales,
        locale: const Locale('en'),
        home: Builder(builder: (context) => Scaffold(
          body: TextButton(onPressed: () async {
            await showDialog<bool>(context: context, builder: (_) =>
                const RecentFileRenameDialog(filePath: '/files/document.pdf'));
            // Rebuild while the closing route and keyboard are still animating.
            (context as Element).markNeedsBuild();
          }, child: const Text('Open')),
        )),
      ));
      for (var i = 0; i < 2; i++) {
        await tester.tap(find.text('Open'));
        await tester.pumpAndSettle();
        if (action == 'barrier') {
          await tester.tapAt(const Offset(5, 5));
        } else {
          await tester.tap(find.text(action));
        }
        await tester.pump();
        await tester.pump(const Duration(milliseconds: 50));
        expect(tester.takeException(), isNull);
        await tester.pumpAndSettle();
        expect(find.byType(RecentFileRenameDialog), findsNothing);
        expect(tester.takeException(), isNull);
      }
    });
  }
}
