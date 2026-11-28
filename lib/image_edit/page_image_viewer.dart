import 'dart:typed_data';

import 'package:doc_scanner/utils/helper.dart';
import 'package:extended_image/extended_image.dart';
import 'package:flutter/material.dart';

/// Full-screen image viewer for pages opened from [EditImagePreview].
/// Two-finger pinch zoom + swipe between pages (CamScanner-style).
class PageImageViewer extends StatefulWidget {
  const PageImageViewer({
    super.key,
    required this.pages,
    required this.initialIndex,
    this.title,
  });

  final List<Uint8List> pages;
  final int initialIndex;
  final String? title;

  @override
  State<PageImageViewer> createState() => _PageImageViewerState();
}

class _PageImageViewerState extends State<PageImageViewer> {
  late final ExtendedPageController _controller;
  late int _index;

  @override
  void initState() {
    super.initState();
    _index = widget.initialIndex.clamp(0, widget.pages.length - 1);
    _controller = ExtendedPageController(initialPage: _index);
  }

  @override
  void dispose() {
    _controller.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final isIpad = AppHelper.isIpad(context);
    final topInset = MediaQuery.paddingOf(context).top;
    final bottomInset = MediaQuery.paddingOf(context).bottom;

    // Phone: compact bar (status pulled slightly up). iPad: full safe area + taller row.
    final toolbarH = isIpad ? 48.0 : 28.0;
    final barTop = isIpad ? topInset : (topInset - 8).clamp(0.0, topInset);
    final barH = barTop + toolbarH;
    final backSize = isIpad ? 22.0 : 18.0;
    final titleSize = isIpad ? 18.0 : 15.0;
    final pageFontSize = isIpad ? 16.0 : 14.0;

    return Scaffold(
      backgroundColor: Colors.black,
      extendBodyBehindAppBar: true,
      appBar: PreferredSize(
        preferredSize: Size.fromHeight(barH),
        child: Container(
          color: Colors.black,
          padding: EdgeInsets.only(top: barTop),
          height: barH,
          child: Row(
            children: [
              IconButton(
                padding: EdgeInsets.zero,
                constraints: BoxConstraints(
                  minWidth: isIpad ? 48 : 36,
                  minHeight: isIpad ? 44 : 28,
                ),
                visualDensity:
                    isIpad ? VisualDensity.standard : VisualDensity.compact,
                onPressed: () => Navigator.pop(context),
                icon: Icon(
                  Icons.arrow_back_ios_new,
                  color: Colors.white,
                  size: backSize,
                ),
              ),
              Expanded(
                child: Text(
                  widget.title ?? '',
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis,
                  style: TextStyle(
                    color: Colors.white,
                    fontSize: titleSize,
                    fontWeight: FontWeight.w500,
                    height: 1.0,
                  ),
                ),
              ),
              if (isIpad) const SizedBox(width: 12),
            ],
          ),
        ),
      ),
      body: Stack(
        children: [
          ExtendedImageGesturePageView.builder(
            controller: _controller,
            itemCount: widget.pages.length,
            onPageChanged: (value) => setState(() => _index = value),
            itemBuilder: (context, index) {
              return ExtendedImage.memory(
                widget.pages[index],
                fit: BoxFit.contain,
                mode: ExtendedImageMode.gesture,
                initGestureConfigHandler: (_) => GestureConfig(
                  minScale: 1,
                  maxScale: 5,
                  animationMinScale: 0.8,
                  animationMaxScale: 5.5,
                  speed: 1,
                  inertialSpeed: 100,
                  initialScale: 1,
                  inPageView: true,
                  initialAlignment: InitialAlignment.center,
                  cacheGesture: false,
                ),
                onDoubleTap: (state) {
                  final pointerDown = state.pointerDownPosition;
                  final begin = state.gestureDetails?.totalScale ?? 1.0;
                  final end = begin > 1.2 ? 1.0 : 2.5;
                  state.handleDoubleTap(
                    scale: end,
                    doubleTapPosition: pointerDown,
                  );
                },
              );
            },
          ),
          Positioned(
            left: 0,
            right: 0,
            bottom: bottomInset + (isIpad ? 36 : 24),
            child: IgnorePointer(
              child: Center(
                child: Container(
                  padding: EdgeInsets.symmetric(
                    horizontal: isIpad ? 18 : 14,
                    vertical: isIpad ? 8 : 6,
                  ),
                  decoration: BoxDecoration(
                    color: Colors.black.withValues(alpha: 0.55),
                    borderRadius: BorderRadius.circular(20),
                  ),
                  child: Text(
                    '${_index + 1}/${widget.pages.length}',
                    style: TextStyle(
                      color: Colors.white,
                      fontSize: pageFontSize,
                      fontWeight: FontWeight.w500,
                    ),
                  ),
                ),
              ),
            ),
          ),
        ],
      ),
    );
  }
}
