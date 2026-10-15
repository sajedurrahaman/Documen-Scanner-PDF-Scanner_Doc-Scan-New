import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:lottie/lottie.dart';

import '../utils/app_assets.dart';

class SplashScreen extends StatefulWidget {
  const SplashScreen({super.key, this.onAnimationShown});

  /// Called once, after the first frame that actually contains the splash
  /// content (the Lottie animation, or the fallback logo if it failed to load).
  /// Until then only the plain gradient background is visible.
  final VoidCallback? onAnimationShown;

  @override
  State<SplashScreen> createState() => _SplashScreenState();
}

class _SplashScreenState extends State<SplashScreen> {
  bool _notified = false;

  void _notifyShownAfterFrame() {
    if (_notified) return;
    _notified = true;
    WidgetsBinding.instance.addPostFrameCallback((_) {
      if (mounted) widget.onAnimationShown?.call();
    });
  }

  @override
  Widget build(BuildContext context) {
    return AnnotatedRegion<SystemUiOverlayStyle>(
      value: SystemUiOverlayStyle.light.copyWith(
        statusBarColor: Colors.transparent,
        systemNavigationBarColor: const Color(0xFF0C3585),
      ),
      child: Scaffold(
        backgroundColor: const Color(0xFF1C59C1),
        body: SizedBox.expand(
          child: DecoratedBox(
            decoration: const BoxDecoration(
              gradient: LinearGradient(
                begin: Alignment.topCenter,
                end: Alignment.bottomCenter,
                colors: [
                  Color(0xFF2468DC),
                  Color(0xFF1C59C1),
                  Color(0xFF0C3585)
                ],
                stops: [0, 0.55, 1],
              ),
            ),
            child: Lottie.asset(
              AppAssets.splashAnimation,
              fit: BoxFit.cover,
              repeat: false,
              backgroundLoading: true,
              // StartupGate owns navigation; animation never delays app readiness.
              // It only tells the gate when the animation is really on screen so
              // the minimum splash time counts visible animation, not load time.
              onLoaded: (_) => _notifyShownAfterFrame(),
              errorBuilder: (_, __, ___) {
                _notifyShownAfterFrame();
                return Center(
                  child:
                      Image.asset(AppAssets.splashLogo, width: 96, height: 96),
                );
              },
            ),
          ),
        ),
      ),
    );
  }
}
