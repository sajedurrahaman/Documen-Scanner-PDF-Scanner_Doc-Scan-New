import 'package:doc_scanner/utils/app_assets.dart';
import 'package:doc_scanner/utils/helper.dart';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:lottie/lottie.dart';

class SplashScreen extends StatefulWidget {
  const SplashScreen({super.key, this.onAnimationShown});

  /// Called once the splash content is actually on screen so the minimum
  /// splash duration counts visible time, not Lottie load time.
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
              // Composition is phone-sized (375x812); cover crops on iPad.
              fit: AppHelper.isIpad(context) ? BoxFit.contain : BoxFit.cover,
              alignment: Alignment.center,
              repeat: false,
              backgroundLoading: true,
              onLoaded: (_) => _notifyShownAfterFrame(),
              errorBuilder: (_, __, ___) {
                _notifyShownAfterFrame();
                return Center(
                  child: Image.asset(AppAssets.splashLogo, width: 96, height: 96),
                );
              },
            ),
          ),
        ),
      ),
    );
  }
}
