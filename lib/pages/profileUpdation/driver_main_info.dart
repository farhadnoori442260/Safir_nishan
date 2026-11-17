import 'package:easy_localization/easy_localization.dart' hide TextDirection;
import 'package:flutter/material.dart';
import 'package:provider/provider.dart';

import 'package:safir_drivers/pages/profileUpdation/basic_driver_info_update_screen.dart'; 
import 'package:safir_drivers/pages/profileUpdation/cninc_update_screen.dart';
import 'package:safir_drivers/pages/profileUpdation/driving_license_update_screen.dart';
import 'package:safir_drivers/pages/profileUpdation/selfie_with_cninc_update_screen.dart';
import 'package:safir_drivers/pages/profileUpdation/vehicle_info_update_screen.dart';
import 'package:safir_drivers/providers/registration_provider.dart';
import 'package:safir_drivers/utils/app_colors.dart';

class DriverMainInfo extends StatefulWidget {
  const DriverMainInfo({super.key});

  @override
  State<DriverMainInfo> createState() => _DriverMainInfoState();
}

class _DriverMainInfoState extends State<DriverMainInfo> {
  bool _forceShowContent = false; // میان‌بر برای رد کردن لودینگ در صورت تایم‌اوت شبکه

  @override
  void initState() {
    super.initState();
    Future.delayed(Duration.zero, () {
      _fetchUserData();
    });
  }

  Future<void> _fetchUserData() async {
    // اگر بعد از ۴ ثانیه پاسخی از سرور نیامد، لودینگ را متوقف کن
    Future.delayed(const Duration(seconds: 4), () {
      if (mounted && !_forceShowContent) {
        setState(() {
          _forceShowContent = true;
        });
      }
    });

    try {
      await Provider.of<RegistrationProvider>(context, listen: false)
          .fetchUserData();
    } catch (e) {
      debugPrint('Error fetching user data: $e');
    }
  }

  @override
  Widget build(BuildContext context) {
    return Consumer<RegistrationProvider>(builder: (context, provider, child) {
      final isLoading = provider.isFetchLoading && !_forceShowContent;

      // آرایه آیتم‌های لیست برای کدهای تمیزتر و پویایی بهتر
      final List<Map<String, dynamic>> steps = [
        {
          'title': 'step_basic_info_title'.tr(),
          'subtitle': 'step_basic_info_sub'.tr(),
          'icon': Icons.person_outline_rounded,
          'color': AppColors.originBlue,
          'screen': const BasicDriverInfoUpdateScreen(),
        },
        {
          'title': 'step_cnic_title'.tr(),
          'subtitle': 'step_cnic_sub'.tr(),
          'icon': Icons.badge_outlined,
          'color': AppColors.accentPurple,
          'screen': const CnincUpdateScreen(),
        },
        {
          'title': 'step_selfie_title'.tr(),
          'subtitle': 'step_selfie_sub'.tr(),
          'icon': Icons.face_retouching_natural_outlined,
          'color': AppColors.accentTeal,
          'screen': const SelfieWithCnincUpdateScreen(),
        },
        {
          'title': 'step_license_title'.tr(),
          'subtitle': 'step_license_sub'.tr(),
          'icon': Icons.credit_card_outlined,
          'color': AppColors.accentOrange,
          'screen': const DrivingLicenseUpdateScreen(),
        },
        {
          'title': 'step_vehicle_title'.tr(),
          'subtitle': 'step_vehicle_sub'.tr(),
          'icon': Icons.directions_car_filled_outlined,
          'color': AppColors.success,
          'screen': const VehicleInfoUpdateScreen(),
        },
      ];

      return Scaffold(
        backgroundColor: AppColors.background,
        appBar: AppBar(
          backgroundColor: AppColors.cardBackground,
          surfaceTintColor: AppColors.cardBackground,
          elevation: 0,
          scrolledUnderElevation: 0,
          iconTheme: IconThemeData(color: AppColors.textPrimary),
          title: Text(
            'reg_steps_title'.tr(),
            style: TextStyle(
              fontWeight: FontWeight.bold,
              fontSize: 16,
              color: AppColors.textPrimary,
            ),
          ),
          centerTitle: true,
        ),
        body: isLoading
            ? Center(
                child: Column(
                  mainAxisAlignment: MainAxisAlignment.center,
                  children: [
                    Text(
                      'please_wait'.tr(),
                      style: TextStyle(
                        fontSize: 14,
                        color: AppColors.textSecondary,
                      ),
                    ),
                    const SizedBox(height: 16),
                    CircularProgressIndicator(
                      color: AppColors.primaryBrand,
                    ),
                  ],
                ),
              )
            : SingleChildScrollView(
                padding: const EdgeInsets.fromLTRB(16, 16, 16, 24),
                child: Container(
                  decoration: BoxDecoration(
                    borderRadius: BorderRadius.circular(18),
                    color: AppColors.cardBackground,
                    border: Border.all(color: AppColors.borderLight),
                  ),
                  child: ClipRRect(
                    borderRadius: BorderRadius.circular(18),
                    child: Column(
                      children: [
                        for (int i = 0; i < steps.length; i++) ...[
                          _buildListTile(
                            title: steps[i]['title'] as String,
                            subtitle: steps[i]['subtitle'] as String,
                            icon: steps[i]['icon'] as IconData,
                            color: steps[i]['color'] as Color,
                            onTap: () async {
                              await Navigator.push(
                                context,
                                MaterialPageRoute(
                                  builder: (context) =>
                                      steps[i]['screen'] as Widget,
                                ),
                              );
                            },
                          ),
                          if (i != steps.length - 1)
                            Divider(
                              color: AppColors.borderLight,
                              thickness: 1,
                              height: 1,
                              indent: 64,
                              endIndent: 16,
                            ),
                        ],
                      ],
                    ),
                  ),
                ),
              ),
      );
    });
  }

  Widget _buildListTile({
    required String title,
    required String subtitle,
    required IconData icon,
    required Color color,
    required VoidCallback onTap,
  }) {
    final bool isRtl = Directionality.of(context) == TextDirection.rtl;
    return ListTile(
      contentPadding: const EdgeInsets.symmetric(horizontal: 16, vertical: 4),
      leading: Icon(icon, color: color, size: 24),
      title: Text(
        title,
        style: TextStyle(
          fontSize: 15,
          fontWeight: FontWeight.bold,
          color: AppColors.textPrimary,
        ),
      ),
      subtitle: Text(
        subtitle,
        style: TextStyle(
          fontSize: 12,
          color: AppColors.textSecondary,
        ),
      ),
      trailing: Icon(
        isRtl ? Icons.chevron_left_rounded : Icons.chevron_right_rounded,
        size: 22,
        color: AppColors.iconSecondary,
      ),
      onTap: onTap,
    );
  }
}
