import 'package:easy_localization/easy_localization.dart';
import 'package:flutter/material.dart';
import 'package:image_picker/image_picker.dart';
import 'package:provider/provider.dart';

import '../../../providers/registration_provider.dart';
import '../../../utils/app_colors.dart';
import '../../../widgets/photo_capture_card.dart';

class DriverCarImageScreeen extends StatefulWidget {
  const DriverCarImageScreeen({super.key});

  @override
  State<DriverCarImageScreeen> createState() => _DriverCarImageScreeenState();
}

class _DriverCarImageScreeenState extends State<DriverCarImageScreeen> {
  final ImagePicker _picker = ImagePicker(); // ابزار دوربین سبک داخلی

  // اگر ترجمه وجود نداشت، .tr() خود کلید را برمی‌گرداند؛ در این حالت متن پیش‌فرض
  String _t(String key, String fallback) {
    final String v = key.tr();
    return v == key ? fallback : v;
  }

  // عکس موتر: اندازهٔ متوسط کافی است (فقط برای شناسایی ظاهر و پلاک)
  Future<void> _takeLightCarPhoto(RegistrationProvider provider) async {
    try {
      final XFile? pickedFile = await _picker.pickImage(
        source: ImageSource.camera,
        maxWidth: 1280,
        maxHeight: 1280,
        imageQuality: 70,
      );

      if (pickedFile != null) {
        // ستر در پرووایدر خودش notifyListeners می‌زند
        provider.vehicleImage = pickedFile;
        provider.isVehiclePhotoAdded = true;
      }
    } catch (e) {
      debugPrint("Error taking vehicle photo: $e");
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
  }

  @override
  Widget build(BuildContext context) {
    return Consumer<RegistrationProvider>(
      builder: (context, registrationProvider, child) => Scaffold(
        backgroundColor: AppColors.background,
        appBar: AppBar(
          title: Text(
            'vehicle_image_title'.tr(),
            style: TextStyle(
              fontWeight: FontWeight.bold,
              color: AppColors.textPrimary,
            ),
          ),
          centerTitle: true,
          elevation: 0,
          surfaceTintColor: Colors.transparent,
          backgroundColor: AppColors.cardBackground,
          actions: [
            TextButton(
              onPressed: () {
                Navigator.pop(context);
              },
              child: Text(
                'close'.tr(),
                style: TextStyle(
                  color: AppColors.textSecondary,
                  fontWeight: FontWeight.bold,
                ),
              ),
            ),
          ],
        ),
        body: SafeArea(
          child: SingleChildScrollView(
            padding: const EdgeInsets.all(16.0),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.stretch,
              children: [
                // بخش انتخاب تصویر موتر/موتورسایکل راننده
                PhotoCaptureCard(
                  label: 'vehicle_image_hint'.tr(),
                  hint: _t(
                    'vehicle_image_tip',
                    'موتر را از روبرو و از فاصلهٔ چند قدمی عکس بگیرید؛ کل موتر و پلاک پیدا باشد.',
                  ),
                  image: registrationProvider.vehicleImage,
                  buttonText: 'take_photo_camera'.tr(),
                  retakeText: _t('retake_photo', 'گرفتن دوباره'),
                  placeholderIcon: Icons.directions_car_outlined,
                  previewHeight: 200,
                  onPressed: () => _takeLightCarPhoto(registrationProvider),
                ),
                const SizedBox(height: 24),

                // دکمه تایید و ثبت نهایی
                SizedBox(
                  height: 52,
                  child: ElevatedButton(
                    onPressed: registrationProvider.isVehiclePhotoAdded &&
                            registrationProvider.vehicleImage != null
                        ? () => Navigator.pop(context, true)
                        : null,
                    style: ElevatedButton.styleFrom(
                      backgroundColor: AppColors.primaryButton,
                      foregroundColor: AppColors.buttonText,
                      disabledBackgroundColor: AppColors.borderLight,
                      disabledForegroundColor: AppColors.textSecondary,
                      shape: RoundedRectangleBorder(
                        borderRadius: BorderRadius.circular(14),
                      ),
                      elevation: 0,
                    ),
                    child: Text(
                      'confirm_and_save'.tr(),
                      style: const TextStyle(
                        fontSize: 16,
                        fontWeight: FontWeight.bold,
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
