import 'dart:async';
import 'dart:developer';
import 'dart:io';
import 'package:pdf/pdf.dart';
import 'package:pdf/widgets.dart' as pw;
import 'package:flutter/material.dart';
import 'package:flutter_image_compress/flutter_image_compress.dart';
import 'package:doc_scanner/utils/meta_events_helper.dart';
import 'package:path_provider/path_provider.dart';

class HomePageProvider extends ChangeNotifier {
  List<Directory> _directories = [];

  List<Directory> get directories => _directories;

  Future<void> getDirectoriesForCreate() async {
    final Directory appDirectory = await getApplicationDocumentsDirectory();

    print("getDirectoriesForCreate-> ${appDirectory.path}");
    final Directory pdfConverterDirectory =
        Directory('${appDirectory.path}/Doc Scanner');
    _directories = await pdfConverterDirectory
        .list(followLinks: false)
        .where((entity) => entity is Directory)
        .cast<Directory>()
        .toList();
    directories.sort((a, b) {
      Map<String, int> order = {
        'D': 0,
        'I': 1,
        'Q': 2,
        'B': 3,
      };
      String aFirstLetter = a.path.split('/').last[0];
      String bFirstLetter = b.path.split('/').last[0];
      int aOrder = order.containsKey(aFirstLetter) ? order[aFirstLetter]! : 4;
      int bOrder = order.containsKey(bFirstLetter) ? order[bFirstLetter]! : 4;
      return aOrder.compareTo(bOrder);
    });
    notifyListeners();
  }

  Future<void> createDirectory({
    required Directory rootDirectory,
    required String directoryName,
  }) async {
    final Directory newDirectory =
        Directory('${rootDirectory.path}/$directoryName');
    if (await newDirectory.exists()) {
    } else {
      await newDirectory.create(recursive: true);
    }
  }

  final List<File> _documentImageFiles = [];

  List<File> get documentImageFiles => _documentImageFiles.reversed.toList();

  final List<File> _idCardImageFiles = [];

  List<File> get idCardImageFiles => _idCardImageFiles.reversed.toList();

  final List<String> _qrCodeFiles = [];

  List<String> get qrCodeFiles => _qrCodeFiles.reversed.toList();

  final List<String> _barCodeFiles = [];

  List<String> get barCodeFiles => _barCodeFiles.reversed.toList();

  void addDocumentImage(File file) {
    _documentImageFiles.add(file);
    notifyListeners();
  }

  void addIdCardImage(File file) {
    _idCardImageFiles.add(file);
    notifyListeners();
  }

  void removeDocumentImage(String imagePath) {
    try {
      int index = _documentImageFiles.indexWhere(
          (file) => file.path.split("/").last == imagePath.split("/").last);
      _documentImageFiles.removeAt(index);
    } catch (e) {
      print(e);
    }
    notifyListeners();
  }

  void removeIdCardImage(String imagePath) {
    try {
      int index = _idCardImageFiles.indexWhere(
          (file) => file.path.split("/").last == imagePath.split("/").last);
      _idCardImageFiles.removeAt(index);
    } catch (e) {
      log(e.toString());
    }
    notifyListeners();
  }

  // void removeIdCarImage(String imagePath) {
  //   int index = _idCardImageFiles.indexWhere(
  //       (file) => file.path.split("/").last == imagePath.split("/").last);
  //   _idCardImageFiles.removeAt(index);
  //   notifyListeners();
  // }

  void removeBarCode(String filePath) {
    // int index = _barCodeFiles
    //     .indexWhere((file) => file.split("/").last == barCode.split("/").last);
    // _barCodeFiles.removeAt(index);
    // notifyListeners();
    int index = _barCodeFiles.indexOf(filePath);
    if (index != -1) {
      // Check if the file exists in the list.
      _barCodeFiles.removeAt(index);
      notifyListeners();
    } else {
      // Handle the case where the file is not found.
      print("File not found in the list: $filePath");
    }
  }

  // void removeQrCode(String qrCode) {
  //   int index = _qrCodeFiles
  //       .indexWhere((file) => file.split("/").last == qrCode.split("/").last);
  //   _qrCodeFiles.removeAt(index);
  //   notifyListeners();
  // }
  void removeQrCode(String filePath) {
    int index = _qrCodeFiles.indexOf(filePath);
    if (index != -1) {
      // Check if the file exists in the list.
      _qrCodeFiles.removeAt(index);
      notifyListeners();
    } else {
      // Handle the case where the file is not found.
      print("File not found in the list: $filePath");
    }
  }

  void addQrCodeFile(String qrCode) {
    _qrCodeFiles.add(qrCode);
    notifyListeners();
  }

  void addBarCodeFile(String qrCode) {
    _barCodeFiles.add(qrCode);
    notifyListeners();
  }

  void clearDocumentImageFiles() {
    _documentImageFiles.clear();
    notifyListeners();
  }

  void clearIdCardImageFiles() {
    _idCardImageFiles.clear();
    notifyListeners();
  }

  void clearQRCodeFiles() {
    _qrCodeFiles.clear();
    notifyListeners();
  }

  void clearBarCodeFiles() {
    _barCodeFiles.clear();
    notifyListeners();
  }

  bool _historyLoading = false;
  bool get isHistoryLoading => _historyLoading;

  Future<void> loadDocumentImage() async {
    try {
      _historyLoading = true;
      notifyListeners();

      Directory appDir = await getApplicationDocumentsDirectory();
      Directory documentDirectory =
          Directory('${appDir.path}/Doc Scanner/Document');
      await for (FileSystemEntity entity in documentDirectory.list()) {
        if (entity is Directory) {
          await for (FileSystemEntity subEntity in entity.list()) {
            if (subEntity is File) {
              String filePath = subEntity.path;
              if (filePath.toLowerCase().endsWith('.jpg') ||
                  filePath.toLowerCase().endsWith('.jpeg') ||
                  filePath.toLowerCase().endsWith('.pdf') ||
                  filePath.toLowerCase().endsWith('.png')) {
                _documentImageFiles.add(File(filePath));
              }
            }
          }
        } else if (entity is File) {
          String filePath = entity.path;
          if (filePath.toLowerCase().endsWith('.jpg') ||
              filePath.toLowerCase().endsWith('.jpeg') ||
              filePath.toLowerCase().endsWith('.pdf') ||
              filePath.toLowerCase().endsWith('.png')) {
            _documentImageFiles.add(File(filePath));
          }
        }
      }
      _historyLoading = false;
      notifyListeners();
    } catch (e) {
      print(e);
    }
  }

  Future<void> loadIdCardImage() async {
    try {
      _historyLoading = true;
      notifyListeners();
      Directory appDir = await getApplicationDocumentsDirectory();
      Directory documentDirectory =
          Directory('${appDir.path}/Doc Scanner/ID Card');
      await for (FileSystemEntity entity in documentDirectory.list()) {
        if (entity is Directory) {
          await for (FileSystemEntity subEntity in entity.list()) {
            if (subEntity is File) {
              String filePath = subEntity.path;
              if (filePath.toLowerCase().endsWith('.jpg') ||
                  filePath.toLowerCase().endsWith('.jpeg') ||
                  filePath.toLowerCase().endsWith('.pdf') ||
                  filePath.toLowerCase().endsWith('.png')) {
                _idCardImageFiles.add(File(filePath));
              }
            }
          }
        } else if (entity is File) {
          String filePath = entity.path;
          if (filePath.toLowerCase().endsWith('.jpg') ||
              filePath.toLowerCase().endsWith('.jpeg') ||
              filePath.toLowerCase().endsWith('.pdf') ||
              filePath.toLowerCase().endsWith('.png')) {
            _idCardImageFiles.add(File(filePath));
          }
        }
      }

      _historyLoading = false;
      notifyListeners();
    } catch (e) {
      print(e.toString());
    }
  }

  Future<void> loadQRCode() async {
    try {
      _historyLoading = true;
      notifyListeners();

      Directory appDir = await getApplicationDocumentsDirectory();
      Directory textFilesDir = Directory('${appDir.path}/Doc Scanner/QR Code');
      await for (var entity
          in textFilesDir.list(recursive: true, followLinks: false)) {
        if (entity is File && entity.path.endsWith('.txt')) {
          _qrCodeFiles.add(entity.path);
        }
      }

      _historyLoading = false;
      notifyListeners();
    } catch (e) {
      print('Error: $e');
    }
  }

  Future<void> loadBarCode() async {
    try {
      _historyLoading = true;
      notifyListeners();

      Directory appDir = await getApplicationDocumentsDirectory();
      Directory textFilesDir = Directory('${appDir.path}/Doc Scanner/Bar Code');
      await for (var entity
          in textFilesDir.list(recursive: true, followLinks: false)) {
        if (entity is File && entity.path.endsWith('.txt')) {
          _barCodeFiles.add(entity.path);
        }
      }
      _historyLoading = false;
      notifyListeners();
    } catch (e) {
      print('Error: $e');
    }
  }

  bool _isCreatingPDF = false;

  bool get isCreatingPDF => _isCreatingPDF;

  Future<List<String>> getFileList(String directoryPath) async {
    List<String> subdirectoryPaths = [];
    List<String> imageAndPdfPaths = [];

    Future<void> traverseDirectory(Directory directory) async {
      await for (FileSystemEntity entity in directory.list()) {
        if (entity is Directory) {
          subdirectoryPaths.add(entity.path);
        } else if (entity is File) {
          String filePath = entity.path;
          if (filePath.toLowerCase().endsWith('.jpg') ||
              filePath.toLowerCase().endsWith('.jpeg') ||
              filePath.toLowerCase().endsWith('.png') ||
              filePath.toLowerCase().endsWith('.pdf') ||
              filePath.toLowerCase().endsWith('.txt')) {
            imageAndPdfPaths.add(filePath);
          }
        }
      }
    }

    Directory directory = Directory(directoryPath);
    if (await directory.exists()) {
      await traverseDirectory(directory);
    }
    List<String> fileList = [];
    fileList.addAll(imageAndPdfPaths);
    fileList.addAll(subdirectoryPaths);
    return fileList.reversed.toList();
  }

  Future<String> readTxtFile(String filePath) async {
    try {
      File file = File(filePath);
      return await file.readAsString();
    } catch (e) {
      return "Error reading file";
    }
  }

  Future<File?> createPDFFromImages({
    required List<File> images,
    required String directoryPath,
    required BuildContext context,
    required String fileName,
  }) async {
    try {
      _isCreatingPDF = true;
      notifyListeners();
      final pdf = pw.Document();
      for (var image in images) {
        final resizedImage = await FlutterImageCompress.compressWithFile(
          image.path,
          minHeight: 600,
          minWidth: 600,
          quality: 50,
        );
        var pdfImage = pw.MemoryImage(resizedImage!);
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
      File pdfFile = await file.writeAsBytes(bytes, flush: true);

      //Save pdf file as documents folder
      if (Platform.isIOS) {
        Directory iosDocumentsDirectory =
            await getApplicationDocumentsDirectory();
        File iOSExternalFile = File(
            "${iosDocumentsDirectory.path}/Doc Scanner/Document/$fileName.pdf");

        final pdfBytes = await pdf.save();
        await iOSExternalFile.writeAsBytes(pdfBytes);
        debugPrint("PDF saved to iOS: ${iOSExternalFile.path}");
        _isCreatingPDF = false;
      } else if (Platform.isAndroid) {
        final externalStorageDirectory =
            directoryPath.split('/').last == 'Document'
                ? Directory('/storage/emulated/0/Documents/Document')
                : Directory('/storage/emulated/0/Documents/IDCard');
        if (!await externalStorageDirectory.exists()) {
          await externalStorageDirectory.create(recursive: true);
        }
        File externalFile =
            File("${externalStorageDirectory.path}/$newFileName.pdf");

        // Write to both locations
        final pdfBytes = await pdf.save();
        await externalFile.writeAsBytes(pdfBytes);
        _isCreatingPDF = false;
      }

      notifyListeners();
      await MetaEventsHelper.logPdfCreated();
      return pdfFile;
    } catch (e) {
      _isCreatingPDF = false;
      notifyListeners();
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
          content: Text('Error creating PDF'),
        ),
      );

      return null;
    }
  }

  // void moveFilesToDirectory({
  //   required String targetDirectoryPath,
  //   required List<String> filePaths,
  // }) {
  //   for (String filePath in filePaths) {
  //     File file = File(filePath);
  //     if (file.existsSync()) {
  //       String fileName = file.path.split('/').last;
  //       String destinationFilePath = '$targetDirectoryPath/$fileName';
  //       if (!File(destinationFilePath).existsSync()) {
  //         file.renameSync(destinationFilePath);
  //         notifyListeners();
  //         print('Moved $filePath to $destinationFilePath');
  //       } else {
  //         print('File $fileName already exists in the destination directory');
  //       }
  //     } else {
  //       print('File $filePath does not exist');
  //     }
  //   }
  // }

  void moveFilesToDirectory({
    required String targetDirectoryPath,
    required List<String> filePaths,
  }) {
    for (String filePath in filePaths) {
      File file = File(filePath);
      if (file.existsSync()) {
        String fileName = file.path.split('/').last;
        String destinationFilePath = '$targetDirectoryPath/$fileName';
        if (File(destinationFilePath).existsSync()) {
          String baseName = fileName.split('.').first;
          String extension =
              fileName.contains('.') ? '.${fileName.split('.').last}' : '';
          int count = 1;
          while (File(destinationFilePath).existsSync()) {
            destinationFilePath =
                '$targetDirectoryPath/$baseName-$count$extension';
            count++;
          }
        }
        file.renameSync(destinationFilePath);
        notifyListeners();
        print('Moved $filePath to $destinationFilePath');
      } else {
        print('File $filePath does not exist');
      }
    }
  }

  bool checkIfFilesExistInDirectory({
    required String targetDirectoryPath,
    required List<String> filePaths,
  }) {
    for (String filePath in filePaths) {
      File file = File(filePath);
      if (file.existsSync()) {
        String fileName = file.path.split('/').last;
        String destinationFilePath = '$targetDirectoryPath/$fileName';
        if (File(destinationFilePath).existsSync()) {
          return true; // A file with the same name exists
        }
      }
    }
    return false; // No files with the same name exist
  }

  List<String> _allFiles = [];

  List<String> get allFiles => _allFiles;

  bool _allFileLoading = false;

  bool get allFileLoading => _allFileLoading;

  Future<void> getAllFileList() async {
    _allFileLoading = true;
    notifyListeners();
    Directory appDirectory = await getApplicationDocumentsDirectory();
    String directoryPath = '${appDirectory.path}/Doc Scanner';
    List<String> subdirectoryPaths = [];
    List<String> imageAndPdfPaths = [];
    Future<void> traverseDirectory(Directory directory) async {
      await for (FileSystemEntity entity in directory.list()) {
        if (entity is Directory) {
          await traverseDirectory(entity);
          subdirectoryPaths.add(entity.path);
        } else if (entity is File) {
          String filePath = entity.path;
          if (filePath.toLowerCase().endsWith('.jpg') ||
              filePath.toLowerCase().endsWith('.jpeg') ||
              filePath.toLowerCase().endsWith('.png') ||
              filePath.toLowerCase().endsWith('.pdf') ||
              filePath.toLowerCase().endsWith('.txt')) {
            imageAndPdfPaths.add(filePath);
          }
        }
      }
    }

    Directory directory = Directory(directoryPath);
    if (await directory.exists()) {
      await traverseDirectory(directory);
    } else {
      throw ArgumentError('Directory does not exist: $directoryPath');
    }
    List<String> fileList = [];
    fileList.addAll(subdirectoryPaths);
    fileList.addAll(imageAndPdfPaths);
    _allFiles = fileList;
    var roodDir = await getApplicationDocumentsDirectory();
    var documentDir = Directory('${roodDir.path}/Doc Scanner/Document');
    var idCardDir = Directory('${roodDir.path}/Doc Scanner/ID Card');
    var qrCodeDir = Directory('${roodDir.path}/Doc Scanner/QR Code');
    var barCodeDir = Directory('${roodDir.path}/Doc Scanner/Bar Code');
    _allFiles.remove(documentDir.path);
    _allFiles.remove(idCardDir.path);
    _allFiles.remove(qrCodeDir.path);
    _allFiles.remove(barCodeDir.path);
    _allFileLoading = false;
    notifyListeners();
  }

  Timer? _debounce;
  List<String> _filteredItems = [];

  List<String> get filteredItems => _filteredItems;

  void clearFilteredItems() {
    _filteredItems.clear();
    notifyListeners();
  }

  void onSearchChanged(String query) {
    if (query.isEmpty) {
      _filteredItems.clear();
      notifyListeners();
      return;
    }
    if (query.contains('.')) {
      return;
    }
    if (_debounce?.isActive ?? false) _debounce?.cancel();
    _debounce = Timer(const Duration(milliseconds: 300), () {
      _filteredItems = _allFiles
          .where((item) =>
              item.split("/").last.toLowerCase().contains(query.toLowerCase()))
          .toList();
      notifyListeners();
    });
  }
}
