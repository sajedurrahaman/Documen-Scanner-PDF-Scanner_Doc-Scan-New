import 'dart:io';
import 'dart:typed_data';
// ignore: depend_on_referenced_packages
import 'package:path/path.dart' as path;
import '../utils/pdf_append_helper.dart';
import '../utils/pdf_merge_helper.dart';

/// Preserves existing files when a destination already contains the same name.
Future<File> availableRecentFile(String directory, String filename) async {
  var target = File(path.join(directory, filename));
  final base = path.basenameWithoutExtension(filename);
  final extension = path.extension(filename);
  for (var index = 1;
      await FileSystemEntity.type(target.path, followLinks: false) !=
          FileSystemEntityType.notFound;
      index++) {
    target = File(path.join(directory, '$base($index)$extension'));
  }
  return target;
}

Future<void> moveRecentFiles(List<String> files, String destination) async {
  for (final source in files) {
    if (path.equals(path.dirname(source), destination)) continue;
    final target =
        await availableRecentFile(destination, path.basename(source));
    await File(source).rename(target.path);
  }
}

Future<File> mergeRecentFiles(List<String> files, String name) async {
  final directory = path.dirname(files.first);
  if (files.every((file) => path.extension(file).toLowerCase() == '.pdf')) {
    return mergePdfFiles(paths: files, directoryPath: directory, name: name);
  }
  final images = <Uint8List>[];
  for (final file in files) {
    images.add(await File(file).readAsBytes());
  }
  final output = await availableRecentFile(directory, '$name.pdf');
  try {
    return await writePdfFromImages(outputPath: output.path, images: images);
  } catch (_) {
    if (await output.exists()) await output.delete();
    rethrow;
  }
}
