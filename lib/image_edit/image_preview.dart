import 'dart:io';
import 'package:cunning_document_scanner/cunning_document_scanner.dart';
import 'package:doc_scanner/bottom_bar/bottom_bar.dart';
import 'package:doc_scanner/image_edit/widget/image_edit_button.dart';
import 'package:doc_scanner/utils/app_color.dart';
import 'package:doc_scanner/utils/helper.dart';
import 'package:doc_scanner/utils/utils.dart';
import 'package:flutter/material.dart';
import 'package:flutter_svg/flutter_svg.dart';
import 'package:image_picker/image_picker.dart';
import 'package:intl/intl.dart';
import 'package:provider/provider.dart';
import '../camera_screen/model/image_model.dart';
import '../camera_screen/provider/camera_provider.dart';
import '../localaization/language_constant.dart';
import '../utils/app_assets.dart';
import 'image_edit_preview.dart';

class ImagePreviewScreen extends StatefulWidget {
  final bool? isCameFromIdCard;
  const ImagePreviewScreen({super.key, this.isCameFromIdCard});

  @override
  State<ImagePreviewScreen> createState() => _ImagePreviewScreenState();
}

class _ImagePreviewScreenState extends State<ImagePreviewScreen> {
  int currentIndex = 0;
  PageController pageController = PageController();

  @override
  Widget build(BuildContext context) {
    final cameraProvider = context.watch<CameraProvider>();
    return PopScope(
      canPop: false,
      onPopInvoked: (didPop) {
        if (cameraProvider.imageList.isEmpty) {
          cameraProvider.clearImageList();
          Navigator.pushAndRemoveUntil(
              context,
              MaterialPageRoute(
                builder: (context) => const BottomBar(),
              ),
              (route) => false);
        } else {
          showNormalAlertDialogue(
            context: context,
            title: translation(context).discardDocument,
            content: translation(context).ifYouLeaveYourProgressWillBeLost,
            onOkText: translation(context).discard,
            onCancelText: translation(context).keepEditing,
            onOk: () {
              cameraProvider.clearImageList();
              Navigator.pushAndRemoveUntil(
                  context,
                  MaterialPageRoute(
                    builder: (context) => const BottomBar(),
                  ),
                  (route) => false);
            },
            onCancel: () {
              Navigator.pop(context);
            },
          );
        }
      },
      child: Scaffold(
        backgroundColor: Colors.white, //const Color(0xFF131314),
        appBar: AppBar(
          centerTitle: true,
          backgroundColor: const Color(0xff1E1F20),
          leading: IconButton(
              onPressed: () {
                if (cameraProvider.imageList.isEmpty) {
                  cameraProvider.clearImageList();
                  Navigator.pushAndRemoveUntil(
                      context,
                      MaterialPageRoute(
                        builder: (context) => const BottomBar(),
                      ),
                      (route) => false);
                } else {
                  showNormalAlertDialogue(
                    context: context,
                    title: translation(context).discardDocument,
                    content:
                        translation(context).ifYouLeaveYourProgressWillBeLost,
                    onOkText: translation(context).discard,
                    onCancelText: translation(context).keepEditing,
                    onOk: () {
                      cameraProvider.clearImageList();
                      Navigator.pushAndRemoveUntil(
                          context,
                          MaterialPageRoute(
                            builder: (context) => const BottomBar(),
                          ),
                          (route) => false);
                    },
                    onCancel: () {
                      Navigator.pop(context);
                    },
                  );
                }
              },
              icon: Icon(
                Platform.isAndroid ? Icons.arrow_back : Icons.arrow_back_ios,
                color: Colors.white,
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
                  cameraProvider.imageList[currentIndex].name,
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
              onPressed: () {
                if (cameraProvider.imageList.isNotEmpty) {
                  Navigator.pushAndRemoveUntil(context, MaterialPageRoute(
                    builder: (context) {
                      return const EditImagePreview();
                    },
                  ), (route) => true);
                }
              },
              child: Text(
                translation(context).next,
                style: TextStyle(
                    color: cameraProvider.imageList.isNotEmpty
                        ? AppColor.primaryColor
                        : Colors.grey,
                    fontSize: 15,
                    fontWeight: FontWeight.w500),
              ),
            ),
          ],
        ),

        body: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            cameraProvider.imageList.isEmpty
                ? Expanded(
                    child: Center(
                      child: Column(
                        mainAxisAlignment: MainAxisAlignment.center,
                        children: [
                          SvgPicture.asset(AppAssets.image_not_found),
                          const SizedBox(height: 10),
                          Text(
                            translation(context).noImageFound,
                            style: const TextStyle(
                                color: Colors.grey,
                                fontSize: 20,
                                fontWeight: FontWeight.bold),
                          ),
                        ],
                      ),
                    ),
                  )
                : Expanded(
                    child: PageView.builder(
                      controller: pageController,
                      itemCount: cameraProvider.imageList.length,
                      onPageChanged: (index) {
                        setState(() {
                          currentIndex = index;
                        });
                      },
                      itemBuilder: (context, index) {
                        return Padding(
                          padding: const EdgeInsets.all(15),
                          child: Image.memory(
                            cameraProvider.imageList[currentIndex].imageByte,
                            fit: BoxFit.contain,
                          ),
                        );
                      },
                    ),
                  ),
            cameraProvider.imageList.isNotEmpty
                ? Container(
                    padding: const EdgeInsets.symmetric(
                        horizontal: 20.0, vertical: 3),
                    child: Text(
                      '${currentIndex + 1}/${cameraProvider.imageList.length}',
                      style: const TextStyle(
                          color: Colors.black,
                          fontSize: 14,
                          fontWeight: FontWeight.w400),
                    ),
                  )
                : const SizedBox.shrink(),
          ],
        ),
        bottomNavigationBar: BottomAppBar(
          color: const Color(0xff1E1F20),
          surfaceTintColor: const Color(0xff1E1F20),
          padding: const EdgeInsets.symmetric(horizontal: 10.0),
          child: Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: [
              ImageEditButton(
                title: translation(context).retake,
                onTap: () async {
                  if (cameraProvider.imageList.isNotEmpty) {
                    await AppHelper.handlePermissions().then((_) async {
                      await CunningDocumentScanner.getPictures(
                              isGalleryImportAllowed: true, noOfPages: 1)
                          .then((pictures) async {
                        if (pictures!.isNotEmpty) {
                          for (final element in pictures) {
                            if (!mounted) return;
                            String imageName = DateFormat('yyyyMMdd_SSSS')
                                .format(DateTime.now());
                            cameraProvider.updateImage(
                                image: ImageModel(
                                    docType: 'Document',
                                    imageByte:
                                        await File(element).readAsBytes(),
                                    name: "Document-$imageName"),
                                index: currentIndex);
                          }

                          if (!mounted) return;
                          if (cameraProvider.imageList.isNotEmpty) {
                            Navigator.push(
                              context,
                              MaterialPageRoute(
                                builder: (context) {
                                  return const ImagePreviewScreen();
                                },
                              ),
                            );
                          }
                        }
                      });
                    });
                  } else {
                    ScaffoldMessenger.of(context).clearSnackBars();
                    ScaffoldMessenger.of(context).showSnackBar(
                      SnackBar(
                        content: Text(translation(context).pleaseAddImageFirst),
                      ),
                    );
                  }
                },
                iconPath: AppAssets.retake,
              ),
              widget.isCameFromIdCard == true
                  ? const SizedBox.shrink()
                  : Material(
                      color: Colors.transparent,
                      child: InkWell(
                        onTap: () async {
                          final ImagePicker picker = ImagePicker();
                          final List<XFile?> image =
                              await picker.pickMultiImage(imageQuality: 50);
                          if (image.isNotEmpty) {
                            List<ImageModel> imageList = [];
                            for (int i = 0; i < image.length; i++) {
                              String documentName = DateFormat('yyyyMMdd_SSSS')
                                  .format(DateTime.now());
                              if (image[i] != null) {
                                imageList.add(
                                  ImageModel(
                                    imageByte: await image[i]!.readAsBytes(),
                                    name: 'Doc-$documentName',
                                    docType: 'Document',
                                  ),
                                );
                              }
                            }
                            cameraProvider.addImageSpecipicIndex(
                                imageList, currentIndex + 1);
                            // setState(() {
                            //   currentIndex=currentIndex+1;
                            // });

                            pageController.animateToPage(currentIndex + 1,
                                duration: const Duration(milliseconds: 1),
                                curve: Curves.easeIn);
                            Navigator.of(context);
                          }
                        },
                        child: Container(
                          padding: const EdgeInsets.all(10),
                          child: Column(
                            crossAxisAlignment: CrossAxisAlignment.center,
                            mainAxisAlignment: MainAxisAlignment.center,
                            children: [
                              Container(
                                height: 30,
                                width: 30,
                                decoration: const BoxDecoration(
                                  color: AppColor.primaryColor,
                                  shape: BoxShape.circle,
                                ),
                                child: const Icon(
                                  Icons.add,
                                  color: Colors.white,
                                ),
                              ),
                              const SizedBox(height: 5),
                              Text(
                                translation(context).addPage,
                                style: const TextStyle(
                                  color: Colors.white,
                                  fontSize: 12,
                                  fontWeight: FontWeight.w500,
                                ),
                              ),
                            ],
                          ),
                        ),
                      ),
                    ),
              Material(
                color: Colors.transparent,
                child: InkWell(
                  onTap: () async {
                    if (cameraProvider.imageList.isNotEmpty) {
                      showNormalAlertDialogue(
                        context: context,
                        title: translation(context).deleteImage,
                        content:
                            translation(context).doYouWantToDeleteThisImage,
                        onOkText: translation(context).delete,
                        onCancelText: translation(context).cancel,
                        onOk: () {
                          cameraProvider.deleteImage(currentIndex);
                          setState(() {
                            if (currentIndex > 0) {
                              currentIndex--;
                            }
                          });
                          Navigator.pop(context);
                          if (cameraProvider.imageList.isEmpty) {
                            Navigator.pushAndRemoveUntil(
                                context,
                                MaterialPageRoute(
                                  builder: (context) => const BottomBar(),
                                ),
                                (route) => false);
                          }
                        },
                        onCancel: () => Navigator.pop(context),
                      );
                    } else {
                      ScaffoldMessenger.of(context).clearSnackBars();
                      ScaffoldMessenger.of(context).showSnackBar(
                        SnackBar(
                          content:
                              Text(translation(context).pleaseAddImageFirst),
                        ),
                      );
                    }
                  },
                  child: Container(
                    padding: const EdgeInsets.all(10),
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.center,
                      mainAxisAlignment: MainAxisAlignment.center,
                      children: [
                        SvgPicture.asset(
                          AppAssets.delete,
                          color: Colors.white,
                        ),
                        const SizedBox(height: 5),
                        Text(
                          translation(context).delete,
                          style: const TextStyle(
                            color: Colors.white,
                            fontSize: 12,
                            fontWeight: FontWeight.w500,
                          ),
                        ),
                      ],
                    ),
                  ),
                ),
              ),

              // ImageEditButton(
              //   title: translation(context).rotate,
              //   onTap: () async {
              //     if (cameraProvider.imageList.isNotEmpty) {
              //       Navigator.push(
              //         context,
              //         MaterialPageRoute(
              //           builder: (context) => ImageRotation(
              //             imageModel: cameraProvider.imageList[currentIndex],
              //             index: currentIndex,
              //           ),
              //         ),
              //       );
              //     }
              //   },
              //   iconPath: AppAssets.rotate,
              // ),
              // ImageEditButton(
              //   title: translation(context).reframe,
              //   onTap: () async {
              //     if (cameraProvider.imageList.isNotEmpty) {
              //       Navigator.push(
              //         context,
              //         MaterialPageRoute(
              //           builder: (context) => CropScreen(
              //             imageModel: cameraProvider.imageList[currentIndex],
              //             index: currentIndex,
              //           ),
              //         ),
              //       );
              //     }
              //   },
              //   iconPath: AppAssets.reFrame,
              // ),
            ],
          ),
        ),
      ),
    );
  }
}
