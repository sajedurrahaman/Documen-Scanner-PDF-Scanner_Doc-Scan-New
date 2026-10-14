import 'dart:developer';
import 'ads_initialization.dart';

import 'package:doc_scanner/main.dart';
import 'package:flutter/foundation.dart';
import 'package:flutter/material.dart';
import 'package:google_mobile_ads/google_mobile_ads.dart';

void _disposeInterstitial() {
  try {
    myInterstitial?.dispose();
  } catch (_) {}
  myInterstitial = null;
  interstitialReady = false;
  interstitialReadyNotifier.value = false;
}

class AdHelper {
  static const String _androidTestBanner =
      'ca-app-pub-3940256099942544/6300978111';
  static const String _androidTestInterstitial =
      'ca-app-pub-3940256099942544/1033173712';

  /// Shared production banner id (directory view). Replace when new id is ready.
  static String get _defaultBannerAdUnitId {
    if (kDebugMode) return _androidTestBanner;
    return 'ca-app-pub-9877635475483541/5655684143';
  }

  /// Home and Settings bannerAdUnitId
  static String get homeSettingsBannerAdUnitId {
    if (kDebugMode) return _androidTestBanner;
    return 'ca-app-pub-9877635475483541/5086358025';
  }

  /// Image edit preview bannerAdUnitId
  static String get imageEditPreviewBannerAdUnitId {
    if (kDebugMode) return _androidTestBanner;
    return 'ca-app-pub-9877635475483541/1617886307';
  }

  /// Image edit screen bannerAdUnitId
  static String get imageEditScreenBannerAdUnitId {
    if (kDebugMode) return _androidTestBanner;
    return 'ca-app-pub-9877635475483541/5655684143';
  }

  /// Image filter screen bannerAdUnitId
  static String get imageFilterScreenBannerAdUnitId {
    if (kDebugMode) return _androidTestBanner;
    return 'ca-app-pub-9877635475483541/1270401946';
  }

  /// Image size screen bannerAdUnitId
  static String get imageSizeScreenBannerAdUnitId {
    if (kDebugMode) return _androidTestBanner;
    return 'ca-app-pub-9877635475483541/1436942968';
  }

  /// Image rotation screen bannerAdUnitId
  static String get imageRotationBannerAdUnitId {
    if (kDebugMode) return _androidTestBanner;
    return 'ca-app-pub-9877635475483541/7644238607';
  }

  /// Image crop screen bannerAdUnitId
  static String get imageCropBannerAdUnitId {
    if (kDebugMode) return _androidTestBanner;
    return 'ca-app-pub-9877635475483541/2993567212';
  }

  /// Add signature screen bannerAdUnitId
  static String get addSignatureBannerAdUnitId {
    if (kDebugMode) return _androidTestBanner;
    return 'ca-app-pub-9877635475483541/9367403875';
  }

  /// Drawing screen bannerAdUnitId
  static String get drawingScreenBannerAdUnitId {
    if (kDebugMode) return _androidTestBanner;
    return 'ca-app-pub-9877635475483541/8646329080';
  }

  /// Id card image view bannerAdUnitId
  static String get idCardImageViewBannerAdUnitId {
    if (kDebugMode) return _androidTestBanner;
    return 'ca-app-pub-9877635475483541/1844137072';
  }

  /// Directory view bannerAdUnitId
  static String get directoryViewBannerAdUnitId => _defaultBannerAdUnitId;

  static String get interstitialAdUnitId {
    if (kDebugMode) return _androidTestInterstitial;
    return 'ca-app-pub-9877635475483541/7304641889';
  }

  // bottom_bar
  static String get interstitialAdUnitId1 {
    if (kDebugMode) return _androidTestInterstitial;
    return 'ca-app-pub-9877635475483541/5655684143';
  }
}

bool _interstitialLoading = false;
bool _interstitialShowing = false;

Future<void> createInterstitialAd({String? adUnitId}) async {
  // Several routes request a preload. Retain the existing ad/request instead
  // of destroying a native ad and starting another load on every navigation.
  if (_interstitialLoading || _interstitialShowing || myInterstitial != null) {
    return;
  }
  _interstitialLoading = true;
  try {
    await WidgetsBinding.instance.endOfFrame;
    await AdsInitialization.ensureInitialized();
    await InterstitialAd.load(
      adUnitId: adUnitId ?? AdHelper.interstitialAdUnitId,
      request: const AdRequest(),
      adLoadCallback: InterstitialAdLoadCallback(
        onAdLoaded: (InterstitialAd ad) {
          _interstitialLoading = false;
          myInterstitial = ad;
          interstitialReady = true;
          interstitialReadyNotifier.value = true;
        },
        onAdFailedToLoad: (LoadAdError error) {
          _interstitialLoading = false;
          log('InterstitialAd failed to load: $error.');
          _disposeInterstitial();
        },
      ),
    );
  } catch (error) {
    _interstitialLoading = false;
    log('Interstitial initialization/load failed: $error');
  }
}

void finish(BuildContext context, [Object? result]) {
  if (Navigator.canPop(context)) Navigator.pop(context, result);
}

void showInterstitialAd(BuildContext context) {
  if (_interstitialShowing || myInterstitial == null || !interstitialReady) {
    log('attempt to show interstitial before loaded.');
    // Optional: just return instead of popping
    // finish(context);
    return;
  }

  myInterstitial!.fullScreenContentCallback = FullScreenContentCallback(
    onAdShowedFullScreenContent: (InterstitialAd ad) =>
        log('ad onAdShowedFullScreenContent.'),
    onAdClicked: (ad) {
      interstitialReady = false;
      interstitialReadyNotifier.value = false;
    },
    onAdDismissedFullScreenContent: (InterstitialAd ad) {
      _interstitialShowing = false;
      log('$ad onAdDismissedFullScreenContent.');
      _disposeInterstitial();
      createInterstitialAd(); // preload next
    },
    onAdFailedToShowFullScreenContent: (InterstitialAd ad, AdError error) {
      _interstitialShowing = false;
      log('$ad onAdFailedToShowFullScreenContent: $error');
      _disposeInterstitial();
      createInterstitialAd(); // preload next
    },
  );

  interstitialReady = false;
  interstitialReadyNotifier.value = false;
  _interstitialShowing = true;
  myInterstitial!.show();
}
