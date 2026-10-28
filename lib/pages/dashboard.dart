import 'package:easy_localization/easy_localization.dart';
import 'package:flutter/material.dart';
import 'package:provider/provider.dart';

import 'package:safir_drivers/pages/earnings/earnings_page.dart';
import 'package:safir_drivers/pages/home/home_page.dart';
import 'package:safir_drivers/pages/profile/profile_page.dart';
import 'package:safir_drivers/pages/trips/trips_page.dart';
import 'package:safir_drivers/providers/dashboard_provider.dart';
import 'package:safir_drivers/providers/registration_provider.dart';
import 'package:safir_drivers/utils/app_colors.dart';

class Dashboard extends StatefulWidget {
  const Dashboard({super.key});

  @override
  State<Dashboard> createState() => _DashboardState();
}

class _DashboardState extends State<Dashboard> {
  late final List<Widget> _pages;

  @override
  void initState() {
    super.initState();

    _pages = const [
      HomePage(),
      EarningsPage(),
      TripsPage(),
      ProfilePage(),
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
      } else if (index == 3) {
        await registrationProvider.retrieveCurrentDriverInfo();
      }
    } catch (e) {
      debugPrint('Dashboard tab refresh error: $e');
    }
  }

  @override
  Widget build(BuildContext context) {
    final int selectedIndex = context.select<DashboardProvider, int>(
      (provider) => provider.selectedIndex,
    );

    // وقتی صفحهٔ دیگری (مثلاً فرم) روی داشبورد باز است، MediaQuery آن
    // ثابت می‌ماند تا با هر فریم انیمیشن کیبورد هر ۴ تب (از جمله نقشه) زیر
    // آن دوباره ساخته نشوند.
    return _FreezeMediaQueryWhenCovered(
      child: Scaffold(
      backgroundColor: const Color(0xFFF6F8F7),
      extendBody: true,
      body: IndexedStack(
        index: selectedIndex,
        children: _pages,
      ),
      bottomNavigationBar: SafeArea(
        top: false,
        minimum: const EdgeInsets.fromLTRB(12, 0, 12, 12),
        child: Container(
          clipBehavior: Clip.antiAlias,
          decoration: BoxDecoration(
            color: Colors.white.withOpacity(0.97),
            borderRadius: BorderRadius.circular(24),
            border: Border.all(
              color: AppColors.primaryBrand.withOpacity(0.10),
            ),
            boxShadow: [
              BoxShadow(
                color: Colors.black.withOpacity(0.10),
                blurRadius: 22,
                offset: const Offset(0, 8),
              ),
            ],
          ),
          child: NavigationBar(
            selectedIndex: selectedIndex,
            onDestinationSelected: _onDestinationSelected,
            height: 68,
            backgroundColor: Colors.transparent,
            elevation: 0,
            indicatorColor: AppColors.primaryBrand.withOpacity(0.14),
            labelBehavior:
                NavigationDestinationLabelBehavior.alwaysShow,
            animationDuration: const Duration(milliseconds: 280),
            destinations: [
              NavigationDestination(
                icon: const Icon(Icons.map_outlined),
                selectedIcon: const Icon(Icons.map_rounded),
                label: 'nav_home'.tr(),
              ),
              NavigationDestination(
                icon: const Icon(
                  Icons.account_balance_wallet_outlined,
                ),
                selectedIcon: const Icon(
                  Icons.account_balance_wallet_rounded,
                ),
                label: 'nav_earnings'.tr(),
              ),
              NavigationDestination(
                icon: const Icon(Icons.route_outlined),
                selectedIcon: const Icon(Icons.route_rounded),
                label: 'nav_trips'.tr(),
              ),
              NavigationDestination(
                icon: const Icon(Icons.person_outline_rounded),
                selectedIcon: const Icon(Icons.person_rounded),
                label: 'nav_profile'.tr(),
              ),
            ],
          ),
        ),
      ),
      ),
    );
  }
}

/// تا وقتی روی این route صفحهٔ دیگری باز است، آخرین [MediaQueryData] را ثابت
/// نگه می‌دارد. چون IndexedStack هر ۴ تب را زنده نگه می‌دارد، بدون این کار
/// هر تغییر اندازهٔ کیبورد باعث ساخت دوبارهٔ همهٔ آن‌ها می‌شد.
class _FreezeMediaQueryWhenCovered extends StatefulWidget {
  const _FreezeMediaQueryWhenCovered({required this.child});

  final Widget child;

  @override
  State<_FreezeMediaQueryWhenCovered> createState() =>
      _FreezeMediaQueryWhenCoveredState();
}

class _FreezeMediaQueryWhenCoveredState
    extends State<_FreezeMediaQueryWhenCovered> {
  MediaQueryData? _frozen;

  @override
  Widget build(BuildContext context) {
    final MediaQueryData live = MediaQuery.of(context);
    final ModalRoute<dynamic>? route = ModalRoute.of(context);
    final bool covered = route != null && !route.isCurrent;

    if (covered) {
      _frozen ??= live;
    } else {
      _frozen = null;
    }

    return MediaQuery(
      data: covered ? _frozen! : live,
      child: widget.child,
    );
  }
}
