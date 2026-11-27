import 'dart:developer';
import 'dart:io';
import 'dart:typed_data';
import 'package:gal/gal.dart';
import 'package:doc_scanner/home_page/provider/home_page_provider.dart';
import 'package:doc_scanner/utils/download_helper.dart';
import 'package:doc_scanner/utils/pdf_append_helper.dart';
import 'package:flutter/material.dart';
import 'package:intl/intl.dart';
import 'package:path_provider/path_provider.dart';
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

  void replaceImageList(List<ImageModel> images) {
    _imageList
      ..clear()
      ..addAll(images);
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
    /// When set (Recent reopen → edit → save), overwrite this PDF instead of
    /// creating `name(1).pdf`.
    String? overwritePath,
  }) async {
    try {
      final List<Uint8List> images =
          _imageList.map((e) => e.imageByte).toList();
      final Directory appDirectory = await getApplicationDocumentsDirectory();
      final directoryPath = '${appDirectory.path}/Doc Scanner/Document';
      await Directory(directoryPath).create(recursive: true);

      late final String pdfPath;
      if (overwritePath != null &&
          overwritePath.toLowerCase().endsWith('.pdf')) {
        pdfPath = overwritePath;
      } else {
        var newFileName = fileName;
        var index = 1;
        while (File('$directoryPath/$newFileName.pdf').existsSync()) {
          newFileName = '$fileName($index)';
          index++;
        }
        pdfPath = '$directoryPath/$newFileName.pdf';
      }
      final pdfFile = await writePdfFromImages(
        outputPath: pdfPath,
        images: images,
        rawPages: _imageList
            .map((e) => e.rawBytes ?? e.imageByte)
            .toList(growable: false),
      );
      // Public Documents copy is best-effort (scoped storage). App copy is source of truth.
      if (Platform.isAndroid) {
        await DownloadHelper.trySaveToPublicDocuments(
          pdfFile.path,
          subfolder: 'Document',
        );
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

  /// Saves [images] as a PDF under Document/ so the source stays in Recents
  /// after copy/move (CamScanner-style).
  Future<File?> saveImagesAsDocumentPdf({
    required List<Uint8List> images,
    required String fileName,
  }) async {
    if (images.isEmpty) return null;
    try {
      final appDirectory = await getApplicationDocumentsDirectory();
      final directoryPath = '${appDirectory.path}/Doc Scanner/Document';
      await Directory(directoryPath).create(recursive: true);

      var newFileName = fileName;
      var index = 1;
      while (File('$directoryPath/$newFileName.pdf').existsSync()) {
        newFileName = '$fileName($index)';
        index++;
      }
      return writePdfFromImages(
        outputPath: '$directoryPath/$newFileName.pdf',
        images: images,
      );
    } catch (e) {
      log('saveImagesAsDocumentPdf: $e');
      return null;
    }
  }

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

        // Match CamScanner photo pages: drop empty A4 letterbox if present.
        final imageByte = trimWhiteLetterbox(pageImage!.bytes);

        final fileName = DateFormat('yyyyMMdd_SSSS').format(DateTime.now());
        _imageList.add(
          ImageModel(
            imageByte: imageByte,
            rawBytes: imageByte,
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
