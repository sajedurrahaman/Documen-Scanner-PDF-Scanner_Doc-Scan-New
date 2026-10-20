// ignore_for_file: use_build_context_synchronously

import 'dart:io';
import 'dart:typed_data';
import 'dart:ui';
import 'package:doc_scanner/bottom_bar/bottom_bar.dart';
import 'package:doc_scanner/utils/addHelper.dart';
import 'package:doc_scanner/utils/app_color.dart';
import 'package:doc_scanner/utils/banner_ad_widget.dart';
import 'package:doc_scanner/utils/helper.dart';
import 'package:doc_scanner/utils/meta_events_helper.dart';
import 'package:doc_scanner/utils/utils.dart';
import 'package:flutter/material.dart';
import 'package:flutter/rendering.dart';
import 'package:gal/gal.dart';
import 'package:intl/intl.dart';
import 'package:pdf/pdf.dart';
import 'package:pdf/widgets.dart' as pw;
import 'package:interactive_box/interactive_box.dart';
import 'package:path_provider/path_provider.dart';
import 'package:provider/provider.dart';
import '../camera_screen/provider/camera_provider.dart';
import '../localaization/language_constant.dart';

class IdCardImagePreview extends StatefulWidget {
  final bool? isCameFromRetake;
  final int? imageIndex;

  const IdCardImagePreview({super.key, this.isCameFromRetake, this.imageIndex});

  @override
  State<IdCardImagePreview> createState() => _IdCardImagePreviewState();
}

class _IdCardImagePreviewState extends State<IdCardImagePreview> {
  bool isLoading = false;
  /// Only the selected document shows resize/rotate handles.
  int? selectedImageIndex;
  int? _selectedBeforeExport;
  bool isSaving = false;
  List<Map<String, dynamic>> imageProperties = [];
  String fileName =
      "IDCard_${DateFormat('yyyyMMdd_SSSS').format(DateTime.now())}";
  @override
  void initState() {
    super.initState();
    final cameraProvider = context.read<CameraProvider>();
    imageProperties = cameraProvider.idCardImages.map((imagePath) {
      int index = cameraProvider.idCardImages.indexOf(imagePath);
      return {
        'path': imagePath,
        'position': Offset(25 + (index * 150), 150),
        'size': const Size(150, 150), // Initial size
      };
    }).toList();
  }

  final GlobalKey _globalKey = GlobalKey();

  void showTopSnackbar(BuildContext context, String message) {
    final overlay = Overlay.of(context);
    final overlayEntry = OverlayEntry(
      builder: (context) => Positioned(
        top: 10.0,
        left: 0,
        right: 0,
        child: TopSnackbar(message: message),
      ),
    );

    overlay.insert(overlayEntry);

    Future.delayed(const Duration(seconds: 3), () {
      overlayEntry.remove();
    });
  }

  Future<Uint8List> captureWidgetToImage() async {
    try {
      RenderRepaintBoundary boundary = _globalKey.currentContext!
          .findRenderObject() as RenderRepaintBoundary;

      // Determine pixel ratio for high-resolution output
      double pixelRatio =
          1080 / boundary.size.width; // A4 height in pixels / widget height
      var image = await boundary.toImage(
        pixelRatio: pixelRatio,
      );
      ByteData? byteData = await image.toByteData(format: ImageByteFormat.png);
      if (byteData == null) {
        throw Exception("Failed to capture widget to image.");
      }
      return byteData.buffer.asUint8List();
    } catch (e) {
      throw Exception("Error capturing image: $e");
    }
  }

  Future<void> exportToPdf(String fileName, Uint8List imageBytes) async {
    setState(() {
      isLoading = true;
    });
    try {
      final pdf = pw.Document();
      final image = pw.MemoryImage(imageBytes);

      final pageFormat = PdfPageFormat.a4.copyWith(
        marginLeft: 0,
        marginRight: 0,
        marginTop: 0,
        marginBottom: 0,
      );

      pdf.addPage(
        pw.Page(
          pageFormat: pageFormat,
          build: (context) {
            return pw.Center(
              child: pw.Image(
                image,
                fit: pw.BoxFit.contain,
              ),
            );
          },
        ),
      );

      final rootDirectory = await getApplicationDocumentsDirectory();
      String appSpecificPath = "${rootDirectory.path}/Doc Scanner/ID Card";
      Directory directory = Directory(appSpecificPath);

      if (!await directory.exists()) {
        await directory.create(recursive: true);
      }

      String fullFilePath = "$appSpecificPath/$fileName.pdf";
      File pdfFile = File(fullFilePath);

      // Check if file already exists
      if (await pdfFile.exists()) {
        String newFileName = fileName;
        int counter = 1;

        // Loop to find a unique name
        while (await File("$appSpecificPath/$newFileName.pdf").exists()) {
          newFileName = "$fileName($counter)";
          counter++;
        }
        print("NewFile $newFileName");

        // Show popup dialog
        await showDialog(
          context: context,
          builder: (context) {
            return AlertDialog(
              title: const Text("File Already Exists"),
              content: const Text(
                  "This file already exists. Do you want to create a duplicate file?"),
              actions: [
                TextButton(
                  onPressed: () async {
                    // Save with new name
                    if (Platform.isIOS) {
                      Directory iosDocumentsDirectory =
                          await getApplicationDocumentsDirectory();
                      File iOSExternalFile = File(
                          "${iosDocumentsDirectory.path}/Doc Scanner/ID Card/$newFileName.pdf");

                      final pdfBytes = await pdf.save();
                      await iOSExternalFile.writeAsBytes(pdfBytes);
                      debugPrint("PDF saved to iOS: ${iOSExternalFile.path}");
                    } else if (Platform.isAndroid) {
                      final externalStorageDirectory =
                          Directory('/storage/emulated/0/Documents/IDCard');
                      if (!await externalStorageDirectory.exists()) {
                        await externalStorageDirectory.create(recursive: true);
                      }
                      File externalFile = File(
                          "${externalStorageDirectory.path}/$newFileName.pdf");
                      pdfFile = File("$appSpecificPath/$newFileName.pdf");
                      await pdfFile.writeAsBytes(await pdf.save());
                      // Save the PDF in the general "Documents" folder

                      // Write to both locations
                      final pdfBytes = await pdf.save();
                      await externalFile.writeAsBytes(pdfBytes);
                    }

                    await MetaEventsHelper.logPdfCreated();
                    setState(() {
                      isLoading = false;
                      Navigator.pop(context);
                      Navigator.pop(context);
                    });
                  },
                  child: const Text("Create Duplicate"),
                ),
                TextButton(
                  onPressed: () {
                    // Cancel action
                    Navigator.pop(context); // Close dialog
                    setState(() {
                      isLoading = false;
                    });
                  },
                  child: const Text("Cancel"),
                ),
              ],
            );
          },
        );
      } else {
        // Save directly if file does not exist
        await pdfFile.writeAsBytes(await pdf.save());

        // Save the PDF in the general "Documents" folder
        if (Platform.isIOS) {
          Directory iosDocumentsDirectory =
              await getApplicationDocumentsDirectory();
          File iOSExternalFile = File(
              "${iosDocumentsDirectory.path}/Doc Scanner/ID Card/$fileName.pdf");

          final pdfBytes = await pdf.save();
          await iOSExternalFile.writeAsBytes(pdfBytes);
          debugPrint("PDF saved to iOS: ${iOSExternalFile.path}");
        } else if (Platform.isAndroid) {
          final externalStorageDirectory =
              Directory('/storage/emulated/0/Documents/IDCard');
          if (!await externalStorageDirectory.exists()) {
            await externalStorageDirectory.create(recursive: true);
          }
          File externalFile =
              File("${externalStorageDirectory.path}/$fileName.pdf");

          // Write to both locations
          final pdfBytes = await pdf.save();
          await externalFile.writeAsBytes(pdfBytes);
        }

        await MetaEventsHelper.logPdfCreated();
        setState(() {
          isLoading = false;
        });
      }
    } catch (e) {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text('Failed to save PDF: $e')),
      );
      setState(() {
        isLoading = false;
      });
    }
  }

  Future<void> saveImageToFile(Uint8List imageBytes) async {
    try {
      final rootDirectory = await getApplicationDocumentsDirectory();
      String path = "${rootDirectory.path}/Doc Scanner/ID Card";
      Directory directory = Directory(path);

      // Ensure the directory exists
      if (!directory.existsSync()) {
        directory.createSync(recursive: true);
      }

      // Check if a file with the same name already exists
      String filePath = '$path/$fileName.jpg';
      File file = File(filePath);

      if (file.existsSync()) {
        bool shouldCreateDuplicate = await showDuplicateFileDialog();
        if (!shouldCreateDuplicate) {
          print('User canceled the save operation.');
          return;
        }

        // Modify the file name to create a duplicate
        String baseName = fileName;
        int counter = 1;
        while (file.existsSync()) {
          filePath = '$path/${baseName}_$counter.jpg';
          file = File(filePath);
          counter++;
        }
      }

      // Save the file
      await file.writeAsBytes(imageBytes);
      Gal.putImage(file.path);
      print('Image saved at ${file.path}');
    } catch (e) {
      print("Error saving image: $e");
    }
  }

  Future<bool> showDuplicateFileDialog() async {
    return await showDialog<bool>(
          context: context,
          builder: (BuildContext context) {
            return AlertDialog(
              title: const Text("File Already exists"),
              content: const Text(
                  "A file with the same name already exists. Do you want to create a duplicate file?"),
              actions: <Widget>[
                TextButton(
                  onPressed: () => Navigator.of(context).pop(false),
                  child: const Text("Cancel"),
                ),
                TextButton(
                  onPressed: () => Navigator.of(context).pop(true),
                  child: const Text("Create Duplicate"),
                ),
              ],
            );
          },
        ) ??
        false; // Return false if dialog is dismissed without selection
  }

  @override
  Widget build(BuildContext context) {
    final cameraProvider = context.watch<CameraProvider>();
    final size = MediaQuery.sizeOf(context);
    // return PopScope(
    //   canPop: true,
    // onPopInvoked: (didPop) async {
    // await Navigator.pushAndRemoveUntil(context, MaterialPageRoute(
    //   builder: (context) {
    //     return const BottomBar();
    //   },
    // ), (route) => false)
    //     .then((value) => cameraProvider.clearIdCardImages());
    // },
    //   child:
    return PopScope(
      canPop: false,
      onPopInvoked: (didPop) {
        showGoogleAlertDialogue(
            context: context,
            title: 'Discard document?',
            content: 'If you leave now, your progress will be lost',
            onOkText: 'Discard',
            onCancelText: 'keep editing',
            onOk: () {
              cameraProvider.clearImageList();
              setState(() {
                didPop = true;
              });
              Navigator.pushAndRemoveUntil(context, MaterialPageRoute(
                builder: (context) {
                  return const BottomBar();
                },
              ), (route) => false)
                  .then((value) => cameraProvider.clearIdCardImages());
            },
            onCancel: () {
              Navigator.pop(context);
            });
      },
      child: Scaffold(
        appBar: AppBar(
          backgroundColor: const Color(0xff1E1F20),
          centerTitle: true,
          leading: IconButton(
            icon: const Icon(
              Icons.arrow_back_ios_new_rounded,
              color: Colors.white,
            ),
            onPressed: () async {
              showGoogleAlertDialogue(
                  context: context,
                  title: 'Discard document?',
                  content: 'If you leave now, your progress will be lost',
                  onOkText: 'Discard',
                  onCancelText: 'keep editing',
                  onOk: () async {
                    cameraProvider.clearImageList();

                    cameraProvider.clearIdCardImages();
                    await Navigator.pushAndRemoveUntil(context,
                        MaterialPageRoute(
                      builder: (context) {
                        return const BottomBar();
                      },
                    ), (route) => false);
                  },
                  onCancel: () {
                    Navigator.pop(context);
                  });
            },
          ),
          title: Text(
            translation(context).idCardImagePreview,
            style: const TextStyle(
                fontSize: 16, fontWeight: FontWeight.w500, color: Colors.white),
          ),
          actions: [
            GestureDetector(
              onTap: () async {
                setState(() {
                  _selectedBeforeExport = selectedImageIndex;
                  selectedImageIndex = null;
                });
                await showGeneralDialog(
                  context: context,
                  barrierDismissible: true,
                  barrierLabel: '',
                  transitionDuration: const Duration(milliseconds: 300),
                  pageBuilder: (context, animation, secondaryAnimation) {
                    return Align(
                      alignment: Alignment.bottomCenter,
                      child: Container(
                        height:AppHelper.isIpad(context)? MediaQuery.sizeOf(context).height * 0.29:MediaQuery.sizeOf(context).height * 0.35,
                        width: MediaQuery.sizeOf(context).width,
                        decoration: const BoxDecoration(
                            borderRadius: BorderRadius.only(
                              topLeft: Radius.circular(20),
                              topRight: Radius.circular(20),
                            ),
                            color: Colors.white),
                        child: Column(
                          children: [
                            Padding(
                              padding: const EdgeInsets.symmetric(horizontal: 10)
                                  .copyWith(top: 20, bottom: 10),
                              child: Row(
                                crossAxisAlignment: CrossAxisAlignment.center,
                                mainAxisAlignment: MainAxisAlignment.spaceBetween,
                                children: [
                                  const Text(''),
                                  Text(
                                    translation(context).documentFiles,
                                    style: const TextStyle(
                                      color: Colors.black,
                                      decoration: TextDecoration.none,
                                      fontSize: 20,
                                      fontWeight: FontWeight.w500,
                                    ),
                                  ),
                                  Container(
                                    height: size.width >= 600 ? 40 : 30,
                                    width: size.width >= 600 ? 40 : 30,
                                    alignment: Alignment.center,
                                    decoration: const BoxDecoration(
                                      color: Color(0xFFF4F4F4),
                                      shape: BoxShape.circle,
                                    ),
                                    child: Material(
                                      color: Colors.transparent,
                                      child: InkWell(
                                        borderRadius: BorderRadius.circular(30),
                                        onTap: () {
                                          Navigator.pop(context);
                                          setState(() {
                                            selectedImageIndex = _selectedBeforeExport;
                                          });
                                        },
                                        child: Icon(
                                          Icons.close_rounded,
                                          size: size.width >= 600 ? 30 : 20,
                                        ),
                                      ),
                                    ),
                                  ),
                                ],
                              ),
                            ),
                            Divider(
                              color: Colors.grey[200],
                              thickness: 1,
                              // indent: MediaQuery.sizeOf(context).width * 0.15,
                            ),
                            Material(
                              color: Colors.transparent,
                              child: InkWell(
                                onTap: () async {
                                  TextEditingController renameController =
                                      TextEditingController(text: fileName);
                                  showDialog(
                                    context: context,
                                    builder: (context) => AlertDialog(
                                      constraints: BoxConstraints.tightFor(
                                        width: MediaQuery.sizeOf(context).shortestSide >= 600
                                            ? 398
                                            : 348,
                                      ),
                                      title:
                                          SizedBox(
                                              width: AppHelper.isIpad(context)?350:300,
                                              child: Text(translation(context).renameFile)),
                                      content: TextFormField(
                                        controller: renameController,
                                        keyboardType: TextInputType.text,
                                        textInputAction: TextInputAction.done,
                                        autofocus: true,
                                        decoration: const InputDecoration(
                                          hintText: "",
                                          border: OutlineInputBorder(),
                                        ),
                                      ),
                                      actions: [
                                        TextButton(
                                          onPressed: () {
                                            if (renameController
                                                .text.isNotEmpty) {
                                              setState(() {
                                                fileName =
                                                    renameController.text.trim();
                                              });
                                              Navigator.pop(context);
                                            }
                                          },
                                          child: Text(translation(context).ok),
                                        ),
                                        TextButton(
                                          onPressed: () => Navigator.pop(context),
                                          child:
                                              Text(translation(context).cancel),
                                        ),
                                      ],
                                    ),
                                  );
                                },
                                child: Padding(
                                  padding: const EdgeInsets.symmetric(
                                      horizontal: 20.0, vertical: 5),
                                  child: Row(
                                    children: [
                                      Icon(
                                        Icons.edit_outlined,
                                        color: Colors.black,
                                        size: size.width >= 600 ? 30 : 20,
                                      ),
                                      const SizedBox(
                                        width: 20,
                                      ),
                                      Text(
                                        translation(context).renameFile,
                                        style: const TextStyle(
                                          color: Colors.black,
                                          fontSize: 16,
                                          fontWeight: FontWeight.w400,
                                        ),
                                      ),
                                    ],
                                  ),
                                ),
                              ),
                            ),
                            Divider(
                              color: Colors.grey[200],
                              thickness: 1,
                              // indent: MediaQuery.sizeOf(context).width * 0.15,
                            ),
                            //export image
                            Material(
                              color: Colors.transparent,
                              child: InkWell(
                                onTap: () async {
                                  showNormalAlertDialogue(
                                    context: context,
                                    title: translation(context).saveImages,
                                    content: translation(context)
                                        .doYouWantSaveAllImages,
                                    onOkText: translation(context).save,
                                    onCancelText: translation(context).cancel,
                                    onOk: () async {
                                      try {
                                        Uint8List imageBytes =
                                            await captureWidgetToImage();
                                        await saveImageToFile(imageBytes);
                                        cameraProvider.clearIdCardImages();

                                        Navigator.pushAndRemoveUntil(context,
                                            MaterialPageRoute(
                                          builder: (context) {
                                            return const BottomBar(
                                              shouldShowReview: true,
                                            );
                                          },
                                        ), (route) => false);
                                      } catch (e) {
                                        print("Error: $e");
                                      }
                                    },
                                    onCancel: () => Navigator.pop(context),
                                  );
                                },
                                child: Padding(
                                  padding: const EdgeInsets.symmetric(
                                      horizontal: 20.0, vertical: 5),
                                  child: Row(
                                    children: [
                                      Icon(
                                        Icons.ios_share_outlined,
                                        color: Colors.black,
                                        size: size.width >= 600 ? 30 : 20,
                                      ),
                                      const SizedBox(
                                        width: 20,
                                      ),
                                      Text(
                                        translation(context).exportImages,
                                        style: const TextStyle(
                                          color: Colors.black,
                                          fontSize: 16,
                                          fontWeight: FontWeight.w400,
                                        ),
                                      ),
                                    ],
                                  ),
                                ),
                              ),
                            ),
                            Divider(
                              color: Colors.grey[200],
                              thickness: 1,
                              // indent: MediaQuery.sizeOf(context).width * 0.15,
                            ),
                            Material(
                              color: Colors.transparent,
                              child: InkWell(
                                onTap: () async {
                                  await showDialog(
                                    context: context,

                                    builder: (context) {
                                      TextEditingController renameController =
                                          TextEditingController();
                                      // State to track saving progress

                                      return StatefulBuilder(
                                        builder: (context, setState) {
                                          return AlertDialog(
                                            constraints: BoxConstraints.tightFor(
                                              width: AppHelper.isIpad(context) ? 398 : 348,
                                            ),
                                            title: SizedBox(
                                              width: AppHelper.isIpad(context)?350:300,

                                              child: Text(
                                                  translation(context).savePdf),
                                            ),
                                            content: isSaving
                                                ? ConstrainedBox(
                                                    constraints:
                                                        const BoxConstraints(
                                                            maxHeight: 40,
                                                            maxWidth: 40),
                                                    child: const Center(
                                                      child:
                                                          CircularProgressIndicator(),
                                                    ),
                                                  )
                                                : TextFormField(
                                                    controller: renameController,
                                                    keyboardType:
                                                        TextInputType.text,
                                                    textInputAction:
                                                        TextInputAction.done,
                                                    autofocus: true,
                                                    validator: (value) {
                                                      if (value!.isEmpty) {
                                                        return translation(
                                                                context)
                                                            .pleaseEnterFileName;
                                                      }
                                                      return null;
                                                    },
                                                    decoration: InputDecoration(
                                                      hintText:
                                                          translation(context)
                                                              .enterFileName,
                                                      border:
                                                          const OutlineInputBorder(
                                                        borderSide: BorderSide(
                                                            color: AppColor
                                                                .primaryColor),
                                                      ),
                                                      contentPadding:
                                                          const EdgeInsets
                                                              .symmetric(
                                                              horizontal: 10),
                                                    ),
                                                  ),
                                            actions: [
                                              if (!isSaving) // Only show buttons when not saving
                                                TextButton(
                                                  onPressed: () async {
                                                    if (renameController
                                                        .text.isNotEmpty) {
                                                      setState(() {
                                                        isSaving =
                                                            true; // Show progress indicator
                                                      });
                                                      Uint8List imageBytes =
                                                          await captureWidgetToImage();
                                                      await exportToPdf(
                                                          renameController.text
                                                              .trim(),
                                                          imageBytes);

                                                      cameraProvider
                                                          .clearIdCardImages();
                                                      Navigator
                                                          .pushAndRemoveUntil(
                                                        context,
                                                        MaterialPageRoute(
                                                          builder: (context) {
                                                            return const BottomBar();
                                                          },
                                                        ),
                                                        (route) => false,
                                                      ).then(
                                                        (value) {
                                                          setState(() {
                                                            isSaving =
                                                                false; // Hide progress indicator
                                                          });
                                                        },
                                                      );
                                                      showTopSnackbar(context,
                                                          "PDF save successfully in Document Folder");
                                                    }
                                                  },
                                                  child: Text(
                                                      translation(context).ok),
                                                ),
                                              if (!isSaving)
                                                TextButton(
                                                  onPressed: () {
                                                    Navigator.pop(
                                                        context); // Close dialog
                                                  },
                                                  child: Text(translation(context)
                                                      .cancel),
                                                ),
                                            ],
                                          );
                                        },
                                      );
                                    },
                                  );
                                },
                                child: Padding(
                                  padding: const EdgeInsets.symmetric(
                                      horizontal: 20.0, vertical: 5),
                                  child: Row(
                                    children: [
                                      Icon(
                                        Icons.picture_as_pdf_outlined,
                                        color: Colors.black,
                                        size: size.width >= 600 ? 30 : 20,
                                      ),
                                      const SizedBox(
                                        width: 20,
                                      ),
                                      Text(
                                        translation(context).exportAsPdf,
                                        style: const TextStyle(
                                          color: Colors.black,
                                          fontSize: 16,
                                          fontWeight: FontWeight.w400,
                                        ),
                                      ),
                                    ],
                                  ),
                                ),
                              ),
                            ),
                          ],
                        ),
                      ),
                    );
                  },
                );
              },
              child: Text(
                "${translation(context).option}   ",
                style: const TextStyle(
                  fontSize: 15,
                  fontWeight: FontWeight.w500,
                  color: AppColor.primaryColor,
                ),
              ),
            ),
          ],
        ),
        backgroundColor: Colors.grey,
        bottomNavigationBar: SafeArea(
          top: false,
          left: false,
          right: false,
          child: BannerAdWidget(
            adUnitId: AdHelper.idCardImageViewBannerAdUnitId,
          ),
        ),
        body: isLoading
            ? const Center(child: CircularProgressIndicator())
            : SingleChildScrollView(
                child: Column(
                  mainAxisAlignment: MainAxisAlignment.center,
                  children: [
                    Container(
                      height: MediaQuery.of(context).size.height * 0.09,
                      color: Colors.grey,
                    ),
                    RepaintBoundary(
                      key: _globalKey, // Assign the global key
                      child: Center(
                        child: Container(
                          height: MediaQuery.of(context).size.height * 0.665,
                          color: Colors.white,
                          child: Stack(
                            children:
                                imageProperties.asMap().entries.map((entry) {
                              final index = entry.key;
                              final imageProps = entry.value;

                              return InteractiveBox(
                                key: ValueKey('id_card_image_$index'),
                                initialPosition: imageProps['position'],
                                initialSize: imageProps['size'],
                                initialShowActionIcons: selectedImageIndex == index,
                                toggleBy: null,
                                includedScaleDirections: const [
                                  ScaleDirection.topRight,
                                  ScaleDirection.bottomRight,
                                  ScaleDirection.bottomLeft,
                                  ScaleDirection.topLeft,
                                ],
                                includedActions: selectedImageIndex == index
                                    ? const [
                                        ControlActionType.move,
                                        ControlActionType.scale,
                                        ControlActionType.rotate,
                                      ]
                                    : const [
                                      ControlActionType.move,
                                ],
                                onTap: () {
                                  setState(() {
                                    selectedImageIndex =
                                    selectedImageIndex == index
                                        ? null
                                        : index;
                                  });
                                },
                                onActionSelected: (ControlActionType actionType,
                                    InteractiveBoxInfo info) {
                                  setState(() {
                                    if (actionType ==
                                        ControlActionType.delete) {
                                      imageProperties.removeAt(index);
                                      if (selectedImageIndex == index) {
                                        selectedImageIndex =
                                        imageProperties.isEmpty
                                            ? null
                                            : 0;
                                      } else if (selectedImageIndex != null &&
                                          selectedImageIndex! > index) {
                                        selectedImageIndex =
                                            selectedImageIndex! - 1;
                                      }
                                    } else {
                                      imageProperties[index]['position'] =
                                          info.position;
                                      imageProperties[index]['size'] =
                                          info.size;
                                    }
                                  });
                                },
                                child: Image.file(
                                  File(imageProps['path']),
                                  fit: BoxFit.contain,
                                ),
                              );
                            }).toList(),
                          ),
                        ),
                      ),
                    ),
                  ],
                ),
              ),
      ),
    );
  }
}
