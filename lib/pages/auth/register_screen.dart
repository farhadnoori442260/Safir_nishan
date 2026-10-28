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
      builder: (BuildContext sheetContext) {
        return SafeArea(
          top: false,
          child: Container(
            decoration: const BoxDecoration(
              color: AppColors.cardBackground,
              borderRadius: BorderRadius.vertical(
                top: Radius.circular(24),
              ),
            ),
            padding: const EdgeInsets.fromLTRB(18, 10, 18, 20),
            child: Column(
              mainAxisSize: MainAxisSize.min,
              children: <Widget>[
                Container(
                  width: 38,
                  height: 4,
                  decoration: BoxDecoration(
                    color: Colors.grey.shade300,
                    borderRadius: BorderRadius.circular(20),
                  ),
                ),
                const SizedBox(height: 16),
                Text(
                  'select_language'.tr(),
                  style: const TextStyle(
                    color: AppColors.textPrimary,
                    fontSize: 17,
                    fontWeight: FontWeight.bold,
                  ),
                ),
                const SizedBox(height: 8),
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
    final bool isSelected =
        context.locale.languageCode == locale.languageCode;

    return Container(
      margin: const EdgeInsets.only(top: 8),
      decoration: BoxDecoration(
        color: isSelected
            ? AppColors.primaryBrand.withOpacity(0.08)
            : Colors.grey.shade50,
        borderRadius: BorderRadius.circular(14),
        border: Border.all(
          color: isSelected
              ? AppColors.primaryBrand
              : Colors.grey.shade200,
        ),
      ),
      child: ListTile(
        dense: true,
        visualDensity: const VisualDensity(vertical: -1),
        onTap: () async {
          await context.setLocale(locale);

          if (!mounted) {
            return;
          }

          Navigator.pop(sheetContext);
        },
        leading: Text(
          flag,
          style: const TextStyle(fontSize: 22),
        ),
        title: Text(
          title,
          style: TextStyle(
            fontSize: 14,
            fontWeight: isSelected ? FontWeight.bold : FontWeight.w500,
            color: AppColors.textPrimary,
          ),
        ),
        trailing: isSelected
            ? const Icon(
                Icons.check_circle_rounded,
                color: AppColors.primaryBrand,
                size: 21,
              )
            : const Icon(
                Icons.radio_button_unchecked_rounded,
                color: AppColors.textSecondary,
                size: 21,
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

  String _phoneDigits() {
    return _normalizeDigits(phoneController.text)
        .replaceAll(RegExp(r'D'), '');
  }

  bool _isValidAfghanMobile(String digits) {
    return RegExp(r'^7[0-9]{8}$').hasMatch(digits);
  }

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
    final bool isLoading = context.select<
        AuthenticationProvider,
        bool>(
      (AuthenticationProvider provider) => provider.isLoading,
    );

    final bool isGoogleLoading = context.select<
        AuthenticationProvider,
        bool>(
      (AuthenticationProvider provider) =>
          provider.isGoogleSigInLoading,
    );

    return Scaffold(
      resizeToAvoidBottomInset: true,
      backgroundColor: AppColors.background,
      body: SafeArea(
        child: LayoutBuilder(
          builder: (
            BuildContext context,
            BoxConstraints constraints,
          ) {
            final double screenHeight = constraints.maxHeight;
            final bool isSmallScreen = screenHeight < 650;

            return Stack(
              fit: StackFit.expand,
              children: <Widget>[
                Positioned(
                  top: -85,
                  right: -75,
                  child: IgnorePointer(
                    child: Container(
                      width: 210,
                      height: 210,
                      decoration: BoxDecoration(
                        shape: BoxShape.circle,
                        color: AppColors.primaryBrand.withOpacity(0.08),
                      ),
                    ),
                  ),
                ),
                Positioned(
                  top: 105,
                  left: -115,
                  child: IgnorePointer(
                    child: Container(
                      width: 190,
                      height: 190,
                      decoration: BoxDecoration(
                        shape: BoxShape.circle,
                        color: AppColors.primaryBrand.withOpacity(0.04),
                      ),
                    ),
                  ),
                ),
                SingleChildScrollView(
                  keyboardDismissBehavior:
                      ScrollViewKeyboardDismissBehavior.onDrag,
                  padding: EdgeInsets.fromLTRB(
                    20,
                    isSmallScreen ? 10 : 16,
                    20,
                    18,
                  ),
                  child: ConstrainedBox(
                    constraints: BoxConstraints(
                      minHeight: constraints.maxHeight -
                          (isSmallScreen ? 28 : 34),
                    ),
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: <Widget>[
                        _buildLanguageButton(),
                        SizedBox(height: isSmallScreen ? 12 : 18),
                        _buildLogo(
                          isSmallScreen: isSmallScreen,
                        ),
                        SizedBox(height: isSmallScreen ? 16 : 22),
                        Text(
                          'register_title'.tr(),
                          style: TextStyle(
                            color: AppColors.textPrimary,
                            fontSize: isSmallScreen ? 22 : 24,
                            fontWeight: FontWeight.w800,
                            height: 1.2,
                          ),
                        ),
                        const SizedBox(height: 7),
                        Text(
                          'register_subtitle'.tr(),
                          style: TextStyle(
                            color: AppColors.textSecondary,
                            fontSize: isSmallScreen ? 13 : 14,
                            height: 1.45,
                          ),
                        ),
                        SizedBox(height: isSmallScreen ? 18 : 23),
                        _buildPhoneCard(isLoading),
                        SizedBox(height: isSmallScreen ? 16 : 20),
                        _buildOrDivider(),
                        SizedBox(height: isSmallScreen ? 14 : 17),
                        _buildGoogleButton(
                          isLoading,
                          isGoogleLoading,
                        ),
                        SizedBox(height: isSmallScreen ? 18 : 24),
                        Center(
                          child: Text(
                            'terms_and_conditions'.tr(),
                            textAlign: TextAlign.center,
                            style: TextStyle(
                              color: AppColors.textSecondary,
                              fontSize: isSmallScreen ? 11 : 12,
                              height: 1.45,
                            ),
                          ),
                        ),
                      ],
                    ),
                  ),
                ),
              ],
            );
          },
        ),
      ),
    );
  }

  Widget _buildLanguageButton() {
    return Align(
      alignment: AlignmentDirectional.topEnd,
      child: InkWell(
        onTap: _showLanguageSelector,
        borderRadius: BorderRadius.circular(22),
        child: Container(
          padding: const EdgeInsets.symmetric(
            horizontal: 11,
            vertical: 7,
          ),
          decoration: BoxDecoration(
            color: Colors.white.withOpacity(0.9),
            borderRadius: BorderRadius.circular(22),
            border: Border.all(
              color: AppColors.primaryBrand.withOpacity(0.22),
            ),
          ),
          child: Row(
            mainAxisSize: MainAxisSize.min,
            children: <Widget>[
              const Icon(
                Icons.language_rounded,
                color: AppColors.primaryBrand,
                size: 17,
              ),
              const SizedBox(width: 6),
              Text(
                'language_button'.tr(),
                style: const TextStyle(
                  color: AppColors.primaryBrand,
                  fontSize: 12,
                  fontWeight: FontWeight.bold,
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }

  Widget _buildLogo({
    required bool isSmallScreen,
  }) {
    final double logoSize = isSmallScreen ? 66 : 72;
    final double iconSize = isSmallScreen ? 34 : 38;

    return Center(
      child: Container(
        width: logoSize,
        height: logoSize,
        decoration: BoxDecoration(
          color: AppColors.primaryBrand,
          borderRadius: BorderRadius.circular(21),
          boxShadow: <BoxShadow>[
            BoxShadow(
              color: AppColors.primaryBrand.withOpacity(0.20),
              blurRadius: 15,
              offset: const Offset(0, 6),
            ),
          ],
        ),
        child: Icon(
          Icons.local_taxi_rounded,
          color: Colors.white,
          size: iconSize,
        ),
      ),
    );
  }

  Widget _buildPhoneCard(bool isLoading) {
    return Container(
      padding: const EdgeInsets.all(15),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(18),
        border: Border.all(
          color: Colors.grey.shade100,
        ),
        boxShadow: <BoxShadow>[
          BoxShadow(
            color: Colors.black.withOpacity(0.035),
            blurRadius: 13,
            offset: const Offset(0, 5),
          ),
        ],
      ),
      child: ValueListenableBuilder<TextEditingValue>(
        valueListenable: phoneController,
        builder: (
          BuildContext context,
          TextEditingValue value,
          Widget? child,
        ) {
          final String digits = _normalizeDigits(value.text)
              .replaceAll(RegExp(r'D'), '');

          final bool isValid = _isValidAfghanMobile(digits);
          final bool badStart =
              digits.isNotEmpty && !digits.startsWith('7');

          return Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: <Widget>[
              Text(
                'mobile_number'.tr(),
                style: const TextStyle(
                  color: AppColors.textPrimary,
                  fontSize: 12.5,
                  fontWeight: FontWeight.w700,
                ),
              ),
              const SizedBox(height: 8),
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
                  scrollPadding: const EdgeInsets.only(
                    bottom: 120,
                  ),
                  inputFormatters: <TextInputFormatter>[
                    _AfghanPhoneFormatter(),
                  ],
                  onFieldSubmitted: (_) {
                    if (!isLoading && isValid) {
                      sendPhoneNumber();
                    }
                  },
                  style: const TextStyle(
                    fontSize: 18,
                    letterSpacing: 1.1,
                    fontWeight: FontWeight.w700,
                    color: AppColors.textPrimary,
                  ),
                  decoration: InputDecoration(
                    hintText: '7X XXX XXXX',
                    hintStyle: TextStyle(
                      color: AppColors.textSecondary.withOpacity(0.50),
                      fontSize: 16,
                      letterSpacing: 1,
                      fontWeight: FontWeight.w500,
                    ),
                    filled: true,
                    fillColor: AppColors.background,
                    contentPadding: const EdgeInsets.symmetric(
                      horizontal: 12,
                      vertical: 14,
                    ),
                    prefixIconConstraints: const BoxConstraints(
                      minWidth: 0,
                      minHeight: 0,
                    ),
                    prefixIcon: Padding(
                      padding: const EdgeInsets.only(
                        left: 12,
                        right: 10,
                      ),
                      child: Row(
                        mainAxisSize: MainAxisSize.min,
                        children: <Widget>[
                          const Text(
                            '+93',
                            style: TextStyle(
                              color: AppColors.textPrimary,
                              fontSize: 16,
                              fontWeight: FontWeight.w800,
                            ),
                          ),
                          const SizedBox(width: 10),
                          Container(
                            width: 1,
                            height: 21,
                            color: Colors.grey.shade300,
                          ),
                        ],
                      ),
                    ),
                    suffixIcon: isValid
                        ? Container(
                            width: 22,
                            height: 22,
                            margin: const EdgeInsets.all(11),
                            decoration: const BoxDecoration(
                              shape: BoxShape.circle,
                              color: AppColors.primaryBrand,
                            ),
                            child: const Icon(
                              Icons.check_rounded,
                              color: Colors.white,
                              size: 15,
                            ),
                          )
                        : null,
                    enabledBorder: OutlineInputBorder(
                      borderRadius: BorderRadius.circular(13),
                      borderSide: BorderSide(
                        color: badStart
                            ? Colors.red.shade300
                            : Colors.grey.shade200,
                      ),
                    ),
                    focusedBorder: OutlineInputBorder(
                      borderRadius: BorderRadius.circular(13),
                      borderSide: BorderSide(
                        color: badStart
                            ? Colors.red.shade400
                            : AppColors.primaryBrand,
                        width: 1.6,
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
                        padding: const EdgeInsets.only(top: 6),
                        child: Text(
                          'invalid_phone_error'.tr(),
                          style: TextStyle(
                            color: Colors.red.shade600,
                            fontSize: 11,
                          ),
                        ),
                      )
                    : const SizedBox(
                        width: double.infinity,
                        height: 0,
                      ),
              ),
              const SizedBox(height: 14),
              SizedBox(
                width: double.infinity,
                height: 48,
                child: ElevatedButton(
                  onPressed:
                      isLoading || !isValid ? null : sendPhoneNumber,
                  style: ElevatedButton.styleFrom(
                    backgroundColor: AppColors.primaryButton,
                    foregroundColor: AppColors.buttonText,
                    disabledBackgroundColor:
                        AppColors.primaryButton.withOpacity(0.42),
                    disabledForegroundColor:
                        AppColors.buttonText.withOpacity(0.82),
                    elevation: 0,
                    shape: RoundedRectangleBorder(
                      borderRadius: BorderRadius.circular(13),
                    ),
                  ),
                  child: isLoading
                      ? const SizedBox(
                          width: 20,
                          height: 20,
                          child: CircularProgressIndicator(
                            strokeWidth: 2.2,
                            color: AppColors.buttonText,
                          ),
                        )
                      : Row(
                          mainAxisAlignment: MainAxisAlignment.center,
                          children: <Widget>[
                            Text(
                              'btn_continue'.tr(),
                              style: const TextStyle(
                                fontSize: 14.5,
                                fontWeight: FontWeight.bold,
                              ),
                            ),
                            const SizedBox(width: 7),
                            const Icon(
                              Icons.arrow_forward_rounded,
                              size: 18,
                            ),
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
      children: <Widget>[
        Expanded(
          child: Divider(
            color: Colors.grey.shade300,
            height: 1,
          ),
        ),
        Padding(
          padding: const EdgeInsets.symmetric(horizontal: 11),
          child: Text(
            'or_label'.tr(),
            style: const TextStyle(
              color: AppColors.textSecondary,
              fontSize: 12,
            ),
          ),
        ),
        Expanded(
          child: Divider(
            color: Colors.grey.shade300,
            height: 1,
          ),
        ),
      ],
    );
  }

  Widget _buildGoogleButton(
    bool isLoading,
    bool isGoogleLoading,
  ) {
    return SizedBox(
      width: double.infinity,
      height: 48,
      child: OutlinedButton(
        onPressed: isGoogleLoading || isLoading
            ? null
            : _handleGoogleSignIn,
        style: OutlinedButton.styleFrom(
          backgroundColor: Colors.white,
          foregroundColor: AppColors.textPrimary,
          side: BorderSide(
            color: Colors.grey.shade300,
          ),
          shape: RoundedRectangleBorder(
            borderRadius: BorderRadius.circular(13),
          ),
        ),
        child: isGoogleLoading
            ? const SizedBox(
                width: 20,
                height: 20,
                child: CircularProgressIndicator(
                  strokeWidth: 2.1,
                  color: AppColors.primaryBrand,
                ),
              )
            : Row(
                mainAxisAlignment: MainAxisAlignment.center,
                children: <Widget>[
                  Image.asset(
                    'assets/images/google_logo.png',
                    height: 19,
                    errorBuilder: (
                      BuildContext context,
                      Object error,
                      StackTrace? stackTrace,
                    ) {
                      return const Icon(
                        Icons.g_mobiledata_rounded,
                        size: 25,
                        color: Colors.red,
                      );
                    },
                  ),
                  const SizedBox(width: 9),
                  Text(
                    'google_sign_in'.tr(),
                    style: const TextStyle(
                      fontSize: 14,
                      fontWeight: FontWeight.w600,
                    ),
                  ),
                ],
              ),
      ),
    );
  }
}

String _normalizeDigits(String input) {
  final StringBuffer buffer = StringBuffer();

  for (final int rune in input.runes) {
    if (rune >= 0x06F0 && rune <= 0x06F9) {
      buffer.writeCharCode(
        0x30 + (rune - 0x06F0),
      );
    } else if (rune >= 0x0660 && rune <= 0x0669) {
      buffer.writeCharCode(
        0x30 + (rune - 0x0660),
      );
    } else {
      buffer.writeCharCode(rune);
    }
  }

  return buffer.toString();
}

class _AfghanPhoneFormatter extends TextInputFormatter {
  @override
  TextEditingValue formatEditUpdate(
    TextEditingValue oldValue,
    TextEditingValue newValue,
  ) {
    String digits = _normalizeDigits(newValue.text)
        .replaceAll(RegExp(r'D'), '');

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

    for (int index = 0; index < digits.length; index++) {
      if (index == 2 || index == 5) {
        buffer.write(' ');
      }

      buffer.write(digits[index]);
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
