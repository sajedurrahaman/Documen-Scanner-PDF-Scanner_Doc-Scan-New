import 'dart:async';

import 'package:flutter/foundation.dart';
import 'package:flutter/material.dart';

OverlayEntry? _copyToast;
Timer? _copyToastTimer;

void _removeCopyToast() {
  _copyToastTimer?.cancel();
  final entry = _copyToast;
  if (entry != null) {
    entry.remove();
    entry.dispose();
  }
  _copyToast = null;
}

/// A bottom SnackBar moves Scaffold's floating camera button on iOS.
/// Use a safe-area overlay there so copy feedback never changes its layout.
void showCopyFeedback(BuildContext context, String message,
    {Duration duration = const Duration(seconds: 3)}) {
  if (defaultTargetPlatform != TargetPlatform.iOS) {
    ScaffoldMessenger.of(context)
      ..clearSnackBars()
      ..showSnackBar(SnackBar(content: Text(message), duration: duration));
    return;
  }
  _removeCopyToast();
  final overlay = Overlay.of(context, rootOverlay: true);
  final entry = OverlayEntry(
    builder: (_) => Positioned(
      top: 0,
      left: 0,
      right: 0,
      child: IgnorePointer(
        child: SafeArea(
          bottom: false,
          child: Padding(
            padding: const EdgeInsets.fromLTRB(20, 10, 20, 0),
            child: Material(
              color: Colors.black87,
              borderRadius: BorderRadius.circular(10),
              child: Padding(
                padding: const EdgeInsets.all(16),
                child: Semantics(
                  liveRegion: true,
                  child: Text(message,
                      style: const TextStyle(color: Colors.white)),
                ),
              ),
            ),
          ),
        ),
      ),
    ),
  );
  _copyToast = entry;
  overlay.insert(entry);
  _copyToastTimer = Timer(duration, _removeCopyToast);
}
