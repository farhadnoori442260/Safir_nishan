import 'package:cached_network_image/cached_network_image.dart';
import 'package:easy_localization/easy_localization.dart' hide TextDirection;
import 'package:flutter/material.dart';
import 'package:provider/provider.dart';

import 'package:safir_drivers/pages/profileUpdation/driver_main_info.dart';
import 'package:safir_drivers/pages/profileUpdation/driving_license_update_screen.dart';
import 'package:safir_drivers/pages/profileUpdation/vehicleUpdation/vehicle_basic_info_screen.dart';
import 'package:safir_drivers/pages/profileUpdation/vehicleUpdation/vehicle_registration_update_screen.dart';
import 'package:safir_drivers/providers/authentication_provider.dart';
import 'package:safir_drivers/providers/registration_provider.dart';
import 'package:safir_drivers/utils/app_colors.dart';

import '../../widgets/rating_stars.dart';

class ProfilePage extends StatefulWidget {
  const ProfilePage({super.key});

  @override
  State<ProfilePage> createState() => _ProfilePageState();
}

class _ProfilePageState extends State<ProfilePage> {
  @override
  void initState() {
    super.initState();

    WidgetsBinding.instance.addPostFrameCallback((_) {
      if (mounted) {
        context.read<RegistrationProvider>().retrieveCurrentDriverInfo();
      }
    });
  }

  @override
  Widget build(BuildContext context) {
    final authProvider = context.watch<AuthenticationProvider>();

    return SafeArea(
      child: Scaffold(
        backgroundColor: AppColors.background,
        body: Consumer<RegistrationProvider>(
          builder: (context, regProvider, child) {
            final driver = regProvider.driverInformation;

            final String name =
                driver['name']?.toString().trim().isNotEmpty == true
                    ? driver['name'].toString()
                    : 'profile_name_not_set'.tr();

            final String phone =
                driver['phone']?.toString().trim().isNotEmpty == true
                    ? driver['phone'].toString()
                    : 'profile_phone_not_set'.tr();

            final String email = driver['email']?.toString().trim() ?? '';
            final String address = driver['address']?.toString().trim() ?? '';
            final String photo = driver['photo']?.toString().trim() ?? '';

            final double rating =
                double.tryParse(driver['rating']?.toString() ?? '5.0') ?? 5.0;

            return SingleChildScrollView(
              padding: const EdgeInsets.only(bottom: 105),
              child: Column(
                children: [
                  _buildProfileHeader(
                    name: name,
                    phone: phone,
                    email: email,
                    address: address,
                    photo: photo,
                    rating: rating,
                  ),

                  const SizedBox(height: 8),

                  _buildSectionTitle('profile_section_account'.tr()),

                  _buildProfileMenuOption(
                    context,
                    icon: Icons.account_circle_outlined,
                    title: 'profile_menu_account'.tr(),
                    subtitle: 'profile_menu_account_subtitle'.tr(),
                    onTap: () async {
                      await Navigator.push(
                        context,
                        MaterialPageRoute(
                          builder: (_) => const DriverMainInfo(),
                        ),
                      );

                      if (mounted) {
                        context
                            .read<RegistrationProvider>()
                            .retrieveCurrentDriverInfo();
                      }
                    },
                  ),

                  const SizedBox(height: 12),

                  _buildProfileMenuOption(
                    context,
                    icon: Icons.directions_car_filled_outlined,
                    title: 'profile_menu_vehicle'.tr(),
                    subtitle: 'profile_menu_vehicle_subtitle'.tr(),
                    onTap: () async {
                      await Navigator.push(
                        context,
                        MaterialPageRoute(
                          builder: (_) => const VehicleBasicInfoScreen(),
                        ),
                      );

                      if (mounted) {
                        context
                            .read<RegistrationProvider>()
                            .retrieveCurrentDriverInfo();
                      }
                    },
                  ),

                  const SizedBox(height: 20),

                  _buildSectionTitle('profile_section_documents'.tr()),

                  _buildProfileMenuOption(
                    context,
                    icon: Icons.badge_outlined,
                    title: 'profile_menu_license'.tr(),
                    subtitle: 'profile_menu_license_subtitle'.tr(),
                    onTap: () async {
                      await Navigator.push(
                        context,
                        MaterialPageRoute(
                          builder: (_) => const DrivingLicenseUpdateScreen(),
                        ),
                      );

                      if (mounted) {
                        context
                            .read<RegistrationProvider>()
                            .retrieveCurrentDriverInfo();
                      }
                    },
                  ),

                  const SizedBox(height: 12),

                  _buildProfileMenuOption(
                    context,
                    icon: Icons.description_outlined,
                    title: 'profile_menu_vehicle_registration'.tr(),
                    subtitle:
                        'profile_menu_vehicle_registration_subtitle'.tr(),
                    onTap: () async {
                      await Navigator.push(
                        context,
                        MaterialPageRoute(
                          builder: (_) =>
                              const VehicleRegistrationUpdateScreen(),
                        ),
                      );

                      if (mounted) {
                        context
                            .read<RegistrationProvider>()
                            .retrieveCurrentDriverInfo();
                      }
                    },
                  ),

                  const SizedBox(height: 20),

                  _buildSectionTitle('profile_section_app'.tr()),

                  _buildProfileMenuOption(
                    context,
                    icon: Icons.settings_outlined,
                    title: 'profile_menu_settings'.tr(),
                    subtitle: 'profile_menu_settings_subtitle'.tr(),
                    onTap: () {
                      Navigator.push(
                        context,
                        MaterialPageRoute(
                          builder: (_) => const SettingsPage(),
                        ),
                      );
                    },
                  ),

                  const SizedBox(height: 12),

                  _buildProfileMenuOption(
                    context,
                    icon: Icons.help_outline_rounded,
                    title: 'profile_menu_support'.tr(),
                    subtitle: 'profile_menu_support_subtitle'.tr(),
                    onTap: () {
                      _showSupportDialog(context);
                    },
                  ),

                  const SizedBox(height: 12),

                  _buildProfileMenuOption(
                    context,
                    icon: Icons.privacy_tip_outlined,
                    title: 'profile_menu_privacy'.tr(),
                    subtitle: 'profile_menu_privacy_subtitle'.tr(),
                    onTap: () {
                      _showPrivacyPage(context);
                    },
                  ),

                  const SizedBox(height: 12),

                  _buildProfileMenuOption(
                    context,
                    icon: Icons.info_outline_rounded,
                    title: 'profile_menu_about'.tr(),
                    subtitle: 'profile_menu_about_subtitle'.tr(),
                    onTap: () {
                      _showAboutDialog(context);
                    },
                  ),

                  const SizedBox(height: 20),

                  _buildSectionTitle(
                    'profile_section_account_management'.tr(),
                    color: Colors.red.shade700,
                  ),

                  _buildProfileMenuOption(
                    context,
                    icon: Icons.delete_outline_rounded,
                    iconColor: Colors.red.shade700,
                    title: 'profile_menu_delete_account'.tr(),
                    subtitle: 'profile_menu_delete_account_subtitle'.tr(),
                    onTap: () {
                      _showDeleteAccountDialog(context, authProvider);
                    },
                  ),
                ],
              ),
            );
          },
        ),
        floatingActionButton: FloatingActionButton.extended(
          backgroundColor: Colors.red.shade700,
          onPressed: authProvider.isLoading
              ? null
              : () async {
                  await authProvider.signOut(context);
                },
          icon: const Icon(
            Icons.logout_rounded,
            color: Colors.white,
            size: 18,
          ),
          label: Text(
            'profile_logout'.tr(),
            style: const TextStyle(
              color: AppColors.buttonText,
              fontWeight: FontWeight.bold,
              fontSize: 14,
            ),
          ),
        ),
      ),
    );
  }

  Widget _buildProfileHeader({
    required String name,
    required String phone,
    required String email,
    required String address,
    required String photo,
    required double rating,
  }) {
    return Center(
      child: Padding(
        padding: const EdgeInsets.fromLTRB(16, 24, 16, 16),
        child: Container(
          width: double.infinity,
          padding: const EdgeInsets.all(16),
          decoration: BoxDecoration(
            color: AppColors.cardBackground,
            borderRadius: BorderRadius.circular(18),
            boxShadow: const [
              BoxShadow(
                color: Colors.black12,
                offset: Offset(0, 2),
                blurRadius: 8,
              ),
            ],
          ),
          child: Row(
            children: [
              SizedBox(
                height: 80,
                width: 80,
                child: photo.isNotEmpty
                    ? CachedNetworkImage(
                        imageUrl: photo,
                        imageBuilder: (context, imageProvider) => Container(
                          decoration: BoxDecoration(
                            shape: BoxShape.circle,
                            border: Border.all(
                              color: AppColors.primaryBrand.withOpacity(0.2),
                              width: 2,
                            ),
                            image: DecorationImage(
                              image: imageProvider,
                              fit: BoxFit.cover,
                            ),
                          ),
                        ),
                        placeholder: (_, __) => const Center(
                          child: CircularProgressIndicator(
                            strokeWidth: 2,
                            color: AppColors.primaryBrand,
                          ),
                        ),
                        errorWidget: (_, __, ___) => _buildAvatarPlaceholder(),
                      )
                    : _buildAvatarPlaceholder(),
              ),
              const SizedBox(width: 14),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      name,
                      maxLines: 1,
                      overflow: TextOverflow.ellipsis,
                      style: const TextStyle(
                        fontSize: 16,
                        fontWeight: FontWeight.bold,
                        color: AppColors.textPrimary,
                      ),
                    ),
                    const SizedBox(height: 7),
                    _buildHeaderRow(
                      icon: Icons.phone_outlined,
                      child: Directionality(
                        textDirection: TextDirection.ltr,
                        child: Text(
                          phone,
                          maxLines: 1,
                          overflow: TextOverflow.ellipsis,
                          style: const TextStyle(
                            fontSize: 13,
                            color: AppColors.textPrimary,
                          ),
                        ),
                      ),
                    ),
                    if (email.isNotEmpty) ...[
                      const SizedBox(height: 5),
                      _buildHeaderRow(
                        icon: Icons.email_outlined,
                        child: Text(
                          email,
                          maxLines: 1,
                          overflow: TextOverflow.ellipsis,
                          style: const TextStyle(
                            fontSize: 12,
                            color: AppColors.textSecondary,
                          ),
                        ),
                      ),
                    ],
                    if (address.isNotEmpty) ...[
                      const SizedBox(height: 5),
                      _buildHeaderRow(
                        icon: Icons.location_on_outlined,
                        child: Text(
                          address,
                          maxLines: 1,
                          overflow: TextOverflow.ellipsis,
                          style: const TextStyle(
                            fontSize: 12,
                            color: AppColors.textSecondary,
                          ),
                        ),
                      ),
                    ],
                    const SizedBox(height: 9),
                    RatingStars(ratting: rating.toStringAsFixed(1)),
                  ],
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }

  Widget _buildHeaderRow({
    required IconData icon,
    required Widget child,
  }) {
    return Row(
      children: [
        Icon(
          icon,
          size: 14,
          color: AppColors.textSecondary,
        ),
        const SizedBox(width: 6),
        Expanded(child: child),
      ],
    );
  }

  Widget _buildAvatarPlaceholder() {
    return CircleAvatar(
      backgroundColor: Colors.grey.shade200,
      child: Icon(
        Icons.person_rounded,
        color: Colors.grey.shade500,
        size: 42,
      ),
    );
  }

  Widget _buildSectionTitle(
    String title, {
    Color? color,
  }) {
    return Container(
      width: double.infinity,
      margin: const EdgeInsets.fromLTRB(20, 8, 20, 10),
      child: Text(
        title,
        style: TextStyle(
          fontSize: 12,
          fontWeight: FontWeight.bold,
          color: color ?? AppColors.textSecondary,
        ),
      ),
    );
  }

  Widget _buildProfileMenuOption(
    BuildContext context, {
    required IconData icon,
    required String title,
    required String subtitle,
    required VoidCallback onTap,
    Color? iconColor,
  }) {
    final bool isRtl = Directionality.of(context) == TextDirection.rtl;
    final Color currentIconColor = iconColor ?? AppColors.primaryBrand;

    return Container(
      width: MediaQuery.of(context).size.width * 0.92,
      decoration: BoxDecoration(
        color: AppColors.cardBackground,
        borderRadius: BorderRadius.circular(14),
        boxShadow: const [
          BoxShadow(
            color: Colors.black12,
            offset: Offset(0, 1),
            blurRadius: 4,
          ),
        ],
      ),
      child: Material(
        color: Colors.transparent,
        borderRadius: BorderRadius.circular(14),
        child: InkWell(
          onTap: onTap,
          borderRadius: BorderRadius.circular(14),
          child: Padding(
            padding: const EdgeInsets.symmetric(
              horizontal: 16,
              vertical: 13,
            ),
            child: Row(
              children: [
                Icon(
                  icon,
                  color: currentIconColor,
                  size: 24,
                ),
                const SizedBox(width: 14),
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        title,
                        style: const TextStyle(
                          fontSize: 14,
                          fontWeight: FontWeight.w600,
                          color: AppColors.textPrimary,
                        ),
                      ),
                      const SizedBox(height: 3),
                      Text(
                        subtitle,
                        maxLines: 1,
                        overflow: TextOverflow.ellipsis,
                        style: const TextStyle(
                          fontSize: 11,
                          color: AppColors.textSecondary,
                        ),
                      ),
                    ],
                  ),
                ),
                const SizedBox(width: 8),
                Icon(
                  isRtl ? Icons.chevron_left : Icons.chevron_right,
                  color: AppColors.textSecondary.withOpacity(0.55),
                  size: 21,
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }

  void _showSupportDialog(BuildContext context) {
    showDialog(
      context: context,
      builder: (dialogContext) {
        return AlertDialog(
          backgroundColor: AppColors.cardBackground,
          shape: RoundedRectangleBorder(
            borderRadius: BorderRadius.circular(18),
          ),
          title: Text(
            'profile_menu_support'.tr(),
            style: const TextStyle(
              color: AppColors.textPrimary,
              fontWeight: FontWeight.bold,
              fontSize: 16,
            ),
          ),
          content: Text(
            'support_dialog_message'.tr(),
            style: const TextStyle(
              color: AppColors.textSecondary,
              height: 1.5,
            ),
          ),
          actions: [
            TextButton(
              onPressed: () => Navigator.pop(dialogContext),
              child: Text('close'.tr()),
            ),
          ],
        );
      },
    );
  }

  void _showPrivacyPage(BuildContext context) {
    Navigator.push(
      context,
      MaterialPageRoute(
        builder: (_) => const PrivacyPolicyPage(),
      ),
    );
  }

  void _showAboutDialog(BuildContext context) {
    showAboutDialog(
      context: context,
      applicationName: 'app_name'.tr(),
      applicationVersion: '1.0.0',
      applicationIcon: const Icon(
        Icons.local_taxi_rounded,
        color: AppColors.primaryBrand,
        size: 44,
      ),
      children: [
        const SizedBox(height: 12),
        Text(
          'profile_about_description'.tr(),
          style: const TextStyle(
            color: AppColors.textSecondary,
            height: 1.5,
          ),
        ),
      ],
    );
  }

  void _showDeleteAccountDialog(
    BuildContext context,
    AuthenticationProvider authProvider,
  ) {
    showDialog(
      context: context,
      barrierDismissible: false,
      builder: (dialogContext) {
        bool isDeleting = false;

        return StatefulBuilder(
          builder: (context, setDialogState) {
            return AlertDialog(
              backgroundColor: AppColors.cardBackground,
              shape: RoundedRectangleBorder(
                borderRadius: BorderRadius.circular(18),
              ),
              title: Text(
                'profile_menu_delete_account'.tr(),
                style: TextStyle(
                  color: Colors.red.shade700,
                  fontWeight: FontWeight.bold,
                  fontSize: 16,
                ),
              ),
              content: Text(
                'delete_account_confirmation'.tr(),
                style: const TextStyle(
                  color: AppColors.textSecondary,
                  height: 1.5,
                ),
              ),
              actions: [
                TextButton(
                  onPressed: isDeleting
                      ? null
                      : () => Navigator.pop(dialogContext),
                  child: Text('btn_cancel'.tr()),
                ),
                ElevatedButton(
                  onPressed: isDeleting
                      ? null
                      : () async {
                          setDialogState(() {
                            isDeleting = true;
                          });

                          final bool deleted =
                              await authProvider.deleteCurrentDriverAccount(
                            context,
                          );

                          if (!context.mounted) return;

                          if (deleted) {
                            if (dialogContext.mounted) {
                              Navigator.pop(dialogContext);
                            }

                            ScaffoldMessenger.of(context).showSnackBar(
                              SnackBar(
                                content: Text(
                                  'account_delete_success'.tr(),
                                ),
                              ),
                            );

                            await authProvider.signOut(context);
                          } else {
                            if (dialogContext.mounted) {
                              setDialogState(() {
                                isDeleting = false;
                              });
                            }
                          }
                        },
                  style: ElevatedButton.styleFrom(
                    backgroundColor: Colors.red.shade700,
                    foregroundColor: Colors.white,
                  ),
                  child: isDeleting
                      ? const SizedBox(
                          height: 18,
                          width: 18,
                          child: CircularProgressIndicator(
                            strokeWidth: 2,
                            color: Colors.white,
                          ),
                        )
                      : Text('btn_delete'.tr()),
                ),
              ],
            );
          },
        );
      },
    );
  }
}

class PrivacyPolicyPage extends StatelessWidget {
  const PrivacyPolicyPage({super.key});

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: AppColors.background,
      appBar: AppBar(
        backgroundColor: AppColors.cardBackground,
        elevation: 1,
        centerTitle: true,
        iconTheme: const IconThemeData(
          color: AppColors.textPrimary,
        ),
        title: Text(
          'profile_menu_privacy'.tr(),
          style: const TextStyle(
            fontSize: 16,
            fontWeight: FontWeight.bold,
            color: AppColors.textPrimary,
          ),
        ),
      ),
      body: SingleChildScrollView(
        padding: const EdgeInsets.all(16),
        child: Container(
          width: double.infinity,
          padding: const EdgeInsets.all(18),
          decoration: BoxDecoration(
            color: AppColors.cardBackground,
            borderRadius: BorderRadius.circular(16),
          ),
          child: Text(
            'privacy_policy_text'.tr(),
            style: const TextStyle(
              fontSize: 14,
              height: 1.8,
              color: AppColors.textPrimary,
            ),
          ),
        ),
      ),
    );
  }
}

class SettingsPage extends StatelessWidget {
  const SettingsPage({super.key});

  @override
  Widget build(BuildContext context) {
    final bool isRtl = Directionality.of(context) == TextDirection.rtl;

    return Scaffold(
      backgroundColor: AppColors.background,
      appBar: AppBar(
        title: Text(
          'settings_title'.tr(),
          style: const TextStyle(
            fontSize: 16,
            fontWeight: FontWeight.bold,
            color: AppColors.textPrimary,
          ),
        ),
        centerTitle: true,
        backgroundColor: AppColors.cardBackground,
        elevation: 1,
        iconTheme: const IconThemeData(
          color: AppColors.textPrimary,
        ),
      ),
      body: Padding(
        padding: const EdgeInsets.all(16),
        child: _buildSettingsTile(
          context,
          icon: Icons.language_rounded,
          title: 'settings_language'.tr(),
          subtitle: _getCurrentLanguageName(context),
          onTap: () {
            Navigator.push(
              context,
              MaterialPageRoute(
                builder: (_) => const LanguagePage(),
              ),
            );
          },
          isRtl: isRtl,
        ),
      ),
    );
  }

  String _getCurrentLanguageName(BuildContext context) {
    switch (context.locale.languageCode) {
      case 'fa':
        return 'language_dari'.tr();
      case 'ps':
        return 'language_pashto'.tr();
      case 'en':
      default:
        return 'language_english'.tr();
    }
  }

  Widget _buildSettingsTile(
    BuildContext context, {
    required IconData icon,
    required String title,
    required String subtitle,
    required VoidCallback onTap,
    required bool isRtl,
  }) {
    return Container(
      decoration: BoxDecoration(
        color: AppColors.cardBackground,
        borderRadius: BorderRadius.circular(14),
        boxShadow: const [
          BoxShadow(
            color: Colors.black12,
            offset: Offset(0, 1),
            blurRadius: 4,
          ),
        ],
      ),
      child: ListTile(
        onTap: onTap,
        leading: Icon(
          icon,
          color: AppColors.primaryBrand,
        ),
        title: Text(
          title,
          style: const TextStyle(
            fontWeight: FontWeight.w600,
            color: AppColors.textPrimary,
            fontSize: 14,
          ),
        ),
        subtitle: Text(
          subtitle,
          style: const TextStyle(
            color: AppColors.textSecondary,
            fontSize: 12,
          ),
        ),
        trailing: Icon(
          isRtl ? Icons.chevron_left : Icons.chevron_right,
          color: AppColors.textSecondary.withOpacity(0.5),
        ),
      ),
    );
  }
}

class LanguagePage extends StatefulWidget {
  const LanguagePage({super.key});

  @override
  State<LanguagePage> createState() => _LanguagePageState();
}

class _LanguagePageState extends State<LanguagePage> {
  late Locale _selectedLocale;

  @override
  void didChangeDependencies() {
    super.didChangeDependencies();
    _selectedLocale = context.locale;
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: AppColors.background,
      appBar: AppBar(
        title: Text(
          'select_language_title'.tr(),
          style: const TextStyle(
            fontSize: 16,
            fontWeight: FontWeight.bold,
            color: AppColors.textPrimary,
          ),
        ),
        centerTitle: true,
        backgroundColor: AppColors.cardBackground,
        elevation: 1,
        iconTheme: const IconThemeData(
          color: AppColors.textPrimary,
        ),
      ),
      body: Padding(
        padding: const EdgeInsets.all(20),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text(
              'select_language_title'.tr(),
              style: const TextStyle(
                fontSize: 15,
                fontWeight: FontWeight.bold,
                color: AppColors.textPrimary,
              ),
            ),
            const SizedBox(height: 16),
            _buildLanguageOption(
              title: 'language_dari'.tr(),
              locale: const Locale('fa'),
            ),
            _buildLanguageOption(
              title: 'language_pashto'.tr(),
              locale: const Locale('ps'),
            ),
            _buildLanguageOption(
              title: 'language_english'.tr(),
              locale: const Locale('en'),
            ),
            const Spacer(),
            SizedBox(
              width: double.infinity,
              child: ElevatedButton(
                onPressed: () async {
                  await context.setLocale(_selectedLocale);

                  if (!mounted) return;

                  ScaffoldMessenger.of(context).showSnackBar(
                    SnackBar(
                      content: Text('lang_change_success'.tr()),
                    ),
                  );

                  Navigator.pop(context);
                },
                style: ElevatedButton.styleFrom(
                  backgroundColor: AppColors.primaryBrand,
                  foregroundColor: Colors.white,
                  padding: const EdgeInsets.symmetric(vertical: 16),
                  shape: RoundedRectangleBorder(
                    borderRadius: BorderRadius.circular(14),
                  ),
                  elevation: 0,
                ),
                child: Text(
                  'btn_confirm'.tr(),
                  style: const TextStyle(
                    fontWeight: FontWeight.bold,
                    fontSize: 16,
                  ),
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildLanguageOption({
    required String title,
    required Locale locale,
  }) {
    final bool isSelected =
        _selectedLocale.languageCode == locale.languageCode;

    return Container(
      margin: const EdgeInsets.only(bottom: 12),
      decoration: BoxDecoration(
        color: AppColors.cardBackground,
        borderRadius: BorderRadius.circular(12),
        border: Border.all(
          color: isSelected ? AppColors.primaryBrand : Colors.transparent,
          width: 2,
        ),
      ),
      child: ListTile(
        title: Text(
          title,
          style: TextStyle(
            fontWeight: isSelected ? FontWeight.bold : FontWeight.normal,
            color: AppColors.textPrimary,
          ),
        ),
        trailing: isSelected
            ? const Icon(
                Icons.check_circle,
                color: AppColors.primaryBrand,
              )
            : const Icon(
                Icons.radio_button_unchecked,
                color: Colors.grey,
              ),
        onTap: () {
          setState(() {
            _selectedLocale = locale;
          });
        },
      ),
    );
  }
}
