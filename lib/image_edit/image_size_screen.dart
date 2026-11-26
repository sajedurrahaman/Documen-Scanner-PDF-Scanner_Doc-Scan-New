import 'dart:typed_data';
import 'dart:ui' as ui;

import 'package:doc_scanner/camera_screen/model/image_model.dart';
import 'package:doc_scanner/camera_screen/provider/camera_provider.dart';
import 'package:doc_scanner/utils/banner_ad_widget.dart';
import 'package:doc_scanner/utils/addHelper.dart';
import 'package:doc_scanner/image_edit/provider/image_edit_provider.dart';
import 'package:doc_scanner/image_edit/widget/full_screen_saving_overlay.dart';
import 'package:doc_scanner/utils/image_bytes_helper.dart';
import 'package:flutter/material.dart';
import 'package:flutter_svg/svg.dart';
import 'package:image/image.dart' as img;
import 'package:provider/provider.dart';

import '../localaization/language_constant.dart';
import '../utils/app_assets.dart';
import '../utils/app_color.dart';

class _PageSizeState {
  _PageSizeState({
    required this.bytes,
    required this.originalRatio,
    String? selectedTitle,
    double? selectedRatio,
  })  : selectedTitle = selectedTitle ?? 'Original',
        selectedRatio = selectedRatio ?? originalRatio;

  Uint8List bytes;
  double originalRatio;
  String selectedTitle;
  double selectedRatio;
}

/// CamScanner-style size: swipe all pages; Done applies every page.
class ImageSizeScreen extends StatefulWidget {
  const ImageSizeScreen({
    super.key,
    this.initialIndex = 0,
  });

  final int initialIndex;

  @override
  State<ImageSizeScreen> createState() => _ImageSizeScreenState();
}

class _ImageSizeScreenState extends State<ImageSizeScreen> {
  static const List<SizeOption> availableSizeOption = [
    SizeOption(title: 'Original', radio: null),
    SizeOption(title: 'A4', radio: 1 / 1.4),
    SizeOption(title: 'A5', radio: 1 / 1.5),
    SizeOption(title: 'ID Card', radio: 3 / 2),
    SizeOption(title: 'Legal', radio: 8.5 / 14),
  ];

  late final PageController _pageController;
  late List<_PageSizeState> _pages;
  late int _pageIndex;
  bool _loading = true;
  bool _saving = false;
  bool _pageAnimating = false;

  _PageSizeState get _current {
    final i = _pageIndex.clamp(0, _pages.length - 1);
    return _pages[i];
  }

  @override
  void initState() {
    super.initState();
    _pageIndex = 0;
    _pages = [];
    _pageController = PageController(initialPage: 0);
    WidgetsBinding.instance.addPostFrameCallback((_) {
      if (mounted) _bootstrapPages();
    });
  }

  Future<double> _ratioOf(Uint8List bytes) async {
    final codec = await ui.instantiateImageCodec(bytes);
    try {
      final frame = await codec.getNextFrame();
      final ratio = frame.image.width / frame.image.height;
      frame.image.dispose();
      return ratio;
    } finally {
      codec.dispose();
    }
  }

  Future<void> _bootstrapPages() async {
    final camera = context.read<CameraProvider>();
    final edit = context.read<ImageEditProvider>();
    final list = camera.imageList;
    if (list.isEmpty) {
      if (mounted) setState(() => _loading = false);
      return;
    }
    final start = widget.initialIndex.clamp(0, list.length - 1);
    final pages = <_PageSizeState>[];
    try {
      for (var i = 0; i < list.length; i++) {
        var bytes = Uint8List.fromList(list[i].imageByte);
        if (i == start &&
            edit.currentState != null &&
            edit.currentState!.isNotEmpty) {
          bytes = Uint8List.fromList(edit.currentState!);
        }
        final ratio = await _ratioOf(bytes);
        pages.add(_PageSizeState(bytes: bytes, originalRatio: ratio));
      }
      if (!mounted) return;
      setState(() {
        _pages = pages;
        _pageIndex = start;
        _loading = false;
      });
      if (_pageController.hasClients) {
        _pageController.jumpToPage(start);
      }
    } catch (_) {
      if (!mounted) return;
      setState(() => _loading = false);
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text(translation(context).somethingWentWrong)),
      );
    }
  }

  @override
  void dispose() {
    _pageController.dispose();
    super.dispose();
  }

  double _ratioFor(_PageSizeState page, SizeOption size) {
    if (size.title == 'Original') return page.originalRatio;
    return size.radio!;
  }

  Future<void> _goToPage(int index) async {
    if (_pageAnimating || _saving || _loading) return;
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

  /// Stretch to selected aspect (same as preview BoxFit.fill).
  Uint8List _bakePage(_PageSizeState page) {
    if (page.selectedTitle == 'Original' ||
        (page.selectedRatio - page.originalRatio).abs() < 0.001) {
      return ensureJpegBytes(page.bytes);
    }
    final decoded = decodeAnyImage(page.bytes);
    if (decoded == null) return ensureJpegBytes(page.bytes);

    final ratio = page.selectedRatio;
    late final int w;
    late final int h;
    if (ratio >= page.originalRatio) {
      // Wider than original → keep width, shrink height.
      w = decoded.width;
      h = (w / ratio).round().clamp(1, 20000);
    } else {
      // Taller than original → keep height, shrink width.
      h = decoded.height;
      w = (h * ratio).round().clamp(1, 20000);
    }
    final out = img.copyResize(
      decoded,
      width: w,
      height: h,
      interpolation: img.Interpolation.linear,
    );
    return Uint8List.fromList(img.encodeJpg(out, quality: 92));
  }

  Future<void> _onDone() async {
    if (_saving || _pages.isEmpty || _loading) return;
    setState(() => _saving = true);
    await WidgetsBinding.instance.endOfFrame;
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
        final ratio = await _ratioOf(jpeg);
        _pages[i].bytes = jpeg;
        _pages[i].originalRatio = ratio;
        _pages[i].selectedTitle = 'Original';
        _pages[i].selectedRatio = ratio;
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
    if (_loading) {
      return const Scaffold(
        backgroundColor: Color(0xFF131314),
        body: Center(child: CircularProgressIndicator()),
      );
    }
    if (_pages.isEmpty) {
      return const Scaffold(
        backgroundColor: Color(0xFF131314),
        body: Center(child: Text('No pages', style: TextStyle(color: Colors.white))),
      );
    }

    final pageCount = _pages.length;
    final current = _current;

    return Stack(
      fit: StackFit.expand,
      children: [
        Scaffold(
      backgroundColor: const Color(0xFF131314),
      appBar: AppBar(
        backgroundColor: const Color(0xff1E1F20),
        leading: IconButton(
          onPressed: _saving ? null : () => Navigator.pop(context),
          icon: const Icon(Icons.arrow_back, color: Color(0xffffffff)),
        ),
        centerTitle: true,
        title: Text(translation(context).resize),
        titleTextStyle: const TextStyle(
          color: Colors.white,
          fontSize: 20,
          fontWeight: FontWeight.w500,
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
      body: Stack(
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
                        return Center(
                          child: AspectRatio(
                            aspectRatio: page.selectedRatio,
                            child: Image.memory(
                              page.bytes,
                              fit: BoxFit.fill,
                            ),
                          ),
                        );
                      },
                    ),
                  ),
                ),
                if (pageCount > 1)
                  Positioned(
                    left: 0,
                    right: 0,
                    bottom: 12,
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
              for (final size in availableSizeOption)
                Material(
                  color: Colors.transparent,
                  child: InkWell(
                    onTap: _saving
                        ? null
                        : () {
                            setState(() {
                              current.selectedTitle = size.title!;
                              current.selectedRatio = _ratioFor(current, size);
                            });
                          },
                    child: Padding(
                      padding: const EdgeInsets.symmetric(horizontal: 8.0),
                      child: Column(
                        mainAxisAlignment: MainAxisAlignment.center,
                        children: [
                          SvgPicture.asset(
                            AppAssets.size_preview,
                            colorFilter: ColorFilter.mode(
                              current.selectedTitle == size.title
                                  ? Colors.white
                                  : Colors.grey,
                              BlendMode.srcIn,
                            ),
                          ),
                          Container(
                            padding: const EdgeInsets.symmetric(
                                horizontal: 8, vertical: 4),
                            child: Text(
                              getTitle(size, context),
                              style: TextStyle(
                                color: current.selectedTitle == size.title
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
        ),
        if (_saving) const FullScreenSavingOverlay(),
      ],
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

  String getTitle(SizeOption size, BuildContext context) {
    switch (size.title) {
      case 'Original':
        return translation(context).original;
      case 'A4':
        return 'A4';
      case 'A5':
        return 'A5';
      case 'ID Card':
        return translation(context).idCard;
      case 'Legal':
        return translation(context).legal;
      default:
        return '';
    }
  }
}

class SizeOption {
  final String? title;
  final double? radio;

  const SizeOption({this.title, this.radio});
}
