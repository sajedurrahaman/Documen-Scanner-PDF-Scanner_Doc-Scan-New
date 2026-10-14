import 'package:google_mobile_ads/google_mobile_ads.dart';

/// Share SDK initialization across banners and interstitial requests.
class AdsInitialization {
  static Future<InitializationStatus>? _initialization;

  static Future<InitializationStatus> ensureInitialized() async {
    try {
      return await (_initialization ??= MobileAds.instance.initialize());
    } catch (_) {
      _initialization = null;
      rethrow;
    }
  }
}
