import 'package:doc_scanner/home_page/provider/recent_files_provider.dart';
import 'package:doc_scanner/home_page/recent_file_see_all_screen.dart';
import 'package:doc_scanner/l10n/app_localizations.dart';
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:provider/provider.dart';

class _Files extends RecentFilesProvider {
  @override
  bool get loading => false;
  @override
  List<RecentFile> get files => [
        for (final kind in RecentKind.values)
          RecentFile(
              path: '/files/${kind.name}.pdf',
              kind: kind,
              modified: DateTime(2026),
              size: 1024),
        for (var i = 0; i < 15; i++)
          RecentFile(
              path: '/files/Document_$i.jpg',
              kind: RecentKind.document,
              modified: DateTime(2026),
              size: 2048),
      ];
}

void main() {
  testWidgets(
      'filters and search combine, actions work, and all files are reachable',
      (tester) async {
    await tester.binding.setSurfaceSize(const Size(393, 852));
    addTearDown(() => tester.binding.setSurfaceSize(null));
    final provider = _Files();
    addTearDown(provider.dispose);
    String? opened;
    String? shared;
    Future<void> noop(RecentFile _) async {}
    await tester.pumpWidget(ChangeNotifierProvider<RecentFilesProvider>.value(
      value: provider,
      child: MaterialApp(
        localizationsDelegates: AppLocalizations.localizationsDelegates,
        supportedLocales: AppLocalizations.supportedLocales,
        home: RecentFileSeeAllScreen(
          onOpen: (file) async => opened = file.path,
          onRename: noop,
          onDownload: noop,
          onShare: (file) async => shared = file.path,
          onDelete: noop,
          onRefresh: () async {},
          timeAgo: (_) => '2 hours ago',
          sizeLabel: (_) => '1 KB',
        ),
      ),
    ));
    await tester.pumpAndSettle();
    await tester.tap(find.text('ID Card'));
    await tester.pumpAndSettle();
    expect(find.text('idCard.pdf'), findsOneWidget);
    expect(find.text('document.pdf'), findsNothing);
    await tester.tap(find.text('idCard.pdf'));
    expect(opened, '/files/idCard.pdf');
    await tester.tap(find.byIcon(Icons.more_vert));
    await tester.pumpAndSettle();
    await tester.tap(find.text('Share'));
    await tester.pumpAndSettle();
    expect(shared, '/files/idCard.pdf');
    await tester.tap(find.byTooltip('Search'));
    await tester.pumpAndSettle();
    await tester.enterText(find.byType(TextField), 'DOCUMENT');
    await tester.pumpAndSettle();
    expect(find.text('No Result Found'), findsOneWidget);
    await tester.tap(find.text('All'));
    await tester.pumpAndSettle();
    expect(find.text('document.pdf'), findsOneWidget);
    await tester.tap(find.byIcon(Icons.close));
    await tester.pumpAndSettle();
    await tester.scrollUntilVisible(find.text('Document_14.jpg'), 300,
        scrollable: find.byType(Scrollable).last);
    expect(find.text('Document_14.jpg'), findsOneWidget);
    expect(tester.takeException(), isNull);
  });
}
