import 'package:flutter/material.dart';
import 'package:flutter_svg/flutter_svg.dart';

class ImageEditButton extends StatefulWidget {
  final String title;
  final VoidCallback? onTap;
  final String iconPath;

  const ImageEditButton(
      {super.key,
      required this.title,
      required this.onTap,
      required this.iconPath});

  @override
  State<ImageEditButton> createState() => _ImageEditButtonState();
}

class _ImageEditButtonState extends State<ImageEditButton> {
  @override
  Widget build(BuildContext context) {
    final size = MediaQuery.sizeOf(context);
    return Material(
      color: const Color(0xff1E1F20),
      child: InkWell(
        onTap: widget.onTap,
        child: Container(
          padding: const EdgeInsets.all(10),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.center,
            mainAxisAlignment: MainAxisAlignment.center,
            children: [
              SvgPicture.asset(
                widget.iconPath,
                height: size.width >= 600 ? 30 : 20,
                width: size.width >= 600 ? 30 : 20,
                fit: BoxFit.cover,
                color: Colors.white,
              ),
              const SizedBox(height: 5),
              Text(
                widget.title,
                style: const TextStyle(
                  color: Colors.white,
                  fontSize: 12,
                  fontWeight: FontWeight.w500,
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}
