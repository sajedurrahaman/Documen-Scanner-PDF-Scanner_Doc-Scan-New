import 'dart:developer';
import 'ads_initialization.dart';

import 'package:flutter/material.dart';
import 'package:google_mobile_ads/google_mobile_ads.dart';

/// Banner under a bottom bar. Takes no height until loaded; collapses on fail.
class BannerAdWidget extends StatefulWidget {
  final String adUnitId;

  const BannerAdWidget({super.key, required this.adUnitId});

  @override
  State<BannerAdWidget> createState() => _BannerAdWidgetState();
}

class _BannerAdWidgetState extends State<BannerAdWidget> {
  BannerAd? _bannerAd;
  bool _isLoaded = false;

  @override
  void initState() {
    super.initState();
    _loadAd();
  }

  Future<void> _loadAd() async {
    // Let the home screen render before invoking the native ads SDK.
    await WidgetsBinding.instance.endOfFrame;
    if (!mounted) return;
    try {
      await AdsInitialization.ensureInitialized();
    } catch (error) {
      log('Ads initialization failed: $error');
      return;
    }
    if (!mounted) return;
    final ad = BannerAd(
      size: AdSize.banner,
      adUnitId: widget.adUnitId,
      request: const AdRequest(),
      listener: BannerAdListener(
        onAdLoaded: (ad) {
          log('${ad.runtimeType} loaded.');
          if (!mounted) {
            ad.dispose();
            return;
          }
          setState(() {
            _bannerAd = ad as BannerAd;
            _isLoaded = true;
          });
        },
        onAdFailedToLoad: (ad, error) {
          log('${ad.runtimeType} failed to load: $error.');
          ad.dispose();
          if (!mounted) return;
          setState(() {
            _bannerAd = null;
            _isLoaded = false;
          });
        },
      ),
    );
    _bannerAd = ad;
    ad.load();
  }

  @override
  void dispose() {
    _bannerAd?.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    if (!_isLoaded || _bannerAd == null) {
      return const SizedBox.shrink();
    }
    return SizedBox(
      width: double.infinity,
      height: _bannerAd!.size.height.toDouble(),
      child: AdWidget(ad: _bannerAd!),
    );
  }
}

/// Places [child] bottom bar above [BannerAdWidget], above the home-indicator safe area.
class BottomBarWithBanner extends StatelessWidget {
  final Widget child;
  final String adUnitId;

  const BottomBarWithBanner({
    super.key,
    required this.child,
    required this.adUnitId,
  });

  @override
  Widget build(BuildContext context) {
    return SafeArea(
      top: false,
      left: false,
      right: false,
      child: Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          child,
          BannerAdWidget(adUnitId: adUnitId),
        ],
      ),
    );
  }
}
