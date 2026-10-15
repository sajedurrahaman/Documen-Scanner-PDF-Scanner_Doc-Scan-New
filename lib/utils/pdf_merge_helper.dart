import 'dart:io';
import 'package:pdf/pdf.dart';
import 'package:pdf/widgets.dart' as pw;
import 'package:pdfx/pdfx.dart' as pdfx;

/// Matches the reference app's rendered-page PDF merge workflow.
/// The result preserves page appearance and order, rather than editable text.
Future<File> mergePdfFiles({
  required List<String> paths,
  required String directoryPath,
  required String name,
}) async {
  final output = pw.Document();
  for (final path in paths) {
    final source = await pdfx.PdfDocument.openFile(path);
    try {
      for (var number = 1; number <= source.pagesCount; number++) {
        final page = await source.getPage(number);
        try {
          final rendered = await page.render(
            width: page.width * 2,
            height: page.height * 2,
            format: pdfx.PdfPageImageFormat.png,
            backgroundColor: '#FFFFFF',
          );
          if (rendered == null) {
            throw StateError('Could not read PDF page $number');
          }
          final image = pw.MemoryImage(rendered.bytes);
          output.addPage(pw.Page(
            pageFormat: PdfPageFormat(page.width, page.height, marginAll: 0),
            build: (_) => pw.Image(image, fit: pw.BoxFit.fill),
          ));
        } finally {
          await page.close();
        }
      }
    } finally {
      await source.close();
    }
  }
  var file = File('$directoryPath/$name.pdf');
  for (var index = 1; await file.exists(); index++) {
    file = File('$directoryPath/$name($index).pdf');
  }
  final bytes = await output.save();
  // A failed write must not leave a corrupt PDF in the folder.
  try {
    return await file.writeAsBytes(bytes, flush: true);
  } catch (_) {
    if (await file.exists()) await file.delete();
    rethrow;
  }
}
