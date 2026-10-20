import 'package:doc_scanner/utils/copy_feedback.dart';
import 'package:flutter/foundation.dart';
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';

void main() {
  testWidgets('iOS copy toast stays at top without moving camera and replaces repeats', (tester) async {
    await tester.pumpWidget(MaterialApp(home: Builder(builder: (context) => Scaffold(
      floatingActionButtonLocation: FloatingActionButtonLocation.centerDocked,
      floatingActionButton: FloatingActionButton(onPressed: () {}, child: const Icon(Icons.camera)),
      bottomNavigationBar: const BottomAppBar(child: SizedBox(height: 50)),
      body: TextButton(onPressed: () => showCopyFeedback(context, 'Copied'), child: const Text('Copy')),
    ))));
    final before = tester.getTopLeft(find.byType(FloatingActionButton));
    for (var i = 0; i < 2; i++) {
      await tester.tap(find.text('Copy'));
      await tester.pump();
      expect(find.text('Copied'), findsOneWidget);
      expect(find.byType(SnackBar), findsNothing);
      expect(tester.getTopLeft(find.text('Copied')).dy, lessThan(100));
      expect(tester.getTopLeft(find.byType(FloatingActionButton)), before);
    }
    await tester.pump(const Duration(seconds: 3));
    expect(find.text('Copied'), findsNothing);
    expect(tester.takeException(), isNull);
  }, variant: TargetPlatformVariant.only(TargetPlatform.iOS));
}
