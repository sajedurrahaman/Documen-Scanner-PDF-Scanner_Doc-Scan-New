import 'dart:async';
import 'package:doc_scanner/core/startup_gate.dart';
import 'package:doc_scanner/splash_screen/splash_screen.dart';
import 'package:doc_scanner/utils/app_assets.dart';
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:lottie/lottie.dart';

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  test('supplied splash JSON loads as a six-second portrait animation',
      () async {
    final composition = await AssetLottie(AppAssets.splashAnimation).load();
    expect(composition.bounds.width, 375);
    expect(composition.bounds.height, 812);
    expect(composition.duration, const Duration(seconds: 6));
  });

  test('logo, title and tagline are fully visible from the very first frame',
      () async {
    // No blue-only intro, so the animation can simply play from frame 0.
    final composition = await AssetLottie(AppAssets.splashAnimation).load();
    for (final name in ['Icon', 'Title', 'Tagline']) {
      final layer = composition.layers.singleWhere((l) => l.name == name);
      expect(layer.startFrame, 0, reason: '$name should start at frame 0');
      expect(layer.transform.opacity?.keyframes.first.startValue, 100,
          reason: '$name should be fully opaque at frame 0');
    }
  });

  testWidgets(
      'splash reports shown only after the animation is on screen, '
      'and full-screen Lottie does not delay readiness', (tester) async {
    // Cold start: the composition must really be parsed, not served from cache.
    Lottie.cache.clear();
    final ready = Completer<void>();
    var shown = 0;
    // The asset is parsed in a background isolate, which needs real async.
    await tester.runAsync(() async {
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
      final animation =
          tester.widget<LottieBuilder>(find.byType(LottieBuilder));
      expect(animation.fit, BoxFit.cover);
      expect(animation.repeat, isFalse);
      // First frame: only the gradient is drawn, the asset is still parsing.
      expect(shown, 0);

      final deadline = DateTime.now().add(const Duration(seconds: 15));
      while (shown == 0 && DateTime.now().isBefore(deadline)) {
        await Future<void>.delayed(const Duration(milliseconds: 20));
        await tester.pump();
      }
    });
    expect(shown, 1);
    await tester.pump();
    expect(shown, 1, reason: 'reported once, not on every rebuild');

    ready.complete();
    await tester.pump();
    expect(find.text('Home ready'), findsOneWidget);
    expect(find.byType(SplashScreen), findsNothing);
    await tester.pump(const Duration(seconds: 6));
    expect(tester.takeException(), isNull);
  });
}
