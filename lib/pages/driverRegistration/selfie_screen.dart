import 'package:easy_localization/easy_localization.dart' hide TextDirection;
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:image_picker/image_picker.dart';
import 'package:provider/provider.dart';

import '../../providers/registration_provider.dart';
import '../../utils/app_colors.dart';
import '../../widgets/photo_capture_card.dart';

class SelfieScreen extends StatefulWidget {
  const SelfieScreen({super.key});

  @override
  State<SelfieScreen> createState() => _SelfieScreenState();
}

class _SelfieScreenState extends State<SelfieScreen> {
  // تعریف ImagePicker داخلی برای کنترل سایز عکس
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

  // سلفی با کارت: دوربین جلو (طبیعی‌ترین حالت برای سلفی) و کیفیتی که هم چهره
  // و هم نوشتهٔ کارت دیده شود.
  Future<void> _takeLightPhoto(RegistrationProvider registrationProvider) async {
    try {
      final XFile? pickedFile = await _picker.pickImage(
        source: ImageSource.camera,
        preferredCameraDevice: CameraDevice.front,
        maxWidth: 1280,
        maxHeight: 1280,
        imageQuality: 75,
      );

      if (pickedFile != null) {
        // ستر پرووایدر خودش notifyListeners می‌زند
        registrationProvider.cnicWithSelfieImage = pickedFile;
      }
    } catch (e) {
      debugPrint("خطا در گرفتن عکس سلفی: $e");
      _cameraError();
    }
  }

  @override
  Widget build(BuildContext context) {
    return Consumer<RegistrationProvider>(
      builder: (context, registrationProvider, child) => Scaffold(
        backgroundColor: AppColors.background,
        appBar: _appBar('selfie_screen_title'),
        body: SafeArea(
          child: SingleChildScrollView(
            padding: const EdgeInsets.all(16.0),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.stretch,
              children: [
                // بخش بارگذاری تصویر سلفی تایید هویت
                PhotoCaptureCard(
                  label: 'selfie_label'.tr(),
                  hint: 'selfie_description'.tr(),
                  image: registrationProvider.cnicWithSelfieImage,
                  buttonText: 'selfie_take_photo'.tr(),
                  retakeText: _t('retake_photo', 'گرفتن دوباره'),
                  placeholderIcon: Icons.face_retouching_natural_outlined,
                  previewHeight: 220,
                  onPressed: () => _takeLightPhoto(registrationProvider),
                ),
                const SizedBox(height: 24),

                // دکمه تایید نهایی سلفی
                _confirmButton(
                  enabled: registrationProvider.cnicWithSelfieImage != null,
                  onTap: () => Navigator.pop(context, true),
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }
}
