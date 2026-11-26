import 'dart:io';
import 'dart:math' as math;
import 'dart:typed_data';
import 'dart:ui' as ui;

import 'package:doc_scanner/utils/image_bytes_helper.dart';
import 'package:image/image.dart' as img;
import 'package:pdf/pdf.dart';
import 'package:pdf/widgets.dart' as pw;
import 'package:pdfx/pdfx.dart' as pdfx;

img.Image? _decodePageImage(Uint8List bytes) => decodeAnyImage(bytes);

bool _isNearWhite(img.Pixel p, int threshold) {
  final luma = (0.299 * p.r) + (0.587 * p.g) + (0.114 * p.b);
  return luma >= threshold;
}

bool _rowMostlyWhite(img.Image image, int y, int threshold, double minRatio) {
  var white = 0;
  final w = image.width;
  for (var x = 0; x < w; x++) {
    if (_isNearWhite(image.getPixel(x, y), threshold)) white++;
  }
  return white / w >= minRatio;
}

bool _colMostlyWhite(
  img.Image image,
  int x,
  int top,
  int bottom,
  int threshold,
  double minRatio,
) {
  var white = 0;
  final h = bottom - top + 1;
  if (h <= 0) return true;
  for (var y = top; y <= bottom; y++) {
    if (_isNearWhite(image.getPixel(x, y), threshold)) white++;
  }
  return white / h >= minRatio;
}

/// Removes empty white letterbox only (CamScanner photo pages).
/// Does nothing when the page is already full-bleed.
Uint8List trimWhiteLetterbox(
  Uint8List bytes, {
  int threshold = 242,
  double whiteRatio = 0.985,
}) {
  final decoded = _decodePageImage(bytes);
  if (decoded == null) return bytes;

  var top = 0;
  var bottom = decoded.height - 1;
  var left = 0;
  var right = decoded.width - 1;

  while (top < bottom &&
      _rowMostlyWhite(decoded, top, threshold, whiteRatio)) {
    top++;
  }
  while (bottom > top &&
      _rowMostlyWhite(decoded, bottom, threshold, whiteRatio)) {
    bottom--;
  }
  while (left < right &&
      _colMostlyWhite(decoded, left, top, bottom, threshold, whiteRatio)) {
    left++;
  }
  while (right > left &&
      _colMostlyWhite(decoded, right, top, bottom, threshold, whiteRatio)) {
    right--;
  }

  final cropW = right - left + 1;
  final cropH = bottom - top + 1;
  if (cropW <= 0 ||
      cropH <= 0 ||
      (left == 0 &&
          top == 0 &&
          right == decoded.width - 1 &&
          bottom == decoded.height - 1)) {
    return bytes;
  }

  // Only treat as letterbox if we actually remove a meaningful empty frame.
  final trimmedX = left + (decoded.width - 1 - right);
  final trimmedY = top + (decoded.height - 1 - bottom);
  final padX = trimmedX / decoded.width;
  final padY = trimmedY / decoded.height;
  if (padX < 0.03 && padY < 0.03) return bytes;

  final minKeep = math.min(decoded.width, decoded.height) * 0.2;
  if (cropW < minKeep || cropH < minKeep) return bytes;

  final cropped = img.copyCrop(
    decoded,
    x: left,
    y: top,
    width: cropW,
    height: cropH,
  );
  return Uint8List.fromList(img.encodeJpg(cropped, quality: 92));
}

Future<Uint8List?> _renderPdfPage(
  pdfx.PdfDocument source,
  int number, {
  double scale = 1.5,
}) async {
  final page = await source.getPage(number);
  try {
    final rendered = await page.render(
      width: page.width * scale,
      height: page.height * scale,
      format: pdfx.PdfPageImageFormat.jpeg,
      backgroundColor: '#FFFFFF',
    );
    if (rendered == null) return null;
    return trimWhiteLetterbox(rendered.bytes);
  } finally {
    await page.close();
  }
}

/// Fast page load for preview (CamScanner-style — avoid heavy re-render loops).
Future<List<Uint8List>> loadDocumentPagesFast(String path) async {
  final pages = <Uint8List>[];
  await loadDocumentPagesProgressive(
    path,
    onPage: (bytes, index, total) => pages.add(bytes),
  );
  return pages;
}

/// CamScanner-style: yield page 1 ASAP, then remaining pages one-by-one.
/// [onPage] index is 0-based; [total] is known after open (1 for images).
Future<void> loadDocumentPagesProgressive(
  String path, {
  required void Function(Uint8List bytes, int index, int total) onPage,
  bool Function()? isCancelled,
}) async {
  final lower = path.toLowerCase();
  if (lower.endsWith('.jpg') ||
      lower.endsWith('.jpeg') ||
      lower.endsWith('.png')) {
    if (isCancelled?.call() == true) return;
    onPage(await File(path).readAsBytes(), 0, 1);
    return;
  }
  if (!lower.endsWith('.pdf') || !await File(path).exists()) {
    return;
  }

  final source = await pdfx.PdfDocument.openFile(path);
  try {
    final total = source.pagesCount;
    for (var number = 1; number <= total; number++) {
      if (isCancelled?.call() == true) return;
      final bytes = await _renderPdfPage(source, number);
      if (bytes == null) continue;
      if (isCancelled?.call() == true) return;
      onPage(bytes, number - 1, total);
      // Let UI paint page 1 before continuing heavy work.
      await Future<void>.delayed(Duration.zero);
    }
  } finally {
    await source.close();
  }
}

/// Page size follows image aspect (no forced A4). Normalized to PDF points.
Future<PdfPageFormat> _pageFormatForImage(Uint8List bytes) async {
  final codec = await ui.instantiateImageCodec(bytes);
  try {
    final frame = await codec.getNextFrame();
    final width = frame.image.width.toDouble();
    final height = frame.image.height.toDouble();
    frame.image.dispose();
    if (width <= 0 || height <= 0) return PdfPageFormat.a4;

    // Keep ratio; fit longest side to A4 long side in points (print-friendly).
    const maxSide = 842.0;
    final scale = maxSide / math.max(width, height);
    return PdfPageFormat(width * scale, height * scale, marginAll: 0);
  } finally {
    codec.dispose();
  }
}

/// CamScanner-like PDF: each page = image aspect, full-bleed, no white pad.
Future<File> writePdfFromImages({
  required String outputPath,
  required List<Uint8List> images,
}) async {
  final output = pw.Document();
  for (final raw in images) {
    // Filter/size screens may store PNG screenshots; PDF needs JPEG.
    final normalized = ensureJpegBytes(raw);
    // Ensure we never re-embed a previous A4 letterbox frame.
    final bytes = trimWhiteLetterbox(normalized);
    final image = pw.MemoryImage(ensureJpegBytes(bytes));
    final pageFormat = await _pageFormatForImage(bytes);
    output.addPage(
      pw.Page(
        pageFormat: pageFormat,
        build: (_) => pw.Image(image, fit: pw.BoxFit.fill),
      ),
    );
  }
  final outBytes = await output.save();
  return File(outputPath).writeAsBytes(outBytes, flush: true);
}

String resolvedPdfOutputPath(String targetPath) {
  final lower = targetPath.toLowerCase();
  if (lower.endsWith('.pdf')) return targetPath;
  return targetPath.replaceAll(
    RegExp(r'\.(jpg|jpeg|png)$', caseSensitive: false),
    '.pdf',
  );
}

/// Appends scanned page images onto an existing PDF (or builds a PDF from images).
@Deprecated('Prefer loadDocumentPagesFast + writePdfFromImages')
Future<File> appendImagesToDocument({
  required String targetPath,
  required List<Uint8List> images,
}) async {
  final existing = await loadDocumentPagesFast(targetPath);
  final all = [...existing, ...images];
  final outPath = resolvedPdfOutputPath(targetPath);
  return writePdfFromImages(outputPath: outPath, images: all);
}
