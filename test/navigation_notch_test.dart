import 'package:doc_scanner/bottom_bar/widgets/notched_navigation_surface.dart';
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';

void main() {
  for (final diameter in [55.0, 70.0]) {
    test('camera $diameter retains a transparent notch and solid sides', () {
      final path =
          NavigationNotchClipper(diameter).getClip(const Size(393, 80));
      expect(path.contains(const Offset(196.5, 10)), isFalse);
      expect(path.contains(Offset(196.5, diameter / 2 + 9)), isFalse);
      expect(path.contains(Offset(196.5, diameter / 2 + 12)), isTrue);
      expect(path.contains(const Offset(30, 10)), isTrue);
      expect(path.contains(const Offset(363, 10)), isTrue);
    });
  }
}
