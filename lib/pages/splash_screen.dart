import 'package:easy_localization/easy_localization.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:flutter/material.dart';
import 'package:provider/provider.dart';

import 'package:safir_drivers/pages/auth/register_screen.dart';
import 'package:safir_drivers/pages/dashboard.dart';
import 'package:safir_drivers/providers/authentication_provider.dart';
import 'package:safir_drivers/widgets/blocked_screen.dart';
import 'package:safir_drivers/widgets/safir_splash_screen.dart';

class SplashScreen extends StatefulWidget {
  const SplashScreen({super.key});

  @override
  State<SplashScreen> createState() => _SplashScreenState();
}

class _SplashScreenState extends State<SplashScreen> {
  bool _isLoading = true;
  bool _hasError = false;
  bool _animationDone = false; // انیمیشن لوگو تمام شده؟
  Widget? _targetScreen;

  // رنگ اپ راننده (با آیکن و اسپلش بومی یکی است)
  static const Color _brandColor = Color(0xFF12304F);

  @override
  void initState() {
    super.initState();
    _checkAuthAndNavigation();
  }

  String _tr(String key, String fallback) {
    final String v = key.tr();
    return (v.trim().isEmpty || v == key) ? fallback : v;
  }

  Future<void> _checkAuthAndNavigation() async {
    if (mounted) {
      setState(() {
        _isLoading = true;
        _hasError = false;
        _targetScreen = null;
      });
    }

    try {
      final User? user = await FirebaseAuth.instance
          .authStateChanges()
          .first
          .timeout(
            const Duration(seconds: 4),
            onTimeout: () => FirebaseAuth.instance.currentUser,
          );

      if (!mounted) return;

      if (user == null) {
        setState(() {
          _isLoading = false;
          _targetScreen = const RegisterScreen();
        });
        return;
      }

      final authProvider = Provider.of<AuthenticationProvider>(context, listen: false);

      final results = await Future.wait([
        authProvider.getUserDataFromFirebaseDatabase().then((_) => true).catchError((_) => false),
        authProvider.checkIfDriverIsBlocked().catchError((_) => false),
        authProvider.checkDriverFieldsFilled().catchError((_) => true),
      ]).timeout(
        const Duration(seconds: 5),
        onTimeout: () => [false, false, true],
      );

      if (!mounted) return;

      final bool isBlocked = results[1];
      final bool isProfileComplete = results[2];

      if (isBlocked) {
        setState(() {
          _isLoading = false;
          _targetScreen = const BlockedScreen();
        });
        return;
      }

      if (isProfileComplete) {
        setState(() {
          _isLoading = false;
          _targetScreen = const Dashboard();
        });
      } else {
        setState(() {
          _isLoading = false;
          _targetScreen = const RegisterScreen();
        });
      }

    } catch (e) {
      debugPrint("SplashScreen Auth Exception: $e");
      if (!mounted) return;

      final User? currentUser = FirebaseAuth.instance.currentUser;
      if (currentUser != null) {
        setState(() {
          _isLoading = false;
          _targetScreen = const Dashboard();
        });
      } else {
        setState(() {
          _isLoading = false;
          _hasError = true;
        });
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    if (_hasError) {
      return Scaffold(
        backgroundColor: _brandColor,
        body: SafeArea(
          child: Stack(
            children: [
              Center(
                child: Column(
                  mainAxisAlignment: MainAxisAlignment.center,
                  children: [
                    const SafirLogoMark(
                      size: 140,
                      backgroundColor: _brandColor,
                    ),
                    const SizedBox(height: 24),
                    Padding(
                      padding: const EdgeInsets.symmetric(horizontal: 40.0),
                      child: Text(
                        _tr('network_error_msg',
                            'مشکلی در برقراری ارتباط پیش آمده است.'),
                        textAlign: TextAlign.center,
                        style: const TextStyle(
                          fontSize: 16,
                          color: Colors.white,
                          fontWeight: FontWeight.w500,
                        ),
                      ),
                    ),
                  ],
                ),
              ),
              Align(
                alignment: Alignment.bottomCenter,
                child: Padding(
                  padding: const EdgeInsets.all(20.0),
                  child: SizedBox(
                    width: double.infinity,
                    height: 52,
                    child: ElevatedButton(
                      onPressed: _checkAuthAndNavigation,
                      style: ElevatedButton.styleFrom(
                        backgroundColor: Colors.white,
                        elevation: 0,
                        shape: RoundedRectangleBorder(
                          borderRadius: BorderRadius.circular(14),
                        ),
                      ),
                      child: Text(
                        _tr('retry', 'تلاش دوباره'),
                        style: const TextStyle(
                          fontSize: 17,
                          fontWeight: FontWeight.bold,
                          color: _brandColor,
                        ),
                      ),
                    ),
                  ),
                ),
              ),
            ],
          ),
        ),
      );
    }

    // انیمیشن تمام شده و مقصد مشخص است → برو
    if (_animationDone && _targetScreen != null) {
      return _targetScreen!;
    }

    // اگر انیمیشن تمام شد ولی بررسی لاگین هنوز طول می‌کشد، لودینگ نشان بده
    final bool waiting = _animationDone && _targetScreen == null && _isLoading;

    return Scaffold(
      backgroundColor: _brandColor,
      body: Stack(
        children: [
          Center(
            child: SafirLogoAnimation(
              key: const ValueKey('safir_driver_logo_animation'),
              backgroundColor: _brandColor,
              title: 'Safir',
              subtitle: 'Driver',
              onCompleted: () {
                if (!mounted) return;
                setState(() => _animationDone = true);
              },
            ),
          ),
          if (waiting)
            const Positioned(
              left: 0,
              right: 0,
              bottom: 90,
              child: Center(child: _ThreeDotsLoading()),
            ),
        ],
      ),
    );
  }
}

// ویجت لودینگ ۳ نقطه متحرک
class _ThreeDotsLoading extends StatefulWidget {
  const _ThreeDotsLoading();

  @override
  State<_ThreeDotsLoading> createState() => _ThreeDotsLoadingState();
}

class _ThreeDotsLoadingState extends State<_ThreeDotsLoading>
    with SingleTickerProviderStateMixin {
  late AnimationController _controller;

  @override
  void initState() {
    super.initState();
    _controller = AnimationController(
      vsync: this,
      duration: const Duration(milliseconds: 1000),
    )..repeat();
  }

  @override
  void dispose() {
    _controller.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return AnimatedBuilder(
      animation: _controller,
      builder: (context, child) {
        return Row(
          mainAxisAlignment: MainAxisAlignment.center,
          children: List.generate(3, (index) {
            final double opacity =
                ((_controller.value - (index * 0.25)) % 1.0).clamp(0.2, 1.0);
            return Container(
              margin: const EdgeInsets.symmetric(horizontal: 4),
              width: 10,
              height: 10,
              decoration: BoxDecoration(
                color: Colors.white.withOpacity(opacity),
                shape: BoxShape.circle,
              ),
            );
          }),
        );
      },
    );
  }
}
