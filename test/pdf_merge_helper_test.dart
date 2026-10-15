import 'dart:convert';
import 'dart:io';
import 'package:doc_scanner/utils/pdf_merge_helper.dart';
import 'package:flutter/services.dart';
import 'package:flutter_test/flutter_test.dart';
// ignore: implementation_imports
import 'package:pdfx/src/renderer/interfaces/platform.dart';
// ignore: implementation_imports
import 'package:pdfx/src/renderer/io/platform_method_channel.dart';

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();
  test(
      'merge includes every page in selection order and never overwrites a file',
      () async {
    final root = await Directory.systemTemp.createTemp('pdf_merge_test');
    final original = PdfxPlatform.instance;
    PdfxPlatform.instance = PdfxPlatformMethodChannel();
    const channel = MethodChannel('io.scer.pdf_renderer');
    final messenger =
        TestDefaultBinaryMessengerBinding.instance.defaultBinaryMessenger;
    final rendered = <String>[];
    final closed = <String>[];
    final png = base64Decode(
        'iVBORw0KGgoAAAANSUhEUgAAAAEAAAABCAYAAAAfFcSJAAAAC0lEQVR4nGP4DwQACfsD/fteaysAAAAASUVORK5CYII=');
    messenger.setMockMethodCallHandler(channel, (call) async {
      switch (call.method) {
        case 'open.document.file':
          return {
            'id': call.arguments,
            'pagesCount': call.arguments == 'first.pdf' ? 2 : 1
          };
        case 'open.page':
          return {
            'id': '${call.arguments['documentId']}:${call.arguments['page']}',
            'width': 200,
            'height': 300
          };
        case 'render':
          final id = call.arguments['pageId'] as String;
          rendered.add(id);
          final image = await File('${root.path}/page.png').writeAsBytes(png);
          return {'width': 1, 'height': 1, 'path': image.path, 'data': png};
        case 'close.page':
          closed.add(call.arguments as String);
          return null;
        case 'close.document':
          closed.add(call.arguments as String);
          return null;
      }
      return null;
    });
    addTearDown(() async {
      messenger.setMockMethodCallHandler(channel, null);
      PdfxPlatform.instance = original;
      await root.delete(recursive: true);
    });
    final existing =
        await File('${root.path}/Merged.pdf').writeAsString('keep');
    final output = await mergePdfFiles(
        paths: ['first.pdf', 'second.pdf'],
        directoryPath: root.path,
        name: 'Merged');
    expect(output.path, endsWith('Merged(1).pdf'));
    expect(await existing.readAsString(), 'keep');
    expect(rendered, ['first.pdf:1', 'first.pdf:2', 'second.pdf:1']);
    expect(closed, [
      'first.pdf:1',
      'first.pdf:2',
      'first.pdf',
      'second.pdf:1',
      'second.pdf'
    ]);
    final pdf = latin1.decode(await output.readAsBytes());
    expect(pdf, startsWith('%PDF-'));
    expect(RegExp(r'/Count\s+3\b').hasMatch(pdf), isTrue);
  });
}
