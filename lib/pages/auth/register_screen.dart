import 'dart:ui' as ui;

import 'package:easy_localization/easy_localization.dart';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:provider/provider.dart';

import '../../methods/common_method.dart';
import '../../pages/dashboard.dart';
import '../../pages/driverRegistration/driver_registration.dart';
import '../../providers/authentication_provider.dart';
import '../../utils/app_colors.dart';
import '../../widgets/blocked_screen.dart';

class _AsciiDigitsFormatter extends TextInputFormatter {
  @override
  TextEditingValue formatEditUpdate(
    TextEditingValue oldValue,
    TextEditingValue newValue,
  ) {
    final StringBuffer buffer = StringBuffer();

    for (final int code in newValue.text.runes) {
      if (code >= 0x30 && code <= 0x39) {
        buffer.writeCharCode(code);
      } else if (code >= 0x06F0 && code <= 0x06F9) {
        buffer.writeCharCode(
          0x30 + (code - 0x06F0),
        );
      } else if (code >= 0x0660 && code <= 0x0669) {
        buffer.writeCharCode(
          0x30 + (code - 0x0660),
        );
      }
    }

    final String text = buffer.toString();

    return TextEditingValue(
      text: text,
      selection: TextSelection.collapsed(
        offset: text.length,
      ),
    );
  }
}

class RegisterScreen extends StatefulWidget {
  const RegisterScreen({super.key});

  @override
  State<RegisterScreen> createState() => _RegisterScreenState();
}

class _RegisterScreenState extends State<RegisterScreen> {
  final TextEditingController phoneController =
      TextEditingController();

  final CommonMethods commonMethods = CommonMethods();

  @override
  void dispose() {
    phoneController.dispose();
    super.dispose();
  }

  String _t(String key, String fallback) {
    final String value = key.tr();

    return value.trim().isEmpty || value == key
        ? fallback
        : value;
  }

  String _getLanguageCodeText(BuildContext context) {
    switch (context.locale.languageCode) {
      case 'ps':
        return 'PS';
      case 'en':
        return 'EN';
      case 'fa':
      default:
        return 'FA';
    }
  }

  String _getPhoneSectionTitle() {
    switch (context.locale.languageCode) {
      case 'en':
        return 'Phone Number';
      case 'ps':
        return 'د تلیفون شمېره';
      case 'fa':
      default:
        return 'شماره همراه';
    }
  }

  void _showLanguageSelector() {
    HapticFeedback.selectionClick();

    final String languageCode = context.locale.languageCode;

    final String bottomSheetTitle = languageCode == 'ps'
        ? 'ژبه غوره کړئ'
        : languageCode == 'en'
            ? 'Select Language'
            : 'انتخاب زبان';

    showModalBottomSheet(
      context: context,
      backgroundColor: AppColors.cardBackground,
      elevation: 0,
      isScrollControlled: true,
      shape: const RoundedRectangleBorder(
        borderRadius: BorderRadius.vertical(
          top: Radius.circular(28),
        ),
      ),
      builder: (BuildContext sheetContext) {
        return SafeArea(
          top: false,
          child: Padding(
            padding: const EdgeInsets.fromLTRB(
              20,
              14,
              20,
              16,
            ),
            child: Column(
              mainAxisSize: MainAxisSize.min,
              children: <Widget>[
                Container(
                  width: 38,
                  height: 4.5,
                  decoration: BoxDecoration(
                    color: AppColors.handle,
                    borderRadius: BorderRadius.circular(10),
                  ),
                ),
                const SizedBox(height: 22),
                Text(
                  bottomSheetTitle,
                  textAlign: TextAlign.center,
                  style: TextStyle(
                    fontWeight: FontWeight.w800,
                    fontSize: 17,
                    color: AppColors.textPrimary,
                  ),
                ),
                const SizedBox(height: 18),
                _buildLanguageTile(
                  title: 'دری',
                  locale: const Locale('fa'),
                  sheetContext: sheetContext,
                ),
                const SizedBox(height: 10),
                _buildLanguageTile(
                  title: 'پښتو',
                  locale: const Locale('ps'),
                  sheetContext: sheetContext,
                ),
                const SizedBox(height: 10),
                _buildLanguageTile(
                  title: 'English',
                  locale: const Locale('en'),
                  sheetContext: sheetContext,
                ),
                const SizedBox(height: 8),
              ],
            ),
          ),
        );
      },
    );
  }

  Widget _buildLanguageTile({
    required String title,
    required Locale locale,
    required BuildContext sheetContext,
  }) {
    final bool isSelected =
        context.locale.languageCode == locale.languageCode;

    return InkWell(
      onTap: () async {
        HapticFeedback.selectionClick();

        await context.setLocale(locale);

        if (!mounted || !sheetContext.mounted) {
          return;
        }

        Navigator.pop(sheetContext);
      },
      borderRadius: BorderRadius.circular(16),
      child: AnimatedContainer(
        duration: const Duration(milliseconds: 200),
        padding: const EdgeInsets.symmetric(
          horizontal: 16,
          vertical: 15,
        ),
        decoration: BoxDecoration(
          color: AppColors.background,
          borderRadius: BorderRadius.circular(16),
          border: Border.all(
            color: isSelected
                ? AppColors.primaryBrand
                : AppColors.fieldBorder,
            width: isSelected ? 1.8 : 1,
          ),
        ),
        child: Row(
          children: <Widget>[
            Expanded(
              child: Text(
                title,
                style: TextStyle(
                  fontWeight: isSelected
                      ? FontWeight.w800
                      : FontWeight.w600,
                  fontSize: 15,
                  color: AppColors.textPrimary,
                ),
              ),
            ),
            if (isSelected)
              Icon(
                Icons.check_circle_rounded,
                color: AppColors.primaryBrand,
                size: 22,
              ),
          ],
        ),
      ),
    );
  }

  Future<void> _handleGoogleSignIn() async {
    final AuthenticationProvider authProvider =
        context.read<AuthenticationProvider>();

    await authProvider.signInWithGoogle(
      context,
      () async {
        if (!mounted) {
          return;
        }

        final user = authProvider.firebaseAuth.currentUser;

        if (user == null) {
          return;
        }

        try {
          final bool userExists =
              await authProvider.checkUserExistById();

          if (!mounted) {
            return;
          }

          if (!userExists) {
            navigate(isSignedIn: false);
            return;
          }

          final bool isBlocked =
              await authProvider.checkIfDriverIsBlocked();

          if (!mounted) {
            return;
          }

          if (isBlocked) {
            Navigator.pushReplacement(
              context,
              MaterialPageRoute(
                builder: (_) => const BlockedScreen(),
              ),
            );
            return;
          }

          await authProvider.getUserDataFromFirebaseDatabase();

          if (!mounted) {
            return;
          }

          final bool isDriverComplete =
              await authProvider.checkDriverFieldsFilled();

          if (!mounted) {
            return;
          }

          if (isDriverComplete) {
            navigate(isSignedIn: true);
          } else {
            navigate(isSignedIn: false);

            commonMethods.displaySnackBar(
              'complete_documents_error'.tr(),
              context,
            );
          }
        } catch (_) {
          if (!mounted) {
            return;
          }

          commonMethods.displaySnackBar(
            'error_occurred'.tr(),
            context,
          );
        }
      },
    );
  }

  bool _isPhoneValid(String input) {
    return RegExp(r'^07[0-9]{8}$').hasMatch(input.trim());
  }

  void sendPhoneNumber() {
    final String phoneText = phoneController.text.trim();

    if (!_isPhoneValid(phoneText)) {
      commonMethods.displaySnackBar(
        _t(
          'invalid_phone_error',
          'شماره باید با 07 شروع شود و ۱۰ رقم باشد',
        ),
        context,
      );
      return;
    }

    FocusScope.of(context).unfocus();

    final String digits = phoneText.substring(1);

    final AuthenticationProvider authProvider =
        context.read<AuthenticationProvider>();

    authProvider.signInWithPhone(
      context: context,
      phoneNumber: '+93$digits',
    );
  }

  void navigate({required bool isSignedIn}) {
    if (!mounted) {
      return;
    }

    if (isSignedIn) {
      Navigator.pushAndRemoveUntil(
        context,
        MaterialPageRoute(
          builder: (_) => const Dashboard(),
        ),
        (route) => false,
      );
    } else {
      Navigator.push(
        context,
        MaterialPageRoute(
          builder: (_) => const DriverRegistration(),
        ),
      );
    }
  }

  @override
  Widget build(BuildContext context) {
    final bool isLoading =
        context.select<AuthenticationProvider, bool>(
      (AuthenticationProvider provider) => provider.isLoading,
    );

    final bool isGoogleLoading =
        context.select<AuthenticationProvider, bool>(
      (AuthenticationProvider provider) =>
          provider.isGoogleSigInLoading,
    );

    final bool isDark =
        Theme.of(context).brightness == Brightness.dark;

    return Scaffold(
      resizeToAvoidBottomInset: true,
      backgroundColor: AppColors.background,
      body: SafeArea(
        child: SingleChildScrollView(
          keyboardDismissBehavior:
              ScrollViewKeyboardDismissBehavior.onDrag,
          physics: const BouncingScrollPhysics(),
          child: Padding(
            padding: const EdgeInsets.symmetric(
              horizontal: 20,
              vertical: 16,
            ),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: <Widget>[
                _buildLanguageButton(),
                const SizedBox(height: 28),
                _buildLogo(isDark: isDark),
                const SizedBox(height: 20),
                Center(
                  child: Text(
                    _t(
                      'register_title',
                      'به سفیر رانندگان خوش آمدید',
                    ),
                    textAlign: TextAlign.center,
                    style: TextStyle(
                      fontSize: 24,
                      fontWeight: FontWeight.w800,
                      color: AppColors.textPrimary,
                      height: 1.3,
                    ),
                  ),
                ),
                const SizedBox(height: 8),
                Center(
                  child: Text(
                    _t(
                      'register_subtitle',
                      'شمارهٔ همراه خود را وارد کنید تا کد تأیید برایتان ارسال شود',
                    ),
                    textAlign: TextAlign.center,
                    style: TextStyle(
                      fontSize: 13.5,
                      color: AppColors.textSecondary,
                      height: 1.6,
                    ),
                  ),
                ),
                const SizedBox(height: 30),
                _buildPhoneSection(isLoading),
                const SizedBox(height: 26),
                _buildOrDivider(),
                const SizedBox(height: 20),
                _buildGoogleButton(
                  isLoading: isLoading,
                  isGoogleLoading: isGoogleLoading,
                ),
                const SizedBox(height: 28),
                Center(
                  child: Text(
                    _t(
                      'terms_and_conditions',
                      'با ادامه دادن، شرایط استفاده و سیاست حریم خصوصی سفیر را می‌پذیرید.',
                    ),
                    textAlign: TextAlign.center,
                    style: TextStyle(
                      color: AppColors.textSecondary,
                      fontSize: 11.5,
                      height: 1.6,
                    ),
                  ),
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }

  Widget _buildLanguageButton() {
    return Align(
      alignment: AlignmentDirectional.centerEnd,
      child: Material(
        color: AppColors.cardBackground,
        borderRadius: BorderRadius.circular(22),
        child: InkWell(
          borderRadius: BorderRadius.circular(22),
          onTap: _showLanguageSelector,
          child: Container(
            padding: const EdgeInsets.symmetric(
              horizontal: 12,
              vertical: 9,
            ),
            decoration: BoxDecoration(
              borderRadius: BorderRadius.circular(22),
              border: Border.all(
                color: AppColors.fieldBorder,
              ),
            ),
            child: Row(
              mainAxisSize: MainAxisSize.min,
              children: <Widget>[
                Icon(
                  Icons.language_rounded,
                  size: 18,
                  color: AppColors.textSecondary,
                ),
                const SizedBox(width: 6),
                Text(
                  _getLanguageCodeText(context),
                  style: TextStyle(
                    color: AppColors.textPrimary,
                    fontSize: 12.5,
                    fontWeight: FontWeight.w800,
                    letterSpacing: 0.6,
                  ),
                ),
                const SizedBox(width: 2),
                Icon(
                  Icons.keyboard_arrow_down_rounded,
                  size: 18,
                  color: AppColors.textSecondary,
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }

  Widget _buildLogo({required bool isDark}) {
    return Center(
      child: Container(
        width: 88,
        height: 88,
        decoration: BoxDecoration(
          color: AppColors.cardBackground,
          borderRadius: BorderRadius.circular(24),
          border: Border.all(
            color: AppColors.fieldBorder,
          ),
          boxShadow: isDark
              ? null
              : <BoxShadow>[
                  BoxShadow(
                    color: AppColors.textPrimary.withOpacity(0.07),
                    blurRadius: 16,
                    offset: const Offset(0, 6),
                  ),
                ],
        ),
        child: ClipRRect(
          borderRadius: BorderRadius.circular(23),
          child: Image.asset(
            'assets/icon/so_appstore_1024.png',
            fit: BoxFit.cover,
            errorBuilder: (
              BuildContext context,
              Object error,
              StackTrace? stackTrace,
            ) {
              return Icon(
                Icons.local_taxi_rounded,
                color: AppColors.primaryBrand,
                size: 40,
              );
            },
          ),
        ),
      ),
    );
  }

  Widget _buildPhoneSection(bool isLoading) {
    return ValueListenableBuilder<TextEditingValue>(
      valueListenable: phoneController,
      builder: (
        BuildContext context,
        TextEditingValue value,
        Widget? child,
      ) {
        final String phoneText = value.text;
        final bool isValidPhone = _isPhoneValid(phoneText);

        final bool showPhoneError =
            phoneText.length == 10 && !isValidPhone;

        final bool canSubmit = isValidPhone && !isLoading;

        return Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: <Widget>[
            _buildSectionHeader(_getPhoneSectionTitle()),
            AnimatedContainer(
              duration: const Duration(milliseconds: 180),
              decoration: BoxDecoration(
                color: AppColors.cardBackground,
                borderRadius: BorderRadius.circular(16),
                border: Border.all(
                  color: showPhoneError
                      ? AppColors.danger
                      : isValidPhone
                          ? AppColors.primaryBrand
                          : AppColors.fieldBorder,
                  width: showPhoneError || isValidPhone
                      ? 1.6
                      : 1.2,
                ),
              ),
              child: Directionality(
                textDirection: ui.TextDirection.ltr,
                child: Row(
                  children: <Widget>[
                    Container(
                      padding: const EdgeInsets.symmetric(
                        horizontal: 14,
                        vertical: 16,
                      ),
                      decoration: BoxDecoration(
                        border: Border(
                          right: BorderSide(
                            color: AppColors.fieldBorder,
                          ),
                        ),
                      ),
                      child: Text(
                        '+93',
                        style: TextStyle(
                          fontSize: 16,
                          fontWeight: FontWeight.w800,
                          color: AppColors.textPrimary,
                        ),
                      ),
                    ),
                    Expanded(
                      child: TextFormField(
                        controller: phoneController,
                        autofocus: false,
                        maxLength: 10,
                        textInputAction: TextInputAction.done,
                        keyboardType: TextInputType.phone,
                        autocorrect: false,
                        enableSuggestions: false,
                        inputFormatters: <TextInputFormatter>[
                          _AsciiDigitsFormatter(),
                        ],
                        cursorColor: AppColors.primaryBrand,
                        textAlign: TextAlign.left,
                        style: TextStyle(
                          fontSize: 17,
                          fontWeight: FontWeight.w800,
                          letterSpacing: 1.5,
                          color: AppColors.textPrimary,
                        ),
                        onFieldSubmitted: (_) {
                          if (canSubmit) {
                            sendPhoneNumber();
                          }
                        },
                        decoration: InputDecoration(
                          counterText: '',
                          hintText: '0781234567',
                          hintStyle: TextStyle(
                            color: AppColors.textSecondary
                                .withOpacity(0.55),
                            fontSize: 16,
                            letterSpacing: 1.5,
                            fontWeight: FontWeight.w500,
                          ),
                          border: InputBorder.none,
                          enabledBorder: InputBorder.none,
                          focusedBorder: InputBorder.none,
                          disabledBorder: InputBorder.none,
                          errorBorder: InputBorder.none,
                          focusedErrorBorder: InputBorder.none,
                          filled: true,
                          fillColor: AppColors.cardBackground,
                          contentPadding:
                              const EdgeInsets.symmetric(
                            horizontal: 14,
                            vertical: 16,
                          ),
                        ),
                      ),
                    ),
                    if (isValidPhone)
                      Padding(
                        padding: const EdgeInsets.only(
                          right: 14,
                        ),
                        child: Icon(
                          Icons.check_circle_rounded,
                          color: AppColors.success,
                          size: 22,
                        ),
                      ),
                  ],
                ),
              ),
            ),
            AnimatedSize(
              duration: const Duration(milliseconds: 180),
              alignment: Alignment.topCenter,
              child: showPhoneError
                  ? Padding(
                      padding: const EdgeInsets.only(
                        top: 8,
                        left: 4,
                        right: 4,
                      ),
                      child: Row(
                        children: <Widget>[
                          Icon(
                            Icons.error_outline_rounded,
                            size: 16,
                            color: AppColors.danger,
                          ),
                          const SizedBox(width: 6),
                          Expanded(
                            child: Text(
                              _t(
                                'invalid_phone_error',
                                'شماره باید با 07 شروع شود و ۱۰ رقم باشد',
                              ),
                              style: TextStyle(
                                fontSize: 12.5,
                                fontWeight: FontWeight.w600,
                                color: AppColors.danger,
                              ),
                            ),
                          ),
                        ],
                      ),
                    )
                  : const SizedBox(
                      width: double.infinity,
                      height: 0,
                    ),
            ),
            const SizedBox(height: 20),
            SizedBox(
              width: double.infinity,
              height: 54,
              child: ElevatedButton(
                onPressed: canSubmit ? sendPhoneNumber : null,
                style: ElevatedButton.styleFrom(
                  backgroundColor: AppColors.primaryButton,
                  disabledBackgroundColor:
                      AppColors.fieldBorder,
                  foregroundColor: AppColors.buttonText,
                  disabledForegroundColor:
                      AppColors.textSecondary,
                  elevation: 0,
                  shape: RoundedRectangleBorder(
                    borderRadius: BorderRadius.circular(16),
                  ),
                ),
                child: isLoading
                    ? SizedBox(
                        width: 22,
                        height: 22,
                        child: CircularProgressIndicator(
                          strokeWidth: 2.5,
                          color: AppColors.buttonText,
                        ),
                      )
                    : Text(
                        _t(
                          'btn_continue',
                          'دریافت کد تأیید',
                        ),
                        style: TextStyle(
                          color: isValidPhone
                              ? AppColors.buttonText
                              : AppColors.textSecondary,
                          fontSize: 15.5,
                          fontWeight: FontWeight.w800,
                        ),
                      ),
              ),
            ),
          ],
        );
      },
    );
  }

  Widget _buildSectionHeader(String title) {
    return Padding(
      padding: const EdgeInsets.symmetric(
        horizontal: 6,
        vertical: 8,
      ),
      child: Text(
        title,
        style: TextStyle(
          fontSize: 13,
          fontWeight: FontWeight.w800,
          color: AppColors.textPrimary,
          letterSpacing: 0.2,
        ),
      ),
    );
  }

  Widget _buildOrDivider() {
    return Row(
      children: <Widget>[
        Expanded(
          child: Divider(
            color: AppColors.fieldBorder,
            thickness: 1,
          ),
        ),
        Padding(
          padding: const EdgeInsets.symmetric(
            horizontal: 14,
          ),
          child: Text(
            _t(
              'or_label',
              'یا ادامه با',
            ),
            style: TextStyle(
              color: AppColors.textSecondary,
              fontSize: 12.5,
              fontWeight: FontWeight.w500,
            ),
          ),
        ),
        Expanded(
          child: Divider(
            color: AppColors.fieldBorder,
            thickness: 1,
          ),
        ),
      ],
    );
  }

  Widget _buildGoogleButton({
    required bool isLoading,
    required bool isGoogleLoading,
  }) {
    return SizedBox(
      width: double.infinity,
      height: 54,
      child: OutlinedButton(
        onPressed: isGoogleLoading || isLoading
            ? null
            : () {
                HapticFeedback.selectionClick();
                _handleGoogleSignIn();
              },
        style: OutlinedButton.styleFrom(
          backgroundColor: AppColors.cardBackground,
          foregroundColor: AppColors.textPrimary,
          side: BorderSide(
            color: AppColors.fieldBorder,
            width: 1.3,
          ),
          shape: RoundedRectangleBorder(
            borderRadius: BorderRadius.circular(16),
          ),
        ),
        child: isGoogleLoading
            ? SizedBox(
                width: 22,
                height: 22,
                child: CircularProgressIndicator(
                  color: AppColors.primaryBrand,
                  strokeWidth: 2,
                ),
              )
            : Row(
                mainAxisAlignment: MainAxisAlignment.center,
                children: <Widget>[
                  const _GoogleGMark(),
                  const SizedBox(width: 10),
                  Text(
                    _t(
                      'google_sign_in',
                      'ورود با گوگل',
                    ),
                    style: TextStyle(
                      color: AppColors.textPrimary,
                      fontSize: 14.5,
                      fontWeight: FontWeight.w700,
                    ),
                  ),
                ],
              ),
      ),
    );
  }
}

class _GoogleGMark extends StatelessWidget {
  const _GoogleGMark();

  @override
  Widget build(BuildContext context) {
    return ShaderMask(
      blendMode: BlendMode.srcIn,
      shaderCallback: (Rect bounds) {
        return const SweepGradient(
          colors: <Color>[
            Color(0xFFEA4335),
            Color(0xFFFBBC05),
            Color(0xFF34A853),
            Color(0xFF4285F4),
            Color(0xFFEA4335),
          ],
          stops: <double>[
            0.0,
            0.25,
            0.5,
            0.75,
            1.0,
          ],
        ).createShader(bounds);
      },
      child: const Text(
        'G',
        style: TextStyle(
          fontSize: 24,
          fontWeight: FontWeight.w900,
          height: 1.0,
          color: Colors.white,
        ),
      ),
    );
  }
}
