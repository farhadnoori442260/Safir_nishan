import 'package:easy_localization/easy_localization.dart';
import 'package:flutter/material.dart';
import 'package:provider/provider.dart';

import '../../../providers/registration_provider.dart';
import '../../../utils/app_colors.dart';
import 'vehicle_registration/driver_car_image_screen.dart';
import 'vehicle_registration/vehicle_basic_info_screen.dart';
import 'vehicle_registration/vehicle_registration_screen.dart';

class VehicleInfoScreen extends StatefulWidget {
  const VehicleInfoScreen({super.key});

  @override
  State<VehicleInfoScreen> createState() => _VehicleInfoScreenState();
}

class _VehicleInfoScreenState extends State<VehicleInfoScreen> {
  // اگر ترجمه وجود نداشت، .tr() خود کلید را برمی‌گرداند؛ در این حالت متن پیش‌فرض
  String _t(String key, String fallback) {
    final String v = key.tr();
    return v == key ? fallback : v;
  }

  String _digits(int n) {
    final String code = context.locale.languageCode;
    if (code != 'fa' && code != 'ps') return '$n';
    const fa = ['۰', '۱', '۲', '۳', '۴', '۵', '۶', '۷', '۸', '۹'];
    return '$n'.split('').map((c) => fa[int.parse(c)]).join();
  }

  Future<void> _open(Widget screen) async {
    await Navigator.push(
      context,
      MaterialPageRoute(builder: (_) => screen),
    );
  }

  @override
  Widget build(BuildContext context) {
    return Consumer<RegistrationProvider>(
      builder: (context, registrationProvider, child) {
        // متصل کردن وضعیت‌ها به پرووایدر
        final bool isBasicComplete =
            registrationProvider.isVehicleBasicFormValid;
        final bool isVehiclePictureComplete =
            registrationProvider.vehicleImage != null;
        final bool isCertificateOfVehicleComplete =
            registrationProvider.vehicleRegistrationFrontImage != null &&
                registrationProvider.vehicleRegistrationBackImage != null;

        final bool isAllComplete = isBasicComplete &&
            isVehiclePictureComplete &&
            isCertificateOfVehicleComplete;

        final int done = <bool>[
          isBasicComplete,
          isVehiclePictureComplete,
          isCertificateOfVehicleComplete,
        ].where((bool e) => e).length;

        return Scaffold(
          backgroundColor: AppColors.background,
          appBar: AppBar(
            title: Text(
              'vehicle_screen_title'.tr(),
              style: TextStyle(
                fontWeight: FontWeight.bold,
                fontSize: 16,
                color: AppColors.textPrimary,
              ),
            ),
            centerTitle: true,
            backgroundColor: AppColors.cardBackground,
            surfaceTintColor: Colors.transparent,
            elevation: 0,
            iconTheme: IconThemeData(color: AppColors.textPrimary),
          ),
          body: SafeArea(
            child: SingleChildScrollView(
              padding: const EdgeInsets.fromLTRB(16, 16, 16, 24),
              child: Column(
                children: [
                  _buildProgressCard(done, 3),
                  const SizedBox(height: 14),
                  Container(
                    decoration: BoxDecoration(
                      borderRadius: BorderRadius.circular(20),
                      color: AppColors.cardBackground,
                      border: Border.all(color: AppColors.borderLight),
                    ),
                    clipBehavior: Clip.antiAlias,
                    child: Column(
                      children: [
                        _buildListTile(
                          icon: Icons.directions_car_outlined,
                          accent: AppColors.warningIcon,
                          title: 'v_step_basic_title'.tr(),
                          subtitle: 'v_step_basic_sub'.tr(),
                          isCompleted: isBasicComplete,
                          onTap: () => _open(const VehicleBasicInfoScreen()),
                        ),
                        _divider(),
                        _buildListTile(
                          icon: Icons.photo_camera_outlined,
                          accent: AppColors.accentPurple,
                          title: 'v_step_pic_title'.tr(),
                          subtitle: 'v_step_pic_sub'.tr(),
                          isCompleted: isVehiclePictureComplete,
                          onTap: () => _open(const DriverCarImageScreeen()),
                        ),
                        _divider(),
                        _buildListTile(
                          icon: Icons.description_outlined,
                          accent: AppColors.accentTeal,
                          title: 'v_step_docs_title'.tr(),
                          subtitle: 'v_step_docs_sub'.tr(),
                          isCompleted: isCertificateOfVehicleComplete,
                          onTap: () =>
                              _open(const VehicleRegistrationScreen()),
                        ),
                      ],
                    ),
                  ),
                  const SizedBox(height: 24),

                  // دکمه ذخیره نهایی
                  SizedBox(
                    width: double.infinity,
                    height: 52,
                    child: ElevatedButton(
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
                      onPressed: isAllComplete
                          ? () => Navigator.pop(context, true)
                          : null,
                      child: Text(
                        'v_submit_btn'.tr(),
                        style: const TextStyle(
                          fontSize: 15,
                          fontWeight: FontWeight.bold,
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

  Widget _buildProgressCard(int done, int total) {
    final bool all = done == total;
    return Container(
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: AppColors.cardBackground,
        borderRadius: BorderRadius.circular(20),
        border: Border.all(color: AppColors.borderLight),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              Expanded(
                child: Text(
                  all
                      ? _t('v_all_done', 'اطلاعات وسیله کامل است')
                      : _t('v_progress_title', 'اطلاعات موتر را کامل کنید'),
                  style: TextStyle(
                    fontSize: 15,
                    fontWeight: FontWeight.bold,
                    color: AppColors.textPrimary,
                  ),
                ),
              ),
              Text(
                '${_digits(done)} / ${_digits(total)}',
                style: TextStyle(
                  fontSize: 13,
                  fontWeight: FontWeight.w600,
                  color: all ? AppColors.primaryBrand : AppColors.textSecondary,
                ),
              ),
            ],
          ),
          const SizedBox(height: 12),
          ClipRRect(
            borderRadius: BorderRadius.circular(6),
            child: LinearProgressIndicator(
              value: done / total,
              minHeight: 6,
              backgroundColor: AppColors.borderLight,
              color: AppColors.primaryBrand,
            ),
          ),
        ],
      ),
    );
  }

  Widget _divider() => Divider(
        color: AppColors.borderLight,
        thickness: 1,
        height: 1,
      );

  Widget _buildListTile({
    required IconData icon,
    required Color accent,
    required String title,
    required String subtitle,
    required bool isCompleted,
    required VoidCallback onTap,
  }) {
    return ListTile(
      contentPadding: const EdgeInsets.symmetric(horizontal: 16, vertical: 4),
      leading: Icon(icon, size: 26, color: accent),
      title: Text(
        title,
        style: TextStyle(
          fontSize: 15,
          fontWeight: FontWeight.bold,
          color: AppColors.textPrimary,
        ),
      ),
      subtitle: Padding(
        padding: const EdgeInsets.only(top: 2),
        child: Text(
          subtitle,
          style: TextStyle(
            fontSize: 12,
            color: AppColors.textSecondary,
          ),
        ),
      ),
      trailing: isCompleted
          ? Icon(Icons.check_circle_rounded,
              color: AppColors.primaryBrand, size: 26)
          : Icon(Icons.chevron_right_rounded,
              size: 24, color: AppColors.iconSecondary),
      onTap: onTap,
    );
  }
}
