import 'dart:io';

import 'package:doc_scanner/home_page/directory_view.dart';
import 'package:doc_scanner/home_page/provider/home_page_provider.dart';
import 'package:doc_scanner/l10n/app_localizations.dart';
import 'package:flutter/material.dart';
import 'package:google_mobile_ads/google_mobile_ads.dart';
// ignore: implementation_imports
import 'package:google_mobile_ads/src/ad_instance_manager.dart';
import 'package:flutter_test/flutter_test.dart';
// ignore: depend_on_referenced_packages
import 'package:path_provider_platform_interface/path_provider_platform_interface.dart';
import 'package:provider/provider.dart';

class _Paths extends PathProviderPlatform {
  _Paths(this.root);
  final String root;
  @override
  Future<String?> getApplicationDocumentsPath() async => root;
}

Future<void> settleFiles(WidgetTester tester) async {
  // Directory reads run on the real filesystem, outside the fake test clock.
  for (var i = 0; i < 100; i++) {
    await tester
        .runAsync(() => Future<void>.delayed(const Duration(milliseconds: 20)));
    await tester.pump();
    if (i >= 10 && find.byType(CircularProgressIndicator).evaluate().isEmpty) break;
  }
  await tester.pumpAndSettle();
}

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();
  final messenger =
      TestDefaultBinaryMessengerBinding.instance.defaultBinaryMessenger;
  messenger.setMockMethodCallHandler(instanceManager.channel, (call) async {
    if (call.method == 'MobileAds#initialize') return InitializationStatus({});
    return null;
  });
  late Directory root;
  late HomePageProvider provider;
  late PathProviderPlatform originalPaths;

  setUp(() async {
    root = await Directory.systemTemp.createTemp('directory_ui_test');
    originalPaths = PathProviderPlatform.instance;
    PathProviderPlatform.instance = _Paths(root.path);
    provider = HomePageProvider();
    for (final category in ['Document', 'ID Card', 'QR Code', 'Bar Code']) {
      final folder =
          await Directory('${root.path}/Doc Scanner/$category/Work Report')
              .create(recursive: true);
      await File('${folder.path}/Nested.pdf').writeAsString('sample');
      final extension = category.contains('Code') ? 'txt' : 'pdf';
      await File('${folder.parent.path}/Notes.$extension')
          .writeAsString('sample');
    }
  });
  tearDown(() async {
    provider.dispose();
    PathProviderPlatform.instance = originalPaths;
    await root.delete(recursive: true);
  });

  Future<void> mount(WidgetTester tester, String category) async {
    await tester.binding.setSurfaceSize(const Size(393, 852));
    addTearDown(() => tester.binding.setSurfaceSize(null));
    await tester.pumpWidget(ChangeNotifierProvider.value(
      value: provider,
      child: MaterialApp(
        builder: (context, child) => MediaQuery(
          data: MediaQuery.of(context).copyWith(
            padding: const EdgeInsets.only(bottom: 34),
            viewPadding: const EdgeInsets.only(bottom: 34),
          ),
          child: child!,
        ),
        localizationsDelegates: AppLocalizations.localizationsDelegates,
        supportedLocales: AppLocalizations.supportedLocales,
        home: DirectoryDetailsPage(
            directoryPath: '${root.path}/Doc Scanner/$category'),
      ),
    ));
    await settleFiles(tester);
  }

  testWidgets(
      'folder navigation, search and bulk selection retain their behavior',
      (tester) async {
    await mount(tester, 'Document');
    expect(find.text('Notes.pdf'), findsOneWidget);
    expect(find.text('1 Item'), findsOneWidget);
    expect(tester.getTopLeft(find.text('Work Report')).dy,
        lessThan(tester.getTopLeft(find.text('Notes.pdf')).dy));
    await tester.tap(find.text('Work Report'));
    await settleFiles(tester);
    expect(find.text('Nested.pdf'), findsOneWidget);
    await tester.tap(find.byIcon(Icons.arrow_back).last);
    await settleFiles(tester);
    expect(find.text('Document'), findsOneWidget);
    await tester.tap(find.byIcon(Icons.search));
    await tester.pumpAndSettle();
    await tester.enterText(find.byType(TextField), 'notes');
    await tester.pumpAndSettle();
    expect(find.text('Work Report'), findsNothing);
    expect(find.text('Notes.pdf'), findsOneWidget);
    await tester.tap(find.byIcon(Icons.close));
    await tester.pumpAndSettle();
    await tester.longPress(find.text('Notes.pdf'));
    await tester.pumpAndSettle();
    expect(find.text('1 Selected'), findsOneWidget);
    await tester.tap(find.text('Select All'));
    await tester.pumpAndSettle();
    expect(find.text('2 Selected'), findsOneWidget);
    expect(
        tester
            .widgetList<Checkbox>(find.byType(Checkbox))
            .every((checkbox) => checkbox.value == true),
        isTrue);
    await tester.tap(find.text('Deselect All'));
    await tester.pumpAndSettle();
    expect(
        tester
            .widgetList<Checkbox>(find.byType(Checkbox))
            .every((checkbox) => checkbox.value == false),
        isTrue);
    await tester.tap(find.byIcon(Icons.close));
    await tester.pumpAndSettle();
    expect(find.byType(Checkbox), findsNothing);
    await tester.tap(find.byIcon(Icons.create_new_folder_outlined));
    await tester.pumpAndSettle();
    await tester.enterText(find.byType(TextField), 'New folder');
    await tester.pumpAndSettle();
    await tester.runAsync(() async {
      await tester.tap(find.text('Create Folder'));
      await Future<void>.delayed(const Duration(milliseconds: 300));
    });
    await settleFiles(tester);
    expect(find.text('New folder'), findsOneWidget);
    expect(find.text('Document'), findsOneWidget);
    expect(find.byType(AlertDialog), findsNothing);
    expect(tester.takeException(), isNull);
    await tester.pumpWidget(const SizedBox());
  });

  testWidgets('folder rename stays above the system navigation area',
      (tester) async {
    await mount(tester, 'Document');
    await tester.tap(find.byIcon(Icons.more_vert).first);
    await tester.pumpAndSettle();
    final rename = find.text('Rename Folder');
    expect(rename.hitTestable(), findsOneWidget);
    expect(tester.getBottomRight(rename).dy, lessThan(852 - 34));
    await tester.tap(rename);
    await tester.pumpAndSettle();
    expect(find.byType(AlertDialog), findsOneWidget);
    expect(tester.takeException(), isNull);
    await tester.pumpWidget(const SizedBox());
  });

  for (final folder in [true, false]) {
    testWidgets(
        '${folder ? 'Folder' : 'File'} menu deletion confirms and refreshes the list',
        (tester) async {
      await mount(tester, 'Document');
      final name = folder ? 'Work Report' : 'Notes.pdf';
      Future<void> openDelete() async {
        final menus = find.byIcon(Icons.more_vert);
        await tester.tap(folder ? menus.first : menus.last);
        await tester.pumpAndSettle();
        await tester.tap(find.text('Delete'));
        await tester.pumpAndSettle();
      }

      await openDelete();
      await tester.tap(find.text('Cancel'));
      await tester.pumpAndSettle();
      expect(find.text(name), findsOneWidget);
      expect(
          await tester.runAsync(() =>
              FileSystemEntity.type('${root.path}/Doc Scanner/Document/$name')),
          isNot(FileSystemEntityType.notFound));
      await openDelete();
      await tester.runAsync(() async {
        await tester.tap(find.widgetWithText(TextButton, 'Delete'));
        await Future<void>.delayed(const Duration(milliseconds: 300));
      });
      await settleFiles(tester);
      expect(find.text(name), findsNothing);
      expect(
          await tester.runAsync(() =>
              FileSystemEntity.type('${root.path}/Doc Scanner/Document/$name')),
          FileSystemEntityType.notFound);
      expect(tester.takeException(), isNull);
      await tester.pumpWidget(const SizedBox());
    });
  }

  for (final category in ['ID Card', 'QR Code', 'Bar Code']) {
    testWidgets('$category renders files and opens the existing action menu',
        (tester) async {
      await mount(tester, category);
      expect(find.text(category), findsOneWidget);
      expect(find.text(category.contains('Code') ? 'Notes.txt' : 'Notes.pdf'),
          findsOneWidget);
      await tester.tap(find.byIcon(Icons.more_vert).last);
      await tester.pumpAndSettle();
      expect(find.byType(BottomSheet), findsOneWidget);
      expect(tester.takeException(), isNull);
      await tester.pumpWidget(const SizedBox());
    });
  }
}
