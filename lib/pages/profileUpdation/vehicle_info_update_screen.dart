import 'package:easy_localization/easy_localization.dart' hide TextDirection;
import 'package:flutter/material.dart';

import 'package:safir_drivers/pages/profileUpdation/vehicleUpdation/driver_car_image_update_screen.dart';
import 'package:safir_drivers/pages/profileUpdation/vehicleUpdation/vehicle_basic_info_update_screen.dart';
import 'package:safir_drivers/pages/profileUpdation/vehicleUpdation/vehicle_registration_update_screen.dart';
import 'package:safir_drivers/utils/app_colors.dart';

class VehicleInfoUpdateScreen extends StatelessWidget {
  const VehicleInfoUpdateScreen({super.key});

  @override
  Widget build(BuildContext context) {
    // زیرمجموعه‌های بخش اطلاعات موتر
    final List<Map<String, dynamic>> subSteps = [
      {
        'title': 'vehicle_basic_info_title'.tr(),
        'subtitle': 'vehicle_basic_info_subtitle'.tr(),
        'icon': Icons.directions_car_filled_outlined,
        'color': AppColors.originBlue,
        'screen': const VehicleBasicInfoUpdateScreen(),
      },
      {
        'title': 'vehicle_image_title'.tr(),
        'subtitle': 'vehicle_image_subtitle'.tr(),
        'icon': Icons.photo_camera_outlined,
        'color': AppColors.accentTeal,
        'screen': const DriverCarImageUpdateScreen(),
      },
      {
        'title': 'vehicle_doc_title'.tr(),
        'subtitle': 'vehicle_doc_subtitle'.tr(),
        'icon': Icons.description_outlined,
        'color': AppColors.accentPurple,
        'screen': const VehicleRegistrationUpdateScreen(),
      },
    ];

    return Scaffold(
      backgroundColor: AppColors.background,
      appBar: AppBar(
        title: Text(
          'vehicle_info_title'.tr(),
          style: TextStyle(
            fontWeight: FontWeight.bold,
            fontSize: 16,
            color: AppColors.textPrimary,
          ),
        ),
        centerTitle: true,
        backgroundColor: AppColors.cardBackground,
        surfaceTintColor: AppColors.cardBackground,
        elevation: 0,
        scrolledUnderElevation: 0,
        iconTheme: IconThemeData(color: AppColors.textPrimary),
      ),
      body: SingleChildScrollView(
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
                for (int i = 0; i < subSteps.length; i++) ...[
                  _buildTile(
                    context,
                    title: subSteps[i]['title'] as String,
                    subtitle: subSteps[i]['subtitle'] as String,
                    icon: subSteps[i]['icon'] as IconData,
                    color: subSteps[i]['color'] as Color,
                    onTap: () async {
                      await Navigator.push(
                        context,
                        MaterialPageRoute(
                          builder: (context) => subSteps[i]['screen'] as Widget,
                        ),
                      );
                    },
                  ),
                  if (i != subSteps.length - 1)
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
  }

  Widget _buildTile(
    BuildContext context, {
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
      subtitle: Padding(
        padding: const EdgeInsets.only(top: 4.0),
        child: Text(
          subtitle,
          style: TextStyle(
            fontSize: 12,
            color: AppColors.textSecondary,
          ),
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
