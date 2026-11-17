import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:easy_localization/easy_localization.dart'
    hide TextDirection;
import 'package:firebase_auth/firebase_auth.dart';
import 'package:flutter/material.dart';
import 'package:provider/provider.dart';

import '../../providers/registration_provider.dart';
import '../../utils/app_colors.dart';

String _t(String key, String fallback) {
  final String v = key.tr();
  return (v.trim().isEmpty || v == key) ? fallback : v;
}

class EarningsPage extends StatefulWidget {
  const EarningsPage({super.key});

  @override
  State<EarningsPage> createState() => _EarningsPageState();
}

class _EarningsPageState extends State<EarningsPage> {
  Color get _paidColor => AppColors.success;
  Color get _pendingColor => AppColors.accentOrange;
  Color get _settledColor => AppColors.originBlue;

  Stream<QuerySnapshot<Map<String, dynamic>>>? _ridesStream;

  Future<void> _refreshEarnings() async {
    await context.read<RegistrationProvider>().fetchDriverEarnings();
  }

  @override
  void initState() {
    super.initState();

    final String? uid = FirebaseAuth.instance.currentUser?.uid;

    if (uid != null && uid.isNotEmpty) {
      // دو شرط مساوی/whereIn و بدون orderBy: به ایندکس ترکیبی نیاز ندارد
      _ridesStream = FirebaseFirestore.instance
          .collection('rides')
          .where('driver_id', isEqualTo: uid)
          .where('status', whereIn: <String>['completed', 'ended'])
          .limit(200)
          .snapshots();
    }

    WidgetsBinding.instance.addPostFrameCallback((_) {
      if (!mounted) return;

      _refreshEarnings();
    });
  }

  String _formatAmount(double amount) {
    if (amount.isNaN || amount.isInfinite) {
      return '0';
    }

    if (amount == amount.roundToDouble()) {
      return amount.toInt().toString();
    }

    return amount.toStringAsFixed(2);
  }

  double _toDouble(dynamic value) {
    if (value is num) return value.toDouble();
    return double.tryParse(
          value?.toString().replaceAll(',', '').trim() ?? '',
        ) ??
        0;
  }

  double _rideFare(Map<String, dynamic> d) {
    return _toDouble(
      d['total_fare'] ?? d['fareAmount'] ?? d['fare'] ?? d['price'],
    );
  }

  DateTime? _rideDate(Map<String, dynamic> d) {
    final dynamic v = d['completed_at'] ?? d['updated_at'] ?? d['createdAt'];
    return v is Timestamp ? v.toDate() : null;
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: AppColors.background,
      appBar: AppBar(
        title: Text(
          'earnings_screen_title'.tr(),
          style: TextStyle(
            fontSize: 16,
            fontWeight: FontWeight.bold,
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
      body: RefreshIndicator(
        color: AppColors.primaryBrand,
        onRefresh: _refreshEarnings,
        child: ListView(
          physics: const AlwaysScrollableScrollPhysics(
            parent: BouncingScrollPhysics(),
          ),
          padding: const EdgeInsets.fromLTRB(16, 16, 16, 28),
          children: [
            _buildEarningsCard(),
            const SizedBox(height: 16),
            _buildPaymentSection(),
          ],
        ),
      ),
    );
  }

  // ───────────── کارت اصلی درآمد ─────────────

  Widget _buildEarningsCard() {
    return Container(
      width: double.infinity,
      padding: const EdgeInsets.symmetric(vertical: 26, horizontal: 20),
      decoration: BoxDecoration(
        color: AppColors.cardBackground,
        borderRadius: BorderRadius.circular(22),
        border: Border.all(color: AppColors.borderLight),
      ),
      child: Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          Icon(
            Icons.account_balance_wallet_rounded,
            size: 34,
            color: AppColors.success,
          ),
          const SizedBox(height: 12),
          Text(
            'total_earnings_title'.tr(),
            style: TextStyle(
              color: AppColors.textSecondary,
              fontSize: 14,
              fontWeight: FontWeight.w600,
            ),
          ),
          const SizedBox(height: 8),
          Consumer<RegistrationProvider>(
            builder: (context, provider, child) {
              if (provider.isFetchLoading) {
                return Padding(
                  padding: const EdgeInsets.all(10),
                  child: SizedBox(
                    width: 26,
                    height: 26,
                    child: CircularProgressIndicator(
                      strokeWidth: 2.6,
                      valueColor:
                          AlwaysStoppedAnimation<Color>(AppColors.primaryBrand),
                    ),
                  ),
                );
              }

              return Row(
                mainAxisAlignment: MainAxisAlignment.center,
                crossAxisAlignment: CrossAxisAlignment.baseline,
                textBaseline: TextBaseline.alphabetic,
                children: [
                  Flexible(
                    child: FittedBox(
                      fit: BoxFit.scaleDown,
                      child: Text(
                        _formatAmount(provider.driverEarnings),
                        style: TextStyle(
                          color: AppColors.textPrimary,
                          fontSize: 38,
                          fontWeight: FontWeight.w800,
                        ),
                      ),
                    ),
                  ),
                  const SizedBox(width: 8),
                  Text(
                    'currency_unit'.tr(),
                    style: TextStyle(
                      color: AppColors.textSecondary,
                      fontSize: 15,
                      fontWeight: FontWeight.w600,
                    ),
                  ),
                ],
              );
            },
          ),
        ],
      ),
    );
  }

  // ───────────── وضعیت پرداخت سفرها ─────────────

  Widget _buildPaymentSection() {
    final Stream<QuerySnapshot<Map<String, dynamic>>>? stream = _ridesStream;

    if (stream == null) {
      return const SizedBox.shrink();
    }

    return StreamBuilder<QuerySnapshot<Map<String, dynamic>>>(
      stream: stream,
      builder: (context, snapshot) {
        if (snapshot.hasError) {
          debugPrint('Earnings rides stream error: ${snapshot.error}');
          return const SizedBox.shrink();
        }

        if (!snapshot.hasData) {
          return Padding(
            padding: EdgeInsets.symmetric(vertical: 24),
            child: Center(
              child: SizedBox(
                width: 24,
                height: 24,
                child: CircularProgressIndicator(
                  strokeWidth: 2.4,
                  color: AppColors.primaryBrand,
                ),
              ),
            ),
          );
        }

        final List<Map<String, dynamic>> rides =
            snapshot.data!.docs.map((d) => d.data()).toList()
              ..sort((a, b) {
                final DateTime? da = _rideDate(a);
                final DateTime? db = _rideDate(b);
                if (da == null && db == null) return 0;
                if (da == null) return 1;
                if (db == null) return -1;
                return db.compareTo(da);
              });

        double unconfirmed = 0;
        double confirmed = 0;
        double settled = 0;

        for (final Map<String, dynamic> r in rides) {
          final double fare = _rideFare(r);
          final String status = r['payment_status']?.toString() ?? 'unpaid';

          if (status == 'settled') {
            settled += fare;
          } else if (status == 'paid') {
            confirmed += fare;
          } else {
            unconfirmed += fare;
          }
        }

        return Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(
              children: [
                Expanded(
                  child: _statTile(
                    label: _t('earnings_unconfirmed', 'تایید نشده'),
                    value: unconfirmed,
                    color: _pendingColor,
                    icon: Icons.hourglass_top_rounded,
                  ),
                ),
                const SizedBox(width: 8),
                Expanded(
                  child: _statTile(
                    label: _t('earnings_confirmed', 'تایید شده'),
                    value: confirmed,
                    color: _paidColor,
                    icon: Icons.check_circle_rounded,
                  ),
                ),
                const SizedBox(width: 8),
                Expanded(
                  child: _statTile(
                    label: _t('earnings_settled', 'تسویه شده'),
                    value: settled,
                    color: _settledColor,
                    icon: Icons.verified_rounded,
                  ),
                ),
              ],
            ),
            const SizedBox(height: 20),
            Text(
              _t('earnings_recent_trips', 'آخرین سفرها'),
              style: TextStyle(
                color: AppColors.textPrimary,
                fontSize: 15,
                fontWeight: FontWeight.w800,
              ),
            ),
            const SizedBox(height: 10),
            if (rides.isEmpty)
              _emptyState()
            else
              ...rides.take(15).map(_rideTile),
          ],
        );
      },
    );
  }

  Widget _statTile({
    required String label,
    required double value,
    required Color color,
    required IconData icon,
  }) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 12),
      decoration: BoxDecoration(
        color: AppColors.cardBackground,
        borderRadius: BorderRadius.circular(16),
        border: Border.all(color: AppColors.borderLight),
      ),
      child: Column(
        children: [
          Icon(icon, size: 22, color: color),
          const SizedBox(height: 8),
          FittedBox(
            fit: BoxFit.scaleDown,
            child: Text(
              _formatAmount(value),
              style: TextStyle(
                color: AppColors.textPrimary,
                fontSize: 15,
                fontWeight: FontWeight.w800,
              ),
            ),
          ),
          const SizedBox(height: 2),
          Text(
            label,
            maxLines: 1,
            overflow: TextOverflow.ellipsis,
            style: TextStyle(
              color: color,
              fontSize: 11,
              fontWeight: FontWeight.w700,
            ),
          ),
        ],
      ),
    );
  }

  Widget _rideTile(Map<String, dynamic> ride) {
    final String status = ride['payment_status']?.toString() ?? 'unpaid';

    final Color color;
    final String label;

    switch (status) {
      case 'settled':
        color = _settledColor;
        label = _t('payment_status_settled', 'تسویه شد');
        break;
      case 'paid':
        color = _paidColor;
        label = _t('payment_status_paid', 'تایید شد');
        break;
      case 'awaiting_driver_confirmation':
        color = _pendingColor;
        label = _t('payment_status_awaiting', 'منتظر تایید شما');
        break;
      default:
        color = AppColors.textSecondary;
        label = _t('payment_status_unpaid_short', 'تایید نشده');
    }

    final String destination = ride['destination_address']?.toString() ??
        ride['destinationAddress']?.toString() ??
        ride['dropoff_address']?.toString() ??
        '-';

    final DateTime? date = _rideDate(ride);
    final String dateText =
        date == null ? '' : DateFormat('yyyy/MM/dd  HH:mm').format(date);

    return Container(
      margin: const EdgeInsets.only(bottom: 8),
      padding: const EdgeInsets.all(12),
      decoration: BoxDecoration(
        color: AppColors.cardBackground,
        borderRadius: BorderRadius.circular(16),
        border: Border.all(color: AppColors.borderLight),
      ),
      child: Row(
        children: [
          Icon(Icons.local_taxi_rounded, size: 24, color: color),
          const SizedBox(width: 12),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  destination,
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis,
                  style: TextStyle(
                    color: AppColors.textPrimary,
                    fontSize: 13,
                    fontWeight: FontWeight.w700,
                  ),
                ),
                if (dateText.isNotEmpty) ...[
                  const SizedBox(height: 3),
                  Text(
                    dateText,
                    textDirection: TextDirection.ltr,
                    style: TextStyle(
                      color: AppColors.textSecondary,
                      fontSize: 11,
                    ),
                  ),
                ],
              ],
            ),
          ),
          const SizedBox(width: 8),
          Column(
            crossAxisAlignment: CrossAxisAlignment.end,
            children: [
              Text(
                '${_formatAmount(_rideFare(ride))} ${'currency_unit'.tr()}',
                style: TextStyle(
                  color: AppColors.textPrimary,
                  fontSize: 13,
                  fontWeight: FontWeight.w800,
                ),
              ),
              const SizedBox(height: 4),
              Container(
                padding:
                    const EdgeInsets.symmetric(horizontal: 8, vertical: 3),
                decoration: BoxDecoration(
                  color: color.withOpacity(0.12),
                  borderRadius: BorderRadius.circular(20),
                ),
                child: Text(
                  label,
                  style: TextStyle(
                    color: color,
                    fontSize: 10.5,
                    fontWeight: FontWeight.w700,
                  ),
                ),
              ),
            ],
          ),
        ],
      ),
    );
  }

  Widget _emptyState() {
    return Container(
      width: double.infinity,
      padding: const EdgeInsets.symmetric(vertical: 28),
      decoration: BoxDecoration(
        color: AppColors.cardBackground,
        borderRadius: BorderRadius.circular(16),
        border: Border.all(color: AppColors.borderLight),
      ),
      child: Column(
        children: [
          Icon(Icons.receipt_long_rounded,
              size: 36, color: AppColors.iconSecondary),
          const SizedBox(height: 8),
          Text(
            _t('earnings_no_trips', 'هنوز سفر تمام‌شده‌ای ندارید'),
            style: TextStyle(
              color: AppColors.textSecondary,
              fontSize: 13,
            ),
          ),
        ],
      ),
    );
  }
}
