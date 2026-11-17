import 'package:easy_localization/easy_localization.dart';
import 'package:flutter/material.dart';
import 'package:provider/provider.dart';

import 'trips_history_page.dart';
import 'package:safir_drivers/providers/trip_provider.dart';
import 'package:safir_drivers/utils/app_colors.dart';

class TripsPage extends StatefulWidget {
  const TripsPage({super.key});

  @override
  State<TripsPage> createState() => _TripsPageState();
}

class _TripsPageState extends State<TripsPage> {
  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addPostFrameCallback((_) {
      if (mounted) {
        Provider.of<TripProvider>(context, listen: false)
            .getCurrentDriverTotalNumberOfTripsCompleted();
      }
    });
  }

  Future<void> _refresh() async {
    await Provider.of<TripProvider>(context, listen: false)
        .getCurrentDriverTotalNumberOfTripsCompleted();
  }

  @override
  Widget build(BuildContext context) {
    final tripProvider = Provider.of<TripProvider>(context);

    return Scaffold(
      backgroundColor: AppColors.background,
      appBar: AppBar(
        title: Text(
          'trips_report_title'.tr(),
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
        automaticallyImplyLeading: false,
      ),
      body: tripProvider.isLoading
          ? Center(
              child: CircularProgressIndicator(
                valueColor: AlwaysStoppedAnimation<Color>(AppColors.primaryBrand),
              ),
            )
          : RefreshIndicator(
              color: AppColors.primaryBrand,
              onRefresh: _refresh,
              child: ListView(
                physics: const AlwaysScrollableScrollPhysics(
                  parent: BouncingScrollPhysics(),
                ),
                padding: const EdgeInsets.fromLTRB(20, 24, 20, 28),
                children: [
                  // کارت مجموع سفرها
                  Container(
                    width: double.infinity,
                    padding: const EdgeInsets.all(24),
                    decoration: BoxDecoration(
                      color: AppColors.cardBackground,
                      borderRadius: BorderRadius.circular(20),
                      border: Border.all(color: AppColors.borderLight),
                    ),
                    child: Column(
                      children: [
                        Image.asset(
                          'assets/images/totaltrips.png',
                          width: 90,
                          errorBuilder: (_, __, ___) => Icon(
                            Icons.route_rounded,
                            size: 64,
                            color: AppColors.iconSecondary,
                          ),
                        ),
                        const SizedBox(height: 16),
                        Text(
                          'total_completed_trips'.tr(),
                          style: TextStyle(
                            color: AppColors.textSecondary,
                            fontSize: 14,
                          ),
                        ),
                        const SizedBox(height: 8),
                        Text(
                          tripProvider.currentDriverTotalTripsCompleted,
                          style: TextStyle(
                            color: AppColors.textPrimary,
                            fontSize: 36,
                            fontWeight: FontWeight.w800,
                          ),
                        ),
                      ],
                    ),
                  ),

                  const SizedBox(height: 16),

                  // دکمه تاریخچه سفرها
                  Material(
                    color: AppColors.primaryButton,
                    borderRadius: BorderRadius.circular(18),
                    child: InkWell(
                      borderRadius: BorderRadius.circular(18),
                      onTap: () {
                        Navigator.push(
                          context,
                          MaterialPageRoute(
                            builder: (c) => const TripsHistoryPage(),
                          ),
                        );
                      },
                      child: Padding(
                        padding: const EdgeInsets.symmetric(
                            vertical: 18, horizontal: 20),
                        child: Row(
                          mainAxisAlignment: MainAxisAlignment.center,
                          children: [
                            Icon(Icons.history_rounded,
                                color: AppColors.buttonText, size: 22),
                            const SizedBox(width: 10),
                            Text(
                              'view_trips_history'.tr(),
                              style: TextStyle(
                                color: AppColors.buttonText,
                                fontSize: 15,
                                fontWeight: FontWeight.bold,
                              ),
                            ),
                            const SizedBox(width: 6),
                            Icon(
                              Icons.chevron_left_rounded,
                              color: AppColors.buttonText,
                              size: 22,
                            ),
                          ],
                        ),
                      ),
                    ),
                  ),
                ],
              ),
            ),
    );
  }
}
