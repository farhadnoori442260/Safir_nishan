import 'package:easy_localization/easy_localization.dart';
import 'package:firebase_core/firebase_core.dart';
import 'package:firebase_messaging/firebase_messaging.dart';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
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
import 'package:safir_drivers/utils/theme_controller.dart';

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

  // تم ذخیره‌شده (روشن/تاریک/سیستم) قبل از اولین فریم اعمال می‌شود
  await ThemeController.instance.load();
  AppColors.isDark = ThemeController.instance.resolveDark(
    WidgetsBinding.instance.platformDispatcher.platformBrightness,
  );

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

class MyApp extends StatefulWidget {
  const MyApp({super.key});

  @override
  State<MyApp> createState() => _MyAppState();
}

class _MyAppState extends State<MyApp> with WidgetsBindingObserver {
  static const String _font = 'IranYekan';

  final ThemeController _theme = ThemeController.instance;

  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addObserver(this);
    _theme.addListener(_onThemeChanged);
  }

  @override
  void dispose() {
    _theme.removeListener(_onThemeChanged);
    WidgetsBinding.instance.removeObserver(this);
    super.dispose();
  }

  // کاربر در حالت «سیستم» است و روشنایی گوشی عوض شد
  @override
  void didChangePlatformBrightness() {
    if (_theme.mode == ThemeMode.system) _onThemeChanged();
  }

  void _onThemeChanged() {
    final bool dark = _theme.resolveDark(
      WidgetsBinding.instance.platformDispatcher.platformBrightness,
    );
    if (dark == AppColors.isDark) return;

    // ۱) پالت جدید فعال می‌شود
    AppColors.isDark = dark;

    // ۲) همهٔ المان‌ها (حتی const ها) دوباره ساخته می‌شوند؛ پشتهٔ صفحه‌ها و
    //    stateها دست‌نخورده می‌مانند.
    void mark(Element e) {
      e.markNeedsBuild();
      e.visitChildren(mark);
    }

    if (mounted) {
      setState(() {});
      (context as Element).visitChildren(mark);
    }
  }

  ThemeData _buildTheme(bool dark) {
    // رنگ‌ها را از پالت می‌خوانیم؛ پالت را موقتاً روی حالت درخواستی می‌گذاریم
    final bool saved = AppColors.isDark;
    AppColors.isDark = dark;
    final Color primary = AppColors.primaryBrand;
    final Color bg = AppColors.background;
    final Color surface = AppColors.cardBackground;
    final Color title = AppColors.textPrimary;
    final Color muted = AppColors.textSecondary;
    final Color line = AppColors.borderLight;
    AppColors.isDark = saved;

    return ThemeData(
      useMaterial3: true,
      brightness: dark ? Brightness.dark : Brightness.light,
      fontFamily: _font,
      primaryColor: primary,
      scaffoldBackgroundColor: bg,
      canvasColor: surface,
      dividerColor: line,
      colorScheme: ColorScheme.fromSeed(
        seedColor: primary,
        brightness: dark ? Brightness.dark : Brightness.light,
      ).copyWith(primary: primary, surface: surface),
      dialogTheme: DialogThemeData(
        backgroundColor: surface,
        surfaceTintColor: Colors.transparent,
      ),
      bottomSheetTheme: BottomSheetThemeData(
        backgroundColor: surface,
        surfaceTintColor: Colors.transparent,
      ),
      appBarTheme: AppBarTheme(
        backgroundColor: surface,
        surfaceTintColor: Colors.transparent,
        elevation: 0,
        centerTitle: true,
        iconTheme: IconThemeData(color: title),
        titleTextStyle: TextStyle(
          fontFamily: _font,
          fontSize: 18,
          fontWeight: FontWeight.bold,
          color: title,
        ),
      ),
      inputDecorationTheme: InputDecorationTheme(
        labelStyle: TextStyle(fontFamily: _font, color: muted),
        floatingLabelStyle: TextStyle(fontFamily: _font, color: primary),
        hintStyle: TextStyle(fontFamily: _font, color: muted),
        enabledBorder: OutlineInputBorder(
          borderRadius: BorderRadius.circular(12),
          borderSide: BorderSide(color: line),
        ),
        focusedBorder: OutlineInputBorder(
          borderRadius: BorderRadius.circular(12),
          borderSide: BorderSide(color: primary, width: 1.5),
        ),
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    final bool dark = AppColors.isDark;

    ErrorWidget.builder = (FlutterErrorDetails details) {
      return Scaffold(
        backgroundColor: AppColors.cardBackground,
        body: Center(
          child: Padding(
            padding: const EdgeInsets.all(20),
            child: Text(
              'خطا در بارگذاری برنامه - ${details.exception}',
              textAlign: TextAlign.center,
              style: TextStyle(
                color: AppColors.error,
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
        // تم را خودمان با AppColors.isDark تعیین می‌کنیم
        themeMode: dark ? ThemeMode.dark : ThemeMode.light,
        theme: _buildTheme(false),
        darkTheme: _buildTheme(true),

        // رنگ آیکون‌های نوار وضعیت و نوار پایین متناسب با تم
        builder: (context, child) {
          return AnnotatedRegion<SystemUiOverlayStyle>(
            value: SystemUiOverlayStyle(
              statusBarColor: Colors.transparent,
              statusBarIconBrightness:
                  dark ? Brightness.light : Brightness.dark,
              statusBarBrightness: dark ? Brightness.dark : Brightness.light,
              systemNavigationBarColor: Colors.transparent,
              systemNavigationBarIconBrightness:
                  dark ? Brightness.light : Brightness.dark,
              systemNavigationBarContrastEnforced: false,
            ),
            child: child ?? const SizedBox.shrink(),
          );
        },

        home: const SplashScreen(),
      ),
    );
  }
}
