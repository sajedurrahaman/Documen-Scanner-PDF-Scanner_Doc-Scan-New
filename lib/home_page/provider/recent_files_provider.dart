import 'dart:io';

import 'package:flutter/foundation.dart';
import 'package:path_provider/path_provider.dart';

enum RecentKind { document, idCard, qr, barcode }

class RecentFile {
  final String path;
  final RecentKind kind;
  final DateTime modified;
  final int size;

  const RecentFile({
    required this.path,
    required this.kind,
    required this.modified,
    required this.size,
  });
}

class RecentFilesProvider extends ChangeNotifier {
  List<RecentFile> _files = const [];
  bool _loading = true;
  Future<void>? _inFlight;

  List<RecentFile> get files => _files;
  bool get loading => _loading;

  /// Loads once. A second call while the first is running waits for that
  /// same load instead of starting another one.
  Future<void> load() {
    final current = _inFlight;
    if (current != null) return current;
    final task = _read();
    _inFlight = task;
    return task.whenComplete(() {
      if (identical(_inFlight, task)) _inFlight = null;
    });
  }

  Future<void> _read() async {
    try {
      final appDir = await getApplicationDocumentsDirectory();
      final root = '${appDir.path}/Doc Scanner';
      final groups = await Future.wait([
        _scan(Directory('$root/Document'), RecentKind.document, images: true),
        _scan(Directory('$root/ID Card'), RecentKind.idCard, images: true),
        _scan(Directory('$root/QR Code'), RecentKind.qr, images: false),
        _scan(Directory('$root/Bar Code'), RecentKind.barcode, images: false),
      ]);
      final items = groups.expand((group) => group).toList()
        ..sort((a, b) => b.modified.compareTo(a.modified));
      _files = List.unmodifiable(items);
    } catch (e) {
      debugPrint('$e');
    } finally {
      _loading = false;
      notifyListeners();
    }
  }

  Future<List<RecentFile>> _scan(
    Directory directory,
    RecentKind kind, {
    required bool images,
  }) async {
    if (!await directory.exists()) return const [];
    final items = <RecentFile>[];
    await for (final entity
        in directory.list(recursive: true, followLinks: false)) {
      if (entity is! File) continue;
      final lower = entity.path.toLowerCase();
      final matches = images
          ? lower.endsWith('.jpg') ||
              lower.endsWith('.jpeg') ||
              lower.endsWith('.png') ||
              lower.endsWith('.pdf')
          : lower.endsWith('.txt');
      if (!matches) continue;
      try {
        final stat = await entity.stat();
        items.add(RecentFile(
          path: entity.path,
          kind: kind,
          modified: stat.modified,
          size: stat.size,
        ));
      } catch (_) {}
    }
    return items;
  }
}
