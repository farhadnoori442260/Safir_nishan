import 'package:easy_localization/easy_localization.dart' hide TextDirection;
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:provider/provider.dart';

import '../../methods/common_method.dart';
import '../../pages/dashboard.dart';
import '../../pages/driverRegistration/driver_registration.dart';
import '../../providers/auth_provider.dart';
import '../../utils/app_colors.dart';
import '../../widgets/blocked_screen.dart';

class RegisterScreen extends StatefulWidget {
  const RegisterScreen({super.key});

  @override
  State<RegisterScreen> createState() => _RegisterScreenState();
}

class _RegisterScreenState extends State<RegisterScreen> {
  final TextEditingController phoneController = TextEditingController();
  final CommonMethods commonMethods = CommonMethods();

  @override
  void dispose() {
    phoneController.dispose();
    super.dispose();
  }

  void _showLanguageSelector() {
    showModalBottomSheet(
      context: context,
      backgroundColor: Colors.transparent,
      builder: (sheetContext) {
        return SafeArea(
          top: false,
          child: Container(
            decoration: const BoxDecoration(
              color: AppColors.cardBackground,
              borderRadius: BorderRadius.vertical(
                top: Radius.circular(28),
              ),
            ),
            padding: const EdgeInsets.fromLTRB(20, 12, 20, 24),
            child: Column(
              mainAxisSize: MainAxisSize.min,
              children: [
                Container(
                  width: 42,
                  height: 4,
                  decoration: BoxDecoration(
                    color: Colors.grey.shade300,
                    borderRadius: BorderRadius.circular(20),
                  ),
                ),
                const SizedBox(height: 20),
                Text(
                  'select_language'.tr(),
                  style: const TextStyle(
                    color: AppColors.textPrimary,
                    fontSize: 18,
                    fontWeight: FontWeight.bold,
                  ),
                ),
                const SizedBox(height: 12),
                _buildLanguageTile(
                  title: 'فارسی (دری)',
                  flag: '🇦🇫',
                  locale: const Locale('fa'),
                  sheetContext: sheetContext,
                ),
                _buildLanguageTile(
                  title: 'پښتو',
                  flag: '🇦🇫',
                  locale: const Locale('ps'),
                  sheetContext: sheetContext,
                ),
                _buildLanguageTile(
                  title: 'English',
                  flag: '🇬🇧',
                  locale: const Locale('en'),
                  sheetContext: sheetContext,
                ),
              ],
            ),
          ),
        );
      },
    );
  }

  Widget _buildLanguageTile({
    required String title,
    required String flag,
    required Locale locale,
    required BuildContext sheetContext,
  }) {
    final bool isSelected = context.locale.languageCode == locale.languageCode;

    return Container(
      margin: const EdgeInsets.only(top: 10),
      decoration: BoxDecoration(
        color: isSelected
            ? AppColors.primaryBrand.withOpacity(0.08)
            : Colors.grey.shade50,
        borderRadius: BorderRadius.circular(16),
        border: Border.all(
          color: isSelected
              ? AppColors.primaryBrand
              : Colors.grey.shade200,
        ),
      ),
      child: ListTile(
        onTap: () async {
          await context.setLocale(locale);

          if (!mounted) return;
          Navigator.pop(sheetContext);
        },
        leading: Text(
          flag,
          style: const TextStyle(fontSize: 24),
        ),
        title: Text(
          title,
          style: TextStyle(
            fontWeight: isSelected ? FontWeight.bold : FontWeight.w500,
            color: AppColors.textPrimary,
          ),
        ),
        trailing: isSelected
            ? const Icon(
                Icons.check_circle_rounded,
                color: AppColors.primaryBrand,
              )
            : const Icon(
                Icons.radio_button_unchecked_rounded,
                color: AppColors.textSecondary,
              ),
      ),
    );
  }

  Future<void> _handleGoogleSignIn() async {
    final authProvider = context.read<AuthenticationProvider>();

    await authProvider.signInWithGoogle(
      context,
      () async {
        if (!mounted) return;

        final user = authProvider.firebaseAuth.currentUser;

        if (user == null) return;

        try {
          final bool userExists = await authProvider.checkUserExistById();

          if (!mounted) return;

          if (!userExists) {
            navigate(isSignedIn: false);
            return;
          }

          final bool isBlocked = await authProvider.checkIfDriverIsBlocked();

          if (!mounted) return;

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

          if (!mounted) return;

          final bool isDriverComplete =
              await authProvider.checkDriverFieldsFilled();

          if (!mounted) return;

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
          if (!mounted) return;

          commonMethods.displaySnackBar(
            'error_occurred'.tr(),
            context,
          );
        }
      },
    );
  }

  /// فقط ارقام انگلیسی شمارهٔ ملی (۹ رقم، بدون صفر ابتدایی) را برمی‌گرداند.
  String _phoneDigits() => _normalizeDigits(phoneController.text)
      .replaceAll(RegExp(r'\D'), '');

  bool _isValidAfghanMobile(String digits) =>
      RegExp(r'^7[0-9]{8}$').hasMatch(digits);

  void sendPhoneNumber() {
    final String digits = _phoneDigits();

    if (!_isValidAfghanMobile(digits)) {
      commonMethods.displaySnackBar(
        'invalid_phone_error'.tr(),
        context,
      );
      return;
    }

    FocusScope.of(context).unfocus();

    final authProvider = context.read<AuthenticationProvider>();

    // پیش‌شماره ثابت افغانستان (+93)
    authProvider.signInWithPhone(
      context: context,
      phoneNumber: '+93$digits',
    );
  }

  void navigate({required bool isSignedIn}) {
    if (!mounted) return;

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
    // فقط به فیلدهای لازم گوش می‌دهیم تا با هر تغییر provider کل صفحه
    // دوباره ساخته نشود.
    final bool isLoading = context.select<AuthenticationProvider, bool>(
      (AuthenticationProvider p) => p.isLoading,
    );
    final bool isGoogleLoading = context.select<AuthenticationProvider, bool>(
      (AuthenticationProvider p) => p.isGoogleSigInLoading,
    );

    // کیبورد توسط خود Scaffold مدیریت می‌شود: بدنه کوچک می‌شود و چون
    // محتوا داخل اسکرول است، فیلد شماره همیشه بالای کیبورد دیده می‌شود.
    return Scaffold(
      backgroundColor: const Color(0xFFF7FAF8),
      body: Stack(
        fit: StackFit.expand,
        children: [
          Positioned(
            top: -90,
            right: -75,
            child: IgnorePointer(
              child: Container(
                width: 230,
                height: 230,
                decoration: BoxDecoration(
                  shape: BoxShape.circle,
                  color: AppColors.primaryBrand.withOpacity(0.10),
                ),
              ),
            ),
          ),
          Positioned(
            top: 120,
            left: -120,
            child: IgnorePointer(
              child: Container(
                width: 220,
                height: 220,
                decoration: BoxDecoration(
                  shape: BoxShape.circle,
                  color: AppColors.primaryBrand.withOpacity(0.05),
                ),
              ),
            ),
          ),
          SafeArea(
            child: CustomScrollView(
              keyboardDismissBehavior:
                  ScrollViewKeyboardDismissBehavior.onDrag,
              slivers: [
                SliverPadding(
                  padding: const EdgeInsets.fromLTRB(20, 16, 20, 24),
                  sliver: SliverFillRemaining(
                    hasScrollBody: false,
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        _buildLanguageButton(),
                        const SizedBox(height: 20),
                        _buildLogo(),
                        const SizedBox(height: 26),
                        Text(
                          'register_title'.tr(),
                          style: const TextStyle(
                            color: AppColors.textPrimary,
                            fontSize: 25,
                            fontWeight: FontWeight.w800,
                            height: 1.25,
                          ),
                        ),
                        const SizedBox(height: 9),
                        Text(
                          'register_subtitle'.tr(),
                          style: const TextStyle(
                            color: AppColors.textSecondary,
                            fontSize: 14,
                            height: 1.6,
                          ),
                        ),
                        const SizedBox(height: 28),
                        _buildPhoneCard(isLoading),
                        const SizedBox(height: 24),
                        _buildOrDivider(),
                        const SizedBox(height: 20),
                        _buildGoogleButton(isLoading, isGoogleLoading),
                        const Spacer(),
                        Padding(
                          padding: const EdgeInsets.only(top: 28),
                          child: Center(
                            child: Text(
                              'terms_and_conditions'.tr(),
                              textAlign: TextAlign.center,
                              style: const TextStyle(
                                color: AppColors.textSecondary,
                                fontSize: 12,
                                height: 1.6,
                              ),
                            ),
                          ),
                        ),
                      ],
                    ),
                  ),
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildLanguageButton() {
    return Align(
      alignment: AlignmentDirectional.topEnd,
      child: InkWell(
        onTap: _showLanguageSelector,
        borderRadius: BorderRadius.circular(24),
        child: Container(
          padding: const EdgeInsets.symmetric(horizontal: 13, vertical: 8),
          decoration: BoxDecoration(
            color: Colors.white.withOpacity(0.9),
            borderRadius: BorderRadius.circular(24),
            border: Border.all(
              color: AppColors.primaryBrand.withOpacity(0.25),
            ),
          ),
          child: Row(
            mainAxisSize: MainAxisSize.min,
            children: [
              const Icon(
                Icons.language_rounded,
                color: AppColors.primaryBrand,
                size: 19,
              ),
              const SizedBox(width: 7),
              Text(
                'language_button'.tr(),
                style: const TextStyle(
                  color: AppColors.primaryBrand,
                  fontSize: 13,
                  fontWeight: FontWeight.bold,
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }

  Widget _buildLogo() {
    return Center(
      child: Container(
        width: 86,
        height: 86,
        decoration: BoxDecoration(
          color: AppColors.primaryBrand,
          borderRadius: BorderRadius.circular(28),
          boxShadow: [
            BoxShadow(
              color: AppColors.primaryBrand.withOpacity(0.24),
              blurRadius: 20,
              offset: const Offset(0, 9),
            ),
          ],
        ),
        child: const Icon(
          Icons.local_taxi_rounded,
          color: Colors.white,
          size: 46,
        ),
      ),
    );
  }

  Widget _buildPhoneCard(bool isLoading) {
    return Container(
      padding: const EdgeInsets.all(18),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(22),
        border: Border.all(color: Colors.grey.shade100),
        boxShadow: [
          BoxShadow(
            color: Colors.black.withOpacity(0.045),
            blurRadius: 18,
            offset: const Offset(0, 7),
          ),
        ],
      ),
      // با هر تغییر متن فقط همین بخش دوباره ساخته می‌شود، نه کل صفحه.
      child: ValueListenableBuilder<TextEditingValue>(
        valueListenable: phoneController,
        builder: (BuildContext context, TextEditingValue value, _) {
          final String digits = _normalizeDigits(value.text)
              .replaceAll(RegExp(r'\D'), '');
          final bool isValid = _isValidAfghanMobile(digits);
          final bool badStart = digits.isNotEmpty && !digits.startsWith('7');

          return Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text(
                'mobile_number'.tr(),
                style: const TextStyle(
                  color: AppColors.textPrimary,
                  fontSize: 13,
                  fontWeight: FontWeight.w700,
                ),
              ),
              const SizedBox(height: 10),
              Directionality(
                textDirection: TextDirection.ltr,
                child: TextFormField(
                  controller: phoneController,
                  autofocus: true,
                  textAlign: TextAlign.left,
                  textInputAction: TextInputAction.done,
                  keyboardType: TextInputType.number,
                  autocorrect: false,
                  enableSuggestions: false,
                  cursorColor: AppColors.primaryBrand,
                  // فاصلهٔ کافی تا فیلد و دکمه بالای کیبورد دیده شوند.
                  scrollPadding: const EdgeInsets.only(bottom: 160),
                  inputFormatters: [_AfghanPhoneFormatter()],
                  onFieldSubmitted: (_) {
                    if (!isLoading && isValid) {
                      sendPhoneNumber();
                    }
                  },
                  style: const TextStyle(
                    fontSize: 20,
                    letterSpacing: 1.4,
                    fontWeight: FontWeight.w700,
                    color: AppColors.textPrimary,
                  ),
                  decoration: InputDecoration(
                    hintText: '7X XXX XXXX',
                    hintStyle: TextStyle(
                      color: AppColors.textSecondary.withOpacity(0.55),
                      fontSize: 18,
                      letterSpacing: 1.2,
                      fontWeight: FontWeight.w500,
                    ),
                    filled: true,
                    fillColor: const Color(0xFFF9FBFA),
                    contentPadding: const EdgeInsets.symmetric(
                      horizontal: 14,
                      vertical: 17,
                    ),
                    // پیش‌شماره ثابت +93؛ بدون پرچم و بدون انتخاب کشور
                    prefixIconConstraints: const BoxConstraints(
                      minWidth: 0,
                      minHeight: 0,
                    ),
                    prefixIcon: Padding(
                      padding: const EdgeInsets.only(left: 14, right: 12),
                      child: Row(
                        mainAxisSize: MainAxisSize.min,
                        children: [
                          const Text(
                            '+93',
                            style: TextStyle(
                              color: AppColors.textPrimary,
                              fontSize: 18,
                              fontWeight: FontWeight.w800,
                            ),
                          ),
                          const SizedBox(width: 12),
                          Container(
                            width: 1.2,
                            height: 24,
                            color: Colors.grey.shade300,
                          ),
                        ],
                      ),
                    ),
                    suffixIcon: isValid
                        ? Container(
                            width: 24,
                            height: 24,
                            margin: const EdgeInsets.all(13),
                            decoration: const BoxDecoration(
                              shape: BoxShape.circle,
                              color: AppColors.primaryBrand,
                            ),
                            child: const Icon(
                              Icons.check_rounded,
                              color: Colors.white,
                              size: 16,
                            ),
                          )
                        : null,
                    enabledBorder: OutlineInputBorder(
                      borderRadius: BorderRadius.circular(15),
                      borderSide: BorderSide(
                        color: badStart
                            ? Colors.red.shade300
                            : Colors.grey.shade200,
                      ),
                    ),
                    focusedBorder: OutlineInputBorder(
                      borderRadius: BorderRadius.circular(15),
                      borderSide: BorderSide(
                        color: badStart
                            ? Colors.red.shade400
                            : AppColors.primaryBrand,
                        width: 1.8,
                      ),
                    ),
                  ),
                ),
              ),
              AnimatedSize(
                duration: const Duration(milliseconds: 150),
                alignment: Alignment.topCenter,
                child: badStart
                    ? Padding(
                        padding: const EdgeInsets.only(top: 8),
                        child: Text(
                          'invalid_phone_error'.tr(),
                          style: TextStyle(
                            color: Colors.red.shade600,
                            fontSize: 12,
                          ),
                        ),
                      )
                    : const SizedBox(width: double.infinity),
              ),
              const SizedBox(height: 18),
              SizedBox(
                width: double.infinity,
                height: 53,
                child: ElevatedButton(
                  onPressed: isLoading || !isValid ? null : sendPhoneNumber,
                  style: ElevatedButton.styleFrom(
                    backgroundColor: AppColors.primaryButton,
                    foregroundColor: AppColors.buttonText,
                    disabledBackgroundColor:
                        AppColors.primaryButton.withOpacity(0.45),
                    disabledForegroundColor:
                        AppColors.buttonText.withOpacity(0.85),
                    elevation: 0,
                    shape: RoundedRectangleBorder(
                      borderRadius: BorderRadius.circular(15),
                    ),
                  ),
                  child: isLoading
                      ? const SizedBox(
                          width: 22,
                          height: 22,
                          child: CircularProgressIndicator(
                            strokeWidth: 2.4,
                            color: AppColors.buttonText,
                          ),
                        )
                      : Row(
                          mainAxisAlignment: MainAxisAlignment.center,
                          children: [
                            Text(
                              'btn_continue'.tr(),
                              style: const TextStyle(
                                fontSize: 16,
                                fontWeight: FontWeight.bold,
                              ),
                            ),
                            const SizedBox(width: 8),
                            const Icon(Icons.arrow_forward_rounded, size: 19),
                          ],
                        ),
                ),
              ),
            ],
          );
        },
      ),
    );
  }

  Widget _buildOrDivider() {
    return Row(
      children: [
        Expanded(
          child: Divider(color: Colors.grey.shade300, height: 1),
        ),
        Padding(
          padding: const EdgeInsets.symmetric(horizontal: 13),
          child: Text(
            'or_label'.tr(),
            style: const TextStyle(
              color: AppColors.textSecondary,
              fontSize: 13,
            ),
          ),
        ),
        Expanded(
          child: Divider(color: Colors.grey.shade300, height: 1),
        ),
      ],
    );
  }

  Widget _buildGoogleButton(bool isLoading, bool isGoogleLoading) {
    return SizedBox(
      width: double.infinity,
      height: 53,
      child: OutlinedButton(
        onPressed:
            isGoogleLoading || isLoading ? null : _handleGoogleSignIn,
        style: OutlinedButton.styleFrom(
          backgroundColor: Colors.white,
          foregroundColor: AppColors.textPrimary,
          side: BorderSide(color: Colors.grey.shade300),
          shape: RoundedRectangleBorder(
            borderRadius: BorderRadius.circular(15),
          ),
        ),
        child: isGoogleLoading
            ? const SizedBox(
                width: 22,
                height: 22,
                child: CircularProgressIndicator(
                  strokeWidth: 2.3,
                  color: AppColors.primaryBrand,
                ),
              )
            : Row(
                mainAxisAlignment: MainAxisAlignment.center,
                children: [
                  Image.asset(
                    'assets/images/google_logo.png',
                    height: 21,
                    errorBuilder: (_, __, ___) => const Icon(
                      Icons.g_mobiledata_rounded,
                      size: 27,
                      color: Colors.red,
                    ),
                  ),
                  const SizedBox(width: 11),
                  Text(
                    'google_sign_in'.tr(),
                    style: const TextStyle(
                      fontSize: 15,
                      fontWeight: FontWeight.w600,
                    ),
                  ),
                ],
              ),
      ),
    );
  }
}

/// ارقام فارسی و عربی را به انگلیسی تبدیل می‌کند.
String _normalizeDigits(String input) {
  final StringBuffer buffer = StringBuffer();

  for (final int rune in input.runes) {
    if (rune >= 0x06F0 && rune <= 0x06F9) {
      buffer.writeCharCode(0x30 + (rune - 0x06F0)); // ۰-۹
    } else if (rune >= 0x0660 && rune <= 0x0669) {
      buffer.writeCharCode(0x30 + (rune - 0x0660)); // ٠-٩
    } else {
      buffer.writeCharCode(rune);
    }
  }

  return buffer.toString();
}

/// شمارهٔ موبایل افغانستان را به شکل `7X XXX XXXX` (۹ رقم) نگه می‌دارد.
/// - ارقام فارسی/عربی به انگلیسی تبدیل می‌شوند.
/// - صفر ابتدایی، `+93` و `0093` (مثلاً هنگام paste) حذف می‌شوند.
class _AfghanPhoneFormatter extends TextInputFormatter {
  @override
  TextEditingValue formatEditUpdate(
    TextEditingValue oldValue,
    TextEditingValue newValue,
  ) {
    String digits =
        _normalizeDigits(newValue.text).replaceAll(RegExp(r'\D'), '');

    if (digits.startsWith('0093')) {
      digits = digits.substring(4);
    } else if (digits.startsWith('93') && digits.length > 9) {
      digits = digits.substring(2);
    }

    if (digits.startsWith('0')) {
      digits = digits.substring(1);
    }

    if (digits.length > 9) {
      digits = digits.substring(0, 9);
    }

    final StringBuffer buffer = StringBuffer();

    for (int i = 0; i < digits.length; i++) {
      if (i == 2 || i == 5) {
        buffer.write(' ');
      }
      buffer.write(digits[i]);
    }

    final String text = buffer.toString();

    return TextEditingValue(
      text: text,
      selection: TextSelection.collapsed(offset: text.length),
    );
  }
}
