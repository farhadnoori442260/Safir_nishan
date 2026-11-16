import 'package:easy_localization/easy_localization.dart' hide TextDirection;
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:image_picker/image_picker.dart';
import 'package:provider/provider.dart';

import '../../providers/registration_provider.dart';
import '../../utils/app_colors.dart';
import '../../widgets/photo_capture_card.dart';

class DrivingLicenseScreen extends StatefulWidget {
  const DrivingLicenseScreen({super.key});

  @override
  State<DrivingLicenseScreen> createState() => _DrivingLicenseScreenState();
}

class _DrivingLicenseScreenState extends State<DrivingLicenseScreen> {
  final _formKey = GlobalKey<FormState>();
  final ImagePicker _picker = ImagePicker();

  // اگر ترجمه وجود نداشت، .tr() خود کلید را برمی‌گرداند؛ در این حالت متن پیش‌فرض
  String _t(String key, String fallback) {
    final String v = key.tr();
    return v == key ? fallback : v;
  }

  void _cameraError() {
    if (!mounted) return;
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(
        content: Text(
          _t('camera_unavailable',
              'دوربین باز نشد. اجازهٔ دسترسی به دوربین را در تنظیمات گوشی بدهید.'),
        ),
      ),
    );
  }

  InputDecoration _fieldDecoration(String label, {String? helper}) {
    final OutlineInputBorder border = OutlineInputBorder(
      borderRadius: BorderRadius.circular(12),
      borderSide: BorderSide(color: AppColors.fieldBorder),
    );
    return InputDecoration(
      labelText: label,
      helperText: helper,
      counterText: '',
      labelStyle: TextStyle(fontSize: 14, color: AppColors.textSecondary),
      floatingLabelStyle: TextStyle(fontSize: 14, color: AppColors.primaryBrand),
      helperStyle: TextStyle(fontSize: 11, color: AppColors.textSecondary),
      border: border,
      enabledBorder: border,
      focusedBorder: OutlineInputBorder(
        borderRadius: BorderRadius.circular(12),
        borderSide: BorderSide(color: AppColors.primaryBrand, width: 2),
      ),
      errorBorder: OutlineInputBorder(
        borderRadius: BorderRadius.circular(12),
        borderSide: BorderSide(color: AppColors.danger),
      ),
      focusedErrorBorder: OutlineInputBorder(
        borderRadius: BorderRadius.circular(12),
        borderSide: BorderSide(color: AppColors.danger, width: 2),
      ),
      contentPadding: const EdgeInsets.symmetric(horizontal: 12, vertical: 14),
    );
  }

  AppBar _appBar(String titleKey) {
    return AppBar(
      title: Text(
        titleKey.tr(),
        style: TextStyle(
          fontSize: 16,
          fontWeight: FontWeight.bold,
          color: AppColors.textPrimary,
        ),
      ),
      centerTitle: true,
      elevation: 0,
      surfaceTintColor: Colors.transparent,
      backgroundColor: AppColors.cardBackground,
      iconTheme: IconThemeData(color: AppColors.textPrimary),
      actions: [
        TextButton(
          onPressed: () => Navigator.pop(context),
          child: Text(
            'close'.tr(),
            style: TextStyle(
              color: AppColors.textSecondary,
              fontWeight: FontWeight.bold,
            ),
          ),
        ),
      ],
    );
  }

  Widget _confirmButton({required bool enabled, required VoidCallback onTap}) {
    return SizedBox(
      height: 52,
      child: ElevatedButton(
        onPressed: enabled ? onTap : null,
        style: ElevatedButton.styleFrom(
          backgroundColor: AppColors.primaryButton,
          foregroundColor: AppColors.buttonText,
          disabledBackgroundColor: AppColors.borderLight,
          disabledForegroundColor: AppColors.textSecondary,
          elevation: 0,
          shape: RoundedRectangleBorder(
            borderRadius: BorderRadius.circular(14),
          ),
        ),
        child: Text(
          'confirm_and_save'.tr(),
          style: const TextStyle(fontSize: 16, fontWeight: FontWeight.bold),
        ),
      ),
    );
  }

  Widget _formCard(Widget child) {
    return Container(
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        border: Border.all(color: AppColors.borderLight),
        borderRadius: BorderRadius.circular(20),
        color: AppColors.cardBackground,
      ),
      child: child,
    );
  }

  // سند باید خوانا باشد (قبلاً ۶۰۰ پیکسل و کیفیت ۴۰٪)
  Future<void> _pickLightImage(bool isFront, RegistrationProvider provider) async {
    try {
      final XFile? pickedFile = await _picker.pickImage(
        source: ImageSource.camera,
        maxWidth: 1600,
        maxHeight: 1600,
        imageQuality: 75,
      );

      if (pickedFile != null) {
        // ستر در پرووایدر خودش اعتبار فرم را دوباره حساب و اعلان می‌کند
        if (isFront) {
          provider.drivingLicenseFrontImage = pickedFile;
        } else {
          provider.drivingLicenseBackImage = pickedFile;
        }
      }
    } catch (e) {
      debugPrint("Error picking license image: $e");
      _cameraError();
    }
  }

  @override
  Widget build(BuildContext context) {
    return Consumer<RegistrationProvider>(
      builder: (context, registrationProvider, child) => Scaffold(
        backgroundColor: AppColors.background,
        appBar: _appBar('license_screen_title'),
        body: SafeArea(
          child: SingleChildScrollView(
            padding: const EdgeInsets.all(16.0),
            child: Form(
              key: _formKey,
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.stretch,
                children: [
                  // بارگذاری تصویر روی جواز رانندگی
                  PhotoCaptureCard(
                    label: 'license_front_hint'.tr(),
                    hint: _t(
                      'doc_photo_tip',
                      'سند را روی سطح صاف بگذارید؛ هر چهار گوشه پیدا و نوشته‌ها خوانا باشد، بدون انعکاس نور.',
                    ),
                    image: registrationProvider.drivingLicenseFrontImage,
                    buttonText: 'take_photo_front'.tr(),
                    retakeText: _t('retake_photo', 'گرفتن دوباره'),
                    placeholderIcon: Icons.credit_card_outlined,
                    onPressed: () => _pickLightImage(true, registrationProvider),
                  ),
                  const SizedBox(height: 16),

                  // بارگذاری تصویر پشت جواز رانندگی
                  PhotoCaptureCard(
                    label: 'license_back_hint'.tr(),
                    image: registrationProvider.drivingLicenseBackImage,
                    buttonText: 'take_photo_back'.tr(),
                    retakeText: _t('retake_photo', 'گرفتن دوباره'),
                    placeholderIcon: Icons.credit_card_outlined,
                    onPressed: () => _pickLightImage(false, registrationProvider),
                  ),
                  const SizedBox(height: 16),

                  // فیلد نمبر جواز رانندگی
                  _formCard(
                    Directionality(
                      textDirection: TextDirection.ltr,
                      child: TextFormField(
                        controller: registrationProvider.drivingLicenseController,
                        style: TextStyle(color: AppColors.textPrimary),
                        textCapitalization: TextCapitalization.characters,
                        decoration: _fieldDecoration(
                          'license_number_label'.tr(),
                          helper: _t(
                            'license_number_hint2',
                            'شمارهٔ جواز را دقیقاً مثل روی جواز بنویسید',
                          ),
                        ),
                        keyboardType: TextInputType.text,
                        inputFormatters: [
                          _LicenseFormatter(),
                          LengthLimitingTextInputFormatter(20),
                        ],
                        // قبلاً الگوی Pakistan-style (AB-12-3456) اجباری بود که با
                        // شمارهٔ جواز افغانستان جور نبود؛ حالا فقط طول و نویسهٔ مجاز.
                        validator: (value) {
                          final String v = (value ?? '').trim();
                          if (v.isEmpty) {
                            return 'err_license_required'.tr();
                          }
                          if (v.length < 4) {
                            return 'err_license_format'.tr();
                          }
                          return null;
                        },
                        onChanged: (value) =>
                            registrationProvider.checkDrivingLicenseFormValidity(),
                      ),
                    ),
                  ),
                  const SizedBox(height: 24),

                  // دکمه تایید نهایی جواز رانندگی
                  _confirmButton(
                    enabled: registrationProvider.isFormValidDrivingLicnese,
                    onTap: () {
                      if (_formKey.currentState?.validate() == true) {
                        Navigator.pop(context, true);
                      }
                    },
                  ),
                ],
              ),
            ),
          ),
        ),
      ),
    );
  }
}

/// ارقام فارسی/عربی → لاتین، حروف بزرگ، و فقط حرف/رقم و - / .
class _LicenseFormatter extends TextInputFormatter {
  @override
  TextEditingValue formatEditUpdate(
    TextEditingValue oldValue,
    TextEditingValue newValue,
  ) {
    const String fa = '۰۱۲۳۴۵۶۷۸۹';
    const String ar = '٠١٢٣٤٥٦٧٨٩';
    final StringBuffer out = StringBuffer();
    for (final int r in newValue.text.runes) {
      final String c = String.fromCharCode(r);
      final int fi = fa.indexOf(c);
      final int ai = ar.indexOf(c);
      if (fi >= 0) {
        out.write(fi);
      } else if (ai >= 0) {
        out.write(ai);
      } else if (RegExp(r'[A-Za-z0-9\-/]').hasMatch(c)) {
        out.write(c.toUpperCase());
      }
    }
    final String text = out.toString();
    return TextEditingValue(
      text: text,
      selection: TextSelection.collapsed(
        offset: newValue.selection.baseOffset.clamp(0, text.length),
      ),
    );
  }
}
