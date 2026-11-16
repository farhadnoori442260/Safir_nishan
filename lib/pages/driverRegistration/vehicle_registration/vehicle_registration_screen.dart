import 'package:easy_localization/easy_localization.dart';
import 'package:flutter/material.dart';
import 'package:image_picker/image_picker.dart';
import 'package:provider/provider.dart';

import '../../../providers/registration_provider.dart';
import '../../../utils/app_colors.dart';
import '../../../widgets/photo_capture_card.dart';

class VehicleRegistrationScreen extends StatefulWidget {
  const VehicleRegistrationScreen({super.key});

  @override
  State<VehicleRegistrationScreen> createState() =>
      _VehicleRegistrationScreenState();
}

class _VehicleRegistrationScreenState extends State<VehicleRegistrationScreen> {
  final _formKey = GlobalKey<FormState>();
  final ImagePicker _picker = ImagePicker();

  // اگر ترجمه وجود نداشت، .tr() خود کلید را برمی‌گرداند؛ در این حالت متن پیش‌فرض
  String _t(String key, String fallback) {
    final String v = key.tr();
    return v == key ? fallback : v;
  }

  // سند باید خوانا باشد: قبلاً ۶۰۰ پیکسل و کیفیت ۴۰٪ بود که نوشته‌های سند را
  // نامفهوم می‌کرد و تأیید مدارک را سخت می‌کرد. حالا کیفیت کافی برای خواندن.
  Future<void> _pickLightImage(bool isFront, RegistrationProvider provider) async {
    try {
      final XFile? pickedFile = await _picker.pickImage(
        source: ImageSource.camera,
        maxWidth: 1600,
        maxHeight: 1600,
        imageQuality: 75,
      );

      if (pickedFile != null) {
        // ستر پرووایدر خودش notifyListeners می‌زند (فراخوانی بیرونی لازم نیست)
        if (isFront) {
          provider.vehicleRegistrationFrontImage = pickedFile;
        } else {
          provider.vehicleRegistrationBackImage = pickedFile;
        }
      }
    } catch (e) {
      debugPrint("Error picking vehicle image: $e");
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
      builder: (context, registrationProvider, child) {
        final bool bothTaken =
            registrationProvider.vehicleRegistrationFrontImage != null &&
                registrationProvider.vehicleRegistrationBackImage != null;

        return Scaffold(
          backgroundColor: AppColors.background,
          appBar: AppBar(
            title: Text(
              'vehicle_registration_title'.tr(),
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
              child: Form(
                key: _formKey,
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.stretch,
                  children: [
                    PhotoCaptureCard(
                      label: 'registration_front_title'.tr(),
                      hint: _t(
                        'doc_photo_tip',
                        'سند را روی سطح صاف بگذارید؛ هر چهار گوشه پیدا و نوشته‌ها خوانا باشد، بدون انعکاس نور.',
                      ),
                      image: registrationProvider.vehicleRegistrationFrontImage,
                      buttonText: 'take_photo_front'.tr(),
                      retakeText: _t('retake_photo', 'گرفتن دوباره'),
                      placeholderIcon: Icons.description_outlined,
                      onPressed: () =>
                          _pickLightImage(true, registrationProvider),
                    ),
                    const SizedBox(height: 16),
                    PhotoCaptureCard(
                      label: 'registration_back_title'.tr(),
                      image: registrationProvider.vehicleRegistrationBackImage,
                      buttonText: 'take_photo_back'.tr(),
                      retakeText: _t('retake_photo', 'گرفتن دوباره'),
                      placeholderIcon: Icons.description_outlined,
                      onPressed: () =>
                          _pickLightImage(false, registrationProvider),
                    ),
                    const SizedBox(height: 24),
                    SizedBox(
                      height: 52,
                      child: ElevatedButton(
                        onPressed: bothTaken
                            ? () {
                                if (_formKey.currentState?.validate() == true) {
                                  Navigator.pop(context, true);
                                }
                              }
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
                        child: Text(
                          'confirm_and_save_final'.tr(),
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
      },
    );
  }
}
