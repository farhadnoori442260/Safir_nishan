import 'package:easy_localization/easy_localization.dart' hide TextDirection;
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:image_picker/image_picker.dart';
import 'package:provider/provider.dart';

import 'package:safir_drivers/methods/common_method.dart';
import 'package:safir_drivers/providers/registration_provider.dart';
import 'package:safir_drivers/utils/app_colors.dart';
import 'package:safir_drivers/widgets/photo_capture_card.dart';

class CnincUpdateScreen extends StatefulWidget {
  const CnincUpdateScreen({super.key});

  @override
  State<CnincUpdateScreen> createState() =>
      _CnincUpdateScreenState();
}

class _CnincUpdateScreenState
    extends State<CnincUpdateScreen> {
  final _formKey = GlobalKey<FormState>();
  final CommonMethods commonMethods = CommonMethods();
  final ImagePicker _picker = ImagePicker();

  String _t(String key, String fallback) {
    final String v = key.tr();
    return (v.trim().isEmpty || v == key) ? fallback : v;
  }

  // سند باید خوانا باشد (۱۶۰۰ پیکسل، کیفیت ۷۵٪)
  Future<void> _pickImage(bool isFront, RegistrationProvider provider) async {
    try {
      final XFile? picked = await _picker.pickImage(
        source: ImageSource.camera,
        maxWidth: 1600,
        maxHeight: 1600,
        imageQuality: 75,
      );
      if (picked == null) return;
      if (isFront) {
        provider.cnincFrontImage = picked;
      } else {
        provider.cnincBackImage = picked;
      }
    } catch (e) {
      debugPrint('Error picking cnic image: $e');
      if (!mounted) return;
      commonMethods.displaySnackBar(
        _t('camera_unavailable',
            'دوربین باز نشد. اجازهٔ دسترسی به دوربین را در تنظیمات گوشی بدهید.'),
        context,
      );
    }
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
      floatingLabelStyle:
          TextStyle(fontSize: 14, color: AppColors.primaryBrand),
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

  Future<void> _save(RegistrationProvider provider) async {
    if (_formKey.currentState?.validate() != true) return;
    FocusScope.of(context).unfocus();
    try {
      final bool ok = await provider.updateCnincInfo(context);
      // پیام خطا را خود provider نشان می‌دهد؛ موفقیت فقط وقتی واقعاً ذخیره شد
      if (!ok || !mounted) return;
      commonMethods.displaySnackBar('cnic_update_success'.tr(), context);
    } catch (e) {
      debugPrint('Error while saving data: $e');
    }
  }

  @override
  Widget build(BuildContext context) {
    return Consumer<RegistrationProvider>(
      builder: (context, registrationProvider, child) => Scaffold(
        backgroundColor: AppColors.background,
        appBar: AppBar(
          backgroundColor: AppColors.cardBackground,
          surfaceTintColor: AppColors.cardBackground,
          elevation: 0,
          scrolledUnderElevation: 0,
          iconTheme: IconThemeData(color: AppColors.textPrimary),
          title: Text(
            'cnic_screen_title'.tr(),
            style: TextStyle(
              fontSize: 16,
              fontWeight: FontWeight.bold,
              color: AppColors.textPrimary,
            ),
          ),
          centerTitle: true,
          leading: IconButton(
            icon: const Icon(Icons.arrow_back_rounded),
            onPressed: () => Navigator.pop(context),
          ),
        ),
        body: SafeArea(
          child: SingleChildScrollView(
            padding: const EdgeInsets.all(16.0),
            child: Form(
              key: _formKey,
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.stretch,
                children: [
                  PhotoCaptureCard(
                    label: 'cnic_front_hint'.tr(),
                    hint: _t(
                      'doc_photo_tip',
                      'سند را روی سطح صاف بگذارید؛ هر چهار گوشه پیدا و نوشته‌ها خوانا باشد، بدون انعکاس نور.',
                    ),
                    image: registrationProvider.cnincFrontImage,
                    buttonText: 'take_photo'.tr(),
                    retakeText: _t('retake_photo', 'گرفتن دوباره'),
                    placeholderIcon: Icons.badge_outlined,
                    onPressed: () => _pickImage(true, registrationProvider),
                  ),
                  const SizedBox(height: 16),
                  PhotoCaptureCard(
                    label: 'cnic_back_hint'.tr(),
                    image: registrationProvider.cnincBackImage,
                    buttonText: 'take_photo'.tr(),
                    retakeText: _t('retake_photo', 'گرفتن دوباره'),
                    placeholderIcon: Icons.badge_outlined,
                    onPressed: () => _pickImage(false, registrationProvider),
                  ),
                  const SizedBox(height: 16),
                  Container(
                    padding: const EdgeInsets.all(16),
                    decoration: BoxDecoration(
                      borderRadius: BorderRadius.circular(20),
                      color: AppColors.cardBackground,
                      border: Border.all(color: AppColors.borderLight),
                    ),
                    child: Directionality(
                      textDirection: TextDirection.ltr,
                      child: TextFormField(
                        controller:
                            registrationProvider.cnicController,
                        style: TextStyle(color: AppColors.textPrimary),
                        keyboardType: TextInputType.number,
                        maxLength: 13,
                        decoration: _fieldDecoration(
                          'cnic_number_label'.tr(),
                        ),
                        inputFormatters: [_AsciiDigitsFormatter()],
                        validator: (value) {
                          final String v = value ?? '';
                          if (v.isEmpty) return 'err_cnic_required'.tr();
                          if (v.length != 13) return 'err_cnic_length'.tr();
                          return null;
                        },
                        onChanged: (value) => registrationProvider
                            .checkCNICFormValidity(),
                      ),
                    ),
                  ),
                  const SizedBox(height: 24),
                  SizedBox(
                    height: 52,
                    child: ElevatedButton(
                      onPressed:
                          registrationProvider.isFormValidCninc &&
                                  !registrationProvider.isLoading
                              ? () => _save(registrationProvider)
                              : null,
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
                      child: registrationProvider.isLoading
                          ? SizedBox(
                              height: 22,
                              width: 22,
                              child: CircularProgressIndicator(
                                strokeWidth: 2.4,
                                color: AppColors.buttonText,
                              ),
                            )
                          : Text(
                              'update_docs'.tr(),
                              style: const TextStyle(
                                fontWeight: FontWeight.bold,
                                fontSize: 15,
                              ),
                            ),
                    ),
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

/// ارقام فارسی/عربی → لاتین و فقط رقم؛ شماره همیشه یک‌شکل ذخیره شود.
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
      } else if (r >= 0x30 && r <= 0x39) {
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
