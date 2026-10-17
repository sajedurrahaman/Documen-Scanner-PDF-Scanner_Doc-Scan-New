import 'dart:async';
import 'dart:io';
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

class _LocalFiles extends RecentFilesProvider {
  _LocalFiles(this.items);
  List<RecentFile> items;
  @override
  bool get loading => false;
  @override
  List<RecentFile> get files => items;
  Future<void> refresh() async {
    final remaining = <RecentFile>[];
    for (final file in items) {
      if (await File(file.path).exists()) remaining.add(file);
    }
    items = remaining;
    notifyListeners();
  }
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
    await tester.longPress(find.text('document.pdf'));
    await tester.pumpAndSettle();
    expect(find.text('1 Selected'), findsOneWidget);
    expect(find.byIcon(Icons.more_vert), findsNothing);
    final mergeButton = find.widgetWithText(TextButton, 'Merge');
    expect(find.text('Move'), findsOneWidget);
    expect(find.text('Share'), findsOneWidget);
    expect(find.text('Delete'), findsOneWidget);
    expect(tester.widget<TextButton>(mergeButton).onPressed, isNull);
    await tester.tap(find.text('idCard.pdf'));
    await tester.pumpAndSettle();
    expect(find.text('2 Selected'), findsOneWidget);
    expect(tester.widget<TextButton>(mergeButton).onPressed, isNotNull);
    expect(
        tester
            .widget<TextButton>(find.widgetWithText(TextButton, 'Move'))
            .onPressed,
        isNull);
    await tester.tap(find.text('Delete'));
    await tester.pumpAndSettle();
    expect(find.byType(AlertDialog), findsOneWidget);
    await tester.tap(find.text('Cancel'));
    await tester.pumpAndSettle();
    expect(find.text('2 Selected'), findsOneWidget);
    expect(opened, isNull);
    await tester.tap(find.text('Select All'));
    await tester.pumpAndSettle();
    expect(find.text('19 Selected'), findsOneWidget);
    expect(tester.widget<TextButton>(mergeButton).onPressed, isNull);
    await tester.tap(find.text('ID Card'));
    await tester.pumpAndSettle();
    expect(find.text('1 Selected'), findsOneWidget);
    await tester.tap(find.text('Deselect All'));
    await tester.pumpAndSettle();
    expect(tester.widget<Checkbox>(find.byType(Checkbox)).value, isFalse);
    await tester.binding.handlePopRoute();
    await tester.pumpAndSettle();
    expect(find.byType(Checkbox), findsNothing);
    expect(find.byIcon(Icons.more_vert), findsOneWidget);
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
  testWidgets(
      'selected share blocks interactions and bulk delete refreshes real files',
      (tester) async {
    final root = (await tester
        .runAsync(() => Directory.systemTemp.createTemp('recent_ui')))!;
    addTearDown(() => root.delete(recursive: true));
    await tester.runAsync(() async {
      await File('${root.path}/one.pdf').writeAsString('one');
      await File('${root.path}/two.pdf').writeAsString('two');
    });
    final provider = _LocalFiles([
      for (final name in ['one', 'two'])
        RecentFile(
            path: '${root.path}/$name.pdf',
            kind: RecentKind.document,
            modified: DateTime(2026),
            size: 3)
    ]);
    addTearDown(provider.dispose);
    Future<void> settleOperations() async {
      for (var i = 0; i < 50; i++) {
        await tester.pump();
        await tester.runAsync(
            () => Future<void>.delayed(const Duration(milliseconds: 20)));
        if (find.byType(CircularProgressIndicator).evaluate().isEmpty) break;
      }
      await tester.pumpAndSettle();
    }

    final shared = Completer<void>();
    Future<void> noop(RecentFile _) async {}
    await tester.pumpWidget(ChangeNotifierProvider<RecentFilesProvider>.value(
      value: provider,
      child: MaterialApp(
          localizationsDelegates: AppLocalizations.localizationsDelegates,
          supportedLocales: AppLocalizations.supportedLocales,
          home: RecentFileSeeAllScreen(
              onOpen: noop,
              onRename: noop,
              onDownload: noop,
              onShare: (_) => shared.future,
              onDelete: noop,
              onRefresh: provider.refresh,
              timeAgo: (_) => 'today',
              sizeLabel: (_) => '3 B')),
    ));
    await tester.pumpAndSettle();
    await tester.longPress(find.text('one.pdf'));
    await tester.pumpAndSettle();
    await tester.tap(find.text('Share'));
    await tester.pump();
    expect(find.byType(CircularProgressIndicator), findsOneWidget);
    await tester.binding.handlePopRoute();
    await tester.pump();
    expect(find.text('1 Selected'), findsOneWidget);
    await tester.runAsync(() async {
      shared.complete();
      await Future<void>.delayed(const Duration(milliseconds: 100));
    });
    await settleOperations();
    expect(find.byType(Checkbox), findsNothing);
    await tester.longPress(find.text('one.pdf'));
    await tester.pumpAndSettle();
    await tester.tap(find.text('two.pdf'));
    await tester.pumpAndSettle();
    await tester.tap(find.text('Delete'));
    await tester.pumpAndSettle();
    await tester.runAsync(() async {
      await tester.tap(find.descendant(
          of: find.byType(AlertDialog),
          matching: find.widgetWithText(TextButton, 'Delete')));
      await Future<void>.delayed(const Duration(milliseconds: 100));
    });
    await settleOperations();
    expect(provider.files, isEmpty);
    expect(find.byType(Checkbox), findsNothing);
    expect(find.text('one.pdf'), findsNothing);
    expect(find.text('two.pdf'), findsNothing);
    expect(tester.takeException(), isNull);
  });
}
