import 'package:doc_scanner/utils/app_color.dart';
import 'package:flutter/material.dart';

/// Blocks the whole screen while Done applies (crop / filter / size / edit).
class FullScreenSavingOverlay extends StatelessWidget {
  const FullScreenSavingOverlay({super.key});

  @override
  Widget build(BuildContext context) {
    return const Positioned.fill(
      child: AbsorbPointer(
        child: ColoredBox(
          color: Color(0xB3000000),
          child: Center(
            child: CircularProgressIndicator(
              color: AppColor.primaryColor,
            ),
          ),
        ),
      ),
    );
  }
}
