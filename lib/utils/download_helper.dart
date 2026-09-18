import 'dart:io';

import 'package:device_info_plus/device_info_plus.dart';
import 'package:flutter/services.dart';
import 'package:path_provider/path_provider.dart';
import 'package:permission_handler/permission_handler.dart';

class DownloadHelper {
  static const MethodChannel _channel =
      MethodChannel('com.documentscannerpdfscanner_/downloads');

  /// Saves [sourceFilePath] into the public Downloads folder on Android.
  static Future<String> saveFileToDownloads(String sourceFilePath) async {
    final source = File(sourceFilePath);
    if (!await source.exists()) {
      throw Exception('Source file not found');
    }

    final fileName = sourceFilePath.split(Platform.pathSeparator).last;
    final bytes = await source.readAsBytes();
    final mimeType = _mimeTypeFor(fileName);

    if (Platform.isAndroid) {
      await _ensureAndroidStoragePermission();
      final result = await _channel.invokeMethod<String>('saveToDownloads', {
        'fileName': fileName,
        'bytes': bytes,
        'mimeType': mimeType,
      });
      if (result == null || result.isEmpty) {
        throw Exception('Failed to save file to Downloads');
      }
      return result;
    }

    final docs = await getApplicationDocumentsDirectory();
    final outFile = File('${docs.path}/$fileName');
    await outFile.writeAsBytes(bytes, flush: true);
    return outFile.path;
  }

  static Future<void> _ensureAndroidStoragePermission() async {
    final sdk = (await DeviceInfoPlugin().androidInfo).version.sdkInt;
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
