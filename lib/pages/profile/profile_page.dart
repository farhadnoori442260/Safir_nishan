import 'package:cached_network_image/cached_network_image.dart';
import 'package:easy_localization/easy_localization.dart' hide TextDirection;
import 'package:flutter/material.dart';
import 'package:provider/provider.dart';

import 'package:safir_drivers/pages/profileUpdation/driver_main_info.dart';
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
      if (!mounted) return;

      context.read<RegistrationProvider>().retrieveCurrentDriverInfo();
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
            final String addressStr =
                driver['address']?.toString().trim() ?? '';
            final String photo = driver['photo']?.toString().trim() ?? '';

            final double ratingVal =
                double.tryParse(driver['rating']?.toString() ?? '5.0') ??
                    5.0;

            return SingleChildScrollView(
              padding: const EdgeInsets.only(bottom: 110),
              child: Column(
                children: [
                  _buildProfileHeader(
                    context: context,
                    name: name,
                    phone: phone,
                    email: email,
                    address: addressStr,
                    photo: photo,
                    rating: ratingVal,
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
                          builder: (context) => const DriverMainInfo(),
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
                    onTap: () {
                      _showPlaceholderPage(
                        context,
                        'profile_menu_vehicle'.tr(),
                      );
                    },
                  ),

                  const SizedBox(height: 12),

                  _buildProfileMenuOption(
                    context,
                    icon: Icons.badge_outlined,
                    title: 'profile_menu_documents'.tr(),
                    subtitle: 'profile_menu_documents_subtitle'.tr(),
                    onTap: () {
                      _showPlaceholderPage(
                        context,
                        'profile_menu_documents'.tr(),
                      );
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
                          builder: (context) => const SettingsPage(),
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
                      _showPlaceholderPage(
                        context,
                        'profile_menu_support'.tr(),
                      );
                    },
                  ),

                  const SizedBox(height: 12),

                  _buildProfileMenuOption(
                    context,
                    icon: Icons.privacy_tip_outlined,
                    title: 'profile_menu_privacy'.tr(),
                    subtitle: 'profile_menu_privacy_subtitle'.tr(),
                    onTap: () {
                      _showPlaceholderPage(
                        context,
                        'profile_menu_privacy'.tr(),
                      );
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
                    title: 'profile_menu_delete_account'.tr(),
                    subtitle: 'profile_menu_delete_account_subtitle'.tr(),
                    iconColor: Colors.red.shade700,
                    onTap: () {
                      _showPlaceholderPage(
                        context,
                        'profile_menu_delete_account'.tr(),
                      );
                    },
                  ),
                ],
              ),
            );
          },
        ),
        floatingActionButton: FloatingActionButton.extended(
          backgroundColor: Colors.red.shade700,
          onPressed: () async {
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
    required BuildContext context,
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
            crossAxisAlignment: CrossAxisAlignment.center,
            children: [
              SizedBox(
                width: 80,
                height: 80,
                child: photo.isNotEmpty
                    ? CachedNetworkImage(
                        imageUrl: photo,
                        imageBuilder: (context, imageProvider) {
                          return Container(
                            decoration: BoxDecoration(
                              shape: BoxShape.circle,
                              border: Border.all(
                                color:
                                    AppColors.primaryBrand.withOpacity(0.20),
                                width: 2,
                              ),
                              image: DecorationImage(
                                image: imageProvider,
                                fit: BoxFit.cover,
                              ),
                            ),
                          );
                        },
                        placeholder: (context, url) {
                          return const Center(
                            child: CircularProgressIndicator(
                              strokeWidth: 2,
                              valueColor: AlwaysStoppedAnimation<Color>(
                                AppColors.primaryBrand,
                              ),
                            ),
                          );
                        },
                        errorWidget: (context, url, error) {
                          return _buildAvatarPlaceholder();
                        },
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
                    Row(
                      children: [
                        const Icon(
                          Icons.phone_outlined,
                          size: 14,
                          color: AppColors.textSecondary,
                        ),
                        const SizedBox(width: 6),
                        Expanded(
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
                      ],
                    ),
                    if (email.isNotEmpty) ...[
                      const SizedBox(height: 5),
                      Row(
                        children: [
                          const Icon(
                            Icons.email_outlined,
                            size: 14,
                            color: AppColors.textSecondary,
                          ),
                          const SizedBox(width: 6),
                          Expanded(
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
                      ),
                    ],
                    if (address.isNotEmpty) ...[
                      const SizedBox(height: 5),
                      Row(
                        children: [
                          const Icon(
                            Icons.location_on_outlined,
                            size: 14,
                            color: AppColors.textSecondary,
                          ),
                          const SizedBox(width: 6),
                          Expanded(
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

  Widget _buildAvatarPlaceholder() {
    return CircleAvatar(
      backgroundColor: Colors.grey.shade200,
      child: Icon(
        Icons.person_rounded,
        size: 42,
        color: Colors.grey.shade500,
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

  void _showPlaceholderPage(BuildContext context, String title) {
    Navigator.push(
      context,
      MaterialPageRoute(
        builder: (context) => Scaffold(
          backgroundColor: AppColors.background,
          appBar: AppBar(
            title: Text(
              title,
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
          body: Center(
            child: Text(
              'coming_soon'.tr(),
              style: const TextStyle(
                fontSize: 16,
                color: AppColors.textSecondary,
              ),
            ),
          ),
        ),
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
        size: 42,
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

  Widget _buildProfileMenuOption(
    BuildContext context, {
    required IconData icon,
    required String title,
    required String subtitle,
    required VoidCallback onTap,
    Color? iconColor,
  }) {
    final isRtl = Directionality.of(context) == TextDirection.rtl;
    final itemIconColor = iconColor ?? AppColors.primaryBrand;

    return Container(
      width: MediaQuery.of(context).size.width * 0.92,
      margin: const EdgeInsets.symmetric(horizontal: 16),
      decoration: BoxDecoration(
        borderRadius: BorderRadius.circular(14),
        color: AppColors.cardBackground,
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
                  color: itemIconColor,
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
                  size: 21,
                  color: AppColors.textSecondary.withOpacity(0.55),
                ),
              ],
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
    final isRtl = Directionality.of(context) == TextDirection.rtl;

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
      body: SingleChildScrollView(
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
                builder: (context) => const LanguagePage(),
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
        leading: Icon(icon, color: AppColors.primaryBrand),
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
                      duration: const Duration(seconds: 2),
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
