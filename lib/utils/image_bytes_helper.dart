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
