import 'package:flutter/material.dart';

/// Uses one outline for both the bar's clipping and its upward shadow.
class NotchedNavigationSurface extends StatelessWidget {
  const NotchedNavigationSurface({
    super.key,
    required this.cameraDiameter,
    required this.child,
  });

  final double cameraDiameter;
  final Widget child;

  @override
  Widget build(BuildContext context) {
    final clipper = NavigationNotchClipper(cameraDiameter);
    return CustomPaint(
      painter: _NavigationShadow(clipper),
      child: ClipPath(clipper: clipper, child: child),
    );
  }
}

class NavigationNotchClipper extends CustomClipper<Path> {
  const NavigationNotchClipper(this.cameraDiameter);
  final double cameraDiameter;

  @override
  Path getClip(Size size) => const CircularNotchedRectangle().getOuterPath(
        Offset.zero & size,
        Rect.fromCircle(
          center: Offset(size.width / 2, 0),
          radius: cameraDiameter / 2 + 10,
        ),
      );

  @override
  bool shouldReclip(NavigationNotchClipper oldClipper) =>
      cameraDiameter != oldClipper.cameraDiameter;
}

class _NavigationShadow extends CustomPainter {
  const _NavigationShadow(this.clipper);
  final NavigationNotchClipper clipper;

  @override
  void paint(Canvas canvas, Size size) {
    final outline = clipper.getClip(size);
    canvas.drawPath(
      outline.shift(const Offset(0, -3)),
      Paint()
        ..color = const Color(0x33000000)
        ..maskFilter = const MaskFilter.blur(BlurStyle.normal, 7),
    );
  }

  @override
  bool shouldRepaint(_NavigationShadow oldDelegate) =>
      clipper.shouldReclip(oldDelegate.clipper);
}
