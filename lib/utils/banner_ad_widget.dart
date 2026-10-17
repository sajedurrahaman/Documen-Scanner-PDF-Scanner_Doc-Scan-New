import 'dart:developer';

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
  bool _loading = false;

  @override
  void initState() {
    super.initState();
    _loadAd();
  }

  Future<void> _loadAd({bool retry = true}) async {
    if (_loading) return;
    _loading = true;
    try {
      // Safe if already initialized during splash.
      await MobileAds.instance.initialize();
      if (!mounted) return;

      final ad = BannerAd(
        size: AdSize.banner,
        adUnitId: widget.adUnitId,
        request: const AdRequest(),
        listener: BannerAdListener(
          onAdLoaded: (ad) {
            log('${ad.runtimeType} loaded: ${widget.adUnitId}');
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
            log('${ad.runtimeType} failed to load: $error. id=${widget.adUnitId}');
            ad.dispose();
            if (!mounted) return;
            setState(() {
              _bannerAd = null;
              _isLoaded = false;
            });
            if (retry) {
              Future.delayed(const Duration(seconds: 2), () {
                if (mounted) _loadAd(retry: false);
              });
            }
          },
        ),
      );
      await ad.load();
    } catch (error, stack) {
      log('BannerAd load error: $error\n$stack');
      if (retry && mounted) {
        Future.delayed(const Duration(seconds: 2), () {
          if (mounted) _loadAd(retry: false);
        });
      }
    } finally {
      _loading = false;
    }
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

/// Places banner under [child] by default. Set [bannerAbove] for directory_view-style layout.
class BottomBarWithBanner extends StatelessWidget {
  final Widget child;
  final String adUnitId;
  final bool bannerAbove;

  const BottomBarWithBanner({
    super.key,
    required this.child,
    required this.adUnitId,
    this.bannerAbove = false,
  });

  @override
  Widget build(BuildContext context) {
    return SafeArea(
      top: false,
      left: false,
      right: false,
      child: Column(
        mainAxisSize: MainAxisSize.min,
        children: bannerAbove
            ? [
                BannerAdWidget(adUnitId: adUnitId),
                child,
              ]
            : [
                child,
                BannerAdWidget(adUnitId: adUnitId),
              ],
      ),
    );
  }
}
