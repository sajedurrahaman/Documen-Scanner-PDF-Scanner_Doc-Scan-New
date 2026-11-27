import 'dart:math' as math;
import 'dart:typed_data';

import 'package:image/image.dart' as img;

bool isJpegBytes(Uint8List bytes) =>
    bytes.length >= 2 && bytes[0] == 0xFF && bytes[1] == 0xD8;

bool isPngBytes(Uint8List bytes) =>
    bytes.length >= 8 &&
    bytes[0] == 0x89 &&
    bytes[1] == 0x50 &&
    bytes[2] == 0x4E &&
    bytes[3] == 0x47;

img.Image? _tryDecode(Uint8List bytes, img.Image? Function(Uint8List) decode) {
  try {
    return decode(bytes);
  } catch (_) {
    // image package may throw (e.g. JpegDecoder on PNG) instead of null.
    return null;
  }
}

/// Decodes JPEG/PNG/etc without throwing on wrong container format.
img.Image? decodeAnyImage(Uint8List bytes) {
  if (bytes.isEmpty) return null;

  // Prefer the matching decoder first to avoid JpegDecoder exceptions on PNG.
  if (isJpegBytes(bytes)) {
    return _tryDecode(bytes, img.decodeJpg) ??
        _tryDecode(bytes, img.decodeImage);
  }
  if (isPngBytes(bytes)) {
    return _tryDecode(bytes, img.decodePng) ??
        _tryDecode(bytes, img.decodeImage);
  }

  return _tryDecode(bytes, img.decodeJpg) ??
      _tryDecode(bytes, img.decodePng) ??
      _tryDecode(bytes, img.decodeImage);
}

/// PDF `MemoryImage` expects JPEG. Filter/size screens capture PNG — normalize.
Uint8List ensureJpegBytes(Uint8List bytes, {int quality = 92}) {
  if (bytes.isEmpty) return bytes;
  if (isJpegBytes(bytes)) return bytes;
  final decoded = decodeAnyImage(bytes);
  if (decoded == null) {
    throw StateError(
      'Could not decode image bytes for JPEG conversion '
      '(len=${bytes.length}, head=${bytes.isEmpty ? "empty" : bytes.take(4).toList()})',
    );
  }
  return Uint8List.fromList(img.encodeJpg(decoded, quality: quality));
}

/// Places [bytes] centered on a white A4 sheet (ID Card PDF style).
Uint8List placeImageOnA4Canvas(Uint8List bytes, {int quality = 92}) {
  final decoded = decodeAnyImage(bytes);
  if (decoded == null) return bytes;

  // ~150 DPI A4
  const a4w = 1240;
  const a4h = 1754;
  final canvas = img.Image(width: a4w, height: a4h);
  img.fill(canvas, color: img.ColorRgb8(255, 255, 255));

  final maxW = (a4w * 0.84).round();
  final maxH = (a4h * 0.84).round();
  final scale = math.min(maxW / decoded.width, maxH / decoded.height);
  final dw = math.max(1, (decoded.width * scale).round());
  final dh = math.max(1, (decoded.height * scale).round());
  final resized = img.copyResize(decoded, width: dw, height: dh);
  img.compositeImage(
    canvas,
    resized,
    dstX: (a4w - dw) ~/ 2,
    dstY: (a4h - dh) ~/ 2,
  );
  return Uint8List.fromList(img.encodeJpg(canvas, quality: quality));
}
