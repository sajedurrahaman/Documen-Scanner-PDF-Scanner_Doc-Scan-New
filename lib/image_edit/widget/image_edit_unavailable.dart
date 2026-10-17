import 'package:flutter/material.dart';
import '../../localaization/language_constant.dart';

/// Keeps Back available when an editing session has ended or has no image.
class ImageEditUnavailable extends StatelessWidget {
  const ImageEditUnavailable({super.key});

  @override
  Widget build(BuildContext context) => Scaffold(
        backgroundColor: const Color(0xFF131314),
        appBar: AppBar(
          backgroundColor: const Color(0xFF1E1F20),
          foregroundColor: Colors.white,
        ),
        body: Center(
          child: Text(translation(context).noFilesHereYet,
              style: const TextStyle(color: Colors.white)),
        ),
      );
}
