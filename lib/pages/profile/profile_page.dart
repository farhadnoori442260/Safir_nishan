import 'package:cached_network_image/cached_network_image.dart';
import 'package:easy_localization/easy_localization.dart' hide TextDirection;
import 'package:flutter/material.dart';
import 'package:provider/provider.dart';

import 'package:safir_drivers/pages/auth/register_screen.dart';
import 'package:safir_drivers/pages/profileUpdation/driver_main_info.dart';
import 'package:safir_drivers/pages/profileUpdation/driving_license_update_screen.dart';
import 'package:safir_drivers/pages/driverRegistration/vehicle_registration/vehicle_basic_info_screen.dart';
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

  /// صفحه را باز می‌کند و بعد از برگشت، اطلاعات پروفایل را تازه می‌کند.
  Future<void> _open(Widget page) async {
    await Navigator.push(
      context,
      MaterialPageRoute(builder: (_) => page),
    );

    if (!mounted) return;

    context.read<RegistrationProvider>().retrieveCurrentDriverInfo();
  }

  /// مشخصات راننده مستقیم از کارت بالای پروفایل (کارت یا آیکن ویرایش) باز می‌شود.
  Future<void> _openDriverInfo() => _open(const DriverMainInfo());

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
              padding: const EdgeInsets.fromLTRB(16, 20, 16, 105),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.stretch,
                children: [
                  _buildProfileHeader(
                    name: name,
                    phone: phone,
                    email: email,
                    address: address,
                    photo: photo,
                    rating: rating,
                  ),

                  const SizedBox(height: 24),

                  // «مشخصات راننده» حالا از خود کارت بالا باز می‌شود؛
                  // اینجا فقط موتر می‌ماند تا تکراری نشود.
                  _buildSectionTitle('profile_section_account'.tr()),
                  _buildMenuGroup(
                    context,
                    [
                      _MenuItem(
                        icon: Icons.directions_car_filled_outlined,
                        title: 'profile_menu_vehicle'.tr(),
                        subtitle: 'profile_menu_vehicle_subtitle'.tr(),
                        onTap: () => _open(const VehicleBasicInfoScreen()),
                      ),
                    ],
                  ),

                  const SizedBox(height: 20),

                  _buildSectionTitle('profile_section_documents'.tr()),
                  _buildMenuGroup(
                    context,
                    [
                      _MenuItem(
                        icon: Icons.badge_outlined,
                        title: 'profile_menu_license'.tr(),
                        subtitle: 'profile_menu_license_subtitle'.tr(),
                        onTap: () => _open(const DrivingLicenseUpdateScreen()),
                      ),
                      _MenuItem(
                        icon: Icons.description_outlined,
                        title: 'profile_menu_vehicle_registration'.tr(),
                        subtitle:
                            'profile_menu_vehicle_registration_subtitle'.tr(),
                        onTap: () =>
                            _open(const VehicleRegistrationUpdateScreen()),
                      ),
                    ],
                  ),

                  const SizedBox(height: 20),

                  _buildSectionTitle('profile_section_app'.tr()),
                  _buildMenuGroup(
                    context,
                    [
                      _MenuItem(
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
                      _MenuItem(
                        icon: Icons.help_outline_rounded,
                        title: 'profile_menu_support'.tr(),
                        subtitle: 'profile_menu_support_subtitle'.tr(),
                        onTap: () => _showSupportDialog(context),
                      ),
                      _MenuItem(
                        icon: Icons.privacy_tip_outlined,
                        title: 'profile_menu_privacy'.tr(),
                        subtitle: 'profile_menu_privacy_subtitle'.tr(),
                        onTap: () => _showPrivacyPage(context),
                      ),
                      _MenuItem(
                        icon: Icons.info_outline_rounded,
                        title: 'profile_menu_about'.tr(),
                        subtitle: 'profile_menu_about_subtitle'.tr(),
                        onTap: () => _showAboutDialog(context),
                      ),
                      // خروج از حساب به‌جای دکمهٔ شناور، داخل لیست آمده تا
                      // روی نوار پایین و محتوا نیفتد.
                      _MenuItem(
                        icon: Icons.logout_rounded,
                        title: 'profile_logout'.tr(),
                        onTap: () {
                          if (authProvider.isLoading) return;
                          _confirmLogout(authProvider);
                        },
                      ),
                    ],
                  ),

                  const SizedBox(height: 20),

                  _buildSectionTitle(
                    'profile_section_account_management'.tr(),
                    color: AppColors.error,
                  ),
                  _buildMenuGroup(
                    context,
                    [
                      _MenuItem(
                        icon: Icons.delete_outline_rounded,
                        iconColor: AppColors.error,
                        title: 'profile_menu_delete_account'.tr(),
                        subtitle: 'profile_menu_delete_account_subtitle'.tr(),
                        onTap: () =>
                            _showDeleteAccountDialog(context, authProvider),
                      ),
                    ],
                  ),
                ],
              ),
            );
          },
        ),
      ),
    );
  }

  // ════════════════════════════════════════════════════════════
  //  ظاهر مشترک
  // ════════════════════════════════════════════════════════════

  BoxDecoration _cardDecoration({double radius = 18}) {
    return BoxDecoration(
      color: AppColors.cardBackground,
      borderRadius: BorderRadius.circular(radius),
      border: Border.all(
        color: AppColors.textSecondary.withOpacity(0.10),
      ),
      boxShadow: [
        BoxShadow(
          color: Colors.black.withOpacity(0.03),
          offset: const Offset(0, 3),
          blurRadius: 10,
        ),
      ],
    );
  }

  // ════════════════════════════════════════════════════════════
  //  کارت بالای پروفایل
  // ════════════════════════════════════════════════════════════

  Widget _buildProfileHeader({
    required String name,
    required String phone,
    required String email,
    required String address,
    required String photo,
    required double rating,
  }) {
    // شماره و ایمیل کنار هم می‌آیند و اگر جا نبود خودکار به خط بعد می‌روند.
    final List<Widget> infoChips = [
      _buildInfoChip(
        icon: Icons.phone_outlined,
        child: Directionality(
          textDirection: TextDirection.ltr,
          child: Text(
            phone,
            maxLines: 1,
            overflow: TextOverflow.ellipsis,
            style: const TextStyle(
              fontSize: 12,
              color: AppColors.textPrimary,
            ),
          ),
        ),
      ),
      if (email.isNotEmpty)
        _buildInfoChip(
          icon: Icons.mail_outline_rounded,
          child: Text(
            email,
            maxLines: 1,
            overflow: TextOverflow.ellipsis,
            style: const TextStyle(
              fontSize: 12,
              color: AppColors.textPrimary,
            ),
          ),
        ),
      if (address.isNotEmpty)
        _buildInfoChip(
          icon: Icons.location_on_outlined,
          child: Text(
            address,
            maxLines: 1,
            overflow: TextOverflow.ellipsis,
            style: const TextStyle(
              fontSize: 12,
              color: AppColors.textPrimary,
            ),
          ),
        ),
    ];

    return Container(
      decoration: _cardDecoration(radius: 22),
      child: Material(
        color: Colors.transparent,
        borderRadius: BorderRadius.circular(22),
        child: InkWell(
          onTap: _openDriverInfo,
          borderRadius: BorderRadius.circular(22),
          child: Padding(
            padding: const EdgeInsets.all(16),
            child: Column(
              children: [
                Row(
                  children: [
                    SizedBox(
                      height: 68,
                      width: 68,
                      child: photo.isNotEmpty
                          ? CachedNetworkImage(
                              imageUrl: photo,
                              imageBuilder: (context, imageProvider) =>
                                  Container(
                                decoration: BoxDecoration(
                                  shape: BoxShape.circle,
                                  border: Border.all(
                                    color: AppColors.primaryBrand
                                        .withOpacity(0.25),
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
                              errorWidget: (_, __, ___) =>
                                  _buildAvatarPlaceholder(),
                            )
                          : _buildAvatarPlaceholder(),
                    ),
                    const SizedBox(width: 14),
                    Expanded(
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        mainAxisSize: MainAxisSize.min,
                        children: [
                          Text(
                            name,
                            maxLines: 1,
                            overflow: TextOverflow.ellipsis,
                            style: const TextStyle(
                              fontSize: 17,
                              fontWeight: FontWeight.w700,
                              color: AppColors.textPrimary,
                            ),
                          ),
                          const SizedBox(height: 6),
                          RatingStars(ratting: rating.toStringAsFixed(1)),
                        ],
                      ),
                    ),
                    const SizedBox(width: 8),
                    // آیکن ویرایش: کل کارت هم قابل لمس است و همین‌جا باز می‌شود.
                    Semantics(
                      button: true,
                      label: 'profile_menu_account'.tr(),
                      child: Container(
                        height: 38,
                        width: 38,
                        decoration: BoxDecoration(
                          shape: BoxShape.circle,
                          color: AppColors.primaryBrand.withOpacity(0.10),
                        ),
                        child: const Icon(
                          Icons.edit_outlined,
                          size: 19,
                          color: AppColors.primaryBrand,
                        ),
                      ),
                    ),
                  ],
                ),
                const SizedBox(height: 14),
                Divider(
                  height: 1,
                  thickness: 1,
                  color: AppColors.textSecondary.withOpacity(0.10),
                ),
                const SizedBox(height: 12),
                Align(
                  alignment: AlignmentDirectional.centerStart,
                  child: Wrap(
                    spacing: 8,
                    runSpacing: 8,
                    children: infoChips,
                  ),
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }

  Widget _buildInfoChip({
    required IconData icon,
    required Widget child,
  }) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 7),
      decoration: BoxDecoration(
        color: AppColors.background,
        borderRadius: BorderRadius.circular(20),
        border: Border.all(
          color: AppColors.textSecondary.withOpacity(0.12),
        ),
      ),
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          Icon(
            icon,
            size: 14,
            color: AppColors.textSecondary,
          ),
          const SizedBox(width: 6),
          Flexible(child: child),
        ],
      ),
    );
  }

  Widget _buildAvatarPlaceholder() {
    return CircleAvatar(
      backgroundColor: AppColors.background,
      child: Icon(
        Icons.person_rounded,
        color: AppColors.textSecondary.withOpacity(0.6),
        size: 38,
      ),
    );
  }

  // ════════════════════════════════════════════════════════════
  //  منو
  // ════════════════════════════════════════════════════════════

  Widget _buildSectionTitle(
    String title, {
    Color? color,
  }) {
    return Padding(
      padding: const EdgeInsetsDirectional.fromSTEB(6, 0, 6, 8),
      child: Text(
        title,
        style: TextStyle(
          fontSize: 12,
          fontWeight: FontWeight.w700,
          color: color ?? AppColors.textSecondary,
        ),
      ),
    );
  }

  /// چند ردیف داخل یک کارت، با خط جداکنندهٔ ظریف (به‌جای کارت جدا برای هر ردیف).
  Widget _buildMenuGroup(
    BuildContext context,
    List<_MenuItem> items,
  ) {
    return Container(
      decoration: _cardDecoration(),
      child: ClipRRect(
        borderRadius: BorderRadius.circular(18),
        child: Material(
          color: Colors.transparent,
          child: Column(
            children: [
              for (int i = 0; i < items.length; i++) ...[
                _buildMenuRow(context, items[i]),
                if (i != items.length - 1)
                  Divider(
                    height: 1,
                    thickness: 1,
                    indent: 66,
                    endIndent: 16,
                    color: AppColors.textSecondary.withOpacity(0.10),
                  ),
              ],
            ],
          ),
        ),
      ),
    );
  }

  Widget _buildMenuRow(
    BuildContext context,
    _MenuItem item,
  ) {
    final bool isRtl = Directionality.of(context) == TextDirection.rtl;
    final Color color = item.iconColor ?? AppColors.primaryBrand;

    return InkWell(
      onTap: item.onTap,
      child: Padding(
        padding: const EdgeInsets.symmetric(
          horizontal: 16,
          vertical: 12,
        ),
        child: Row(
          children: [
            Container(
              height: 36,
              width: 36,
              decoration: BoxDecoration(
                color: color.withOpacity(0.10),
                borderRadius: BorderRadius.circular(10),
              ),
              child: Icon(
                item.icon,
                color: color,
                size: 20,
              ),
            ),
            const SizedBox(width: 14),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    item.title,
                    style: const TextStyle(
                      fontSize: 14,
                      fontWeight: FontWeight.w600,
                      color: AppColors.textPrimary,
                    ),
                  ),
                  if (item.subtitle != null) ...[
                    const SizedBox(height: 3),
                    Text(
                      item.subtitle!,
                      maxLines: 1,
                      overflow: TextOverflow.ellipsis,
                      style: const TextStyle(
                        fontSize: 11.5,
                        color: AppColors.textSecondary,
                      ),
                    ),
                  ],
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
    );
  }

  // ════════════════════════════════════════════════════════════
  //  دیالوگ‌ها
  // ════════════════════════════════════════════════════════════

  Future<void> _confirmLogout(AuthenticationProvider authProvider) async {
    final bool? confirmed = await showDialog<bool>(
      context: context,
      builder: (dialogContext) {
        return AlertDialog(
          backgroundColor: AppColors.cardBackground,
          shape: RoundedRectangleBorder(
            borderRadius: BorderRadius.circular(18),
          ),
          title: Text(
            'profile_logout'.tr(),
            style: const TextStyle(
              color: AppColors.textPrimary,
              fontWeight: FontWeight.bold,
              fontSize: 16,
            ),
          ),
          actions: [
            TextButton(
              onPressed: () => Navigator.pop(dialogContext, false),
              child: Text('btn_cancel'.tr()),
            ),
            ElevatedButton(
              onPressed: () => Navigator.pop(dialogContext, true),
              style: ElevatedButton.styleFrom(
                backgroundColor: AppColors.primaryButton,
                foregroundColor: AppColors.buttonText,
                elevation: 0,
              ),
              child: Text('btn_confirm'.tr()),
            ),
          ],
        );
      },
    );

    if (confirmed != true || !mounted) return;

    await authProvider.signOut(context);
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
      // TODO(release): نسخه را از package_info_plus بخوانید تا با نسخهٔ
      // پلی‌استور همیشه یکی باشد.
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
                style: const TextStyle(
                  color: AppColors.error,
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

                            if (context.mounted) {
                              Navigator.of(context).pushAndRemoveUntil(
                                MaterialPageRoute(
                                  builder: (_) => const RegisterScreen(),
                                ),
                                (route) => false,
                              );
                            }
                          } else {
                            if (dialogContext.mounted) {
                              setDialogState(() {
                                isDeleting = false;
                              });
                            }
                          }
                        },
                  style: ElevatedButton.styleFrom(
                    backgroundColor: AppColors.error,
                    foregroundColor: AppColors.buttonText,
                    elevation: 0,
                  ),
                  child: isDeleting
                      ? const SizedBox(
                          height: 18,
                          width: 18,
                          child: CircularProgressIndicator(
                            strokeWidth: 2,
                            color: AppColors.buttonText,
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

/// یک ردیف از منوی پروفایل.
class _MenuItem {
  const _MenuItem({
    required this.icon,
    required this.title,
    required this.onTap,
    this.subtitle,
    this.iconColor,
  });

  final IconData icon;
  final String title;
  final String? subtitle;
  final VoidCallback onTap;
  final Color? iconColor;
}

class PrivacyPolicyPage extends StatelessWidget {
  const PrivacyPolicyPage({super.key});

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: AppColors.background,
      appBar: AppBar(
        backgroundColor: AppColors.cardBackground,
        elevation: 0,
        scrolledUnderElevation: 0,
        surfaceTintColor: Colors.transparent,
        shape: Border(
          bottom: BorderSide(
            color: AppColors.textSecondary.withOpacity(0.10),
          ),
        ),
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
            border: Border.all(
              color: AppColors.textSecondary.withOpacity(0.10),
            ),
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
        elevation: 0,
        scrolledUnderElevation: 0,
        surfaceTintColor: Colors.transparent,
        shape: Border(
          bottom: BorderSide(
            color: AppColors.textSecondary.withOpacity(0.10),
          ),
        ),
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
        borderRadius: BorderRadius.circular(18),
        border: Border.all(
          color: AppColors.textSecondary.withOpacity(0.10),
        ),
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
        elevation: 0,
        scrolledUnderElevation: 0,
        surfaceTintColor: Colors.transparent,
        shape: Border(
          bottom: BorderSide(
            color: AppColors.textSecondary.withOpacity(0.10),
          ),
        ),
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
                  backgroundColor: AppColors.primaryButton,
                  foregroundColor: AppColors.buttonText,
                  padding: const EdgeInsets.symmetric(vertical: 16),
                  shape: RoundedRectangleBorder(
                    borderRadius: BorderRadius.circular(16),
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
                color: AppColors.textSecondary,
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
