import 'widget/image_edit_unavailable.dart';
import 'dart:typed_data';
import 'package:doc_scanner/camera_screen/model/image_model.dart';
import 'package:doc_scanner/google_ads_helper/banner_ad_widget.dart';
import 'package:doc_scanner/google_ads_helper/google_ads_helper.dart';
import 'package:doc_scanner/image_edit/provider/image_edit_provider.dart';
import 'package:doc_scanner/utils/app_color.dart';
import 'package:extended_image/extended_image.dart';
import 'package:flutter/material.dart';
import 'package:image_editor/image_editor.dart';
import 'package:provider/provider.dart';

import '../camera_screen/provider/camera_provider.dart';
import '../localaization/language_constant.dart';

class CropScreen extends StatefulWidget {
  final ImageModel imageModel;
  final int index;
  final bool? cameFromEdit;

  const CropScreen(
      {super.key,
      required this.imageModel,
      required this.index,
      this.cameFromEdit});

  @override
  State<CropScreen> createState() => _CropScreenState();
}

class _CropScreenState extends State<CropScreen> {
  final GlobalKey<ExtendedImageEditorState> _controller =
      GlobalKey<ExtendedImageEditorState>();

  @override
  Widget build(BuildContext context) {
    final cameraProvider = context.watch<CameraProvider>();
    final imageEditProvider = context.watch<ImageEditProvider>();
    final bytes = widget.cameFromEdit == true
        ? imageEditProvider.currentState
        : widget.imageModel.imageByte;
    if (bytes == null || bytes.isEmpty) return const ImageEditUnavailable();
    return Scaffold(
      backgroundColor: const Color(0xFF131314),
      appBar: AppBar(
        backgroundColor: const Color(0xff1E1F20),
        leading: IconButton(
            onPressed: () {
              Navigator.pop(context);
            },
            icon: const Icon(
              Icons.arrow_back,
              color: Color(0xffffffff),
            )),
        centerTitle: true,
        title: Text(
          translation(context).crop,
          style: const TextStyle(
              fontSize: 20, fontWeight: FontWeight.w500, color: Colors.white),
        ),
        actions: [
          TextButton(
              onPressed: () async {
                var state = _controller.currentState;
                if (state == null || state.getCropRect() == null) {
                  Navigator.pop(context);
                } else {
                  final Uint8List img = state.rawImageData;
                  Rect cropRect = state.getCropRect()!;
                  final ImageEditorOption option = ImageEditorOption();
                  option.addOption(ClipOption.fromRect(cropRect));
                  final Uint8List? result = await ImageEditor.editImage(
                    image: img,
                    imageEditorOption: option,
                  );
                  if (!mounted || result == null || result.isEmpty) return;
                  if (widget.cameFromEdit == true &&
                      imageEditProvider.currentState == null) return;
                  if (widget.cameFromEdit == true) {
                    imageEditProvider.addState(result);
                  } else {
                    cameraProvider.updateImage(
                      index: widget.index,
                      image: ImageModel(
                          imageByte: result,
                          name: widget.imageModel.name,
                          docType: widget.imageModel.docType),
                    );
                  }

                  Navigator.pop(context);
                }
              },
              child: Text(
                translation(context).done,
                style: const TextStyle(
                  fontSize: 15,
                  fontWeight: FontWeight.w500,
                  color: AppColor.primaryColor,
                ),
              ))
        ],
      ),
      body: ExtendedImage.memory(
        bytes,
        cacheRawData: true,
        fit: BoxFit.contain,
        extendedImageEditorKey: _controller,
        mode: ExtendedImageMode.editor,
        initEditorConfigHandler: (state) {
          return EditorConfig(
            cornerColor: AppColor.primaryColor,
          );
        },
      ),
      bottomNavigationBar: SafeArea(
        top: false,
        left: false,
        right: false,
        child: BannerAdWidget(
          adUnitId: AdHelper.imageCropBannerAdUnitId,
        ),
      ),
    );
  }
}
