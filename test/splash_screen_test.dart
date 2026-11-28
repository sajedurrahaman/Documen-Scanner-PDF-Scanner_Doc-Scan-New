import 'dart:async';

import 'package:doc_scanner/core/startup_gate.dart';
import 'package:doc_scanner/splash_screen/splash_screen.dart';
import 'package:doc_scanner/utils/app_assets.dart';
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  testWidgets('classic splash shows logo and tagline', (tester) async {
    await tester.pumpWidget(
      const MaterialApp(home: SplashScreen()),
    );
    expect(find.byType(SplashScreen), findsOneWidget);
    expect(find.text('SCAN FASTER, WORK SMARTER.'), findsOneWidget);
    expect(find.image(AssetImage(AppAssets.splashLogo)), findsOneWidget);
  });

  testWidgets(
      'splash reports shown after first frame and does not delay readiness',
      (tester) async {
    final ready = Completer<void>();
    var shown = 0;

    await tester.pumpWidget(MaterialApp(
      home: StartupGate(
        initialize: () => ready.future,
        loadingBuilder: (_, onShown) => SplashScreen(onAnimationShown: () {
          shown++;
          onShown();
        }),
        child: const Scaffold(body: Text('Home ready')),
      ),
    ));

    expect(find.byType(SplashScreen), findsOneWidget);
    expect(shown, 0);
    await tester.pump();
    expect(shown, 1);
    await tester.pump();
    expect(shown, 1, reason: 'reported once, not on every rebuild');

    ready.complete();
    await tester.pump();
    expect(find.text('Home ready'), findsOneWidget);
    expect(find.byType(SplashScreen), findsNothing);
    expect(tester.takeException(), isNull);
  });
}
