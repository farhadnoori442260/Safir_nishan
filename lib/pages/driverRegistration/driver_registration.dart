import 'package:easy_localization/easy_localization.dart';
import 'package:flutter/material.dart';
import 'package:provider/provider.dart';

import '../../methods/common_method.dart';
import '../../providers/registration_provider.dart';
import '../../utils/app_colors.dart';
import '../dashboard.dart';
import 'basic_info_screen.dart';
import 'cnic_screen.dart';
import 'driving_license_screen.dart';
import 'selfie_screen.dart';
import 'vehicle_info_screen.dart';

class DriverRegistration extends StatefulWidget {
  const DriverRegistration({super.key});

  @override
  State<DriverRegistration> createState() => _DriverRegistrationState();
}

class _DriverRegistrationState extends State<DriverRegistration> {
  bool isBasicInfoComplete = false;
  bool isCnicComplete = false;
  bool isSelfieComplete = false;
  bool isVehicleInfoComplete = false;
  bool isDrivingLicenseInfoComplete = false;
  bool isAllComplete = false;

  static const int _totalSteps = 5;

  int get _doneCount => [
        isBasicInfoComplete,
        isCnicComplete,
        isSelfieComplete,
        isDrivingLicenseInfoComplete,
        isVehicleInfoComplete,
      ].where((e) => e).length;

  @override
  void initState() {
    super.initState();
    // اگر راننده قبلاً بخشی از مراحل را پر کرده و برگشته (یا مدارکش از سرور
    // آمده)، تیک مرحله‌های کامل از همان اول دیده شود، نه از صفر.
    WidgetsBinding.instance.addPostFrameCallback((_) {
      if (!mounted) return;
      final RegistrationProvider p = context.read<RegistrationProvider>();
      setState(() {
        isBasicInfoComplete = p.isFormValidBasic;
        isCnicComplete = p.isFormValidCninc;
        isSelfieComplete = p.isSelfieStepComplete;
        isDrivingLicenseInfoComplete = p.isFormValidDrivingLicnese;
        isVehicleInfoComplete = p.isVehicleStepComplete;
        isAllComplete = isBasicInfoComplete &&
            isCnicComplete &&
            isSelfieComplete &&
            isDrivingLicenseInfoComplete &&
            isVehicleInfoComplete;
      });
    });
  }

  // اگر ترجمه وجود نداشت، .tr() خود کلید را برمی‌گرداند؛ در این حالت متن پیش‌فرض
  String _t(String key, String fallback) {
    final String v = key.tr();
    return v == key ? fallback : v;
  }

  // ارقام فارسی برای فارسی/پشتو
  String _digits(int n) {
    final String code = context.locale.languageCode;
    if (code != 'fa' && code != 'ps') return '$n';
    const fa = ['۰', '۱', '۲', '۳', '۴', '۵', '۶', '۷', '۸', '۹'];
    return '$n'.split('').map((c) => fa[int.parse(c)]).join();
  }

  // تابع بازخوانی وضعیت تکمیل تمامی مدارک
  void _recalculateAllComplete() {
    setState(() {
      isAllComplete = isBasicInfoComplete &&
          isCnicComplete &&
          isSelfieComplete &&
          isVehicleInfoComplete &&
          isDrivingLicenseInfoComplete;
    });
  }

  // باز کردن یک مرحله؛ اگر با موفقیت برگشت، همان مرحله تکمیل‌شده ثبت می‌شود
  Future<void> _openStep(Widget screen, VoidCallback markDone) async {
    final bool? result = await Navigator.push<bool>(
      context,
      MaterialPageRoute(builder: (_) => screen),
    );
    if (!mounted) return;
    if (result == true) {
      markDone();
      _recalculateAllComplete();
    }
  }

  Future<void> _submit(RegistrationProvider registrationProvider) async {
    registrationProvider.startLoading();
    try {
      // saveUserData خودش پیام خطا نشان می‌دهد؛ فقط اگر موفق بود ادامه می‌دهیم
      final bool saved = await registrationProvider.saveUserData(context);
      if (!saved || !mounted) return;
      Navigator.pushReplacement(
        context,
        MaterialPageRoute(builder: (c) => const Dashboard()),
      );
      CommonMethods commonMethods = CommonMethods();
      commonMethods.displaySnackBar('reg_success_msg'.tr(), context);
    } catch (e) {
      debugPrint("Error while saving data: $e");
      // قبلاً خطا بی‌صدا بلعیده می‌شد و کاربر نمی‌فهمید چرا اتفاقی نیفتاد
      if (mounted) {
        CommonMethods().displaySnackBar(
          _t('reg_save_failed',
              'ثبت اطلاعات انجام نشد. اینترنت را بررسی کنید و دوباره تلاش کنید.'),
          context,
        );
      }
    } finally {
      registrationProvider.stopLoading();
    }
  }

  @override
  Widget build(BuildContext context) {
    return Consumer<RegistrationProvider>(
      builder: (context, registrationProvider, child) => Scaffold(
        backgroundColor: AppColors.background,
        appBar: AppBar(
          title: Text(
            'reg_steps_title'.tr(),
            style: TextStyle(
              fontWeight: FontWeight.bold,
              fontSize: 18,
              color: AppColors.textPrimary,
            ),
          ),
          centerTitle: true,
          elevation: 0,
          backgroundColor: AppColors.cardBackground,
          surfaceTintColor: Colors.transparent,
          iconTheme: IconThemeData(color: AppColors.textPrimary),
        ),
        body: SafeArea(
          child: SingleChildScrollView(
            padding: const EdgeInsets.fromLTRB(16, 16, 16, 24),
            child: Column(
              children: [
                _buildProgressCard(),
                const SizedBox(height: 14),

                // لیست چک‌لیست مراحل ثبت‌نام مدارک
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
                        icon: Icons.person_outline_rounded,
                        accent: AppColors.originBlue,
                        title: 'step_basic_info_title'.tr(),
                        subtitle: 'step_basic_info_sub'.tr(),
                        isCompleted: isBasicInfoComplete,
                        onTap: () => _openStep(
                          const BasicInfoScreen(),
                          () => isBasicInfoComplete = true,
                        ),
                      ),
                      _divider(),
                      _buildListTile(
                        icon: Icons.badge_outlined,
                        accent: AppColors.accentOrange,
                        title: 'step_cnic_title'.tr(),
                        subtitle: 'step_cnic_sub'.tr(),
                        isCompleted: isCnicComplete,
                        onTap: () => _openStep(
                          const CNICScreen(),
                          () => isCnicComplete = true,
                        ),
                      ),
                      _divider(),
                      _buildListTile(
                        icon: Icons.face_retouching_natural_outlined,
                        accent: AppColors.accentPurple,
                        title: 'step_selfie_title'.tr(),
                        subtitle: 'step_selfie_sub'.tr(),
                        isCompleted: isSelfieComplete,
                        onTap: () => _openStep(
                          const SelfieScreen(),
                          () => isSelfieComplete = true,
                        ),
                      ),
                      _divider(),
                      _buildListTile(
                        icon: Icons.credit_card_outlined,
                        accent: AppColors.accentTeal,
                        title: 'step_license_title'.tr(),
                        subtitle: 'step_license_sub'.tr(),
                        isCompleted: isDrivingLicenseInfoComplete,
                        onTap: () => _openStep(
                          const DrivingLicenseScreen(),
                          () => isDrivingLicenseInfoComplete = true,
                        ),
                      ),
                      _divider(),
                      _buildListTile(
                        icon: Icons.directions_car_outlined,
                        accent: AppColors.warningIcon,
                        title: 'step_vehicle_title'.tr(),
                        subtitle: 'step_vehicle_sub'.tr(),
                        isCompleted: isVehicleInfoComplete,
                        onTap: () => _openStep(
                          VehicleInfoScreen(),
                          () => isVehicleInfoComplete = true,
                        ),
                      ),
                    ],
                  ),
                ),
                const SizedBox(height: 24),

                // دکمه ثبت نهایی حساب
                SizedBox(
                  width: double.infinity,
                  height: 52,
                  child: ElevatedButton(
                    onPressed: isAllComplete && !registrationProvider.isLoading
                        ? () => _submit(registrationProvider)
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
                            width: 22,
                            height: 22,
                            child: CircularProgressIndicator(
                              strokeWidth: 2.5,
                              color: AppColors.buttonText,
                            ),
                          )
                        : Text(
                            'submit_all_docs'.tr(),
                            style: const TextStyle(
                              fontSize: 16,
                              fontWeight: FontWeight.bold,
                            ),
                          ),
                  ),
                ),
                const SizedBox(height: 10),
                Padding(
                  padding: const EdgeInsets.symmetric(
                      horizontal: 12.0, vertical: 8.0),
                  child: Text(
                    'reg_terms_note'.tr(),
                    textAlign: TextAlign.center,
                    style: TextStyle(
                      fontSize: 11,
                      height: 1.6,
                      color: AppColors.textSecondary,
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

  // کارت پیشرفت: کاربر می‌بیند چند مرحله مانده
  Widget _buildProgressCard() {
    final int done = _doneCount;
    final bool all = done == _totalSteps;
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
                      ? _t('reg_all_done', 'همه مدارک آماده است')
                      : _t('reg_progress_title', 'مدارک خود را کامل کنید'),
                  style: TextStyle(
                    fontSize: 15,
                    fontWeight: FontWeight.bold,
                    color: AppColors.textPrimary,
                  ),
                ),
              ),
              Text(
                '${_digits(done)} / ${_digits(_totalSteps)}',
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
              value: done / _totalSteps,
              minHeight: 6,
              backgroundColor: AppColors.borderLight,
              color: AppColors.primaryBrand,
            ),
          ),
          const SizedBox(height: 10),
          Text(
            all
                ? _t('reg_all_done_sub',
                    'حالا دکمه ثبت نهایی را بزنید تا حساب شما بررسی شود.')
                : _t('reg_progress_sub',
                    'برای فعال شدن حساب، هر پنج مرحله باید تکمیل شود.'),
            style: TextStyle(
              fontSize: 12,
              height: 1.6,
              color: AppColors.textSecondary,
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

  // متد ساخت کاستوم لیست‌تایل‌ها
  Widget _buildListTile({
    required IconData icon,
    required Color accent,
    required String title,
    required String subtitle,
    required bool isCompleted,
    required Function() onTap,
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
          style: TextStyle(fontSize: 12, color: AppColors.textSecondary),
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
