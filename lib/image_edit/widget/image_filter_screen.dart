import 'dart:typed_data';

import 'package:colorfilter_generator/colorfilter_generator.dart';
import 'package:colorfilter_generator/presets.dart';
import 'package:doc_scanner/camera_screen/model/image_model.dart';
import 'package:doc_scanner/camera_screen/provider/camera_provider.dart';
import 'package:doc_scanner/utils/banner_ad_widget.dart';
import 'package:doc_scanner/utils/addHelper.dart';
import 'package:doc_scanner/image_edit/provider/image_edit_provider.dart';
import 'package:doc_scanner/utils/app_color.dart';
import 'package:doc_scanner/utils/image_bytes_helper.dart';
import 'package:flutter/material.dart';
import 'package:image/image.dart' as img;
import 'package:provider/provider.dart';

import '../../localaization/language_constant.dart';

class _PageFilterState {
  _PageFilterState({
    required this.bytes,
    ColorFilterGenerator? filter,
    this.opacity = 1,
  }) : filter = filter ?? PresetFilters.none;

  Uint8List bytes;
  ColorFilterGenerator filter;
  double opacity;
}

/// CamScanner-style filters: swipe all pages; Done applies every page.
class ImageFilters extends StatefulWidget {
  const ImageFilters({
    super.key,
    this.initialIndex = 0,
  });

  final int initialIndex;

  @override
  State<ImageFilters> createState() => _ImageFiltersState();
}

class _ImageFiltersState extends State<ImageFilters> {
  late final PageController _pageController;
  late List<_PageFilterState> _pages;
  late int _pageIndex;
  late final List<ColorFilterGenerator> _filters;
  bool _saving = false;
  bool _pageAnimating = false;

  _PageFilterState get _current {
    final i = _pageIndex.clamp(0, _pages.length - 1);
    return _pages[i];
  }

  @override
  void initState() {
    super.initState();
    _filters = [PresetFilters.none, ...presetFiltersList.sublist(1)];
    _pageIndex = 0;
    _pages = [];
    _pageController = PageController(initialPage: 0);
    WidgetsBinding.instance.addPostFrameCallback((_) {
      if (mounted) _bootstrapPages();
    });
  }

  void _bootstrapPages() {
    final camera = context.read<CameraProvider>();
    final edit = context.read<ImageEditProvider>();
    final list = camera.imageList;
    if (list.isEmpty) {
      setState(() => _pages = []);
      return;
    }
    final start = widget.initialIndex.clamp(0, list.length - 1);
    final pages = <_PageFilterState>[];
    for (var i = 0; i < list.length; i++) {
      var bytes = Uint8List.fromList(list[i].imageByte);
      if (i == start &&
          edit.currentState != null &&
          edit.currentState!.isNotEmpty) {
        bytes = Uint8List.fromList(edit.currentState!);
      }
      pages.add(_PageFilterState(bytes: bytes));
    }
    setState(() {
      _pages = pages;
      _pageIndex = start;
    });
    if (_pageController.hasClients) {
      _pageController.jumpToPage(start);
    }
  }

  @override
  void dispose() {
    _pageController.dispose();
    super.dispose();
  }

  Future<void> _goToPage(int index) async {
    if (_pageAnimating || _saving) return;
    if (index < 0 || index >= _pages.length || index == _pageIndex) return;
    _pageAnimating = true;
    try {
      await _pageController.animateToPage(
        index,
        duration: const Duration(milliseconds: 240),
        curve: Curves.easeOut,
      );
    } finally {
      _pageAnimating = false;
    }
  }

  /// Bake ColorFilter (+ opacity as filter strength) into JPEG bytes.
  Uint8List _bakePage(_PageFilterState page) {
    if (page.filter.filters.isEmpty) {
      return ensureJpegBytes(page.bytes);
    }
    final decoded = decodeAnyImage(page.bytes);
    if (decoded == null) return ensureJpegBytes(page.bytes);

    final matrix = page.filter.matrix;
    final t = page.opacity.clamp(0.0, 1.0);
    for (final pixel in decoded) {
      final or = pixel.r.toDouble();
      final og = pixel.g.toDouble();
      final ob = pixel.b.toDouble();
      final oa = pixel.a.toDouble();

      var fr = matrix[0] * or +
          matrix[1] * og +
          matrix[2] * ob +
          matrix[3] * oa +
          matrix[4];
      var fg = matrix[5] * or +
          matrix[6] * og +
          matrix[7] * ob +
          matrix[8] * oa +
          matrix[9];
      var fb = matrix[10] * or +
          matrix[11] * og +
          matrix[12] * ob +
          matrix[13] * oa +
          matrix[14];
      var fa = matrix[15] * or +
          matrix[16] * og +
          matrix[17] * ob +
          matrix[18] * oa +
          matrix[19];

      if (t < 1) {
        fr = or + (fr - or) * t;
        fg = og + (fg - og) * t;
        fb = ob + (fb - ob) * t;
        fa = oa + (fa - oa) * t;
      }

      pixel
        ..r = fr.round().clamp(0, 255)
        ..g = fg.round().clamp(0, 255)
        ..b = fb.round().clamp(0, 255)
        ..a = fa.round().clamp(0, 255);
    }
    return Uint8List.fromList(img.encodeJpg(decoded, quality: 92));
  }

  Future<void> _onDone() async {
    if (_saving || _pages.isEmpty) return;
    setState(() => _saving = true);
    try {
      final camera = context.read<CameraProvider>();
      final count =
          _pages.length < camera.imageList.length
              ? _pages.length
              : camera.imageList.length;
      Uint8List? currentJpeg;
      final currentIndex = _pageIndex.clamp(0, count - 1);

      for (var i = 0; i < count; i++) {
        final jpeg = _bakePage(_pages[i]);
        _pages[i].bytes = jpeg;
        _pages[i].filter = PresetFilters.none;
        _pages[i].opacity = 1;
        final old = camera.imageList[i];
        camera.updateImage(
          index: i,
          image: ImageModel(
            imageByte: jpeg,
            name: old.name,
            docType: old.docType,
          ),
        );
        if (i == currentIndex) currentJpeg = jpeg;
      }

      if (!mounted || currentJpeg == null) return;
      Navigator.pop(context, (currentIndex, currentJpeg));
    } catch (e) {
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text('${translation(context).somethingWentWrong}: $e'),
        ),
      );
      setState(() => _saving = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    if (_pages.isEmpty) {
      return const Scaffold(
        backgroundColor: Color(0xFF131314),
        body: Center(child: CircularProgressIndicator()),
      );
    }
    final pageCount = _pages.length;
    final current = _current;

    return Scaffold(
      backgroundColor: const Color(0xFF131314),
      appBar: AppBar(
        backgroundColor: const Color(0xff1E1F20),
        leading: IconButton(
          onPressed: _saving ? null : () => Navigator.pop(context),
          icon: const Icon(Icons.arrow_back, color: Color(0xffffffff)),
        ),
        centerTitle: true,
        title: Text(
          translation(context).filters,
          style: const TextStyle(
            fontSize: 20,
            fontWeight: FontWeight.w500,
            color: Colors.white,
          ),
        ),
        actions: [
          TextButton(
            onPressed: _saving ? null : _onDone,
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
      body: _saving
          ? const Center(child: CircularProgressIndicator())
          : Stack(
              children: [
                Positioned.fill(
                  child: Padding(
                    padding: const EdgeInsets.fromLTRB(12, 8, 12, 56),
                    child: PageView.builder(
                      controller: _pageController,
                      itemCount: pageCount,
                      onPageChanged: (i) => setState(() => _pageIndex = i),
                      itemBuilder: (context, index) {
                        final page = _pages[index];
                        return FilterAppliedImage(
                          key: ValueKey(
                            'page-$index-${page.filter.name}-${page.opacity}',
                          ),
                          image: page.bytes,
                          filter: page.filter,
                          fit: BoxFit.contain,
                          opacity: page.opacity,
                        );
                      },
                    ),
                  ),
                ),
                if (pageCount > 1)
                  Positioned(
                    left: 0,
                    right: 0,
                    bottom: 0,
                    child: Row(
                      mainAxisAlignment: MainAxisAlignment.center,
                      children: [
                        _pageNavButton(
                          icon: Icons.chevron_left,
                          enabled: _pageIndex > 0,
                          onTap: () => _goToPage(_pageIndex - 1),
                        ),
                        const SizedBox(width: 12),
                        Container(
                          padding: const EdgeInsets.symmetric(
                              horizontal: 14, vertical: 6),
                          decoration: BoxDecoration(
                            color: const Color(0xCC1E1F20),
                            borderRadius: BorderRadius.circular(20),
                          ),
                          child: Text(
                            '${_pageIndex + 1}/$pageCount',
                            style: const TextStyle(
                              color: Colors.white,
                              fontSize: 14,
                              fontWeight: FontWeight.w500,
                            ),
                          ),
                        ),
                        const SizedBox(width: 12),
                        _pageNavButton(
                          icon: Icons.chevron_right,
                          enabled: _pageIndex < pageCount - 1,
                          onTap: () => _goToPage(_pageIndex + 1),
                        ),
                      ],
                    ),
                  ),
              ],
            ),
      bottomNavigationBar: BottomBarWithBanner(
        adUnitId: AdHelper.imageFilterScreenBannerAdUnitId,
        child: SizedBox(
          height: 160,
          child: Column(
            children: [
              SizedBox(
                height: 40,
                child: current.filter == PresetFilters.none
                    ? const SizedBox.shrink()
                    : current.filter.build(
                        Slider(
                          min: 0.3,
                          max: 1,
                          divisions: 70,
                          value: current.opacity,
                          onChanged: (value) {
                            setState(() => current.opacity = value);
                          },
                        ),
                      ),
              ),
              SizedBox(
                height: 120,
                child: ListView(
                  scrollDirection: Axis.horizontal,
                  children: [
                    for (final filter in _filters)
                      GestureDetector(
                        onTap: () {
                          setState(() => current.filter = filter);
                        },
                        child: Column(
                          children: [
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
                                  color: current.filter == filter
                                      ? AppColor.primaryColor
                                      : Colors.white,
                                  width: 2,
                                ),
                              ),
                              child: FilterAppliedImage(
                                key: Key(
                                  'filterPreview:${filter.name}:$_pageIndex',
                                ),
                                image: current.bytes,
                                filter: filter,
                                fit: BoxFit.cover,
                              ),
                            ),
                            Text(
                              filter.name,
                              style: const TextStyle(
                                fontSize: 12,
                                color: Colors.white,
                              ),
                            ),
                          ],
                        ),
                      ),
                  ],
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }

  Widget _pageNavButton({
    required IconData icon,
    required bool enabled,
    required VoidCallback onTap,
  }) {
    return Material(
      color: const Color(0xCC2A2B2C),
      shape: const CircleBorder(),
      child: InkWell(
        customBorder: const CircleBorder(),
        onTap: enabled && !_saving ? onTap : null,
        child: SizedBox(
          width: 28,
          height: 28,
          child: Icon(
            icon,
            color: enabled ? Colors.white : Colors.white24,
            size: 20,
          ),
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
  void initState() {
    super.initState();
    if (widget.onProcess != null) {
      if (widget.filter.filters.isEmpty) {
        widget.onProcess!(widget.image);
        return;
      }

      final filterTask = img.Command();
      filterTask.decodeImage(widget.image);
      final matrix = widget.filter.matrix;

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
