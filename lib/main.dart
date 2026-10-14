import 'dart:async';
import 'package:doc_scanner/bottom_bar/bottom_bar.dart';
import 'package:doc_scanner/core/startup_gate.dart';
import 'package:doc_scanner/home_page/provider/home_page_provider.dart';
import 'package:doc_scanner/image_edit/provider/image_edit_provider.dart';
import 'package:doc_scanner/l10n/app_localizations.dart';
import 'package:doc_scanner/splash_screen/splash_screen.dart';
import 'package:doc_scanner/utils/app_color.dart';
import 'package:doc_scanner/utils/helper.dart';
import 'package:doc_scanner/utils/meta_events_helper.dart';
import 'package:firebase_core/firebase_core.dart';
import 'package:firebase_messaging/firebase_messaging.dart';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_local_notifications/flutter_local_notifications.dart';
import 'package:google_mobile_ads/google_mobile_ads.dart';
import 'package:provider/provider.dart';
import 'core/local_storage.dart';
import 'camera_screen/provider/camera_provider.dart';
import 'localaization/language_constant.dart';
import 'firebase_options.dart';

bool bannerReady = false;
bool interstitialReady = false;
InterstitialAd? myInterstitial;
ValueNotifier<bool> interstitialReadyNotifier = ValueNotifier(false);
final GlobalKey<NavigatorState> navigatorKey = GlobalKey<NavigatorState>();
// Notification Plugin
final FlutterLocalNotificationsPlugin flutterLocalNotificationsPlugin =
    FlutterLocalNotificationsPlugin();

Future<void> setupFirebaseMessaging() async {
  try {
    // Request permissions (iOS)
    final settings = await FirebaseMessaging.instance.requestPermission(
      alert: true,
      badge: true,
      sound: true,
    );

    if (settings.authorizationStatus == AuthorizationStatus.authorized) {
      print('User granted permission');
    }

    // Initialize local notifications
    const AndroidInitializationSettings androidSettings =
        AndroidInitializationSettings('@mipmap/ic_launcher');
    const DarwinInitializationSettings iosSettings =
        DarwinInitializationSettings(
      requestAlertPermission: true,
      requestBadgePermission: true,
      requestSoundPermission: true,
    );

    await flutterLocalNotificationsPlugin.initialize(
      settings: const InitializationSettings(
          android: androidSettings, iOS: iosSettings),
      onDidReceiveNotificationResponse: (details) {
        // Handle notification tap when app is in foreground
      },
    );

    // Foreground message handling
    FirebaseMessaging.onMessage.listen((RemoteMessage message) {
      print('Got a message whilst in the foreground!');
      print('Message data: ${message.data}');

      if (message.notification != null) {
        _showNotification(
          message.notification!.title ?? 'New Notification',
          message.notification!.body ?? 'You have a new message',
        );
      }
    });

    // Background message handling
    FirebaseMessaging.onMessageOpenedApp.listen((RemoteMessage message) {
      print('App opened from background via notification');
      _handleNotificationTap(message);
    });

    // Terminated state message handling
    RemoteMessage? initialMessage =
        await FirebaseMessaging.instance.getInitialMessage();
    if (initialMessage != null) {
      _handleNotificationTap(initialMessage);
    }

    // Get FCM token
    String? token = await FirebaseMessaging.instance.getToken();
    print('FCM Token: $token');

    // Subscribe to topics if needed
    // await FirebaseMessaging.instance.subscribeToTopic('all');
  } catch (e) {
    print('Error setting up Firebase Messaging: $e');
  }
}

Future<void> _showNotification(String title, String body) async {
  const AndroidNotificationDetails androidDetails = AndroidNotificationDetails(
    'high_importance_channel',
    'High Importance Notifications',
    importance: Importance.max,
    priority: Priority.high,
    showWhen: true,
  );

  const DarwinNotificationDetails iosDetails = DarwinNotificationDetails();

  await flutterLocalNotificationsPlugin.show(
    id: 0,
    title: title,
    body: body,
    notificationDetails:
        const NotificationDetails(android: androidDetails, iOS: iosDetails),
    payload: 'notification_payload',
  );
}

void _handleNotificationTap(RemoteMessage message) {
  if (navigatorKey.currentContext == null) {
    Future.delayed(const Duration(seconds: 1), () {
      _handleNotificationTap(message);
    });
    return;
  }
}

void main() {
  WidgetsFlutterBinding.ensureInitialized();
  unawaited(
      SystemChrome.setPreferredOrientations([DeviceOrientation.portraitUp]));
  runApp(const MyApp());
}

// These services do not gate access to local documents or the first home frame.
Future<void> _initializeBackgroundServices() async {
  unawaited(_initializeMessaging());
  await MetaEventsHelper.initialize();
  await MetaEventsHelper.logAppOpen();
}

Future<void> _initializeMessaging() async {
  try {
    await Firebase.initializeApp(
      options: DefaultFirebaseOptions.currentPlatform,
    );
    await setupFirebaseMessaging();
  } catch (error) {
    debugPrint('Firebase startup failed: $error');
  }
}

class MyApp extends StatefulWidget {
  const MyApp({super.key});

  @override
  State<MyApp> createState() => _MyAppState();

  static void setLocale(BuildContext context, Locale locale) {
    _MyAppState? state = context.findAncestorStateOfType<_MyAppState>();
    state!.setLocale(locale);
  }
}

class _MyAppState extends State<MyApp> {
  Locale? _locale;

  Future<void> _initializeLocalData() async {
    await Future.wait([
      LocalStorage().init(),
      AppHelper().createDirectories(),
    ]);
    final locale = await getLocale();
    setLocale(locale);
  }

  void setLocale(Locale locale) {
    if (!mounted || _locale == locale) return;
    setState(() => _locale = locale);
  }

  @override
  Widget build(BuildContext context) {
    return MultiProvider(
      providers: [
        ChangeNotifierProvider(create: (_) => CameraProvider()),
        ChangeNotifierProvider(create: (_) => HomePageProvider()),
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
              textButtonTheme: TextButtonThemeData(
                style: TextButton.styleFrom(
                    foregroundColor: AppColor.primaryColor),
              ),
            ),
            home: StartupGate(
              initialize: _initializeLocalData,
              onReady: () => unawaited(_initializeBackgroundServices()),
              loading: const SplashScreen(),
              child: const BottomBar(),
            ),
          ),
        );
      }),
    );
  }
}
