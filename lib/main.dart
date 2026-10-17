import 'dart:async';

import 'package:doc_scanner/bottom_bar/bottom_bar.dart';
import 'package:doc_scanner/core/local_storage.dart';
import 'package:doc_scanner/core/startup_gate.dart';
import 'package:doc_scanner/home_page/provider/home_page_provider.dart';
import 'package:doc_scanner/home_page/provider/recent_files_provider.dart';
import 'package:doc_scanner/image_edit/provider/image_edit_provider.dart';
import 'package:doc_scanner/l10n/app_localizations.dart';
import 'package:doc_scanner/splash_screen/splash_screen.dart';
import 'package:doc_scanner/utils/app_color.dart';
import 'package:doc_scanner/utils/firebase_messageing.dart';
import 'package:doc_scanner/utils/helper.dart';
import 'package:doc_scanner/utils/local_notification.dart';
import 'package:doc_scanner/utils/meta_events_helper.dart';
import 'package:firebase_core/firebase_core.dart';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:google_mobile_ads/google_mobile_ads.dart';
import 'package:nb_utils/nb_utils.dart';
import 'package:provider/provider.dart';

import 'camera_screen/provider/camera_provider.dart';
import 'firebase_options.dart';
import 'localaization/language_constant.dart';

bool bannerReady = false;
bool interstitialReady = false;
InterstitialAd? myInterstitial;
ValueNotifier<bool> interstitialReadyNotifier = ValueNotifier(false);

void main() {
  WidgetsFlutterBinding.ensureInitialized();
  unawaited(
      SystemChrome.setPreferredOrientations([DeviceOrientation.portraitUp]));
  runApp(const MyApp());
}

/// Local setup that must finish before home opens.
Future<void> _initializeLocalData() async {
  await Future.wait([
    LocalStorage().init(),
    initialize(),
    AppHelper().createDirectories(),
    // Banner under BottomBar loads as soon as home opens — SDK must be ready.
    MobileAds.instance.initialize(),
  ]);
}

/// Ads / Firebase / Meta — do not block the first home frame.
Future<void> _initializeBackgroundServices() async {
  unawaited(_initializeHeavyServices());
  try {
    await MetaEventsHelper.initialize();
    await MetaEventsHelper.logAppOpen();
  } catch (error, stack) {
    debugPrint('MetaEvents startup failed: $error\n$stack');
  }
}

Future<void> _initializeHeavyServices() async {
  try {
    await Firebase.initializeApp(
      options: DefaultFirebaseOptions.currentPlatform,
    );

    final localNotificationsService = LocalNotificationsService.instance();
    await localNotificationsService.init();
    await FirebaseMessagingService.instance().init(
      localNotificationsService: localNotificationsService,
    );
  } catch (error, stack) {
    debugPrint('Background startup failed: $error\n$stack');
  }
}

class MyApp extends StatefulWidget {
  const MyApp({super.key});

  @override
  State<MyApp> createState() => _MyAppState();

  static void setLocale(BuildContext context, Locale locale) {
    _MyAppState? state = context.findAncestorStateOfType<_MyAppState>();
    state?.setLocale(locale);
  }
}

class _MyAppState extends State<MyApp> {
  Locale? _locale;

  void setLocale(Locale locale) {
    if (!mounted || _locale == locale) return;
    setState(() {
      _locale = locale;
    });
  }

  @override
  void didChangeDependencies() {
    getLocale().then((locale) => setLocale(locale));
    super.didChangeDependencies();
  }

  @override
  Widget build(BuildContext context) {
    return MultiProvider(
      providers: [
        ChangeNotifierProvider(create: (_) => CameraProvider()),
        ChangeNotifierProvider(create: (_) => HomePageProvider()),
        ChangeNotifierProvider(create: (_) => RecentFilesProvider()),
        ChangeNotifierProvider(create: (_) => ImageEditProvider()),
      ],
      child: Builder(builder: (context) {
        bool isTablet = MediaQuery.of(context).size.shortestSide >= 600;
        double textScaleFactor = isTablet ? 1.3 : 1.0;
        return MediaQuery(
          data: MediaQuery.of(context)
              .copyWith(textScaler: TextScaler.linear(textScaleFactor)),
          child: MaterialApp(
            navigatorKey: navigatorKey,
            title: 'Document Scanner - PDF Scanner',
            debugShowCheckedModeBanner: false,
            localizationsDelegates: AppLocalizations.localizationsDelegates,
            supportedLocales: AppLocalizations.supportedLocales,
            locale: _locale,
            theme: ThemeData(
              colorScheme: ColorScheme.fromSeed(seedColor: Colors.deepPurple),
              useMaterial3: true,
              appBarTheme: const AppBarTheme(
                backgroundColor: Colors.white,
                foregroundColor: Colors.black,
                surfaceTintColor: Colors.transparent,
                shadowColor: Colors.transparent,
                scrolledUnderElevation: 0,
                elevation: 0,
                iconTheme: IconThemeData(color: Colors.black),
                actionsIconTheme: IconThemeData(color: Colors.black),
              ),
              textButtonTheme: TextButtonThemeData(
                style: TextButton.styleFrom(
                    foregroundColor: AppColor.primaryColor),
              ),
            ),
            home: StartupGate(
              // Same as Android / tablet-mobile: ~2s after animation is visible.
              minimumDuration: const Duration(seconds: 2),
              initialize: _initializeLocalData,
              onReady: () => unawaited(_initializeBackgroundServices()),
              loadingBuilder: (_, onShown) =>
                  SplashScreen(onAnimationShown: onShown),
              child: const BottomBar(),
            ),
          ),
        );
      }),
    );
  }
}
