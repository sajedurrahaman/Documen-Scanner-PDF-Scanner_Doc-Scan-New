import 'dart:async';

import 'package:doc_scanner/core/startup_gate.dart';
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';

void main() {
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
        loading: const Text('Loading'),
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
        loading: const Text('Loading'),
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
        loading: const Text('Loading'),
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
