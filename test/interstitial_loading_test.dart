import 'package:doc_scanner/google_ads_helper/google_ads_helper.dart';
import 'package:doc_scanner/main.dart';
import 'package:flutter/services.dart';
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:google_mobile_ads/google_mobile_ads.dart';
// Use the SDK's codec to simulate native callbacks without real ad requests.
// ignore: implementation_imports
import 'package:google_mobile_ads/src/ad_instance_manager.dart';

void main() {
  testWidgets('Concurrent and repeated preloads reuse one native interstitial',
      (tester) async {
    final calls = <MethodCall>[];
    var failLoads = true;
    final messenger =
        TestDefaultBinaryMessengerBinding.instance.defaultBinaryMessenger;
    messenger.setMockMethodCallHandler(instanceManager.channel, (call) async {
      calls.add(call);
      if (call.method == 'MobileAds#initialize') {
        return InitializationStatus({});
      }
      if (call.method == 'loadInterstitialAd' && failLoads) {
        throw PlatformException(code: 'test_load_failure');
      }
      return null;
    });
    addTearDown(() async {
      await myInterstitial?.dispose();
      myInterstitial = null;
      interstitialReady = false;
      interstitialReadyNotifier.value = false;
      messenger.setMockMethodCallHandler(instanceManager.channel, null);
    });

    // A failed platform request must permit a later retry.
    for (var attempt = 0; attempt < 2; attempt++) {
      final loading = createInterstitialAd();
      await tester.pump();
      await loading;
    }
    expect(calls.where((call) => call.method == 'loadInterstitialAd'),
        hasLength(2));
    expect(interstitialReady, isFalse);
    failLoads = false;
    calls.clear();

    final first = createInterstitialAd();
    final second = createInterstitialAd();
    await tester.pump();
    await Future.wait([first, second]);
    var loads =
        calls.where((call) => call.method == 'loadInterstitialAd').toList();
    expect(loads, hasLength(1));

    // A route asks again while the native load callback is still pending.
    await createInterstitialAd();
    expect(calls.where((call) => call.method == 'loadInterstitialAd'),
        hasLength(1));
    final id = loads.single.arguments['adId'];
    await messenger.handlePlatformMessage(
      instanceManager.channel.name,
      instanceManager.channel.codec.encodeMethodCall(MethodCall('onAdEvent', {
        'adId': id,
        'eventName': 'onAdLoaded',
      })),
      (_) {},
    );
    expect(interstitialReady, isTrue);
    final loaded = myInterstitial;
    await createInterstitialAd();
    expect(myInterstitial, same(loaded));
    expect(calls.where((call) => call.method == 'loadInterstitialAd'),
        hasLength(1));
    expect(calls.where((call) => call.method == 'disposeAd'), isEmpty);

    // A preloaded ad remains showable when returning to Home, only once.
    late BuildContext homeContext;
    await tester.pumpWidget(MaterialApp(home: Builder(builder: (context) {
      homeContext = context;
      return const SizedBox();
    })));
    showInterstitialAd(homeContext);
    showInterstitialAd(homeContext);
    await tester.pump();
    expect(calls.where((call) => call.method == 'showAdWithoutView'), hasLength(1));

    await messenger.handlePlatformMessage(
      instanceManager.channel.name,
      instanceManager.channel.codec.encodeMethodCall(MethodCall('onAdEvent', {
        'adId': id,
        'eventName': 'onAdDismissedFullScreenContent',
      })),
      (_) {},
    );
    await tester.pump();
    expect(calls.where((call) => call.method == 'loadInterstitialAd'), hasLength(2));
    final nextId = calls.lastWhere((call) => call.method == 'loadInterstitialAd').arguments['adId'];
    await messenger.handlePlatformMessage(
      instanceManager.channel.name,
      instanceManager.channel.codec.encodeMethodCall(MethodCall('onAdEvent', {
        'adId': nextId,
        'eventName': 'onAdLoaded',
      })),
      (_) {},
    );
    expect(interstitialReady, isTrue);

  });
}
