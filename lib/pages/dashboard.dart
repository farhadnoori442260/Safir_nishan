import 'package:easy_localization/easy_localization.dart';
import 'package:flutter/material.dart';
import 'package:provider/provider.dart';

import 'package:safir_drivers/controllers/driver_online_controller.dart';
import 'package:safir_drivers/pages/earnings/earnings_page.dart';
import 'package:safir_drivers/pages/home/home_page.dart';
import 'package:safir_drivers/pages/messages/messages_page.dart';
import 'package:safir_drivers/pages/trips/trips_page.dart';
import 'package:safir_drivers/providers/dashboard_provider.dart';
import 'package:safir_drivers/providers/registration_provider.dart';
import 'package:safir_drivers/utils/app_colors.dart';
import 'package:safir_drivers/utils/driver_prefs.dart';
import 'package:safir_drivers/widgets/coach_marks.dart';
import 'package:safir_drivers/widgets/driver_drawer.dart';
import 'package:safir_drivers/widgets/driver_text_scale.dart';

String _t(String key, String fallback) {
  final String value = key.tr();
  return value.trim().isEmpty || value == key ? fallback : value;
}

class Dashboard extends StatefulWidget {
  const Dashboard({super.key});

  @override
  State<Dashboard> createState() => _DashboardState();
}

class _DashboardState extends State<Dashboard> {
  late final List<Widget> _pages;

  final GlobalKey<ScaffoldState> _scaffoldKey =
      GlobalKey<ScaffoldState>();

  @override
  void initState() {
    super.initState();

    DriverPrefs.instance.ensureLoaded();

    CoachMarks.replayTick.addListener(_onReplay);

    Future<void>.delayed(
      const Duration(milliseconds: 1500),
      () {
        if (mounted) CoachMarks.maybeStart(context);
      },
    );

    DriverOnlineController.instance.openDrawer =
        () => _scaffoldKey.currentState?.openEndDrawer();

    _pages = const [
      HomePage(),
      EarningsPage(),
      TripsPage(),
      MessagesPage(),
    ];

    WidgetsBinding.instance.addPostFrameCallback((_) {
      _refreshInitialData();
    });
  }

  void _onReplay() {
    if (!mounted) return;

    context.read<DashboardProvider>().setIndex(0);

    Future<void>.delayed(
      const Duration(milliseconds: 600),
      () {
        if (mounted) {
          CoachMarks.maybeStart(context, force: true);
        }
      },
    );
  }

  @override
  void dispose() {
    CoachMarks.replayTick.removeListener(_onReplay);
    super.dispose();
  }

  Future<void> _refreshInitialData() async {
    if (!mounted) return;

    final registrationProvider =
        context.read<RegistrationProvider>();

    try {
      await Future.wait([
        registrationProvider.retrieveCurrentDriverInfo(),
        registrationProvider.fetchDriverEarnings(),
      ]);
    } catch (e) {
      debugPrint('Dashboard initial refresh error: $e');
    }
  }

  Future<void> _onDestinationSelected(int index) async {
    if (!mounted) return;

    final dashboardProvider = context.read<DashboardProvider>();

    if (dashboardProvider.selectedIndex == index) {
      return;
    }

    dashboardProvider.setIndex(index);

    // فقط هنگام رفتن به درآمدها یا پروفایل، اطلاعات مربوطه تازه می‌شود.
    final registrationProvider =
        context.read<RegistrationProvider>();

    try {
      if (index == 1) {
        await registrationProvider.fetchDriverEarnings();
      }
    } catch (e) {
      debugPrint('Dashboard tab refresh error: $e');
    }
  }

  Widget _navItem(
    int index,
    int selectedIndex,
    IconData icon,
    IconData selectedIcon,
    String label, {
    GlobalKey? tourKey,
  }) {
    final bool on = selectedIndex == index;

    final Color color =
        on ? AppColors.primaryBrand : AppColors.iconSecondary;

    return Expanded(
      child: InkWell(
        borderRadius: BorderRadius.circular(18),
        onTap: () => _onDestinationSelected(index),
        child: Column(
          key: tourKey,
          mainAxisAlignment: MainAxisAlignment.center,
          children: <Widget>[
            AnimatedContainer(
              duration: const Duration(milliseconds: 200),
              padding: const EdgeInsets.symmetric(
                horizontal: 14,
                vertical: 3,
              ),
              decoration: BoxDecoration(
                color: on
                    ? AppColors.primaryBrand.withOpacity(0.14)
                    : Colors.transparent,
                borderRadius: BorderRadius.circular(14),
              ),
              child: Icon(
                on ? selectedIcon : icon,
                size: 24,
                color: color,
              ),
            ),
            const SizedBox(height: 2),
            Text(
              label,
              maxLines: 1,
              overflow: TextOverflow.ellipsis,
              style: TextStyle(
                fontSize: 11,
                fontWeight: on ? FontWeight.bold : FontWeight.w500,
                color: on
                    ? AppColors.primaryBrand
                    : AppColors.textSecondary,
              ),
            ),
          ],
        ),
      ),
    );
  }

  /// دکمهٔ مرکزی آنلاین/آفلاین؛ منطق اصلی در HomePage است.
  Widget _buildPowerButton(int selectedIndex) {
    final DriverOnlineController c =
        DriverOnlineController.instance;

    return SizedBox(
      width: 88,
      child: ValueListenableBuilder<bool>(
        valueListenable: c.online,
        builder: (
          BuildContext context,
          bool online,
          Widget? _,
        ) {
          return ValueListenableBuilder<bool>(
            valueListenable: c.busy,
            builder: (
              BuildContext context,
              bool busy,
              Widget? __,
            ) {
              final String label = online
                  ? _t('driver_power_online', 'آنلاین')
                  : _t('driver_power_offline', 'آفلاین');

              final Color accent = AppColors.primaryBrand;

              return Semantics(
                button: true,
                enabled: !busy,
                label: label,
                child: InkWell(
                  borderRadius: BorderRadius.circular(22),
                  onTap: busy
                      ? null
                      : () {
                          if (selectedIndex != 0) {
                            context
                                .read<DashboardProvider>()
                                .setIndex(0);
                          }

                          c.toggle();
                        },
                  child: Column(
                    mainAxisAlignment: MainAxisAlignment.center,
                    children: <Widget>[
                      AnimatedContainer(
                        key: CoachKeys.power,
                        duration: const Duration(milliseconds: 250),
                        curve: Curves.easeInOut,
                        width: 60,
                        height: 60,
                        padding: const EdgeInsets.all(4),
                        decoration: BoxDecoration(
                          shape: BoxShape.circle,
                          color: online
                              ? accent.withOpacity(0.12)
                              : AppColors.neutralSoft,
                          border: Border.all(
                            color: online
                                ? accent.withOpacity(0.45)
                                : AppColors.borderLight,
                            width: 1.3,
                          ),
                          boxShadow: [
                            BoxShadow(
                              color: accent.withOpacity(
                                online ? 0.22 : 0.08,
                              ),
                              blurRadius: online ? 14 : 8,
                              offset: const Offset(0, 4),
                            ),
                          ],
                        ),
                        child: AnimatedContainer(
                          duration: const Duration(
                            milliseconds: 250,
                          ),
                          curve: Curves.easeInOut,
                          decoration: BoxDecoration(
                            shape: BoxShape.circle,
                            color: online
                                ? AppColors.primaryButton
                                : AppColors.cardBackground,
                            border: Border.all(
                              color: online
                                  ? Colors.transparent
                                  : accent.withOpacity(0.30),
                            ),
                          ),
                          child: Center(
                            child: busy
                                ? SizedBox(
                                    width: 24,
                                    height: 24,
                                    child:
                                        CircularProgressIndicator(
                                      strokeWidth: 2.5,
                                      color: online
                                          ? AppColors.buttonText
                                          : accent,
                                    ),
                                  )
                                : Icon(
                                    Icons.power_settings_new_rounded,
                                    size: 30,
                                    color: online
                                        ? AppColors.buttonText
                                        : accent,
                                  ),
                          ),
                        ),
                      ),
                      const SizedBox(height: 4),
                      Flexible(
                        child: Text(
                          label,
                          maxLines: 1,
                          overflow: TextOverflow.ellipsis,
                          style: TextStyle(
                            fontSize: 11,
                            fontWeight: FontWeight.w700,
                            color: online
                                ? accent
                                : AppColors.textSecondary,
                          ),
                        ),
                      ),
                    ],
                  ),
                ),
              );
            },
          );
        },
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    final int selectedIndex = context.select<DashboardProvider, int>(
      (provider) => provider.selectedIndex,
    );

    // دکمهٔ برگشت در تب‌های دیگر: اول به تب «خانه» برمی‌گردد، نه اینکه مستقیم
    // از برنامه خارج شود (در خانه، برگشت مثل قبل عمل می‌کند).
    return PopScope(
      canPop: selectedIndex == 0,
      onPopInvokedWithResult: (bool didPop, Object? result) {
        if (!didPop && selectedIndex != 0) {
          context.read<DashboardProvider>().setIndex(0);
        }
      },
      child: DriverTextScale(
        child: Scaffold(
          key: _scaffoldKey,
          endDrawer: const DriverDrawer(),
          endDrawerEnableOpenDragGesture: false,
          backgroundColor: AppColors.background,
          extendBody: true,
          body: IndexedStack(
            index: selectedIndex,
            children: _pages,
          ),
          bottomNavigationBar: SafeArea(
            top: false,
            minimum: const EdgeInsets.fromLTRB(12, 0, 12, 12),
            child: Container(
              height: 88,
              decoration: BoxDecoration(
                color: AppColors.cardBackground,
                borderRadius: BorderRadius.circular(24),
                border: Border.all(
                  color: AppColors.borderLight,
                ),
              ),
              child: Row(
                children: <Widget>[
                  _navItem(
                    0,
                    selectedIndex,
                    Icons.map_outlined,
                    Icons.map_rounded,
                    'nav_home'.tr(),
                  ),
                  _navItem(
                    1,
                    selectedIndex,
                    Icons.account_balance_wallet_outlined,
                    Icons.account_balance_wallet_rounded,
                    'nav_earnings'.tr(),
                  ),
                  _buildPowerButton(selectedIndex),
                  _navItem(
                    2,
                    selectedIndex,
                    Icons.route_outlined,
                    Icons.route_rounded,
                    'nav_trips'.tr(),
                  ),
                  _navItem(
                    3,
                    selectedIndex,
                    Icons.mail_outline_rounded,
                    Icons.mail_rounded,
                    _t('nav_messages', 'پیام‌ها'),
                    tourKey: CoachKeys.messages,
                  ),
                ],
              ),
            ),
          ),
        ),
      ),
    );
  }
}
