import 'package:cached_network_image/cached_network_image.dart';
import 'package:easy_localization/easy_localization.dart' hide TextDirection;
import 'package:flutter/material.dart';
import 'package:provider/provider.dart';

import 'package:safir_drivers/pages/profile/profile_page.dart';
import 'package:safir_drivers/pages/trips/trips_history_page.dart';
import 'package:safir_drivers/providers/dashboard_provider.dart';
import 'package:safir_drivers/providers/registration_provider.dart';
import 'package:safir_drivers/utils/app_colors.dart';

String _t(String key, String fallback) {
  final String v = key.tr();
  return (v.trim().isEmpty || v == key) ? fallback : v;
}

/// کشوی راننده: پروفایل، تنظیمات و چیزهای کم‌استفاده.
/// (آنلاین، درآمد و مسیریابی روی نقشه‌اند و اینجا نیستند.)
class DriverDrawer extends StatelessWidget {
  const DriverDrawer({super.key});

  @override
  Widget build(BuildContext context) {
    // پیش از بسته‌شدن کشو گرفته می‌شود تا بعد از آن هم کار کند
    final NavigatorState nav = Navigator.of(context);
    final ScaffoldState scaffold = Scaffold.of(context);

    void go(Widget page) {
      scaffold.closeEndDrawer();
      nav.push(MaterialPageRoute<void>(builder: (_) => page));
    }

    return Drawer(
      width: MediaQuery.of(context).size.width * 0.82,
      backgroundColor: AppColors.background,
      surfaceTintColor: Colors.transparent,
      elevation: 0,
      shape: const RoundedRectangleBorder(),
      child: SafeArea(
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: <Widget>[
            _header(context, () => go(const ProfilePage(asRoute: true))),
            Divider(height: 1, thickness: 1.0, color: AppColors.borderLight),
            Expanded(
              child: ListView(
                padding: const EdgeInsets.symmetric(vertical: 8),
                children: <Widget>[
                  _item(
                    Icons.settings_outlined,
                    _t('profile_menu_settings', 'تنظیمات'),
                    () => go(const SettingsPage()),
                  ),
                  Divider(
                    height: 17,
                    thickness: 1.0,
                    indent: 16,
                    endIndent: 16,
                    color: AppColors.borderLight,
                  ),
                  _item(
                    Icons.history_rounded,
                    _t('profile_menu_trips_history', 'تاریخچه سفرها'),
                    () => go(const TripsHistoryPage()),
                  ),
                  _item(
                    Icons.account_balance_wallet_outlined,
                    _t('nav_earnings', 'درآمد'),
                    () {
                      scaffold.closeEndDrawer();
                      context.read<DashboardProvider>().setIndex(1);
                    },
                  ),
                  Divider(
                    height: 17,
                    thickness: 1.0,
                    indent: 16,
                    endIndent: 16,
                    color: AppColors.borderLight,
                  ),
                  _item(
                    Icons.help_outline_rounded,
                    _t('profile_menu_support', 'پشتیبانی'),
                    () {
                      scaffold.closeEndDrawer();
                      showDialog<void>(
                        context: nav.context,
                        builder: (BuildContext d) => AlertDialog(
                          backgroundColor: AppColors.cardBackground,
                          shape: RoundedRectangleBorder(
                            borderRadius: BorderRadius.circular(18),
                          ),
                          title: Text(
                            _t('profile_menu_support', 'پشتیبانی'),
                            style: TextStyle(
                              color: AppColors.textPrimary,
                              fontWeight: FontWeight.bold,
                              fontSize: 16,
                            ),
                          ),
                          content: Text(
                            'support_dialog_message'.tr(),
                            style: TextStyle(
                              color: AppColors.textSecondary,
                              height: 1.5,
                            ),
                          ),
                          actions: <Widget>[
                            TextButton(
                              onPressed: () => Navigator.pop(d),
                              child: Text(_t('close', 'بستن')),
                            ),
                          ],
                        ),
                      );
                    },
                  ),
                  _item(
                    Icons.privacy_tip_outlined,
                    _t('profile_menu_privacy', 'حریم خصوصی'),
                    () => go(const PrivacyPolicyPage()),
                  ),
                ],
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _header(BuildContext context, VoidCallback onTap) {
    return Consumer<RegistrationProvider>(
      builder: (BuildContext context, RegistrationProvider reg, Widget? _) {
        final dynamic info = reg.driverInformation;
        final String name = info['name']?.toString().trim() ?? '';
        final String phone = info['phone']?.toString().trim() ?? '';
        final String photo = info['photo']?.toString().trim() ?? '';
        final double rating =
            double.tryParse(info['rating']?.toString() ?? '') ?? 0.0;

        Widget placeholder() => Container(
              decoration: BoxDecoration(
                shape: BoxShape.circle,
                color: AppColors.cardBackground,
                border: Border.all(color: AppColors.borderLight, width: 1.0),
              ),
              child: Icon(
                Icons.person_rounded,
                color: AppColors.iconSecondary,
                size: 32,
              ),
            );

        return InkWell(
          onTap: onTap,
          child: Padding(
            padding: const EdgeInsets.fromLTRB(16, 18, 16, 16),
            child: Row(
              children: <Widget>[
                SizedBox(
                  width: 60,
                  height: 60,
                  child: photo.isEmpty
                      ? placeholder()
                      : CachedNetworkImage(
                          imageUrl: photo,
                          imageBuilder: (_, ImageProvider img) => Container(
                            decoration: BoxDecoration(
                              shape: BoxShape.circle,
                              border: Border.all(
                                color: AppColors.borderLight,
                                width: 1.0,
                              ),
                              image: DecorationImage(
                                image: img,
                                fit: BoxFit.cover,
                              ),
                            ),
                          ),
                          placeholder: (_, __) => placeholder(),
                          errorWidget: (_, __, ___) => placeholder(),
                        ),
                ),
                const SizedBox(width: 14),
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: <Widget>[
                      Text(
                        name.isEmpty ? 'profile_name_not_set'.tr() : name,
                        maxLines: 1,
                        overflow: TextOverflow.ellipsis,
                        style: TextStyle(
                          fontSize: 16,
                          fontWeight: FontWeight.w800,
                          color: AppColors.textPrimary,
                        ),
                      ),
                      if (phone.isNotEmpty) ...<Widget>[
                        const SizedBox(height: 4),
                        Directionality(
                          textDirection: TextDirection.ltr,
                          child: Text(
                            phone,
                            style: TextStyle(
                              fontSize: 12.5,
                              color: AppColors.textSecondary,
                            ),
                          ),
                        ),
                      ],
                      if (rating > 0) ...<Widget>[
                        const SizedBox(height: 4),
                        Row(
                          mainAxisSize: MainAxisSize.min,
                          children: <Widget>[
                            Icon(
                              Icons.star_rounded,
                              size: 16,
                              color: AppColors.warning,
                            ),
                            const SizedBox(width: 3),
                            Text(
                              rating.toStringAsFixed(1),
                              style: TextStyle(
                                fontSize: 12.5,
                                fontWeight: FontWeight.w700,
                                color: AppColors.textPrimary,
                              ),
                            ),
                          ],
                        ),
                      ],
                    ],
                  ),
                ),
                Icon(
                  Directionality.of(context) == TextDirection.rtl
                      ? Icons.chevron_left_rounded
                      : Icons.chevron_right_rounded,
                  color: AppColors.textSecondary,
                  size: 26,
                ),
              ],
            ),
          ),
        );
      },
    );
  }

  Widget _item(IconData icon, String title, VoidCallback onTap) {
    return InkWell(
      onTap: onTap,
      child: Padding(
        padding: const EdgeInsets.symmetric(horizontal: 18, vertical: 14),
        child: Row(
          children: <Widget>[
            Icon(icon, size: 23, color: AppColors.iconSecondary),
            const SizedBox(width: 16),
            Expanded(
              child: Text(
                title,
                style: TextStyle(
                  fontSize: 14.5,
                  fontWeight: FontWeight.w600,
                  color: AppColors.textPrimary,
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }
}
