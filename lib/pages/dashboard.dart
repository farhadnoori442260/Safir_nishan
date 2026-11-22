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
  final GlobalKey<ScaffoldState> _scaffoldKey = GlobalKey<ScaffoldState>();

  @override
  void initState() {
    super.initState();

    DriverPrefs.instance.ensureLoaded();
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
    String label,
  ) {
    final bool on = selectedIndex == index;
    final Color color = on ? AppColors.primaryBrand : AppColors.iconSecondary;

    return Expanded(
      child: InkWell(
        borderRadius: BorderRadius.circular(18),
        onTap: () => _onDestinationSelected(index),
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: <Widget>[
            AnimatedContainer(
              duration: const Duration(milliseconds: 200),
              padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 3),
              decoration: BoxDecoration(
                color: on
                    ? AppColors.primaryBrand.withOpacity(0.14)
                    : Colors.transparent,
                borderRadius: BorderRadius.circular(14),
              ),
              child: Icon(on ? selectedIcon : icon, size: 24, color: color),
            ),
            const SizedBox(height: 2),
            Text(
              label,
              maxLines: 1,
              overflow: TextOverflow.ellipsis,
              style: TextStyle(
                fontSize: 11,
                fontWeight: on ? FontWeight.bold : FontWeight.w500,
                color: on ? AppColors.primaryBrand : AppColors.textSecondary,
              ),
            ),
          ],
        ),
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
            height: 70,
            decoration: BoxDecoration(
              color: AppColors.cardBackground,
              borderRadius: BorderRadius.circular(24),
              border: Border.all(color: AppColors.borderLight),
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
