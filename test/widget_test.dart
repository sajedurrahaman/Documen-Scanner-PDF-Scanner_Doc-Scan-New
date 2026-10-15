import 'dart:async';

import 'package:doc_scanner/core/startup_gate.dart';
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';

/// Loading UI that reports itself as shown as soon as it is built.
StartupLoadingBuilder _instantLoading(String label) => (_, onShown) {
      onShown();
      return Text(label);
    };

void main() {
  testWidgets('Two-second countdown starts when the splash content is shown',
      (tester) async {
    VoidCallback? reportShown;
    await tester.pumpWidget(MaterialApp(
      home: StartupGate(
        minimumDuration: const Duration(seconds: 2),
        initialize: () async {},
        loadingBuilder: (_, onShown) {
          reportShown = onShown;
          return const Text('Splash');
        },
        child: const Text('Home'),
      ),
    ));
    // Simulates a slow Lottie load: setup is done but the animation is not
    // on screen yet, so the splash must not be dismissed.
    await tester.pump(const Duration(milliseconds: 1500));
    expect(find.text('Splash'), findsOneWidget);
    reportShown!();
    await tester.pump(const Duration(milliseconds: 1999));
    expect(find.text('Splash'), findsOneWidget);
    await tester.pump(const Duration(milliseconds: 1));
    expect(find.text('Home'), findsOneWidget);
  });

  for (final slowSetup in [false, true]) {
    testWidgets(
        'Two-second splash waits for ${slowSetup ? "slow" : "fast"} setup',
        (tester) async {
      final ready = Completer<void>();
      await tester.pumpWidget(MaterialApp(
          home: StartupGate(
        minimumDuration: const Duration(seconds: 2),
        initialize: () => ready.future,
        loadingBuilder: _instantLoading('Splash'),
        child: const Text('Home'),
      )));
      if (!slowSetup) ready.complete();
      await tester.pump(const Duration(milliseconds: 1999));
      expect(find.text('Splash'), findsOneWidget);
      await tester.pump(const Duration(milliseconds: 1));
      if (slowSetup) {
        expect(find.text('Splash'), findsOneWidget);
        await tester.pump(const Duration(seconds: 1));
        ready.complete();
        await tester.pump();
        await tester.pump();
      }
      expect(find.text('Home'), findsOneWidget);
    });
  }

  testWidgets('Home waits for local data but has no fixed splash delay',
      (tester) async {
    final initialization = Completer<void>();
    var calls = 0;
    var readyCalls = 0;
    final app = MaterialApp(
      home: StartupGate(
        initialize: () {
          calls++;
          return initialization.future;
        },
        onReady: () => readyCalls++,
        loadingBuilder: (_, __) => const Text('Loading'),
        child: const Text('Documents'),
      ),
    );
    await tester.pumpWidget(app);
    expect(find.text('Loading'), findsOneWidget);
    expect(find.text('Documents'), findsNothing);
    expect(calls, 1);
    expect(readyCalls, 0);

    initialization.complete();
    await tester.pump();
    expect(find.text('Documents'), findsOneWidget);
    expect(readyCalls, 1);
    await tester.pumpWidget(app);
    await tester.pump();
    expect(calls, 1);
    expect(readyCalls, 1);
  });

  testWidgets('Failed local setup can be retried', (tester) async {
    var attempts = 0;
    await tester.pumpWidget(MaterialApp(
      home: StartupGate(
        initialize: () async {
          if (++attempts == 1) throw StateError('Storage unavailable');
        },
        loadingBuilder: (_, __) => const Text('Loading'),
        child: const Text('Documents'),
      ),
    ));
    await tester.pump();
    expect(find.text('Retry'), findsOneWidget);
    expect(find.text('Documents'), findsNothing);
    await tester.tap(find.text('Retry'));
    await tester.pump();
    expect(find.text('Documents'), findsOneWidget);
    expect(attempts, 2);
  });

  testWidgets('Disposal during setup does not trigger navigation or services',
      (tester) async {
    final initialization = Completer<void>();
    var ready = false;
    await tester.pumpWidget(MaterialApp(
      home: StartupGate(
        initialize: () => initialization.future,
        onReady: () => ready = true,
        loadingBuilder: (_, __) => const Text('Loading'),
        child: const Text('Documents'),
      ),
    ));
    await tester.pumpWidget(const SizedBox());
    initialization.complete();
    await tester.pump();
    expect(ready, false);
    expect(tester.takeException(), isNull);
  });
}
