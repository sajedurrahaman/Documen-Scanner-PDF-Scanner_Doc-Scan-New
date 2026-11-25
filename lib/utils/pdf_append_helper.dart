import 'dart:io';
import 'dart:typed_data';

import 'package:pdf/pdf.dart';
import 'package:pdf/widgets.dart' as pw;
import 'package:pdfx/pdfx.dart' as pdfx;

/// Fast page load for preview (CamScanner-style — avoid heavy re-render loops).
Future<List<Uint8List>> loadDocumentPagesFast(String path) async {
  final lower = path.toLowerCase();
  if (lower.endsWith('.jpg') ||
      lower.endsWith('.jpeg') ||
      lower.endsWith('.png')) {
    return [await File(path).readAsBytes()];
  }
  if (!lower.endsWith('.pdf') || !await File(path).exists()) {
    return const [];
  }

  final pages = <Uint8List>[];
  final source = await pdfx.PdfDocument.openFile(path);
  try {
    // Scale 1.5 is enough for grid thumbs and much faster than 2x/3x.
    const scale = 1.5;
    for (var number = 1; number <= source.pagesCount; number++) {
      final page = await source.getPage(number);
      try {
        final rendered = await page.render(
          width: page.width * scale,
          height: page.height * scale,
          format: pdfx.PdfPageImageFormat.jpeg,
          backgroundColor: '#FFFFFF',
        );
        if (rendered != null) pages.add(rendered.bytes);
      } finally {
        await page.close();
      }
    }
  } finally {
    await source.close();
  }
  return pages;
}

/// Builds a PDF directly from page images (no PDF→raster→PDF round trip).
Future<File> writePdfFromImages({
  required String outputPath,
  required List<Uint8List> images,
}) async {
  final output = pw.Document();
  for (final bytes in images) {
    final image = pw.MemoryImage(bytes);
    output.addPage(
      pw.Page(
        pageFormat: PdfPageFormat.a4,
        margin: pw.EdgeInsets.zero,
        build: (_) => pw.Center(child: pw.Image(image, fit: pw.BoxFit.contain)),
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
