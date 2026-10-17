import 'widget/image_edit_unavailable.dart';
import 'dart:typed_data';
import 'dart:ui' as ui;

import 'package:doc_scanner/google_ads_helper/banner_ad_widget.dart';
import 'package:doc_scanner/google_ads_helper/google_ads_helper.dart';
import 'package:doc_scanner/image_edit/provider/image_edit_provider.dart';
import 'package:flutter/material.dart';
import 'package:flutter_svg/svg.dart';
import 'package:provider/provider.dart';
import 'package:screenshot/screenshot.dart';
import '../localaization/language_constant.dart';
import '../utils/app_assets.dart';
import '../utils/app_color.dart';

class ImageSizeScreen extends StatefulWidget {
  const ImageSizeScreen({
    super.key,
  });

  @override
  State<ImageSizeScreen> createState() => _ImageSizeScreenState();
}

class _ImageSizeScreenState extends State<ImageSizeScreen> {
  ScreenshotController screenshotController = ScreenshotController();

  static const List<SizeOption> availableSizeOption = [
    SizeOption(title: 'Original', radio: null),
    SizeOption(title: 'A4', radio: 1 / 1.4),
    SizeOption(title: 'A5', radio: 1 / 1.5),
    SizeOption(title: 'ID Card', radio: 3 / 2),
    SizeOption(title: 'Legal', radio: 8.5 / 14),
  ];

  String _selectedTitle = 'Original';
  double? _originalRatio;
  double _selectedRatio = 1;
  bool _isLoadingRatio = true;

  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addPostFrameCallback((_) {
      if (mounted) _loadOriginalRatio();
    });
  }

  Future<void> _loadOriginalRatio() async {
    final bytes = context.read<ImageEditProvider>().currentState;
    if (bytes == null) return;
    try {
      final codec = await ui.instantiateImageCodec(bytes);
      try {
        final frame = await codec.getNextFrame();
        final image = frame.image;
        final ratio = image.width / image.height;
        image.dispose();
        if (!mounted) return;
        setState(() {
          _originalRatio = ratio;
          _selectedRatio = ratio;
          _selectedTitle = 'Original';
          _isLoadingRatio = false;
        });
      } finally {
        codec.dispose();
      }
    } catch (_) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
            SnackBar(content: Text(translation(context).somethingWentWrong)));
      }
    }
  }

  double _ratioFor(SizeOption size) {
    if (size.title == 'Original') {
      return _originalRatio ?? 1;
    }
    return size.radio!;
  }

  @override
  Widget build(BuildContext context) {
    final imageEditProvider = context.watch<ImageEditProvider>();
    final bytes = imageEditProvider.currentState;
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
        title: Text(translation(context).resize),
        titleTextStyle: const TextStyle(
          color: Colors.white,
          fontSize: 20,
          fontWeight: FontWeight.w500,
        ),
        actions: [
          TextButton(
            onPressed: _isLoadingRatio
                ? null
                : () async {
                    Uint8List? data = await screenshotController.capture();
                    if (!mounted ||
                        data == null ||
                        data.isEmpty ||
                        imageEditProvider.currentState == null) return;
                    imageEditProvider.addState(data);
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
        child: _isLoadingRatio
            ? const CircularProgressIndicator()
            : Screenshot(
                controller: screenshotController,
                child: AspectRatio(
                  aspectRatio: _selectedRatio,
                  child: Image.memory(
                    bytes,
                    fit: BoxFit.fill,
                  ),
                ),
              ),
      ),
      bottomNavigationBar: BottomBarWithBanner(
        adUnitId: AdHelper.imageSizeScreenBannerAdUnitId,
        child: Container(
          padding: const EdgeInsets.symmetric(vertical: 4),
          height: 80,
          decoration: const BoxDecoration(
            color: Color(0xff1E1F20),
          ),
          child: Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: <Widget>[
              for (var size in availableSizeOption)
                Material(
                  color: Colors.transparent,
                  child: InkWell(
                    onTap: _isLoadingRatio
                        ? null
                        : () {
                            setState(() {
                              _selectedTitle = size.title!;
                              _selectedRatio = _ratioFor(size);
                            });
                          },
                    child: Padding(
                      padding: const EdgeInsets.symmetric(horizontal: 8.0),
                      child: Column(
                        mainAxisAlignment: MainAxisAlignment.center,
                        children: [
                          SvgPicture.asset(
                            AppAssets.size_preview,
                            color: _selectedTitle == size.title
                                ? Colors.white
                                : Colors.grey,
                          ),
                          Container(
                            padding: const EdgeInsets.symmetric(
                                horizontal: 8, vertical: 4),
                            child: Text(
                              getTitle(size, context),
                              style: TextStyle(
                                color: _selectedTitle == size.title
                                    ? Colors.white
                                    : Colors.grey,
                              ),
                            ),
                          ),
                        ],
                      ),
                    ),
                  ),
                )
            ],
          ),
        ),
      ),
    );
  }

  String getTitle(SizeOption size, BuildContext context) {
    switch (size.title) {
      case "Original":
        return translation(context).original;
      case "A4":
        return "A4";
      case "A5":
        return "A5";
      case "ID Card":
        return translation(context).idCard;
      case "Legal":
        return translation(context).legal;
      default:
        return "";
    }
  }
}

class SizeOption {
  final String? title;
  final double? radio;

  const SizeOption({this.title, this.radio});
}
