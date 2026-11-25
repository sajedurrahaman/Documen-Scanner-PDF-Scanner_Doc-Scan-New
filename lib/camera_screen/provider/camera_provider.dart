import 'dart:developer';
import 'dart:io';
import 'dart:typed_data';
import 'package:gal/gal.dart';
import 'package:pdf/widgets.dart' as pw;
import 'package:doc_scanner/home_page/provider/home_page_provider.dart';
import 'package:flutter/material.dart';
import 'package:intl/intl.dart';
import 'package:path_provider/path_provider.dart';
import 'package:pdf/pdf.dart' hide PdfDocument;
import 'package:pdfx/pdfx.dart';
import 'package:doc_scanner/utils/meta_events_helper.dart';
import 'package:provider/provider.dart';
import '../model/image_model.dart';

class CameraProvider extends ChangeNotifier {
  final List<String> _documentType = ['QR Code', 'Bar Code'];
  List<String> get documentTypes => _documentType;

  final List<ImageModel> _imageList = [];
  List<ImageModel> get imageList => _imageList;

  void addImage(ImageModel image) {
    _imageList.add(image);
    notifyListeners();
  }

  void addImageSpecipicIndex(List<ImageModel> image, int index) {
    _imageList.insertAll(index, image);
    notifyListeners();
  }

  void updateImage({required int index, required ImageModel image}) {
    _imageList[index] = image;
    notifyListeners();
  }

  void deleteImage(int index) {
    _imageList.removeAt(index);
    notifyListeners();
  }

  /// Drag-reorder pages in the preview grid (same idea as PDF_Converter-New).
  void reorderImages(int fromIndex, int toIndex) {
    if (fromIndex == toIndex) return;
    if (fromIndex < 0 || fromIndex >= _imageList.length) return;
    if (toIndex < 0 || toIndex >= _imageList.length) return;
    final item = _imageList.removeAt(fromIndex);
    _imageList.insert(toIndex, item);
    notifyListeners();
  }

  void clearImageList() {
    _imageList.clear();
    notifyListeners();
  }

  List<String> _idCardImages = [];
  List<String> get idCardImages => _idCardImages;

  addIdCardImage(String imagePath) {
    _idCardImages.add(imagePath);
    notifyListeners();
  }

  void updateIdCardImage({required int index, required String imagePath}) {
    _idCardImages[index] = imagePath;
    notifyListeners();
  }

  void reverseIdCardImages() {
    _idCardImages = _idCardImages.reversed.toList();
    notifyListeners();
  }

  void clearIdCardImages() {
    _idCardImages.clear();
    notifyListeners();
  }

  void replaceIdCardImage({required int index, required String imagePath}) {
    _idCardImages[index] = imagePath;
    notifyListeners();
  }

  Future<void> exportAllImages() async {
    final Directory appDirectory = await getApplicationDocumentsDirectory();
    final String documentDirectoryPath =
        '${appDirectory.path}/Doc Scanner/Document';

    for (int i = 0; i < _imageList.length; i++) {
      final Uint8List bytes = _imageList[i].imageByte;

      // Base file path
      String imagePath = '$documentDirectoryPath/${_imageList[i].name}.jpg';
      File imageFile = File(imagePath);

      // Check if file exists and generate a unique file name
      int duplicateCount = 1;
      while (await imageFile.exists()) {
        imagePath =
            '$documentDirectoryPath/${_imageList[i].name}_$duplicateCount.jpg';
        imageFile = File(imagePath);
        duplicateCount++;
      }

      // Write the file and add to the gallery
      await imageFile.writeAsBytes(bytes);
      Gal.putImage(imageFile.path);
    }
  }

  Future<void> saveQRCodeText(String text, BuildContext context) async {
    Directory appDir = await getApplicationDocumentsDirectory();
    final fileName = DateFormat('yyyyMMdd_SSSS').format(DateTime.now());
    String filePath = '${appDir.path}/Doc Scanner/QR Code/QrCode-$fileName.txt';
    File file = File(filePath);
    await file.writeAsString(text);
    context.read<HomePageProvider>().addQrCodeFile(filePath);
  }

  Future<void> saveBarCodeText(String text, BuildContext context) async {
    Directory appDir = await getApplicationDocumentsDirectory();
    final fileName = DateFormat('yyyyMMdd_SSSS').format(DateTime.now());
    String filePath =
        '${appDir.path}/Doc Scanner/Bar Code/BarCode$fileName.txt';
    File file = File(filePath);
    await file.writeAsString(text);
    context.read<HomePageProvider>().addBarCodeFile(filePath);
  }

  Future<File?> createPDFFromByte({
    required BuildContext context,
    required String fileName,
  }) async {
    try {
      String directoryPath;
      final List<Uint8List> images =
          _imageList.map((e) => e.imageByte).toList();
      final Directory appDirectory = await getApplicationDocumentsDirectory();

      directoryPath = '${appDirectory.path}/Doc Scanner/Document';

      final pdf = pw.Document();

      for (var imageData in images) {
        final pdfImage = pw.MemoryImage(imageData);
        pdf.addPage(
          pw.Page(
            clip: false,
            pageFormat: PdfPageFormat.a4,
            margin: const pw.EdgeInsets.all(0),
            build: (pw.Context context) {
              return pw.Center(
                child: pw.Image(
                  pdfImage,
                  fit: pw.BoxFit.fill,
                ),
              );
            },
          ),
        );
      }
      int index = 1;
      String newFileName = fileName;
      while (File('$directoryPath/$newFileName.pdf').existsSync()) {
        newFileName = '$fileName($index)';
        index++;
      }
      final File file = File('$directoryPath/$newFileName.pdf');
      final bytes = await pdf.save();
      final pdfFile = await file.writeAsBytes(bytes, flush: true);
      if (Platform.isIOS) {
        Directory iosDocumentsDirectory =
            await getApplicationDocumentsDirectory();
        File iOSExternalFile = File(
            "${iosDocumentsDirectory.path}/Doc Scanner/Document/$fileName.pdf");

        final pdfBytes = await pdf.save();
        await iOSExternalFile.writeAsBytes(pdfBytes);
        debugPrint("PDF saved to iOS: ${iOSExternalFile.path}");
      } else if (Platform.isAndroid) {
        final externalStorageDirectory =
            Directory('/storage/emulated/0/Documents/Document');
        if (!await externalStorageDirectory.exists()) {
          await externalStorageDirectory.create(recursive: true);
        }
        File externalFile =
            File("${externalStorageDirectory.path}/$newFileName.pdf");

        // Write to both locations
        final pdfBytes = await pdf.save();
        await externalFile.writeAsBytes(pdfBytes);
      }

      _isCreatingPDFLoader = false;
      notifyListeners();
      await MetaEventsHelper.logPdfCreated();
      return pdfFile;
    } catch (e) {
      _isCreatingPDFLoader = false;
      notifyListeners();
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text('Error creating PDF: $e'),
        ),
      );
      return null;
    }
  }

  bool _isCreatingPDFLoader = false;
  bool get isCreatingPDFLoader => _isCreatingPDFLoader;

  bool _pdfConverting = false;
  bool get pdfConverting => _pdfConverting;

  Future<bool> convertPdfToImage(File pdfFile) async {
    try {
      _pdfConverting = true;
      notifyListeners();

      final pdfDocument = await PdfDocument.openFile(pdfFile.path);
      final totalPages = pdfDocument.pagesCount;

      for (int i = 1; i <= totalPages; i++) {
        final page = await pdfDocument.getPage(i);

// Increase DPI by multiplying width/height
        final scale = 3.0; // try 2.0 or 3.0 for sharper text
        final pageImage = await page.render(
          width: (page.width * scale).toDouble(),
          height: (page.height * scale).toDouble(),
          format: PdfPageImageFormat.png,
          backgroundColor: '#FFFFFFFF', // optional: white background
        );

        final imageByte = pageImage!.bytes;

        final fileName = DateFormat('yyyyMMdd_SSSS').format(DateTime.now());
        _imageList.add(
          ImageModel(
            imageByte: imageByte,
            name: "Doc-$fileName",
            docType: 'Document',
          ),
        );

        await page.close();
      }

      await pdfDocument.close();

      _pdfConverting = false;
      notifyListeners();
      return true;
    } catch (e) {
      log(e.toString());
      _pdfConverting = false;
      notifyListeners();
      return false;
    }
  }
}
