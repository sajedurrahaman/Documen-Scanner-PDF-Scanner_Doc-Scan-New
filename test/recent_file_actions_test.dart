import 'dart:convert';
import 'dart:io';
import 'package:doc_scanner/home_page/recent_file_actions.dart';
import 'package:flutter_test/flutter_test.dart';

void main() {
  test('move preserves colliding files and skips files already in destination',
      () async {
    final root = await Directory.systemTemp.createTemp('recent_move');
    addTearDown(() => root.delete(recursive: true));
    final from = await Directory('${root.path}/from').create();
    final to = await Directory('${root.path}/to').create();
    final source = await File('${from.path}/a.pdf').writeAsString('source');
    final existing = await File('${to.path}/a.pdf').writeAsString('existing');
    await moveRecentFiles([source.path, existing.path], to.path);
    expect(await source.exists(), isFalse);
    expect(await existing.readAsString(), 'existing');
    expect(await File('${to.path}/a(1).pdf').readAsString(), 'source');
  });

  test(
      'image merge creates a new PDF beside first selection and keeps originals',
      () async {
    final root = await Directory.systemTemp.createTemp('recent_merge');
    addTearDown(() => root.delete(recursive: true));
    final png = base64Decode(
        'iVBORw0KGgoAAAANSUhEUgAAAAEAAAABCAYAAAAfFcSJAAAAC0lEQVR4nGP4DwQACfsD/fteaysAAAAASUVORK5CYII=');
    final first = await File('${root.path}/a.png').writeAsBytes(png);
    final second = await File('${root.path}/b.png').writeAsBytes(png);
    final existing =
        await File('${root.path}/Merged.pdf').writeAsString('keep');
    final result = await mergeRecentFiles([first.path, second.path], 'Merged');
    expect(result.path, endsWith('Merged(1).pdf'));
    expect(await existing.readAsString(), 'keep');
    expect(await first.exists(), isTrue);
    expect(await second.exists(), isTrue);
    expect(
        ascii.decode((await result.readAsBytes()).take(5).toList()), '%PDF-');
  });
}
