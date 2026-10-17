import 'dart:convert';
import 'dart:typed_data';
import 'package:doc_scanner/camera_screen/model/image_model.dart';
import 'package:doc_scanner/camera_screen/provider/camera_provider.dart';
import 'package:doc_scanner/image_edit/image_edit_screen.dart';
import 'package:doc_scanner/image_edit/image_size_screen.dart';
import 'package:doc_scanner/image_edit/image_rotation.dart';
import 'package:doc_scanner/image_edit/crop_screen.dart';
import 'package:doc_scanner/image_edit/widget/image_filter_screen.dart';
import 'package:doc_scanner/image_edit/widget/image_edit_unavailable.dart';
import 'package:doc_scanner/image_edit/provider/image_edit_provider.dart';
import 'package:doc_scanner/l10n/app_localizations.dart';
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:google_mobile_ads/google_mobile_ads.dart';
// ignore: implementation_imports
import 'package:google_mobile_ads/src/ad_instance_manager.dart';
import 'package:provider/provider.dart';

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();
  TestDefaultBinaryMessengerBinding.instance.defaultBinaryMessenger
      .setMockMethodCallHandler(instanceManager.channel, (call) async {
    if (call.method == 'MobileAds#initialize') return InitializationStatus({});
    return null;
  });
  final png = base64Decode(
      'iVBORw0KGgoAAAANSUhEUgAAAAEAAAABCAYAAAAfFcSJAAAAC0lEQVR4nGP4DwQACfsD/fteaysAAAAASUVORK5CYII=');
  ImageModel model(Uint8List bytes) =>
      ImageModel(imageByte: bytes, name: 'scan', docType: 'Document');

  test('empty and cleared history is safe, new sessions reset undo history',
      () {
    final editor = ImageEditProvider();
    addTearDown(editor.dispose);
    expect(editor.currentState, isNull);
    editor.undo();
    editor.startSession(png);
    final edited = Uint8List.fromList([1, 2, 3]);
    editor.addState(edited);
    expect(editor.currentState, same(edited));
    editor.undo();
    expect(editor.currentState, same(png));
    editor.addState(Uint8List.fromList([4]));
    expect(editor.currentIndex, 1);
    editor.startSession(png);
    expect(editor.canUndo, isFalse);
    var notified = false;
    editor.addListener(() => notified = true);
    editor.clearState();
    expect(notified, isTrue);
    expect(editor.currentState, isNull);
    editor.addState(Uint8List(0));
    expect(editor.currentState, isNull);
  });

  Future<void> mount(WidgetTester tester, Widget screen,
      ImageEditProvider editor, CameraProvider camera) async {
    await tester.pumpWidget(MultiProvider(
        providers: [
          ChangeNotifierProvider.value(value: editor),
          ChangeNotifierProvider.value(value: camera),
        ],
        child: MaterialApp(
          localizationsDelegates: AppLocalizations.localizationsDelegates,
          supportedLocales: AppLocalizations.supportedLocales,
          home: screen,
        )));
  }

  testWidgets('editor first frame disables Done and clear safely rebuilds',
      (tester) async {
    final editor = ImageEditProvider();
    final camera = CameraProvider()..addImage(model(png));
    addTearDown(editor.dispose);
    addTearDown(camera.dispose);
    await mount(
        tester,
        ImageEditScreen(image: camera.imageList.first, imageIndex: 0),
        editor,
        camera);
    expect(
        tester
            .widget<TextButton>(find.widgetWithText(TextButton, 'Done'))
            .onPressed,
        isNull);
    await tester.pumpAndSettle();
    expect(
        tester
            .widget<TextButton>(find.widgetWithText(TextButton, 'Done'))
            .onPressed,
        isNotNull);
    camera.clearImageList();
    await tester.pump();
    expect(
        tester
            .widget<TextButton>(find.widgetWithText(TextButton, 'Done'))
            .onPressed,
        isNull);
    editor.clearState();
    await tester.pumpAndSettle();
    expect(find.byType(ImageEditUnavailable), findsOneWidget);
    expect(tester.takeException(), isNull);
  });

  testWidgets('empty input does not enter a permanently loading editor',
      (tester) async {
    final editor = ImageEditProvider();
    final camera = CameraProvider();
    addTearDown(editor.dispose);
    addTearDown(camera.dispose);
    await mount(
        tester,
        ImageEditScreen(image: model(Uint8List(0)), imageIndex: -1),
        editor,
        camera);
    await tester.pumpAndSettle();
    expect(find.byType(ImageEditUnavailable), findsOneWidget);
    expect(find.byType(CircularProgressIndicator), findsNothing);
    expect(tester.takeException(), isNull);
  });

  for (final screen in <Widget>[
    const ImageFilters(),
    const ImageSizeScreen(),
    CropScreen(imageModel: model(png), index: 0, cameFromEdit: true),
    ImageRotation(imageModel: model(png), index: 0, cameFromEdit: true),
  ]) {
    testWidgets('${screen.runtimeType} handles an empty editing session',
        (tester) async {
      final editor = ImageEditProvider();
      final camera = CameraProvider();
      addTearDown(editor.dispose);
      addTearDown(camera.dispose);
      await mount(tester, screen, editor, camera);
      await tester.pumpAndSettle();
      expect(find.byType(ImageEditUnavailable), findsOneWidget);
      expect(tester.takeException(), isNull);
    });
  }
}
