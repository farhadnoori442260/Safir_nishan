import 'package:easy_localization/easy_localization.dart' hide TextDirection;
import 'package:flutter/material.dart';
import 'package:image_picker/image_picker.dart';
import 'package:provider/provider.dart';

import 'package:safir_drivers/methods/common_method.dart';
import 'package:safir_drivers/providers/registration_provider.dart';
import 'package:safir_drivers/utils/app_colors.dart';
import 'package:safir_drivers/widgets/photo_capture_card.dart';

class DriverCarImageUpdateScreen extends StatefulWidget {
  const DriverCarImageUpdateScreen({super.key});

  @override
  State<DriverCarImageUpdateScreen> createState() =>
      _DriverCarImageUpdateScreenState();
}

class _DriverCarImageUpdateScreenState
    extends State<DriverCarImageUpdateScreen> {
  final CommonMethods commonMethods = CommonMethods();
  final ImagePicker _picker = ImagePicker();

  String _t(String key, String fallback) {
    final String v = key.tr();
    return (v.trim().isEmpty || v == key) ? fallback : v;
  }

  // عکس موتر: اندازهٔ متوسط کافی است (فقط برای شناسایی ظاهر و پلاک)
  Future<void> _takePhoto(RegistrationProvider provider) async {
    try {
      final XFile? picked = await _picker.pickImage(
        source: ImageSource.camera,
        maxWidth: 1280,
        maxHeight: 1280,
        imageQuality: 70,
      );
      if (picked != null) {
        provider.vehicleImage = picked;
        provider.isVehiclePhotoAdded = true;
      }
    } catch (e) {
      debugPrint('Error taking vehicle photo: $e');
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
      final bool ok = await provider.updateVehicleImage(context);
      // پیام خطا را خود provider نشان می‌دهد؛ موفقیت فقط وقتی واقعاً ذخیره شد
      if (!ok || !mounted) return;
      commonMethods.displaySnackBar('car_img_success'.tr(), context);
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
            'car_img_title'.tr(),
            style: TextStyle(
              fontWeight: FontWeight.bold,
              fontSize: 16,
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
                  label: 'car_img_picker_label'.tr(),
                  hint: _t(
                    'vehicle_image_tip',
                    'موتر را از روبرو و از فاصلهٔ چند قدمی عکس بگیرید؛ کل موتر و پلاک پیدا باشد.',
                  ),
                  image: registrationProvider.vehicleImage,
                  buttonText: 'car_img_take_photo'.tr(),
                  retakeText: _t('retake_photo', 'گرفتن دوباره'),
                  placeholderIcon: Icons.directions_car_outlined,
                  previewHeight: 200,
                  onPressed: () => _takePhoto(registrationProvider),
                ),
                const SizedBox(height: 24),
                SizedBox(
                  height: 52,
                  child: ElevatedButton(
                    onPressed: registrationProvider.isVehiclePhotoAdded &&
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
                            'final_confirm'.tr(),
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
