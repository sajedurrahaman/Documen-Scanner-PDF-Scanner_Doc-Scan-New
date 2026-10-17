import 'dart:io';
import 'dart:async';

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

class _PendingMerge extends HomePageProvider {
  final result = Completer<File?>();
  @override
  Future<File?> createPDFFromImages({
    required List<File> images,
    required String directoryPath,
    required BuildContext context,
    required String fileName,
  }) =>
      result.future;
}

Future<void> settleFiles(WidgetTester tester) async {
  // Directory reads run on the real filesystem, outside the fake test clock.
  for (var i = 0; i < 100; i++) {
    await tester
        .runAsync(() => Future<void>.delayed(const Duration(milliseconds: 20)));
    await tester.pump();
    if (i >= 10 && find.byType(CircularProgressIndicator).evaluate().isEmpty) {
      break;
    }
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
    await tester.tap(find.byTooltip('Search'));
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
    await tester.tap(find.byTooltip('Create folder'));
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

  testWidgets(
      'create folder checks current category and reports invalid or duplicate names',
      (tester) async {
    await tester.runAsync(() =>
        Directory('${root.path}/Doc Scanner/ID Card/Only there').create());
    await mount(tester, 'Document');
    await tester.tap(find.byTooltip('Create folder'));
    await tester.pumpAndSettle();
    await tester.enterText(find.byType(TextField), '../outside');
    await tester.tap(find.text('Create Folder'));
    await tester.pumpAndSettle();
    expect(find.text('Please enter a directory name'), findsOneWidget);
    await tester.enterText(find.byType(TextField), 'work report');
    await tester.runAsync(() async {
      await tester.tap(find.text('Create Folder'));
      await Future<void>.delayed(const Duration(milliseconds: 100));
    });
    await tester.pumpAndSettle();
    expect(find.text('Already exists in the destination directory'),
        findsOneWidget);
    await tester.enterText(find.byType(TextField), '  Only there  ');
    await tester.runAsync(() async {
      await tester.tap(find.text('Create Folder'));
      await Future<void>.delayed(const Duration(milliseconds: 100));
    });
    await settleFiles(tester);
    expect(find.text('Only there'), findsOneWidget);
    expect(find.byType(AlertDialog), findsNothing);
    expect(tester.takeException(), isNull);
    await tester.pumpWidget(const SizedBox());
  });

  testWidgets(
      'Document and QR Code can both create shahjalal through the dialog',
      (tester) async {
    for (final category in ['Document', 'QR Code']) {
      await mount(tester, category);
      await tester.tap(find.byTooltip('Create folder'));
      await tester.pumpAndSettle();
      await tester.enterText(find.byType(TextField), 'shahjalal');
      await tester.runAsync(() async {
        await tester.tap(find.text('Create Folder'));
        await Future<void>.delayed(const Duration(milliseconds: 100));
      });
      await settleFiles(tester);
      expect(find.byType(AlertDialog), findsNothing);
      expect(find.text('shahjalal'), findsOneWidget);
      await tester.runAsync(() async {
        expect(
            await Directory('${root.path}/Doc Scanner/$category/shahjalal')
                .exists(),
            isTrue);
      });
      expect(tester.takeException(), isNull);
      await tester.pumpWidget(const SizedBox());
      await tester.pumpAndSettle();
    }
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

  testWidgets('actions follow selection types and two PDFs enable Merge',
      (tester) async {
    await tester.runAsync(() async {
      await File('${root.path}/Doc Scanner/Document/Second.pdf')
          .writeAsString('sample');
      await File('${root.path}/Doc Scanner/Document/Image.jpg')
          .writeAsString('sample');
    });
    await mount(tester, 'Document');
    bool enabled(String label) =>
        tester
            .widget<GestureDetector>(find
                .ancestor(
                    of: find.text(label),
                    matching: find.byType(GestureDetector))
                .first)
            .onTap !=
        null;
    await tester.longPress(find.text('Notes.pdf'));
    await tester.pumpAndSettle();
    expect(enabled('Merge'), isFalse);
    expect(enabled('Share'), isTrue);
    expect(enabled('Move'), isTrue);
    await tester.tap(find.text('Second.pdf'));
    await tester.pumpAndSettle();
    expect(enabled('Merge'), isTrue);
    await tester.tap(find.text('Merge'));
    await tester.pumpAndSettle();
    expect(find.byType(AlertDialog), findsOneWidget);
    await tester.tap(find.widgetWithText(TextButton, 'Cancel'));
    await tester.pumpAndSettle();
    await tester.tap(find.text('Image.jpg'));
    await tester.pumpAndSettle();
    expect(enabled('Merge'), isFalse);
    await tester.tap(find.text('Work Report'));
    await tester.pumpAndSettle();
    expect(enabled('Merge'), isFalse);
    expect(enabled('Share'), isFalse);
    expect(enabled('Move'), isFalse);
    expect(enabled('Delete'), isTrue);
    await tester.tap(find.text('Deselect All'));
    await tester.pumpAndSettle();
    expect(enabled('Delete'), isFalse);
    expect(tester.takeException(), isNull);
    await tester.pumpWidget(const SizedBox());
  });

  testWidgets(
      'merge naming matches rename and loading blocks header taps and Back',
      (tester) async {
    provider.dispose();
    final pending = _PendingMerge();
    provider = pending;
    late File output;
    await tester.runAsync(() async {
      await File('${root.path}/Doc Scanner/Document/First.jpg')
          .writeAsString('sample');
      await File('${root.path}/Doc Scanner/Document/Second.jpg')
          .writeAsString('sample');
      output = File('${root.path}/Doc Scanner/Document/Combined.pdf');
    });
    await mount(tester, 'Document');
    await tester.longPress(find.text('First.jpg'));
    await tester.pumpAndSettle();
    await tester.tap(find.text('Second.jpg'));
    await tester.pumpAndSettle();
    await tester.tap(find.text('Merge'));
    await tester.pumpAndSettle();
    expect(find.text('Rename File'), findsOneWidget);
    expect(tester.widget<TextField>(find.byType(TextField)).decoration!.border,
        isA<OutlineInputBorder>());
    await tester.enterText(find.byType(TextFormField), 'Combined');
    await tester.tap(find.widgetWithText(TextButton, 'Ok'));
    await tester.pump();
    await tester.pump(const Duration(milliseconds: 300));
    expect(find.byType(CircularProgressIndicator), findsOneWidget);
    expect(
        find.byWidgetPredicate(
            (w) => w is AbsorbPointer && w.absorbing && w.child is Scaffold),
        findsOneWidget);
    await tester.tap(find.byIcon(Icons.close), warnIfMissed: false);
    await tester.pump();
    expect(find.text('2 Selected'), findsOneWidget);
    await tester.binding.handlePopRoute();
    await tester.pump();
    expect(find.byType(DirectoryDetailsPage), findsOneWidget);
    expect(find.text('2 Selected'), findsOneWidget);
    await tester.runAsync(() async {
      await output.writeAsString('sample output');
      pending.result.complete(output);
    });
    await settleFiles(tester);
    expect(find.text('Combined.pdf'), findsOneWidget);
    expect(find.byType(CircularProgressIndicator), findsNothing);
    await tester.tap(find.byTooltip('Search'));
    await tester.pumpAndSettle();
    expect(find.byType(TextField), findsOneWidget);
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
