import 'package:easy_localization/easy_localization.dart' hide TextDirection;
import 'package:flutter/material.dart';
import 'package:image_picker/image_picker.dart';
import 'package:provider/provider.dart';

import 'package:safir_drivers/methods/common_method.dart';
import 'package:safir_drivers/providers/registration_provider.dart';
import 'package:safir_drivers/utils/app_colors.dart';
import 'package:safir_drivers/widgets/photo_capture_card.dart';

class SelfieWithCnincUpdateScreen extends StatefulWidget {
  const SelfieWithCnincUpdateScreen({super.key});

  @override
  State<SelfieWithCnincUpdateScreen> createState() =>
      _SelfieWithCnincUpdateScreenState();
}

class _SelfieWithCnincUpdateScreenState
    extends State<SelfieWithCnincUpdateScreen> {
  final CommonMethods commonMethods = CommonMethods();
  final ImagePicker _picker = ImagePicker();

  String _t(String key, String fallback) {
    final String v = key.tr();
    return (v.trim().isEmpty || v == key) ? fallback : v;
  }

  // سلفی با کارت: دوربین جلو، کیفیتی که هم چهره و هم نوشتهٔ کارت دیده شود
  Future<void> _takePhoto(RegistrationProvider provider) async {
    try {
      final XFile? picked = await _picker.pickImage(
        source: ImageSource.camera,
        preferredCameraDevice: CameraDevice.front,
        maxWidth: 1280,
        maxHeight: 1280,
        imageQuality: 75,
      );
      if (picked != null) {
        provider.cnicWithSelfieImage = picked;
      }
    } catch (e) {
      debugPrint('Error taking selfie: $e');
      if (!mounted) return;
      commonMethods.displaySnackBar(
        _t('camera_unavailable',
            'دوربین باز نشد. اجازهٔ دسترسی به دوربین را در تنظیمات گوشی بدهید.'),
        context,
      );
    }
  }

  Future<void> _save(RegistrationProvider provider) async {
    try {
      final bool ok = await provider.updateSelfieWithCnincInfo(context);
      // پیام خطا را خود provider نشان می‌دهد؛ موفقیت فقط وقتی واقعاً ذخیره شد
      if (!ok || !mounted) return;
      commonMethods.displaySnackBar('selfie_update_success'.tr(), context);
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
            'selfie_screen_title'.tr(),
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
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.stretch,
              children: [
                PhotoCaptureCard(
                  label: 'selfie_label'.tr(),
                  hint: 'selfie_description'.tr(),
                  image: registrationProvider.cnicWithSelfieImage,
                  buttonText: 'selfie_take_photo'.tr(),
                  retakeText: _t('retake_photo', 'گرفتن دوباره'),
                  placeholderIcon: Icons.face_retouching_natural_outlined,
                  previewHeight: 220,
                  onPressed: () => _takePhoto(registrationProvider),
                ),
                const SizedBox(height: 24),
                SizedBox(
                  height: 52,
                  child: ElevatedButton(
                    onPressed:
                        registrationProvider.cnicWithSelfieImage != null &&
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
    );
  }
}
