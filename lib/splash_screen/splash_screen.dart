import 'package:doc_scanner/core/local_storage.dart';
import 'package:doc_scanner/utils/app_assets.dart';
import 'package:doc_scanner/utils/firebase_messageing.dart';
import 'package:doc_scanner/utils/helper.dart';
import 'package:doc_scanner/utils/local_notification.dart';
import 'package:firebase_core/firebase_core.dart';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:google_mobile_ads/google_mobile_ads.dart';
import 'package:lottie/lottie.dart';
import 'package:nb_utils/nb_utils.dart';
import '../bottom_bar/bottom_bar.dart';
import '../firebase_options.dart';

class SplashScreen extends StatefulWidget {
  const SplashScreen({super.key});

  @override
  State<SplashScreen> createState() => _SplashScreenState();
}

class _SplashScreenState extends State<SplashScreen> {
  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addPostFrameCallback((_) => _initAndNavigate());
  }

  Future<void> _initAndNavigate() async {
    try {
      await Firebase.initializeApp(
        options: DefaultFirebaseOptions.currentPlatform,
      );
      await LocalStorage().init();
      await initialize();
      await AppHelper().createDirectories();
      MobileAds.instance.initialize();

      final localNotificationsService = LocalNotificationsService.instance();
      await localNotificationsService.init();
      final firebaseMessagingService = FirebaseMessagingService.instance();
      await firebaseMessagingService.init(
        localNotificationsService: localNotificationsService,
      );
    } catch (e, st) {
      debugPrint('Splash init error: $e\n$st');
    }

    if (!mounted) return;
    await Future.delayed(const Duration(seconds: 3));
    if (!mounted) return;
    Navigator.pushAndRemoveUntil(
      context,
      MaterialPageRoute(builder: (context) => const BottomBar()),
      (route) => false,
    );
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
              errorBuilder: (_, __, ___) => Center(
                child: Image.asset(AppAssets.splashLogo, width: 96, height: 96),
              ),
            ),
          ),
        ),
      ),
    );
  }
}
