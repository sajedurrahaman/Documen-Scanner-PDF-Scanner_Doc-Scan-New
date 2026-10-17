import 'image_edit_unavailable.dart';
import 'dart:typed_data';

import 'package:colorfilter_generator/colorfilter_generator.dart';
import 'package:colorfilter_generator/presets.dart';
import 'package:doc_scanner/google_ads_helper/banner_ad_widget.dart';
import 'package:doc_scanner/google_ads_helper/google_ads_helper.dart';
import 'package:doc_scanner/utils/app_color.dart';
import 'package:image/image.dart' as img;
import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import 'package:screenshot/screenshot.dart';

import '../../localaization/language_constant.dart';
import '../provider/image_edit_provider.dart';

class ImageFilters extends StatefulWidget {
  const ImageFilters({
    super.key,
  });

  @override
  createState() => _ImageFiltersState();
}

class _ImageFiltersState extends State<ImageFilters> {
  late img.Image decodedImage;
  ColorFilterGenerator selectedFilter = PresetFilters.none;
  Uint8List resizedImage = Uint8List.fromList([]);
  double filterOpacity = 1;
  ScreenshotController screenshotController = ScreenshotController();
  late List<ColorFilterGenerator> filters;

  @override
  void initState() {
    filters = [PresetFilters.none, ...(presetFiltersList.sublist(1))];

    super.initState();
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
        title: Text(
          translation(context).filters,
          style: const TextStyle(
              fontSize: 20, fontWeight: FontWeight.w500, color: Colors.white),
        ),
        actions: [
          TextButton(
            child: Text(
              translation(context).done,
              style: const TextStyle(
                fontSize: 15,
                fontWeight: FontWeight.w500,
                color: AppColor.primaryColor,
              ),
            ),
            onPressed: () async {
              Uint8List? data = await screenshotController.capture();
              if (!mounted ||
                  data == null ||
                  data.isEmpty ||
                  imageEditProvider.currentState == null) return;
              imageEditProvider.addState(data);
              Navigator.pop(context);
            },
          ),
        ],
      ),
      body: Center(
        child: Screenshot(
          controller: screenshotController,
          child: FilterAppliedImage(
            key: Key('selectedFilter:${selectedFilter.name}'),
            image: bytes,
            filter: selectedFilter,
            fit: BoxFit.cover,
            opacity: filterOpacity,
          ),
        ),
      ),
      bottomNavigationBar: BottomBarWithBanner(
        adUnitId: AdHelper.imageFilterScreenBannerAdUnitId,
        child: SizedBox(
          height: 160,
          child: Column(children: [
            SizedBox(
              height: 40,
              child: selectedFilter == PresetFilters.none
                  ? Container()
                  : selectedFilter.build(
                      Slider(
                        min: 0.3,
                        max: 1,
                        divisions: 70,
                        value: filterOpacity,
                        onChanged: (value) {
                          filterOpacity = value;
                          setState(() {});
                        },
                      ),
                    ),
            ),
            SizedBox(
              height: 120,
              child: ListView(
                scrollDirection: Axis.horizontal,
                children: [
                  for (var filter in filters)
                    GestureDetector(
                      onTap: () {
                        selectedFilter = filter;
                        setState(() {});
                      },
                      child: Column(children: [
                        Container(
                          height: 64,
                          width: 64,
                          margin: const EdgeInsets.symmetric(
                            horizontal: 16,
                            vertical: 12,
                          ),
                          decoration: BoxDecoration(
                            borderRadius: BorderRadius.circular(4),
                            border: Border.all(
                              color: selectedFilter == filter
                                  ? AppColor.primaryColor
                                  : Colors.white,
                              width: 2,
                            ),
                          ),
                          child: FilterAppliedImage(
                            key: Key('filterPreviewButton:${filter.name}'),
                            image: bytes,
                            filter: filter,
                            fit: BoxFit.cover,
                          ),
                        ),
                        Text(
                          filter.name,
                          style: const TextStyle(
                              fontSize: 12, color: Colors.white),
                        ),
                      ]),
                    ),
                ],
              ),
            ),
          ]),
        ),
      ),
    );
  }
}

class FilterAppliedImage extends StatefulWidget {
  final Uint8List image;
  final ColorFilterGenerator filter;
  final BoxFit? fit;
  final Function(Uint8List)? onProcess;
  final double opacity;

  const FilterAppliedImage({
    super.key,
    required this.image,
    required this.filter,
    this.fit,
    this.onProcess,
    this.opacity = 1,
  });

  @override
  State<FilterAppliedImage> createState() => _FilterAppliedImageState();
}

class _FilterAppliedImageState extends State<FilterAppliedImage> {
  @override
  initState() {
    super.initState();
    if (widget.onProcess != null) {
      if (widget.filter.filters.isEmpty) {
        widget.onProcess!(widget.image);
        return;
      }

      var filterTask = img.Command();
      filterTask.decodeImage(widget.image);

      var matrix = widget.filter.matrix;

      filterTask.filter((image) {
        for (final pixel in image) {
          pixel.r = matrix[0] * pixel.r +
              matrix[1] * pixel.g +
              matrix[2] * pixel.b +
              matrix[3] * pixel.a +
              matrix[4];

          pixel.g = matrix[5] * pixel.r +
              matrix[6] * pixel.g +
              matrix[7] * pixel.b +
              matrix[8] * pixel.a +
              matrix[9];

          pixel.b = matrix[10] * pixel.r +
              matrix[11] * pixel.g +
              matrix[12] * pixel.b +
              matrix[13] * pixel.a +
              matrix[14];

          pixel.a = matrix[15] * pixel.r +
              matrix[16] * pixel.g +
              matrix[17] * pixel.b +
              matrix[18] * pixel.a +
              matrix[19];
        }

        return image;
      });

      filterTask.getBytesThread().then((result) {
        if (widget.onProcess != null && result != null) {
          widget.onProcess!(result);
        }
      }).catchError((err, stack) {});
    }
  }

  @override
  Widget build(BuildContext context) {
    if (widget.filter.filters.isEmpty) {
      return Image.memory(
        widget.image,
        fit: widget.fit,
      );
    }

    return Opacity(
      opacity: widget.opacity,
      child: widget.filter.build(
        Image.memory(
          widget.image,
          fit: widget.fit,
        ),
      ),
    );
  }
}
