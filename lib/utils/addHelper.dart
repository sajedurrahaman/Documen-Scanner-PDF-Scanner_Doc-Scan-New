import 'package:flutter/foundation.dart';

class AdHelper {
  static const String _iosTestBanner =
      'ca-app-pub-3940256099942544/2934735716';
  static const String _iosTestInterstitial =
      'ca-app-pub-3940256099942544/4411468910';

  /// Home and Settings bannerAdUnitId
  static String get homeSettingsBannerAdUnitId {
    if (kDebugMode) return _iosTestBanner;
    return 'ca-app-pub-9877635475483541/2004633185'; // nav bar ads
  }

  /// Image edit preview bannerAdUnitId
  static String get imageEditPreviewBannerAdUnitId {
    if (kDebugMode) return _iosTestBanner;
    return 'ca-app-pub-9877635475483541/5653334239';
  }

  /// Image edit screen bannerAdUnitId
  static String get imageEditScreenBannerAdUnitId {
    if (kDebugMode) return _iosTestBanner;
    return 'ca-app-pub-9877635475483541/1714089228';
  }

  /// Image filter screen bannerAdUnitId
  static String get imageFilterScreenBannerAdUnitId {
    if (kDebugMode) return _iosTestBanner;
    return 'ca-app-pub-9877635475483541/6774844211';
  }

  /// Image size screen bannerAdUnitId
  static String get imageSizeScreenBannerAdUnitId {
    if (kDebugMode) return _iosTestBanner;
    return 'ca-app-pub-9877635475483541/1522517539';
  }

  /// Image rotation screen bannerAdUnitId
  static String get imageRotationBannerAdUnitId {
    if (kDebugMode) return _iosTestBanner;
    return 'ca-app-pub-9877635475483541/6583272522';
  }

  /// Image crop screen bannerAdUnitId
  static String get imageCropBannerAdUnitId {
    if (kDebugMode) return _iosTestBanner;
    return 'ca-app-pub-9877635475483541/1512964587';
  }

  /// Add signature screen bannerAdUnitId
  static String get addSignatureBannerAdUnitId {
    if (kDebugMode) return _iosTestBanner;
    return 'ca-app-pub-9877635475483541/2644027516';
  }

  /// Drawing screen bannerAdUnitId
  static String get drawingScreenBannerAdUnitId {
    if (kDebugMode) return _iosTestBanner;
    return 'ca-app-pub-9877635475483541/4142997350';
  }

  /// Id card image view bannerAdUnitId
  static String get idCardImageViewBannerAdUnitId {
    if (kDebugMode) return _iosTestBanner;
    return 'ca-app-pub-9877635475483541/2452455824'; // id_card_preview_screen
  }

  /// Directory view bannerAdUnitId
  static String get directoryViewBannerAdUnitId {
    if (kDebugMode) return _iosTestBanner;
    return 'ca-app-pub-9877635475483541/3626209183';
  }

  static String get interstitialAdUnitId {
    if (kDebugMode) return _iosTestInterstitial;
    return 'ca-app-pub-9877635475483541/7310836156';
  }

  // bottom_bar
  static String get interstitialAdUnitId1 {
    if (kDebugMode) return _iosTestInterstitial;
    return 'ca-app-pub-9877635475483541/3183166022';
  }
}
