import 'package:doc_scanner/camera_screen/model/image_model.dart';
import 'package:doc_scanner/camera_screen/provider/camera_provider.dart';
import 'package:doc_scanner/google_ads_helper/banner_ad_widget.dart';
import 'package:doc_scanner/google_ads_helper/google_ads_helper.dart';
import 'package:doc_scanner/image_edit/provider/image_edit_provider.dart';
import 'package:doc_scanner/image_edit/image_size_screen.dart';
import 'package:doc_scanner/image_edit/widget/image_edit_button.dart';
import 'package:doc_scanner/image_edit/widget/image_filter_screen.dart';
import 'package:doc_scanner/utils/app_assets.dart';
import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import '../localaization/language_constant.dart';
import '../utils/app_color.dart';
import 'crop_screen.dart';
import 'widget/image_edit_unavailable.dart';
import 'image_rotation.dart';

class ImageEditScreen extends StatefulWidget {
  final ImageModel image;
  final int imageIndex;

  const ImageEditScreen(
      {super.key, required this.image, required this.imageIndex});

  @override
  State<ImageEditScreen> createState() => _ImageEditScreenState();
}

class _ImageEditScreenState extends State<ImageEditScreen> {
  bool _initialized = false;

  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addPostFrameCallback((_) {
      if (!mounted) return;
      context.read<ImageEditProvider>().startSession(widget.image.imageByte);
      setState(() => _initialized = true);
    });
  }

  @override
  Widget build(BuildContext context) {
    final imageEditProvider = context.watch<ImageEditProvider>();
    final cameraProvider = context.watch<CameraProvider>();
    final bytes = _initialized ? imageEditProvider.currentState : null;
    if (_initialized && bytes == null) return const ImageEditUnavailable();
    final canSave = bytes != null &&
        widget.imageIndex >= 0 &&
        widget.imageIndex < cameraProvider.imageList.length;
    return PopScope(
      canPop: true,
      onPopInvoked: (didPop) {
        if (didPop) imageEditProvider.clearState();
      },
      child: Scaffold(
        backgroundColor: const Color(0xFF131314),
        appBar: AppBar(
          backgroundColor: const Color(0xff1E1F20),
          centerTitle: true,
          leading: IconButton(
              onPressed: () {
                Navigator.pop(context);
              },
              icon: const Icon(
                Icons.arrow_back,
                color: Color(0xffffffff),
              )),
          title: Text(widget.image.name),
          titleTextStyle: const TextStyle(
            color: Colors.white,
            fontSize: 20,
            fontWeight: FontWeight.w500,
          ),
          actions: [
            TextButton(
              onPressed: !canSave
                  ? null
                  : () {
                      final current = imageEditProvider.currentState;
                      if (current == null ||
                          widget.imageIndex < 0 ||
                          widget.imageIndex >= cameraProvider.imageList.length)
                        return;
                      cameraProvider.updateImage(
                          index: widget.imageIndex,
                          image: ImageModel(
                            imageByte: current,
                            name: widget.image.name,
                            docType: widget.image.docType,
                          ));
                      Navigator.pop(context);
                    },
              child: Text(
                translation(context).done,
                style: const TextStyle(
                  fontSize: 15,
                  fontWeight: FontWeight.w500,
                  color: AppColor.primaryColor,
                ),
              ),
            ),
          ],
        ),
        body: Center(
          child: Padding(
            padding: const EdgeInsets.all(15.0),
            child: bytes != null
                ? Image.memory(
                    bytes,
                    fit: BoxFit.cover,
                  )
                : const CircularProgressIndicator(),
          ),
        ),
        bottomNavigationBar: BottomBarWithBanner(
          adUnitId: AdHelper.imageEditScreenBannerAdUnitId,
          child: BottomAppBar(
            padding: const EdgeInsets.symmetric(horizontal: 20),
            color: const Color(0xff1E1F20),
            surfaceTintColor: const Color(0xff1E1F20),
            child: Row(
              mainAxisAlignment: MainAxisAlignment.spaceBetween,
              children: [
                ImageEditButton(
                  title: translation(context).crop,
                  onTap: bytes == null
                      ? null
                      : () {
                          Navigator.push(context, MaterialPageRoute(
                            builder: (context) {
                              return CropScreen(
                                imageModel: widget.image,
                                index: widget.imageIndex,
                                cameFromEdit: true,
                              );
                            },
                          ));
                        },
                  iconPath: AppAssets.crop,
                ),
                ImageEditButton(
                  title: translation(context).filters,
                  onTap: bytes == null
                      ? null
                      : () {
                          Navigator.push(context, MaterialPageRoute(
                            builder: (context) {
                              return const ImageFilters();
                            },
                          ));
                        },
                  iconPath: AppAssets.filter,
                ),
                ImageEditButton(
                  title: translation(context).size,
                  onTap: bytes == null
                      ? null
                      : () {
                          Navigator.push(context, MaterialPageRoute(
                            builder: (context) {
                              return const ImageSizeScreen();
                            },
                          ));
                        },
                  iconPath: AppAssets.size,
                ),
                ImageEditButton(
                  title: translation(context).rotate,
                  onTap: bytes == null
                      ? null
                      : () {
                          Navigator.push(context, MaterialPageRoute(
                            builder: (context) {
                              return ImageRotation(
                                imageModel: widget.image,
                                index: widget.imageIndex,
                                cameFromEdit: true,
                              );
                            },
                          ));
                        },
                  iconPath: AppAssets.rotate,
                ),
                ImageEditButton(
                  title: translation(context).undo,
                  onTap: bytes == null
                      ? null
                      : () {
                          if (imageEditProvider.canUndo) {
                            imageEditProvider.undo();
                          } else {
                            ScaffoldMessenger.of(context).clearSnackBars();
                            ScaffoldMessenger.of(context).showSnackBar(
                              SnackBar(
                                content: Text(
                                    translation(context).cannotUndoAnymore),
                              ),
                            );
                          }
                        },
                  iconPath: AppAssets.undo,
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }
}
