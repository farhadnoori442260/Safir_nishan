import 'package:easy_localization/easy_localization.dart' hide TextDirection;
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:image_picker/image_picker.dart';
import 'package:provider/provider.dart';

import '../../providers/registration_provider.dart';
import '../../utils/app_colors.dart';
import '../../widgets/photo_capture_card.dart';

class CNICScreen extends StatefulWidget {
  const CNICScreen({super.key});

  @override
  State<CNICScreen> createState() => _CNICScreenState();
}

class _CNICScreenState extends State<CNICScreen> {
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

  // سند باید خوانا باشد: قبلاً ۶۰۰ پیکسل و کیفیت ۴۰٪ بود و شمارهٔ روی تذکره
  // خوانده نمی‌شد.
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
          provider.cnincFrontImage = pickedFile;
        } else {
          provider.cnincBackImage = pickedFile;
        }
      }
    } catch (e) {
      debugPrint("Error picking CNIC image: $e");
      _cameraError();
    }
  }

  @override
  Widget build(BuildContext context) {
    return Consumer<RegistrationProvider>(
      builder: (context, registrationProvider, child) => Scaffold(
        backgroundColor: AppColors.background,
        appBar: _appBar('cnic_screen_title'),
        body: SafeArea(
          child: SingleChildScrollView(
            padding: const EdgeInsets.all(16.0),
            child: Form(
              key: _formKey,
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.stretch,
                children: [
                  // بارگذاری تصویر روی کارت هویت / تذکره
                  PhotoCaptureCard(
                    label: 'cnic_front_hint'.tr(),
                    hint: _t(
                      'doc_photo_tip',
                      'سند را روی سطح صاف بگذارید؛ هر چهار گوشه پیدا و نوشته‌ها خوانا باشد، بدون انعکاس نور.',
                    ),
                    image: registrationProvider.cnincFrontImage,
                    buttonText: 'take_photo_front'.tr(),
                    retakeText: _t('retake_photo', 'گرفتن دوباره'),
                    placeholderIcon: Icons.badge_outlined,
                    onPressed: () => _pickLightImage(true, registrationProvider),
                  ),
                  const SizedBox(height: 16),

                  // بارگذاری تصویر پشت کارت هویت / تذکره
                  PhotoCaptureCard(
                    label: 'cnic_back_hint'.tr(),
                    image: registrationProvider.cnincBackImage,
                    buttonText: 'take_photo_back'.tr(),
                    retakeText: _t('retake_photo', 'گرفتن دوباره'),
                    placeholderIcon: Icons.badge_outlined,
                    onPressed: () => _pickLightImage(false, registrationProvider),
                  ),
                  const SizedBox(height: 16),

                  // فیلد شماره تذکره/کارت هویت
                  _formCard(
                    Directionality(
                      textDirection: TextDirection.ltr,
                      child: TextFormField(
                        controller: registrationProvider.cnicController,
                        style: TextStyle(color: AppColors.textPrimary),
                        decoration: _fieldDecoration(
                          'cnic_number_label'.tr(),
                        ),
                        keyboardType: TextInputType.number,
                        maxLength: 13,
                        inputFormatters: [_AsciiDigitsFormatter()],
                        validator: (value) {
                          if (value == null || value.isEmpty) {
                            return 'err_cnic_required'.tr();
                          }
                          if (value.length != 13) {
                            return 'err_cnic_length'.tr();
                          }
                          return null;
                        },
                        onChanged: (value) =>
                            registrationProvider.checkCNICFormValidity(),
                      ),
                    ),
                  ),
                  const SizedBox(height: 24),

                  // دکمه تایید نهایی مدارک
                  _confirmButton(
                    enabled: registrationProvider.isFormValidCninc,
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

/// ارقام فارسی/عربی را به لاتین تبدیل می‌کند و فقط رقم می‌پذیرد؛ تا شماره همیشه
/// یک‌شکل ذخیره شود (قبلاً شمارهٔ فارسی‌تایپ‌شده همان‌طور ذخیره می‌شد).
class _AsciiDigitsFormatter extends TextInputFormatter {
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
      } else if (RegExp(r'[0-9]').hasMatch(c)) {
        out.write(c);
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
