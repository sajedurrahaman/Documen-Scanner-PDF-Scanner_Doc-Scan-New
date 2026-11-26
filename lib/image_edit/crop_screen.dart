import 'dart:math' as math;
import 'dart:typed_data';
import 'dart:ui' as ui;

import 'package:doc_scanner/camera_screen/model/image_model.dart';
import 'package:doc_scanner/camera_screen/provider/camera_provider.dart';
import 'package:doc_scanner/google_ads_helper/banner_ad_widget.dart';
import 'package:doc_scanner/google_ads_helper/google_ads_helper.dart';
import 'package:doc_scanner/image_edit/provider/image_edit_provider.dart';
import 'package:doc_scanner/image_edit/widget/full_screen_saving_overlay.dart';
import 'package:doc_scanner/image_edit/widget/image_edit_unavailable.dart';
import 'package:doc_scanner/utils/app_color.dart';
import 'package:doc_scanner/utils/image_bytes_helper.dart';
import 'package:flutter/material.dart';
import 'package:image/image.dart' as img;
import 'package:provider/provider.dart';

import '../localaization/language_constant.dart';

/// Normalized crop rect (0–1), same model as PDF_Converter-New.
class CropRectNorm {
  const CropRectNorm({
    required this.left,
    required this.top,
    required this.right,
    required this.bottom,
  });

  final double left;
  final double top;
  final double right;
  final double bottom;

  CropRectNorm copyWith({
    double? left,
    double? top,
    double? right,
    double? bottom,
  }) {
    return CropRectNorm(
      left: left ?? this.left,
      top: top ?? this.top,
      right: right ?? this.right,
      bottom: bottom ?? this.bottom,
    );
  }

  CropRectNorm clamp({double minSize = 0.08}) {
    var l = left.clamp(0.0, 1.0);
    var t = top.clamp(0.0, 1.0);
    var r = right.clamp(0.0, 1.0);
    var b = bottom.clamp(0.0, 1.0);
    if (r - l < minSize) {
      if (l + minSize <= 1) {
        r = l + minSize;
      } else {
        l = r - minSize;
      }
    }
    if (b - t < minSize) {
      if (t + minSize <= 1) {
        b = t + minSize;
      } else {
        t = b - minSize;
      }
    }
    return CropRectNorm(
      left: l.clamp(0.0, 1.0),
      top: t.clamp(0.0, 1.0),
      right: r.clamp(0.0, 1.0),
      bottom: b.clamp(0.0, 1.0),
    );
  }

  static const full = CropRectNorm(left: 0, top: 0, right: 1, bottom: 1);

  /// Auto document inset (not full-bleed).
  static const auto = CropRectNorm(
    left: 0.08,
    top: 0.08,
    right: 0.92,
    bottom: 0.92,
  );
}

class _PageCropState {
  _PageCropState({
    required this.bytes,
    required this.crop,
    this.autoCrop = true,
  });

  Uint8List bytes;
  CropRectNorm crop;
  bool autoCrop;
}

class _CropSnapshot {
  const _CropSnapshot({
    required this.pageIndex,
    required this.bytes,
    required this.crop,
    required this.autoCrop,
  });

  final int pageIndex;
  final Uint8List bytes;
  final CropRectNorm crop;
  final bool autoCrop;
}

/// PDF_Converter-New style crop for document edit.
class CropScreen extends StatefulWidget {
  final ImageModel imageModel;
  final int index;
  final bool? cameFromEdit;

  const CropScreen({
    super.key,
    required this.imageModel,
    required this.index,
    this.cameFromEdit,
  });

  @override
  State<CropScreen> createState() => _CropScreenState();
}

class _CropScreenState extends State<CropScreen> {
  late PageController _pageController;
  late List<_PageCropState> _pages;
  late int _pageIndex;

  bool _saving = false;
  bool _dragStarted = false;
  bool _pageAnimating = false;

  /// True when crop covers the full image (All option).
  bool get _isFullSelect =>
      _pages.isNotEmpty &&
      _current.crop.left <= 0.001 &&
      _current.crop.top <= 0.001 &&
      _current.crop.right >= 0.999 &&
      _current.crop.bottom >= 0.999;

  final List<_CropSnapshot> _undoStack = [];
  final List<_CropSnapshot> _redoStack = [];

  _PageCropState get _current {
    final i = _pageIndex.clamp(0, _pages.length - 1);
    return _pages[i];
  }

  @override
  void initState() {
    super.initState();
    // Start at 0 until [_bootstrapPages] loads the full list — widget.index
    // may be > 0 while [_pages] still has only the opener image.
    _pageIndex = 0;
    _pages = [
      _PageCropState(
        bytes: Uint8List.fromList(widget.imageModel.imageByte),
        crop: CropRectNorm.auto,
        autoCrop: true,
      ),
    ];
    _pageController = PageController(initialPage: 0);
    WidgetsBinding.instance.addPostFrameCallback((_) {
      if (!mounted) return;
      _bootstrapPages();
    });
  }

  void _bootstrapPages() {
    final camera = context.read<CameraProvider>();
    final edit = context.read<ImageEditProvider>();
    final list = camera.imageList;
    if (list.isEmpty) return;

    final start = widget.index.clamp(0, list.length - 1);
    final pages = <_PageCropState>[];
    for (var i = 0; i < list.length; i++) {
      var bytes = Uint8List.fromList(list[i].imageByte);
      if (widget.cameFromEdit == true &&
          i == start &&
          edit.currentState != null &&
          edit.currentState!.isNotEmpty) {
        bytes = Uint8List.fromList(edit.currentState!);
      }
      pages.add(
        _PageCropState(
          bytes: bytes,
          crop: CropRectNorm.auto,
          autoCrop: true,
        ),
      );
    }

    _pageController.dispose();
    _pageController = PageController(initialPage: start);
    setState(() {
      _pages = pages;
      _pageIndex = start;
    });
    WidgetsBinding.instance.addPostFrameCallback((_) {
      if (!mounted || !_pageController.hasClients) return;
      if (_pageController.page?.round() != start) {
        _pageController.jumpToPage(start);
      }
    });
  }

  @override
  void dispose() {
    _pageController.dispose();
    super.dispose();
  }

  _CropSnapshot _snapshot() => _CropSnapshot(
        pageIndex: _pageIndex,
        bytes: Uint8List.fromList(_current.bytes),
        crop: _current.crop,
        autoCrop: _current.autoCrop,
      );

  void _pushHistory() {
    _undoStack.add(_snapshot());
    _redoStack.clear();
  }

  void _undo() {
    if (_undoStack.isEmpty || _saving) return;
    setState(() {
      _redoStack.add(_snapshot());
      final snap = _undoStack.removeLast();
      _pageIndex = snap.pageIndex.clamp(0, _pages.length - 1);
      _pages[_pageIndex]
        ..bytes = snap.bytes
        ..crop = snap.crop
        ..autoCrop = snap.autoCrop;
    });
    if (_pageController.hasClients &&
        _pageController.page?.round() != _pageIndex) {
      _pageController.jumpToPage(_pageIndex);
    }
  }

  void _redo() {
    if (_redoStack.isEmpty || _saving) return;
    setState(() {
      _undoStack.add(_snapshot());
      final snap = _redoStack.removeLast();
      _pageIndex = snap.pageIndex.clamp(0, _pages.length - 1);
      _pages[_pageIndex]
        ..bytes = snap.bytes
        ..crop = snap.crop
        ..autoCrop = snap.autoCrop;
    });
    if (_pageController.hasClients &&
        _pageController.page?.round() != _pageIndex) {
      _pageController.jumpToPage(_pageIndex);
    }
  }

  Future<Uint8List?> _rotateBytes(Uint8List bytes, int angle) async {
    final decoded = decodeAnyImage(bytes);
    if (decoded == null) return null;
    final rotated = img.copyRotate(decoded, angle: angle);
    return Uint8List.fromList(img.encodeJpg(rotated, quality: 92));
  }

  Future<void> _rotate(int angle) async {
    if (_saving || _pages.isEmpty) return;
    _pushHistory();
    final rotated = await _rotateBytes(_current.bytes, angle);
    if (!mounted || rotated == null) return;
    setState(() {
      _current.bytes = rotated;
      // Keep auto/manual crop mode after rotate.
      _current.crop =
          _current.autoCrop ? CropRectNorm.auto : CropRectNorm.full;
    });
  }

  /// Auto Crop = inset document crop window.
  void _selectAutoCrop() {
    if (_saving || _pages.isEmpty) return;
    if (_current.autoCrop && !_isFullSelect) return;
    _pushHistory();
    setState(() {
      _current.autoCrop = true;
      _current.crop = CropRectNorm.auto;
    });
  }

  /// All = full image select (e.g. 800×888 → entire 800×888).
  void _selectFullDocument() {
    if (_saving || _pages.isEmpty) return;
    if (_isFullSelect) return;
    _pushHistory();
    setState(() {
      _current.autoCrop = false;
      _current.crop = CropRectNorm.full;
    });
  }

  Future<Uint8List?> _cropBytes(Uint8List src, CropRectNorm crop) async {
    final decoded = decodeAnyImage(src);
    if (decoded == null) return ensureJpegBytes(src);
    final w = decoded.width.toDouble();
    final h = decoded.height.toDouble();
    final left = (crop.left * w).round().clamp(0, decoded.width - 1);
    final top = (crop.top * h).round().clamp(0, decoded.height - 1);
    final right = (crop.right * w).round().clamp(left + 1, decoded.width);
    final bottom = (crop.bottom * h).round().clamp(top + 1, decoded.height);
    final cropped = img.copyCrop(
      decoded,
      x: left,
      y: top,
      width: right - left,
      height: bottom - top,
    );
    return Uint8List.fromList(img.encodeJpg(cropped, quality: 92));
  }

  Future<void> _onDone() async {
    if (_saving || _pages.isEmpty) return;
    setState(() => _saving = true);
    await WidgetsBinding.instance.endOfFrame;
    try {
      final camera = context.read<CameraProvider>();
      final edit = context.read<ImageEditProvider>();
      final fromEdit = widget.cameFromEdit == true;
      final count =
          _pages.length < camera.imageList.length
              ? _pages.length
              : camera.imageList.length;
      final currentIndex = _pageIndex.clamp(0, count - 1);
      Uint8List? currentOut;

      // Apply crop on every page (full select = keep bytes, no re-crop).
      for (var i = 0; i < count; i++) {
        final page = _pages[i];
        final isFull = page.crop.left <= 0.001 &&
            page.crop.top <= 0.001 &&
            page.crop.right >= 0.999 &&
            page.crop.bottom >= 0.999;
        final out = isFull
            ? ensureJpegBytes(page.bytes)
            : await _cropBytes(page.bytes, page.crop);
        if (out == null) continue;
        page.bytes = out;
        page.crop = CropRectNorm.full;
        page.autoCrop = false;
        final old = camera.imageList[i];
        camera.updateImage(
          index: i,
          image: ImageModel(
            imageByte: out,
            name: old.name,
            docType: old.docType,
          ),
        );
        if (i == currentIndex) currentOut = out;
      }

      if (fromEdit && currentOut != null) {
        edit.addState(currentOut);
      }

      if (mounted) Navigator.pop(context);
    } catch (e) {
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text('${translation(context).somethingWentWrong}: $e'),
        ),
      );
    } finally {
      if (mounted) setState(() => _saving = false);
    }
  }

  void _onPageChanged(int index) {
    if (index == _pageIndex) return;
    setState(() {
      _pageIndex = index;
      _dragStarted = false;
      _pageAnimating = false;
    });
  }

  Future<void> _goToPage(int index) async {
    if (_pageAnimating || _dragStarted || _saving) return;
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

  @override
  Widget build(BuildContext context) {
    if (_pages.isEmpty) return const ImageEditUnavailable();
    final pageCount = _pages.length;
    final bottomInset = MediaQuery.paddingOf(context).bottom;

    return Stack(
      fit: StackFit.expand,
      children: [
        Scaffold(
      backgroundColor: const Color(0xFF131314),
      appBar: AppBar(
        backgroundColor: const Color(0xff1E1F20),
        centerTitle: true,
        leading: IconButton(
          onPressed: _saving ? null : () => Navigator.pop(context),
          icon: const Icon(Icons.arrow_back, color: Colors.white),
        ),
        title: const Text(
          'Crop Document',
          style: TextStyle(
            fontSize: 18,
            fontWeight: FontWeight.w600,
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
                fontWeight: FontWeight.w600,
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
                    padding: const EdgeInsets.fromLTRB(8, 8, 8, 96),
                    child: PageView.builder(
                      controller: _pageController,
                      itemCount: pageCount,
                      onPageChanged: _onPageChanged,
                      // Never let PageView steal crop-handle drags.
                      // Page changes come from shade-area horizontal swipe.
                      physics: const NeverScrollableScrollPhysics(),
                      itemBuilder: (context, index) {
                        final page = _pages[index];
                        return DocumentCropViewport(
                          imageBytes: page.bytes,
                          crop: page.crop,
                          onCropChanged: (rect) {
                            if (index != _pageIndex) return;
                            setState(() {
                              page.crop = rect;
                              // Manual drag leaves auto mode.
                              page.autoCrop = false;
                            });
                          },
                          onDragStart: () {
                            if (index != _pageIndex) return;
                            if (_dragStarted) return;
                            _pushHistory();
                            setState(() => _dragStarted = true);
                          },
                          onDragEnd: () {
                            if (!_dragStarted) return;
                            setState(() => _dragStarted = false);
                          },
                          onSwipePage: (delta) {
                            if (index != _pageIndex) return;
                            if (delta < 0) {
                              _goToPage(_pageIndex + 1);
                            } else if (delta > 0) {
                              _goToPage(_pageIndex - 1);
                            }
                          },
                        );
                      },
                    ),
                  ),
                ),
                // Undo (correct icon) then Redo — bottom-right of preview.
                Positioned(
                  right: 16,
                  bottom: 73,
                  child: Row(
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      _roundIconButton(
                        enabled: _undoStack.isNotEmpty,
                        tooltip: translation(context).undo,
                        onTap: _undo,
                        child: Icon(
                          Icons.undo,
                          size: 16,
                          color: _undoStack.isEmpty
                              ? Colors.white38
                              : Colors.white,
                        ),
                      ),
                      const SizedBox(width: 8),
                      _roundIconButton(
                        enabled: _redoStack.isNotEmpty,
                        tooltip: 'Redo',
                        onTap: _redo,
                        child: Icon(
                          Icons.redo,
                          size: 16,
                          color: _redoStack.isEmpty
                              ? Colors.white38
                              : Colors.white,
                        ),
                      ),
                    ],
                  ),
                ),
                if (pageCount > 1)
                  Positioned(
                    left: 0,
                    right: 0,
                    bottom: 16,
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
      bottomNavigationBar: Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          Container(
            width: double.infinity,
            color: const Color(0xff1E1F20),
            padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 10),
            child: Row(
              mainAxisAlignment: MainAxisAlignment.spaceEvenly,
              children: [
                _bottomAction(
                  label: 'Left',
                  selected: false,
                  icon: Icons.rotate_left,
                  onTap: () => _rotate(-90),
                ),
                _bottomAction(
                  label: 'Right',
                  selected: false,
                  icon: Icons.rotate_right,
                  onTap: () => _rotate(90),
                ),
                _bottomAction(
                  label: 'Auto Crop',
                  selected: _pages.isNotEmpty &&
                      _current.autoCrop &&
                      !_isFullSelect,
                  icon: Icons.crop_free,
                  onTap: _selectAutoCrop,
                ),
                _bottomAction(
                  label: 'All',
                  selected: _isFullSelect,
                  icon: Icons.select_all,
                  onTap: _selectFullDocument,
                ),
              ],
            ),
          ),
          SafeArea(
            top: false,
            left: false,
            right: false,
            minimum: EdgeInsets.only(bottom: bottomInset > 0 ? 0 : 0),
            child: BannerAdWidget(
              adUnitId: AdHelper.imageCropBannerAdUnitId,
            ),
          ),
        ],
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

  Widget _roundIconButton({
    required bool enabled,
    required VoidCallback onTap,
    required Widget child,
    required String tooltip,
  }) {
    return Material(
      color: const Color(0xCC2A2B2C),
      shape: const CircleBorder(),
      child: InkWell(
        customBorder: const CircleBorder(),
        onTap: enabled && !_saving ? onTap : null,
        child: Tooltip(
          message: tooltip,
          child: SizedBox(
            width: 32,
            height: 32,
            child: Center(child: child),
          ),
        ),
      ),
    );
  }

  Widget _bottomAction({
    required String label,
    required bool selected,
    required IconData icon,
    required VoidCallback onTap,
  }) {
    final color = selected ? AppColor.primaryColor : Colors.white70;
    return InkWell(
      onTap: _saving ? null : onTap,
      borderRadius: BorderRadius.circular(8),
      child: Padding(
        padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 6),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            Icon(icon, color: color, size: 24),
            const SizedBox(height: 4),
            Text(
              label,
              style: TextStyle(
                color: color,
                fontSize: 11,
                fontWeight: selected ? FontWeight.w600 : FontWeight.w400,
              ),
            ),
          ],
        ),
      ),
    );
  }
}

enum _CropHandle {
  topLeft,
  top,
  topRight,
  left,
  right,
  bottomLeft,
  bottom,
  bottomRight,
  move,
}

/// PDF_Converter-New crop viewport — shade + border + 8 handles.
/// Extra margin so full-select handles/border are not clipped.
class DocumentCropViewport extends StatefulWidget {
  const DocumentCropViewport({
    super.key,
    required this.imageBytes,
    required this.crop,
    required this.onCropChanged,
    required this.onDragStart,
    required this.onDragEnd,
    this.onSwipePage,
  });

  final Uint8List imageBytes;
  final CropRectNorm crop;
  final ValueChanged<CropRectNorm> onCropChanged;
  final VoidCallback onDragStart;
  final VoidCallback onDragEnd;

  /// Called with horizontal delta sign when user swipes on the dimmed area
  /// (not on crop handles / crop box): negative = next, positive = previous.
  final ValueChanged<int>? onSwipePage;

  @override
  State<DocumentCropViewport> createState() => _DocumentCropViewportState();
}

class _DocumentCropViewportState extends State<DocumentCropViewport> {
  static const _handleHit = 30.0;
  static const _handleVisual = 16.0;
  static const _edgePad = 20.0; // keeps full-bleed handles visible
  static const _cropColor = AppColor.primaryColor;

  _CropHandle? _activeHandle;
  CropRectNorm? _startCrop;
  Offset? _startLocal;
  bool _pageSwipe = false;
  double _pageSwipeDx = 0;
  Future<Size>? _sizeFuture;
  Uint8List? _sizedBytes;

  @override
  void initState() {
    super.initState();
    _ensureSizeFuture();
  }

  @override
  void didUpdateWidget(covariant DocumentCropViewport oldWidget) {
    super.didUpdateWidget(oldWidget);
    if (!identical(oldWidget.imageBytes, widget.imageBytes)) {
      _ensureSizeFuture();
    }
  }

  void _ensureSizeFuture() {
    if (identical(_sizedBytes, widget.imageBytes) && _sizeFuture != null) {
      return;
    }
    _sizedBytes = widget.imageBytes;
    _sizeFuture = _imageSize(widget.imageBytes);
  }

  Rect _cropToLocal(CropRectNorm crop, Size size) {
    return Rect.fromLTRB(
      crop.left * size.width,
      crop.top * size.height,
      crop.right * size.width,
      crop.bottom * size.height,
    );
  }

  _CropHandle? _hitTest(Offset local, Rect cropRect) {
    Offset center(_CropHandle h) {
      switch (h) {
        case _CropHandle.topLeft:
          return cropRect.topLeft;
        case _CropHandle.top:
          return Offset(cropRect.center.dx, cropRect.top);
        case _CropHandle.topRight:
          return cropRect.topRight;
        case _CropHandle.left:
          return Offset(cropRect.left, cropRect.center.dy);
        case _CropHandle.right:
          return Offset(cropRect.right, cropRect.center.dy);
        case _CropHandle.bottomLeft:
          return cropRect.bottomLeft;
        case _CropHandle.bottom:
          return Offset(cropRect.center.dx, cropRect.bottom);
        case _CropHandle.bottomRight:
          return cropRect.bottomRight;
        case _CropHandle.move:
          return cropRect.center;
      }
    }

    const handles = [
      _CropHandle.topLeft,
      _CropHandle.top,
      _CropHandle.topRight,
      _CropHandle.left,
      _CropHandle.right,
      _CropHandle.bottomLeft,
      _CropHandle.bottom,
      _CropHandle.bottomRight,
    ];

    for (final h in handles) {
      if ((local - center(h)).distance <= _handleHit / 2) return h;
    }
    if (cropRect.contains(local)) return _CropHandle.move;
    return null;
  }

  void _onPanStart(DragStartDetails d, Size size) {
    final cropRect = _cropToLocal(widget.crop, size);
    final handle = _hitTest(d.localPosition, cropRect);
    _startLocal = d.localPosition;
    _pageSwipeDx = 0;
    // Only the 8 edge/corner dots resize the crop. Everything else can
    // become a page swipe (including inside the crop / full-select).
    final isResizeHandle =
        handle != null && handle != _CropHandle.move;
    if (isResizeHandle) {
      widget.onDragStart();
      _activeHandle = handle;
      _startCrop = widget.crop;
      _pageSwipe = false;
      return;
    }
    // Inside crop (move) or dimmed area — start as undecided page-swipe;
    // if movement is mostly vertical/small we can still move crop later.
    _activeHandle = handle == _CropHandle.move ? _CropHandle.move : null;
    _startCrop = handle == _CropHandle.move ? widget.crop : null;
    _pageSwipe = handle != _CropHandle.move;
    if (handle == _CropHandle.move) {
      // Tentative move; may convert to page-swipe if mostly horizontal.
      widget.onDragStart();
    }
  }

  void _onPanUpdate(DragUpdateDetails d, Size size) {
    // Convert tentative crop-move into page swipe when gesture is horizontal.
    if (_activeHandle == _CropHandle.move &&
        _startLocal != null &&
        !_pageSwipe) {
      final totalDx = d.localPosition.dx - _startLocal!.dx;
      final totalDy = d.localPosition.dy - _startLocal!.dy;
      if (totalDx.abs() > 18 && totalDx.abs() > totalDy.abs() * 1.35) {
        widget.onDragEnd();
        _activeHandle = null;
        _startCrop = null;
        _pageSwipe = true;
        _pageSwipeDx = totalDx;
        return;
      }
    }

    if (_pageSwipe) {
      _pageSwipeDx += d.delta.dx;
      return;
    }
    if (_activeHandle == null || _startCrop == null || _startLocal == null) {
      return;
    }
    final dx = (d.localPosition.dx - _startLocal!.dx) / size.width;
    final dy = (d.localPosition.dy - _startLocal!.dy) / size.height;
    var c = _startCrop!;

    switch (_activeHandle!) {
      case _CropHandle.topLeft:
        c = c.copyWith(left: c.left + dx, top: c.top + dy);
      case _CropHandle.top:
        c = c.copyWith(top: c.top + dy);
      case _CropHandle.topRight:
        c = c.copyWith(right: c.right + dx, top: c.top + dy);
      case _CropHandle.left:
        c = c.copyWith(left: c.left + dx);
      case _CropHandle.right:
        c = c.copyWith(right: c.right + dx);
      case _CropHandle.bottomLeft:
        c = c.copyWith(left: c.left + dx, bottom: c.bottom + dy);
      case _CropHandle.bottom:
        c = c.copyWith(bottom: c.bottom + dy);
      case _CropHandle.bottomRight:
        c = c.copyWith(right: c.right + dx, bottom: c.bottom + dy);
      case _CropHandle.move:
        var nl = c.left + dx;
        var nt = c.top + dy;
        var nr = c.right + dx;
        var nb = c.bottom + dy;
        if (nl < 0) {
          nr -= nl;
          nl = 0;
        }
        if (nt < 0) {
          nb -= nt;
          nt = 0;
        }
        if (nr > 1) {
          nl -= (nr - 1);
          nr = 1;
        }
        if (nb > 1) {
          nt -= (nb - 1);
          nb = 1;
        }
        c = CropRectNorm(left: nl, top: nt, right: nr, bottom: nb);
    }

    widget.onCropChanged(c.clamp());
  }

  void _onPanEnd(DragEndDetails _) {
    if (_pageSwipe) {
      const threshold = 28.0;
      if (_pageSwipeDx <= -threshold) {
        widget.onSwipePage?.call(-1);
      } else if (_pageSwipeDx >= threshold) {
        widget.onSwipePage?.call(1);
      }
    } else if (_activeHandle != null) {
      widget.onDragEnd();
    }
    _activeHandle = null;
    _startCrop = null;
    _startLocal = null;
    _pageSwipe = false;
    _pageSwipeDx = 0;
  }

  @override
  Widget build(BuildContext context) {
    return LayoutBuilder(
      builder: (context, constraints) {
        return FutureBuilder<Size>(
          future: _sizeFuture,
          builder: (context, snap) {
            final imgSize = snap.data;
            if (imgSize == null) {
              return const Center(
                child: CircularProgressIndicator(color: _cropColor),
              );
            }

            final maxW = (constraints.maxWidth - _edgePad * 2).clamp(1.0, 9999);
            final maxH =
                (constraints.maxHeight - _edgePad * 2).clamp(1.0, 9999);
            final scale =
                math.min(maxW / imgSize.width, maxH / imgSize.height);
            final dispW = imgSize.width * scale;
            final dispH = imgSize.height * scale;
            final size = Size(dispW, dispH);
            final cropRect = _cropToLocal(widget.crop, size);

            return Center(
              child: Padding(
                padding: const EdgeInsets.all(_edgePad),
                child: SizedBox(
                  width: dispW,
                  height: dispH,
                  child: GestureDetector(
                    behavior: HitTestBehavior.opaque,
                    onPanStart: (d) => _onPanStart(d, size),
                    onPanUpdate: (d) => _onPanUpdate(d, size),
                    onPanEnd: _onPanEnd,
                    child: Stack(
                      clipBehavior: Clip.none,
                      fit: StackFit.expand,
                      children: [
                        Image.memory(
                          widget.imageBytes,
                          fit: BoxFit.fill,
                          filterQuality: FilterQuality.high,
                          gaplessPlayback: true,
                        ),
                        CustomPaint(
                          painter: _CropShadePainter(cropRect: cropRect),
                        ),
                        Positioned.fromRect(
                          rect: cropRect,
                          child: IgnorePointer(
                            child: Container(
                              decoration: BoxDecoration(
                                border: Border.all(
                                  color: _cropColor,
                                  width: 2,
                                ),
                              ),
                            ),
                          ),
                        ),
                        ..._handleWidgets(cropRect),
                      ],
                    ),
                  ),
                ),
              ),
            );
          },
        );
      },
    );
  }

  List<Widget> _handleWidgets(Rect cropRect) {
    final points = <Offset>[
      cropRect.topLeft,
      Offset(cropRect.center.dx, cropRect.top),
      cropRect.topRight,
      Offset(cropRect.left, cropRect.center.dy),
      Offset(cropRect.right, cropRect.center.dy),
      cropRect.bottomLeft,
      Offset(cropRect.center.dx, cropRect.bottom),
      cropRect.bottomRight,
    ];

    return points.map((p) {
      return Positioned(
        left: p.dx - _handleVisual / 2,
        top: p.dy - _handleVisual / 2,
        child: IgnorePointer(
          child: Container(
            width: _handleVisual,
            height: _handleVisual,
            decoration: const BoxDecoration(
              color: _cropColor,
              shape: BoxShape.circle,
            ),
          ),
        ),
      );
    }).toList();
  }

  Future<Size> _imageSize(Uint8List bytes) async {
    final decoded = await ui.instantiateImageCodec(bytes);
    try {
      final frame = await decoded.getNextFrame();
      final size = Size(
        frame.image.width.toDouble(),
        frame.image.height.toDouble(),
      );
      frame.image.dispose();
      return size;
    } finally {
      decoded.dispose();
    }
  }
}

class _CropShadePainter extends CustomPainter {
  _CropShadePainter({required this.cropRect});

  final Rect cropRect;

  @override
  void paint(Canvas canvas, Size size) {
    final path = Path()
      ..addRect(Offset.zero & size)
      ..addRect(cropRect)
      ..fillType = PathFillType.evenOdd;
    canvas.drawPath(
      path,
      Paint()..color = Colors.black.withValues(alpha: 0.35),
    );
  }

  @override
  bool shouldRepaint(covariant _CropShadePainter oldDelegate) =>
      oldDelegate.cropRect != cropRect;
}
