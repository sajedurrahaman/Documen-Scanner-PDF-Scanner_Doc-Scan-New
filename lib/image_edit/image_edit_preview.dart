// ignore_for_file: use_build_context_synchronously

import 'dart:io';
import 'dart:typed_data';
import 'package:doc_scanner/image_edit/text_recognition_screen.dart';
import 'package:doc_scanner/image_edit/widget/image_edit_button.dart';
import 'package:doc_scanner/utils/addHelper.dart';
import 'package:doc_scanner/utils/app_color.dart';
import 'package:doc_scanner/utils/banner_ad_widget.dart';
import 'package:doc_scanner/utils/utils.dart';
import 'package:flutter/material.dart';
import 'package:flutter_svg/svg.dart';
import 'package:google_mlkit_text_recognition/google_mlkit_text_recognition.dart';
import 'package:path_provider/path_provider.dart';
import 'package:provider/provider.dart';
import 'package:share_plus/share_plus.dart';
import '../bottom_bar/bottom_bar.dart';
import '../camera_screen/model/image_model.dart';
import '../camera_screen/provider/camera_provider.dart';
import '../localaization/language_constant.dart';
import '../utils/app_assets.dart';
import '../utils/helper.dart';
import 'add_sgnature_screen.dart';
import 'image_edit_screen.dart';

class EditImagePreview extends StatefulWidget {
  const EditImagePreview({super.key});

  @override
  State<EditImagePreview> createState() => _EditImagePreviewState();
}

class _EditImagePreviewState extends State<EditImagePreview> {
  int _currentIndex = 0;
  bool isSaving = false;
  final PageController _pageController = PageController();
  final TextEditingController _renameController = TextEditingController();
  final _formKey = GlobalKey<FormState>();

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

  Future<String> getUniqueFileName(String baseSavePath, String fileName) async {
    int counter = 1;
    String uniqueFileName = fileName;
    String uniqueSavePath = '$baseSavePath/$uniqueFileName.pdf';

    while (await File(uniqueSavePath).exists()) {
      uniqueFileName = '${fileName}_$counter';
      uniqueSavePath = '$baseSavePath/$uniqueFileName.pdf';
      counter++;
    }

    return uniqueSavePath;
  }

  @override
  Widget build(BuildContext context) {
    final cameraProvider = context.watch<CameraProvider>();
    final size = MediaQuery.sizeOf(context);
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
                ), (route) => false);
              },
              onCancel: () {
                Navigator.pop(context);
              });
        },
        child: Scaffold(
          backgroundColor: const Color(0xFF131314),
          appBar: AppBar(
            backgroundColor: const Color(0xff1E1F20),
            centerTitle: true,
            leading: IconButton(
                onPressed: () {
                  showGoogleAlertDialogue(
                      context: context,
                      title: 'Discard document?',
                      content: 'If you leave now, your progress will be lost',
                      onOkText: 'Discard',
                      onCancelText: 'keep editing',
                      onOk: () {
                        cameraProvider.clearImageList();
                        Navigator.pushAndRemoveUntil(context, MaterialPageRoute(
                          builder: (context) {
                            return const BottomBar();
                          },
                        ), (route) => false);
                      },
                      onCancel: () {
                        Navigator.pop(context);
                      });
                },
                icon: const Icon(
                  Icons.arrow_back,
                  color: Color(0xffffffff),
                )),
            title: cameraProvider.imageList.isEmpty
                ? Text(
                    translation(context).pleaseTakePhoto,
                    style: const TextStyle(
                        fontSize: 20,
                        fontWeight: FontWeight.w500,
                        color: Colors.white),
                  )
                : Text(
                    cameraProvider.imageList[_currentIndex].name,
                    style: const TextStyle(
                        fontSize: 20,
                        fontWeight: FontWeight.w500,
                        color: Colors.white),
                  ),
            titleTextStyle: const TextStyle(
              color: Colors.black,
              fontSize: 16,
              fontWeight: FontWeight.bold,
            ),
            actions: [
              TextButton(
                onPressed: () async {
                  if (cameraProvider.imageList.isNotEmpty) {
                    await showGeneralDialog(
                      context: context,
                      barrierDismissible: true,
                      barrierLabel: '',
                      transitionDuration: const Duration(milliseconds: 300),
                      pageBuilder: (context, animation, secondaryAnimation) {
                        return Align(
                          alignment: Alignment.bottomCenter,
                          child: Container(
                            height:AppHelper.isIpad(context)? MediaQuery.sizeOf(context).height * 0.3: MediaQuery.sizeOf(context).height * 0.35,
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
                                  padding:
                                      const EdgeInsets.symmetric(horizontal: 10)
                                          .copyWith(top: 20, bottom: 10),
                                  child: Row(
                                    crossAxisAlignment: CrossAxisAlignment.center,
                                    mainAxisAlignment:
                                        MainAxisAlignment.spaceBetween,
                                    children: [
                                      const Text(''),
                                      Text(
                                        translation(context).documentFiles,
                                        style: const TextStyle(
                                          color: Colors.black,
                                          fontSize: 20,
                                          decoration: TextDecoration.none,
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
                                            borderRadius:
                                                BorderRadius.circular(30),
                                            onTap: () {
                                              Navigator.pop(context);
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
                                ),
                                Material(
                                  color: Colors.transparent,
                                  child: InkWell(
                                    onTap: () async {
                                      Navigator.pop(context);
                                      _renameController.text = cameraProvider
                                          .imageList[_currentIndex].name;
                                      showDialog(
                                        context: context,
                                        builder: (context) {
                                          String errorMessage = '';
                                          return StatefulBuilder(
                                              builder: (context, setState) {
                                            return AlertDialog(
                                              title: SizedBox(
                                                width: AppHelper.isIpad(context)?300:250,
                                                child: Text(
                                                  translation(context).renameFile,
                                                  style: const TextStyle(
                                                    color: Colors.black,
                                                    fontSize: 16,
                                                    fontWeight: FontWeight.w500,
                                                  ),
                                                ),
                                              ),
                                              content: Form(
                                                key: _formKey,
                                                child: TextFormField(
                                                  controller: _renameController,
                                                  keyboardType:
                                                      TextInputType.text,
                                                  textInputAction:
                                                      TextInputAction.done,
                                                  autofocus: true,
                                                  validator: (value) {
                                                    if (value!.isEmpty) {
                                                      return translation(context)
                                                          .pleaseEnterFileName;
                                                    }
                                                    return null;
                                                  },
                                                  decoration: InputDecoration(
                                                    errorText:
                                                        errorMessage.isEmpty
                                                            ? null
                                                            : errorMessage,
                                                    hintText: translation(context)
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
                                              ),
                                              actions: [
                                                TextButton(
                                                    onPressed: () =>
                                                        Navigator.pop(context),
                                                    child: Text(
                                                        translation(context)
                                                            .cancel)),
                                                TextButton(
                                                    onPressed: () async {
                                                      if (_formKey.currentState!
                                                          .validate()) {
                                                        bool isNameAlreadyExists = cameraProvider
                                                            .imageList
                                                            .any((image) =>
                                                                image.name ==
                                                                    _renameController
                                                                        .text &&
                                                                image !=
                                                                    cameraProvider
                                                                            .imageList[
                                                                        _currentIndex]);

                                                        if (isNameAlreadyExists) {
                                                          // Show confirmation popup for creating a duplicate name
                                                          bool allowDuplicate =
                                                              await showDialog<
                                                                      bool>(
                                                                    context:
                                                                        context,
                                                                    builder:
                                                                        (context) {
                                                                      return AlertDialog(
                                                                        title: const Text(
                                                                            "File Already Exist"),
                                                                        content:
                                                                            const Text(
                                                                                "This file already exists. Do you want to create a duplicate file?"),
                                                                        actions: [
                                                                          TextButton(
                                                                            onPressed: () => Navigator.pop(
                                                                                context,
                                                                                false),
                                                                            child:
                                                                                Text(translation(context).cancel),
                                                                          ),
                                                                          TextButton(
                                                                            onPressed: () => Navigator.pop(
                                                                                context,
                                                                                true),
                                                                            child:
                                                                                const Text("Allow Duplicate"),
                                                                          ),
                                                                        ],
                                                                      );
                                                                    },
                                                                  ) ??
                                                                  false;

                                                          if (allowDuplicate) {
                                                            // Generate a unique name
                                                            String uniqueName =
                                                                _renameController
                                                                    .text;
                                                            int counter = 1;
                                                            while (cameraProvider
                                                                .imageList
                                                                .any((image) =>
                                                                    image.name ==
                                                                    uniqueName)) {
                                                              uniqueName =
                                                                  "${_renameController.text}$counter";
                                                              counter++;
                                                            }

                                                            // Update image with the unique name
                                                            cameraProvider
                                                                .updateImage(
                                                              index:
                                                                  _currentIndex,
                                                              image: ImageModel(
                                                                imageByte:
                                                                    cameraProvider
                                                                        .imageList[
                                                                            _currentIndex]
                                                                        .imageByte,
                                                                name: uniqueName,
                                                                docType: cameraProvider
                                                                    .imageList[
                                                                        _currentIndex]
                                                                    .docType,
                                                              ),
                                                            );

                                                            Navigator.pop(
                                                                context);
                                                          }
                                                        } else if (cameraProvider
                                                                .imageList
                                                                .first
                                                                .docType ==
                                                            "ID Card") {
                                                          Directory
                                                              rootDirectory =
                                                              await getApplicationDocumentsDirectory();
                                                          String path =
                                                              "${rootDirectory.path}/Doc Scanner/ID Card";
                                                          File file = File(
                                                              "$path/${_renameController.text}.jpg");
                                                          if (file.existsSync()) {
                                                            setState(() {
                                                              errorMessage =
                                                                  translation(
                                                                          context)
                                                                      .fileAlreadyExists;
                                                            });
                                                          } else {
                                                            cameraProvider
                                                                .updateImage(
                                                              index:
                                                                  _currentIndex,
                                                              image: ImageModel(
                                                                imageByte:
                                                                    cameraProvider
                                                                        .imageList[
                                                                            _currentIndex]
                                                                        .imageByte,
                                                                name:
                                                                    _renameController
                                                                        .text,
                                                                docType: cameraProvider
                                                                    .imageList[
                                                                        _currentIndex]
                                                                    .docType,
                                                              ),
                                                            );

                                                            Navigator.pop(
                                                                context);
                                                          }
                                                        } else {
                                                          Directory
                                                              rootDirectory =
                                                              await getApplicationDocumentsDirectory();
                                                          String path =
                                                              "${rootDirectory.path}/Doc Scanner/Document";
                                                          File file = File(
                                                              "$path/${_renameController.text}.jpg");
                                                          if (file.existsSync()) {
                                                            setState(() {
                                                              errorMessage =
                                                                  translation(
                                                                          context)
                                                                      .fileAlreadyExists;
                                                            });
                                                          } else {
                                                            cameraProvider
                                                                .updateImage(
                                                              index:
                                                                  _currentIndex,
                                                              image: ImageModel(
                                                                imageByte:
                                                                    cameraProvider
                                                                        .imageList[
                                                                            _currentIndex]
                                                                        .imageByte,
                                                                name:
                                                                    _renameController
                                                                        .text,
                                                                docType: cameraProvider
                                                                    .imageList[
                                                                        _currentIndex]
                                                                    .docType,
                                                              ),
                                                            );

                                                            Navigator.pop(
                                                                context);
                                                          }
                                                        }
                                                      }
                                                    },
                                                    child: Text(
                                                        translation(context)
                                                            .save)),
                                              ],
                                            );
                                          });
                                        },
                                      );
                                    },
                                    child: Padding(
                                      padding: const EdgeInsets.symmetric(
                                          horizontal: 20.0, vertical: 5),
                                      child: Row(
                                        children: [
                                          SvgPicture.asset(
                                            AppAssets.rename,
                                            color: Colors.black,
                                            height: size.width >= 600 ? 30 : 20,
                                            width: size.width >= 600 ? 30 : 20,
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
                                  indent: MediaQuery.sizeOf(context).width * 0.15,
                                ),
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
                                          await cameraProvider
                                              .exportAllImages()
                                              .then((value) {
                                            cameraProvider.clearImageList();
                                            Navigator.pushAndRemoveUntil(context,
                                                MaterialPageRoute(
                                              builder: (context) {
                                                return const BottomBar(
                                                  shouldShowReview: true,
                                                );
                                              },
                                            ), (route) => false);
                                            showTopSnackbar(
                                                context,
                                                translation(context)
                                                    .allImagesSavedSuccessfully);
                                          });
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
                                  indent: MediaQuery.sizeOf(context).width * 0.15,
                                ),
                                Material(
                                  color: Colors.transparent,
                                  child: InkWell(
                                    onTap: () async {
                                      await showDialog(
                                        context: context,
                                        builder: (context) {
                                          final cameProvider =
                                              context.watch<CameraProvider>();
                                          TextEditingController renameController =
                                              TextEditingController();
                                          return StatefulBuilder(
                                            builder: (context, setState) {
                                              return AlertDialog(
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
                                                        controller:
                                                            renameController,
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
                                                        decoration:
                                                            InputDecoration(
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
                                                actions: isSaving
                                                    ? []
                                                    : [
                                                        TextButton(
                                                          onPressed: () async {
                                                            if (renameController
                                                                .text
                                                                .isEmpty) {
                                                              return;
                                                            }
                                                            setState(() {
                                                              isSaving = true;
                                                            });
                                                            try {
                                                              await cameProvider
                                                                  .createPDFFromByte(
                                                                context:
                                                                    context,
                                                                fileName:
                                                                    renameController
                                                                        .text,
                                                              );
                                                              if (!context
                                                                  .mounted) {
                                                                return;
                                                              }
                                                              cameraProvider
                                                                  .clearImageList();
                                                              showTopSnackbar(
                                                                context,
                                                                "PDF save sasuccessfully in Document Folder",
                                                              );
                                                              Navigator
                                                                  .pushAndRemoveUntil(
                                                                context,
                                                                MaterialPageRoute(
                                                                  builder:
                                                                      (context) {
                                                                    return const BottomBar(
                                                                      shouldShowReview:
                                                                          true,
                                                                    );
                                                                  },
                                                                ),
                                                                (route) =>
                                                                    false,
                                                              );
                                                            } catch (_) {
                                                              if (context
                                                                  .mounted) {
                                                                setState(() {
                                                                  isSaving =
                                                                      false;
                                                                });
                                                              }
                                                            }
                                                          },
                                                          style:
                                                              const ButtonStyle(
                                                            splashFactory: InkSparkle
                                                                .splashFactory, // Disable splash effect
                                                          ),
                                                          child: Text(
                                                              translation(context)
                                                                  .ok),
                                                        ),
                                                        TextButton(
                                                          onPressed: () {
                                                            Navigator.pop(
                                                                context);
                                                          },
                                                          child: Text(
                                                              translation(context)
                                                                  .cancel),
                                                        )
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
                      transitionBuilder: (context, animation, secondaryAnimation, child) {
                        return SlideTransition(
                          position: Tween<Offset>(
                            begin: const Offset(0, 1),
                            end: Offset.zero,
                          ).animate(CurvedAnimation(
                            parent: animation,
                            curve: Curves.easeOut,
                          )),
                          child: child,
                        );
                      },
                    );
                  }
                },
                child: Text(
                  translation(context).option,
                  style: const TextStyle(
                    fontSize: 15,
                    fontWeight: FontWeight.w500,
                    color: AppColor.primaryColor,
                  ),
                ),
              ),
            ],
          ),
          body: Column(
            children: [
              cameraProvider.imageList.isEmpty
                  ? Expanded(
                      child: Center(
                        child: Text(
                          translation(context).noImageFound,
                        ),
                      ),
                    )
                  : Expanded(
                      child: PageView.builder(
                        controller: _pageController,
                        itemCount: cameraProvider.imageList.length,
                        onPageChanged: (index) {
                          setState(() {
                            _currentIndex = index;
                          });
                        },
                        itemBuilder: (context, index) {
                          return Padding(
                            padding: const EdgeInsets.all(10),
                            child: Image.memory(
                              cameraProvider.imageList[index].imageByte,
                              fit: BoxFit.contain,
                            ),
                          );
                        },
                      ),
                    ),
              Container(
                padding:
                    const EdgeInsets.symmetric(horizontal: 20.0, vertical: 3),
                child: Text(
                  '${_currentIndex + 1}/${cameraProvider.imageList.length}',
                  style: const TextStyle(
                      color: Colors.white,
                      fontSize: 14,
                      fontWeight: FontWeight.w400),
                ),
              ),
            ],
          ),
          bottomNavigationBar: BottomBarWithBanner(
            adUnitId: AdHelper.imageEditPreviewBannerAdUnitId,
            child: BottomAppBar(
            color: const Color(0xff1E1F20),
            padding: const EdgeInsets.symmetric(horizontal: 10.0),
            surfaceTintColor: const Color(0xff1E1F20),
            child: Row(
              mainAxisAlignment: MainAxisAlignment.spaceBetween,
              children: [
                ImageEditButton(
                  title: translation(context).share,
                  onTap: () async {
                    await AppHelper()
                        .convertUint8ListToFile(
                            data: cameraProvider
                                .imageList[_currentIndex].imageByte,
                            extension: 'jpg')
                        .then((value) async {
                      await Share.shareXFiles([XFile(value.path)]);
                    });
                  },
                  iconPath: AppAssets.share,
                ),
                ImageEditButton(
                  title: translation(context).edit,
                  onTap: () {
                    if (cameraProvider.imageList.isNotEmpty) {
                      Navigator.push(
                        context,
                        MaterialPageRoute(
                          builder: (context) => ImageEditScreen(
                            imageIndex: _currentIndex,
                            image: cameraProvider.imageList[_currentIndex],
                          ),
                        ),
                      );
                    }
                  },
                  iconPath: AppAssets.edit,
                ),
                ImageEditButton(
                  title: translation(context).convert,
                  onTap: () async {
                    final Uint8List textRecognitionImage =
                        cameraProvider.imageList[_currentIndex].imageByte;
                    await AppHelper()
                        .convertUint8ListToFile(data: textRecognitionImage)
                        .then((value) async {
                      final inputImage = InputImage.fromFile(value);
                      final textRecognizer =
                          TextRecognizer(script: TextRecognitionScript.latin);
                      await textRecognizer
                          .processImage(inputImage)
                          .then((recognizedText) {
                        String text = recognizedText.text;
                        if (text.trim().isEmpty) {
                          ScaffoldMessenger.of(context).showSnackBar(
                            SnackBar(
                              content: Text(
                                translation(context).thisLanguageNotSupported,
                              ),
                            ),
                          );
                        } else {
                          Navigator.push(
                            context,
                            MaterialPageRoute(
                              builder: (context) =>
                                  TextRecognitionScreen(recognisedText: text),
                            ),
                          );
                        }
                      });
                    });
                  },
                  iconPath: AppAssets.ocr,
                ),
                ImageEditButton(
                  title: translation(context).sign,
                  onTap: () {
                    if (cameraProvider.imageList.isNotEmpty) {
                      Navigator.push(
                        context,
                        MaterialPageRoute(
                          builder: (context) => AddSignature(
                            imageModel: cameraProvider.imageList[_currentIndex],
                            imageIndex: _currentIndex,
                          ),
                        ),
                      );
                    }
                  },
                  iconPath: AppAssets.sign,
                ),
              ],
            ),
          ),
          ),
        ));
  }
}
