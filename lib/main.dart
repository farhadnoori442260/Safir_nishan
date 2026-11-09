import 'package:easy_localization/easy_localization.dart';
import 'package:firebase_core/firebase_core.dart';
import 'package:firebase_messaging/firebase_messaging.dart';
import 'package:flutter/material.dart';
import 'package:permission_handler/permission_handler.dart';
import 'package:provider/provider.dart';

import 'package:safir_drivers/controllers/navigation_controller.dart'; // 👈 اضافه شد
import 'package:safir_drivers/pages/splash_screen.dart';
import 'package:safir_drivers/providers/authentication_provider.dart';
import 'package:safir_drivers/providers/dashboard_provider.dart';
import 'package:safir_drivers/providers/registration_provider.dart';
import 'package:safir_drivers/providers/trip_provider.dart';
import 'package:safir_drivers/utils/app_colors.dart';
import 'package:safir_drivers/utils/lang_helper.dart';

final GlobalKey<NavigatorState> navigatorKey = GlobalKey<NavigatorState>();

// دریافت پیام در پس‌زمینه
@pragma('vm:entry-point')
Future<void> _firebaseMessagingBackgroundHandler(
  RemoteMessage message,
) async {
  await Firebase.initializeApp();

  debugPrint(
    'Driver background message received: ${message.messageId}',
  );
}

// راه‌اندازی دریافت اعلان‌های عمومی رانندگان
Future<void> _setupDriverNotifications() async {
  try {
    // اگر راه‌اندازی اولیهٔ Firebase ناموفق بود،
    // تنظیم اعلان نباید باعث توقف برنامه شود.
    if (Firebase.apps.isEmpty) {
      debugPrint(
        'Driver notifications: Firebase is not initialized',
      );
      return;
    }

    final messaging = FirebaseMessaging.instance;

    final settings = await messaging.requestPermission(
      alert: true,
      badge: true,
      sound: true,
    );

    if (settings.authorizationStatus == AuthorizationStatus.denied) {
      debugPrint(
        'Driver notifications: permission denied',
      );
      return;
    }

    await messaging.setAutoInitEnabled(true);

    // تنظیم نمایش اعلان در پیش‌زمینه برای پلتفرم‌های Apple
    await messaging.setForegroundNotificationPresentationOptions(
      alert: true,
      badge: true,
      sound: true,
    );

    // ثبت دریافت پیام هنگام بازبودن اپ
    FirebaseMessaging.onMessage.listen((RemoteMessage message) {
      debugPrint(
        'Driver foreground message received: ${message.messageId}',
      );
    });

    // نام این گروه مطابق مقصد رانندگان در سرور Netlify است.
    await messaging.subscribeToTopic('drivers');

    debugPrint(
      'Driver notifications: subscribed to drivers',
    );
  } catch (error) {
    // خطای اعلان نباید مانع بازشدن اپ شود.
    debugPrint(
      'Driver notifications setup error: $error',
    );
  }
}

Future<void> main() async {
  WidgetsFlutterBinding.ensureInitialized();

  FlutterError.onError = (FlutterErrorDetails details) {
    FlutterError.dumpErrorToConsole(details);
  };

  try {
    await EasyLocalization.ensureInitialized();
  } catch (error) {
    debugPrint('EasyLocalization initialization error: $error');
  }

  try {
    await Firebase.initializeApp();

    FirebaseMessaging.onBackgroundMessage(
      _firebaseMessagingBackgroundHandler,
    );
  } catch (error) {
    debugPrint('Firebase initialization error: $error');
  }

  await _requestPermissionsSafely();

  runApp(
    EasyLocalization(
      supportedLocales: const [
        Locale('fa'),
        Locale('ps'),
        Locale('en'),
      ],
      path: 'assets/translations',
      fallbackLocale: const Locale('fa'),
      startLocale: const Locale('fa'),
      useFallbackTranslations: true,
      child: const MyApp(),
    ),
  );

  // تنظیم اعلان پس از نمایش اولین فریم برنامه
  WidgetsBinding.instance.addPostFrameCallback((_) {
    _setupDriverNotifications();
  });
}

Future<void> _requestPermissionsSafely() async {
  try {
    await Permission.locationWhenInUse.request();
    await Permission.notification.request();
  } catch (error) {
    debugPrint('Permission request error: $error');
  }
}

class MyApp extends StatelessWidget {
  const MyApp({super.key});

  @override
  Widget build(BuildContext context) {
    ErrorWidget.builder = (FlutterErrorDetails details) {
      return Scaffold(
        backgroundColor: AppColors.cardBackground,
        body: Center(
          child: Padding(
            padding: const EdgeInsets.all(20),
            child: Text(
              'خطا در بارگذاری برنامه - ${details.exception}',
              textAlign: TextAlign.center,
              style: const TextStyle(
                color: Colors.red,
                fontSize: 13,
              ),
            ),
          ),
        ),
      );
    };

    return MultiProvider(
      providers: [
        ChangeNotifierProvider(
          create: (_) => AppLanguageProvider(),
        ),
        ChangeNotifierProvider(
          create: (_) => DashboardProvider(),
        ),
        ChangeNotifierProvider(
          create: (_) => AuthenticationProvider(),
        ),
        ChangeNotifierProvider(
          create: (_) => RegistrationProvider(),
        ),
        ChangeNotifierProvider(
          create: (_) => TripProvider(),
        ),
        // 👈 پروایدر مسیریابی اضافه شد
        ChangeNotifierProvider(
          create: (_) => NavigationController(),
        ),
      ],
      child: MaterialApp(
        navigatorKey: navigatorKey,
        title: 'Safir Drivers',
        debugShowCheckedModeBanner: false,
        localizationsDelegates: context.localizationDelegates,
        supportedLocales: context.supportedLocales,
        locale: context.locale,
        theme: ThemeData(
          useMaterial3: true,
          fontFamily: 'IranYekan',
          primaryColor: AppColors.primaryBrand,
          scaffoldBackgroundColor: AppColors.background,
          colorScheme: ColorScheme.fromSeed(
            seedColor: AppColors.primaryBrand,
            primary: AppColors.primaryBrand,
            surface: AppColors.cardBackground,
          ),
          appBarTheme: const AppBarTheme(
            backgroundColor: AppColors.cardBackground,
            elevation: 0,
            centerTitle: true,
            iconTheme: IconThemeData(color: AppColors.textPrimary),
            titleTextStyle: TextStyle(
              fontFamily: 'IranYekan',
              fontSize: 18,
              fontWeight: FontWeight.bold,
              color: AppColors.textPrimary,
            ),
          ),
        ),
        home: const SplashScreen(),
      ),
    );
  }
}
