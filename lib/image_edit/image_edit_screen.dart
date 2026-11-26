import 'dart:typed_data';

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
import 'widget/full_screen_saving_overlay.dart';
import 'widget/image_edit_unavailable.dart';
import 'image_rotation.dart';

/// CamScanner-style editor: swipe pages horizontally; tools edit the
/// currently visible page only (1/3, 2/3, 3/3…).
class ImageEditScreen extends StatefulWidget {
  final ImageModel image;
  final int imageIndex;

  const ImageEditScreen({
    super.key,
    required this.image,
    required this.imageIndex,
  });

  @override
  State<ImageEditScreen> createState() => _ImageEditScreenState();
}

class _ImageEditScreenState extends State<ImageEditScreen> {
  late final PageController _pageController;
  late int _pageIndex;
  bool _initialized = false;
  bool _switchingPage = false;
  bool _saving = false;

  @override
  void initState() {
    super.initState();
    _pageIndex = widget.imageIndex;
    _pageController = PageController(initialPage: _pageIndex);
    WidgetsBinding.instance.addPostFrameCallback((_) {
      if (!mounted) return;
      final camera = context.read<CameraProvider>();
      final safe = _pageIndex.clamp(0, camera.imageList.length - 1);
      _pageIndex = safe;
      if (camera.imageList.isEmpty) {
        setState(() => _initialized = true);
        return;
      }
      context
          .read<ImageEditProvider>()
          .startSession(camera.imageList[safe].imageByte);
      setState(() => _initialized = true);
    });
  }

  @override
  void dispose() {
    _pageController.dispose();
    super.dispose();
  }

  ImageModel _modelAt(CameraProvider camera, int index) {
    return camera.imageList[index];
  }

  void _commitPage(int index) {
    final edit = context.read<ImageEditProvider>();
    final camera = context.read<CameraProvider>();
    final current = edit.currentState;
    if (current == null) return;
    if (index < 0 || index >= camera.imageList.length) return;
    final old = camera.imageList[index];
    // Skip write if unchanged.
    if (identical(old.imageByte, current)) return;
    camera.updateImage(
      index: index,
      image: old.withDisplayBytes(current),
    );
  }

  Future<void> _onPageChanged(int index) async {
    if (_switchingPage || index == _pageIndex) return;
    _switchingPage = true;
    try {
      // Persist edits for the page we leave (CamScanner-style).
      _commitPage(_pageIndex);
      final camera = context.read<CameraProvider>();
      if (index < 0 || index >= camera.imageList.length) return;
      context
          .read<ImageEditProvider>()
          .startSession(camera.imageList[index].imageByte);
      if (mounted) setState(() => _pageIndex = index);
    } finally {
      _switchingPage = false;
    }
  }

  Future<void> _done() async {
    if (_saving) return;
    final camera = context.read<CameraProvider>();
    final edit = context.read<ImageEditProvider>();
    final current = edit.currentState;
    if (current == null ||
        _pageIndex < 0 ||
        _pageIndex >= camera.imageList.length) {
      return;
    }
    setState(() => _saving = true);
    await WidgetsBinding.instance.endOfFrame;
    try {
      _commitPage(_pageIndex);
      edit.clearState();
      if (mounted) Navigator.pop(context);
    } catch (_) {
      if (mounted) setState(() => _saving = false);
    }
  }

  void _back() {
    if (_saving) return;
    // Discard in-progress undo stack for the visible page only; earlier
    // swiped pages were already committed in [_onPageChanged].
    context.read<ImageEditProvider>().clearState();
    Navigator.pop(context);
  }

  /// After Filters/Size Done (all pages already saved in CameraProvider).
  Future<void> _applyToolResult((int, Uint8List)? applied) async {
    if (!mounted || applied == null) return;
    final (index, jpeg) = applied;
    final edit = context.read<ImageEditProvider>();
    final camera = context.read<CameraProvider>();
    if (index < 0 || index >= camera.imageList.length) return;
    if (index != _pageIndex) {
      // Leaving page: do not overwrite other pages already baked by the tool.
      setState(() => _pageIndex = index);
      if (_pageController.hasClients) {
        _pageController.jumpToPage(index);
      }
      edit.startSession(jpeg);
    } else {
      edit.addState(jpeg);
    }
    // Force rebuild so off-page thumbnails pick up CameraProvider updates.
    if (mounted) setState(() {});
  }

  @override
  Widget build(BuildContext context) {
    final imageEditProvider = context.watch<ImageEditProvider>();
    final cameraProvider = context.watch<CameraProvider>();
    final pageCount = cameraProvider.imageList.length;
    final bytes = _initialized ? imageEditProvider.currentState : null;

    if (_initialized && pageCount == 0) {
      return const ImageEditUnavailable();
    }
    if (_initialized && bytes == null && pageCount > 0) {
      return const ImageEditUnavailable();
    }

    final safeIndex = pageCount == 0 ? 0 : _pageIndex.clamp(0, pageCount - 1);
    final currentModel =
        pageCount > 0 ? _modelAt(cameraProvider, safeIndex) : widget.image;
    final canSave = bytes != null && pageCount > 0;

    return PopScope(
      canPop: !_saving,
      onPopInvokedWithResult: (didPop, _) {
        if (didPop) imageEditProvider.clearState();
      },
      child: Stack(
        fit: StackFit.expand,
        children: [
          Scaffold(
        backgroundColor: const Color(0xFF131314),
        appBar: AppBar(
          backgroundColor: const Color(0xff1E1F20),
          centerTitle: true,
          leading: IconButton(
            onPressed: _saving ? null : _back,
            icon: const Icon(Icons.arrow_back, color: Color(0xffffffff)),
          ),
          title: Text(currentModel.name),
          titleTextStyle: const TextStyle(
            color: Colors.white,
            fontSize: 20,
            fontWeight: FontWeight.w500,
          ),
          actions: [
            TextButton(
              onPressed: canSave && !_saving ? _done : null,
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
            if (!_initialized || bytes == null)
              const Center(child: CircularProgressIndicator())
            else
              PageView.builder(
                controller: _pageController,
                itemCount: pageCount,
                onPageChanged: _onPageChanged,
                itemBuilder: (context, index) {
                  final pageBytes = index == _pageIndex
                      ? (imageEditProvider.currentState ??
                          cameraProvider.imageList[index].imageByte)
                      : cameraProvider.imageList[index].imageByte;
                  return Padding(
                    padding: const EdgeInsets.all(15),
                    child: Center(
                      child: Image.memory(
                        pageBytes,
                        fit: BoxFit.contain,
                        filterQuality: FilterQuality.high,
                      ),
                    ),
                  );
                },
              ),
            if (pageCount > 1)
              Positioned(
                left: 0,
                right: 0,
                bottom: 7,
                child: Center(
                  child: Container(
                    padding:
                        const EdgeInsets.symmetric(horizontal: 10, vertical: 4),
                    decoration: BoxDecoration(
                      color: const Color(0xCC1E1F20),
                      borderRadius: BorderRadius.circular(14),
                    ),
                    child: Text(
                      '${safeIndex + 1}/$pageCount',
                      style: const TextStyle(
                        color: Colors.white,
                        fontSize: 12,
                        fontWeight: FontWeight.w500,
                      ),
                    ),
                  ),
                ),
              ),
          ],
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
                                imageModel: currentModel,
                                index: safeIndex,
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
                      : () async {
                          final applied =
                              await Navigator.push<(int, Uint8List)>(
                            context,
                            MaterialPageRoute(
                              builder: (context) {
                                return ImageFilters(initialIndex: safeIndex);
                              },
                            ),
                          );
                          await _applyToolResult(applied);
                        },
                  iconPath: AppAssets.filter,
                ),
                ImageEditButton(
                  title: translation(context).size,
                  onTap: bytes == null
                      ? null
                      : () async {
                          final applied =
                              await Navigator.push<(int, Uint8List)>(
                            context,
                            MaterialPageRoute(
                              builder: (context) {
                                return ImageSizeScreen(initialIndex: safeIndex);
                              },
                            ),
                          );
                          await _applyToolResult(applied);
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
                                imageModel: currentModel,
                                index: safeIndex,
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
          if (_saving) const FullScreenSavingOverlay(),
        ],
      ),
    );
  }
}
