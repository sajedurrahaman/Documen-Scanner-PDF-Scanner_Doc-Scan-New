import 'dart:io';

import 'package:device_info_plus/device_info_plus.dart';
import 'package:flutter/services.dart';
import 'package:path_provider/path_provider.dart';
import 'package:permission_handler/permission_handler.dart';

class DownloadHelper {
  static const MethodChannel _channel =
      MethodChannel('com.documentscannerpdfscanner_/downloads');

  /// Saves [sourceFilePath] into the public Downloads folder on Android.
  /// Returns the saved path/URI string on success.
  static Future<String> saveFileToDownloads(String sourceFilePath) async {
    final source = File(sourceFilePath);
    if (!await source.exists()) {
      throw Exception('Source file not found');
    }

    final fileName = sourceFilePath.split(Platform.pathSeparator).last;
    final mimeType = _mimeTypeFor(fileName);

    if (Platform.isAndroid) {
      await _ensureAndroidStoragePermission();
      final result = await _channel.invokeMethod<String>('saveToDownloads', {
        'fileName': fileName,
        'sourcePath': source.path,
        'mimeType': mimeType,
      });
      if (result == null || result.isEmpty) {
        throw Exception('Failed to save file to Downloads');
      }
      return result;
    }

    // iOS has no public Downloads folder — save under app Documents.
    final docs = await getApplicationDocumentsDirectory();
    final outFile = File('${docs.path}/$fileName');
    // absolute paths can differ (/var vs /private/var) for one file.
    // Copying a file onto itself truncates it.
    if (!await _isSameFile(source, outFile)) {
      await source.copy(outFile.path);
    }
    return outFile.path;
  }

  static Future<bool> _isSameFile(File source, File destination) async {
    if (source.absolute.path == destination.absolute.path) return true;
    if (!await destination.exists()) return false;
    try {
      return await source.resolveSymbolicLinks() ==
          await destination.resolveSymbolicLinks();
    } catch (_) {
      return false;
    }
  }

  static Future<void> _ensureAndroidStoragePermission() async {
    final sdk = (await DeviceInfoPlugin().androidInfo).version.sdkInt;
    // MediaStore Downloads (API 29+) does not need legacy storage permission.
    if (sdk >= 29) return;

    final status = await Permission.storage.request();
    if (!status.isGranted) {
      throw Exception('Storage permission denied');
    }
  }

  static String _mimeTypeFor(String fileName) {
    final lower = fileName.toLowerCase();
    if (lower.endsWith('.pdf')) return 'application/pdf';
    if (lower.endsWith('.txt')) return 'text/plain';
    if (lower.endsWith('.jpg') || lower.endsWith('.jpeg')) {
      return 'image/jpeg';
    }
    if (lower.endsWith('.png')) return 'image/png';
    return 'application/octet-stream';
  }
}
