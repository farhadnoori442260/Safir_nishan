import 'package:easy_localization/easy_localization.dart' hide TextDirection;
import 'package:flutter/material.dart';
import 'package:image_picker/image_picker.dart';
import 'package:provider/provider.dart';

import 'package:safir_drivers/methods/common_method.dart';
import 'package:safir_drivers/providers/registration_provider.dart';
import 'package:safir_drivers/utils/app_colors.dart';
import 'package:safir_drivers/widgets/photo_capture_card.dart';

class VehicleRegistrationUpdateScreen extends StatefulWidget {
  const VehicleRegistrationUpdateScreen({super.key});

  @override
  State<VehicleRegistrationUpdateScreen> createState() =>
      _VehicleRegistrationUpdateScreenState();
}

class _VehicleRegistrationUpdateScreenState
    extends State<VehicleRegistrationUpdateScreen> {
  final CommonMethods commonMethods = CommonMethods();
  final ImagePicker _picker = ImagePicker();

  String _t(String key, String fallback) {
    final String v = key.tr();
    return (v.trim().isEmpty || v == key) ? fallback : v;
  }

  // سند باید خوانا باشد (۱۶۰۰ پیکسل، کیفیت ۷۵٪)
  Future<void> _takePhoto(bool isFront, RegistrationProvider provider) async {
    try {
      final XFile? picked = await _picker.pickImage(
        source: ImageSource.camera,
        maxWidth: 1600,
        maxHeight: 1600,
        imageQuality: 75,
      );
      if (picked == null) return;
      if (isFront) {
        provider.vehicleRegistrationFrontImage = picked;
      } else {
        provider.vehicleRegistrationBackImage = picked;
      }
    } catch (e) {
      debugPrint('Error taking registration photo: $e');
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
      final bool ok = await provider.updateVehicleRegistraionImages(context);
      // پیام خطا را خود provider نشان می‌دهد؛ موفقیت فقط وقتی واقعاً ذخیره شد
      if (!ok || !mounted) return;
      commonMethods.displaySnackBar('reg_card_success'.tr(), context);
    } catch (e) {
      debugPrint('Error while saving data: $e');
    }
  }

  @override
  Widget build(BuildContext context) {
    return Consumer<RegistrationProvider>(
      builder: (context, registrationProvider, child) {
        final bool canSave =
            registrationProvider.vehicleRegistrationFrontImage != null &&
                registrationProvider.vehicleRegistrationBackImage != null &&
                !registrationProvider.isLoading;

        return Scaffold(
          backgroundColor: AppColors.background,
          appBar: AppBar(
            backgroundColor: AppColors.cardBackground,
            surfaceTintColor: AppColors.cardBackground,
            elevation: 0,
            scrolledUnderElevation: 0,
            iconTheme: IconThemeData(color: AppColors.textPrimary),
            title: Text(
              'reg_card_title'.tr(),
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
                    label: 'reg_card_front_label'.tr(),
                    hint: _t(
                      'doc_photo_tip',
                      'سند را روی سطح صاف بگذارید؛ هر چهار گوشه پیدا و نوشته‌ها خوانا باشد، بدون انعکاس نور.',
                    ),
                    image: registrationProvider.vehicleRegistrationFrontImage,
                    buttonText: 'take_photo'.tr(),
                    retakeText: _t('retake_photo', 'گرفتن دوباره'),
                    placeholderIcon: Icons.description_outlined,
                    onPressed: () => _takePhoto(true, registrationProvider),
                  ),
                  const SizedBox(height: 16),
                  PhotoCaptureCard(
                    label: 'reg_card_back_label'.tr(),
                    image: registrationProvider.vehicleRegistrationBackImage,
                    buttonText: 'take_photo'.tr(),
                    retakeText: _t('retake_photo', 'گرفتن دوباره'),
                    placeholderIcon: Icons.description_outlined,
                    onPressed: () => _takePhoto(false, registrationProvider),
                  ),
                  const SizedBox(height: 24),
                  SizedBox(
                    height: 52,
                    child: ElevatedButton(
                      onPressed:
                          canSave ? () => _save(registrationProvider) : null,
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
        );
      },
    );
  }
}
