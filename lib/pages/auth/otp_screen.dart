import 'dart:async';

import 'package:easy_localization/easy_localization.dart' hide TextDirection;
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:pinput/pinput.dart';
import 'package:provider/provider.dart';

import '../../methods/common_method.dart';
import '../../pages/dashboard.dart';
import '../../pages/driverRegistration/driver_registration.dart';
import '../../providers/auth_provider.dart';
import '../../utils/app_colors.dart';
import '../../widgets/blocked_screen.dart';

class OTPScreen extends StatefulWidget {
  final String verificationId;
  final String phoneNumber;
  const OTPScreen({
    super.key,
    required this.verificationId,
    this.phoneNumber = '',
  });

  @override
  State<OTPScreen> createState() => _OTPScreenState();
}

class _OTPScreenState extends State<OTPScreen> {
  static const int _resendSeconds = 60;

  String? smsCode;
  CommonMethods commonMethods = CommonMethods();
  final TextEditingController _pinController = TextEditingController();

  Timer? _timer;
  int _secondsLeft = _resendSeconds;

  @override
  void initState() {
    super.initState();
    _startTimer();
  }

  @override
  void dispose() {
    _timer?.cancel();
    _pinController.dispose();
    super.dispose();
  }

  void _startTimer() {
    _timer?.cancel();
    setState(() => _secondsLeft = _resendSeconds);
    _timer = Timer.periodic(const Duration(seconds: 1), (Timer t) {
      if (!mounted) {
        t.cancel();
        return;
      }
      if (_secondsLeft <= 1) {
        t.cancel();
        setState(() => _secondsLeft = 0);
      } else {
        setState(() => _secondsLeft--);
      }
    });
  }

  String _t(String key, String fallback) {
    final String v = key.tr();
    return (v.trim().isEmpty || v == key) ? fallback : v;
  }

  String get _timerText {
    final int m = _secondsLeft ~/ 60;
    final int s = _secondsLeft % 60;
    return '${m.toString().padLeft(2, '0')}:${s.toString().padLeft(2, '0')}';
  }

  void _resend() {
    HapticFeedback.selectionClick();
    if (widget.phoneNumber.trim().isNotEmpty) {
      final AuthenticationProvider auth =
          Provider.of<AuthenticationProvider>(context, listen: false);
      _pinController.clear();
      setState(() => smsCode = null);
      _startTimer();
      auth.signInWithPhone(
        context: context,
        phoneNumber: widget.phoneNumber.trim(),
        replaceCurrent: true,
      );
    } else {
      Navigator.maybePop(context);
    }
  }

  PinTheme _pinTheme({bool focused = false}) {
    return PinTheme(
      width: 48,
      height: 56,
      decoration: BoxDecoration(
        borderRadius: BorderRadius.circular(12),
        color: AppColors.cardBackground,
        border: Border.all(
          color: focused ? AppColors.primaryBrand : AppColors.fieldBorder,
          width: focused ? 2 : 1,
        ),
      ),
      textStyle: TextStyle(
        fontSize: 20,
        fontWeight: FontWeight.w600,
        color: AppColors.textPrimary,
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    final authRepo = Provider.of<AuthenticationProvider>(context, listen: true);
    return Scaffold(
      backgroundColor: AppColors.background,
      appBar: AppBar(
        backgroundColor: AppColors.background,
        surfaceTintColor: AppColors.background,
        elevation: 0,
        scrolledUnderElevation: 0,
        iconTheme: IconThemeData(color: AppColors.textPrimary),
        leading: IconButton(
          icon: const Icon(Icons.arrow_back_rounded),
          onPressed: () => Navigator.maybePop(context),
        ),
      ),
      body: SafeArea(
        child: Center(
          child: SingleChildScrollView(
            child: Padding(
              padding:
                  const EdgeInsets.symmetric(vertical: 25.0, horizontal: 28),
              child: Column(
                mainAxisAlignment: MainAxisAlignment.center,
                children: [
                  Text(
                    'otp_title'.tr(),
                    style: TextStyle(
                      fontSize: 22,
                      fontWeight: FontWeight.bold,
                      color: AppColors.textPrimary,
                    ),
                  ),
                  const SizedBox(height: 10),
                  Text(
                    'otp_subtitle'.tr(),
                    textAlign: TextAlign.center,
                    style: TextStyle(
                      fontSize: 14,
                      color: AppColors.textSecondary,
                    ),
                  ),
                  const SizedBox(height: 30),

                  // فیلد ورود کد ۶ رقمی (اعداد فارسی/عربی به لاتین تبدیل می‌شوند)
                  Directionality(
                    textDirection: TextDirection.ltr,
                    child: Pinput(
                      length: 6,
                      controller: _pinController,
                      autofocus: true,
                      showCursor: true,
                      keyboardType: TextInputType.number,
                      enabled: !authRepo.isLoading,
                      inputFormatters: <TextInputFormatter>[
                        _AsciiDigitsFormatter(),
                      ],
                      defaultPinTheme: _pinTheme(),
                      focusedPinTheme: _pinTheme(focused: true),
                      submittedPinTheme: _pinTheme(),
                      onCompleted: (value) {
                        if (authRepo.isLoading) return;
                        setState(() {
                          smsCode = value;
                        });

                        // اجرای متد بررسی کد پیامک
                        verifyOTP(smsCode: smsCode!);
                      },
                    ),
                  ),

                  const SizedBox(height: 25),

                  // نمایش وضعیت در حال بررسی
                  authRepo.isLoading
                      ? CircularProgressIndicator(
                          color: AppColors.primaryBrand,
                        )
                      : const SizedBox.shrink(),

                  // نشانه موفقیت
                  authRepo.isSuccessful
                      ? Icon(
                          Icons.check_circle_rounded,
                          color: AppColors.success,
                          size: 44,
                        )
                      : const SizedBox.shrink(),

                  const SizedBox(height: 25),

                  if (_secondsLeft > 0)
                    Row(
                      mainAxisSize: MainAxisSize.min,
                      children: [
                        Icon(Icons.timer_outlined,
                            size: 18, color: AppColors.textSecondary),
                        const SizedBox(width: 6),
                        Text(
                          '${_t('otp_resend_in', 'ارسال مجدد کد تا')} $_timerText',
                          style: TextStyle(
                            fontSize: 13,
                            fontWeight: FontWeight.w600,
                            color: AppColors.textSecondary,
                          ),
                        ),
                      ],
                    )
                  else ...[
                    Text(
                      'didnt_receive_code'.tr(),
                      style: TextStyle(
                        fontSize: 14,
                        color: AppColors.textSecondary,
                      ),
                    ),
                    const SizedBox(height: 8),
                    TextButton.icon(
                      onPressed: authRepo.isLoading ? null : _resend,
                      icon: Icon(Icons.refresh_rounded,
                          size: 18, color: AppColors.textPrimary),
                      label: Text(
                        'resend_code'.tr(),
                        style: TextStyle(
                          fontSize: 14,
                          fontWeight: FontWeight.bold,
                          color: AppColors.textPrimary,
                        ),
                      ),
                    ),
                  ],
                ],
              ),
            ),
          ),
        ),
      ),
    );
  }

  // متد اصلاح‌شده برای عبور از لودینگ بی‌نهایت و هدایت سریع راننده
  void verifyOTP({required String smsCode}) {
    final authProvider = Provider.of<AuthenticationProvider>(context, listen: false);

    authProvider.verifyOTP(
      context: context,
      verificationId: widget.verificationId,
      smsCode: smsCode,
      onSuccess: () async {
        try {
          // ۱. بررسی وجود راننده در دیتابیس
          bool driverExists = await authProvider.checkUserExistById().timeout(
            const Duration(seconds: 4),
            onTimeout: () => false,
          );

          if (driverExists) {
            // ۲. بررسی مسدود بودن راننده با مدیریت خطا
            bool isBlocked = false;
            try {
              isBlocked = await authProvider.checkIfDriverIsBlocked();
            } catch (e) {
              isBlocked = false; // اگر خطایی داد، فرض می‌کنیم مسدود نیست
            }

            if (isBlocked) {
              if (!mounted) return;
              Navigator.pushReplacement(
                context,
                MaterialPageRoute(builder: (context) => const BlockedScreen()),
              );
              return;
            }

            // ۳. دریافت اطلاعات با مدیریت خطا
            try {
              await authProvider.getUserDataFromFirebaseDatabase();
            } catch (e) {
              debugPrint("خطا در دریافت اطلاعات راننده: $e");
            }

            // ۴. بررسی پر بودن مدارک
            bool isDriverComplete = false;
            try {
              isDriverComplete = await authProvider.checkDriverFieldsFilled();
            } catch (e) {
              isDriverComplete = false; 
            }

            if (isDriverComplete) {
              navigate(isSignedIn: true);
            } else {
              navigate(isSignedIn: false);
              if (!mounted) return;
              commonMethods.displaySnackBar(
                'please_complete_documents'.tr(),
                context,
              );
            }
          } else {
            // اگر راننده وجود نداشت، مستقیم به ثبت‌نام برو
            navigate(isSignedIn: false);
          }
        } catch (globalError) {
          // 🚀 اگر هر خطای پیش‌بینی نشده‌ای رخ داد، برنامه قفل نشود و مستقیم به صفحه ثبت‌نام برود
          debugPrint("خطای کلی در ورود: $globalError");
          navigate(isSignedIn: false);
        }
      },
    );
  }

  // مدیریت ناوبری نهایی صفحات
  void navigate({required bool isSignedIn}) {
    if (!mounted) return;
    if (isSignedIn) {
      Navigator.pushAndRemoveUntil(
        context,
        MaterialPageRoute(builder: (context) => const Dashboard()),
        (route) => false,
      );
    } else {
      Navigator.pushAndRemoveUntil(
        context,
        MaterialPageRoute(builder: (context) => DriverRegistration()),
        (route) => false,
      );
    }
  }
}
class _AsciiDigitsFormatter extends TextInputFormatter {
  @override
  TextEditingValue formatEditUpdate(
      TextEditingValue oldValue, TextEditingValue newValue) {
    final StringBuffer b = StringBuffer();
    for (final int r in newValue.text.runes) {
      if (r >= 0x06F0 && r <= 0x06F9) {
        b.writeCharCode(0x30 + r - 0x06F0);
      } else if (r >= 0x0660 && r <= 0x0669) {
        b.writeCharCode(0x30 + r - 0x0660);
      } else if (r >= 0x30 && r <= 0x39) {
        b.writeCharCode(r);
      }
    }
    final String t = b.toString();
    return TextEditingValue(
      text: t,
      selection: TextSelection.collapsed(offset: t.length),
    );
  }
}
