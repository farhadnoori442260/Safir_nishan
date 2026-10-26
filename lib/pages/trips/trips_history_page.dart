import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:easy_localization/easy_localization.dart';
import 'package:flutter/material.dart';
import 'package:provider/provider.dart';

import 'package:safir_drivers/providers/trip_provider.dart';
import 'package:safir_drivers/utils/app_colors.dart';
import 'package:safir_drivers/utils/trip_extras.dart';

const String _enDigits = '0123456789';
const String _faDigits = '۰۱۲۳۴۵۶۷۸۹';
const String _arDigits = '٠١٢٣٤٥٦٧٨٩';

String _toEnglishDigits(String input) {
  String value = input;

  for (int i = 0; i < 10; i++) {
    value = value
        .replaceAll(_faDigits[i], _enDigits[i])
        .replaceAll(_arDigits[i], _enDigits[i]);
  }

  return value;
}

String _toFaDigits(Object value) {
  String result = value.toString();

  for (int i = 0; i < 10; i++) {
    result = result.replaceAll(_enDigits[i], _faDigits[i]);
  }

  return result;
}

double? _toNumber(Object? value) {
  if (value == null) return null;
  if (value is num) return value.toDouble();

  String text = _toEnglishDigits(value.toString().trim());
  text = text.replaceAll(RegExp(r'[,،٬s]'), '').replaceAll('٫', '.');
  text = text.replaceAll(RegExp(r'[^0-9.-]'), '');

  return double.tryParse(text);
}

String _formatMoney(double value) {
  final String digits = value.round().abs().toString();
  final StringBuffer buffer = StringBuffer();

  for (int i = 0; i < digits.length; i++) {
    if (i > 0 && (digits.length - i) % 3 == 0) {
      buffer.write(',');
    }
    buffer.write(digits[i]);
  }

  return _toFaDigits('${value < 0 ? '-' : ''}$buffer');
}

DateTime? _tripDate(Map<String, dynamic> trip) {
  final Object? raw = trip['completed_at'] ??
      trip['completedAt'] ??
      trip['ended_at'] ??
      trip['endedAt'] ??
      trip['updated_at'] ??
      trip['updatedAt'] ??
      trip['created_at'] ??
      trip['createdAt'];

  if (raw is Timestamp) return raw.toDate();
  if (raw is DateTime) return raw;
  if (raw is String) return DateTime.tryParse(raw);

  return null;
}

class TripsHistoryPage extends StatefulWidget {
  const TripsHistoryPage({super.key});

  @override
  State<TripsHistoryPage> createState() => _TripsHistoryPageState();
}

class _TripsHistoryPageState extends State<TripsHistoryPage> {
  @override
  void initState() {
    super.initState();

    WidgetsBinding.instance.addPostFrameCallback((_) {
      if (!mounted) return;
      context.read<TripProvider>().getCompletedTrips();
    });
  }

  Future<void> _refresh() async {
    await context.read<TripProvider>().getCompletedTrips();
  }

  @override
  Widget build(BuildContext context) {
    final TripProvider tripProvider = context.watch<TripProvider>();

    final List<Map<String, dynamic>> trips =
        List<Map<String, dynamic>>.of(tripProvider.completedTrips)
          ..sort((Map<String, dynamic> a, Map<String, dynamic> b) {
            final DateTime dateA =
                _tripDate(a) ?? DateTime.fromMillisecondsSinceEpoch(0);
            final DateTime dateB =
                _tripDate(b) ?? DateTime.fromMillisecondsSinceEpoch(0);

            return dateB.compareTo(dateA);
          });

    return Scaffold(
      backgroundColor: AppColors.background,
      appBar: AppBar(
        title: Text(
          'trips_history_title'.tr(),
          style: const TextStyle(
            fontWeight: FontWeight.bold,
            fontSize: 17,
            color: AppColors.textPrimary,
          ),
        ),
        centerTitle: true,
        backgroundColor: AppColors.cardBackground,
        elevation: 0,
        automaticallyImplyLeading: true,
        iconTheme: const IconThemeData(
          color: AppColors.iconPrimary,
        ),
        actions: [
          IconButton(
            tooltip: 'tooltip_refresh'.tr(),
            onPressed: tripProvider.isLoading ? null : _refresh,
            icon: const Icon(Icons.refresh_rounded),
          ),
        ],
      ),
      body: tripProvider.isLoading && trips.isEmpty
          ? const Center(
              child: CircularProgressIndicator(
                valueColor: AlwaysStoppedAnimation<Color>(
                  AppColors.primaryBrand,
                ),
              ),
            )
          : RefreshIndicator(
              color: AppColors.primaryBrand,
              onRefresh: _refresh,
              child: trips.isEmpty
                  ? _buildEmptyState()
                  : ListView.separated(
                      physics: const AlwaysScrollableScrollPhysics(
                        parent: BouncingScrollPhysics(),
                      ),
                      padding: const EdgeInsets.fromLTRB(16, 16, 16, 28),
                      itemCount: trips.length,
                      separatorBuilder: (_, __) =>
                          const SizedBox(height: 14),
                      itemBuilder: (BuildContext context, int index) {
                        return _TripCard(
                          trip: trips[index],
                          tripNumber: trips.length - index,
                        );
                      },
                    ),
            ),
    );
  }

  Widget _buildEmptyState() {
    return ListView(
      physics: const AlwaysScrollableScrollPhysics(
        parent: BouncingScrollPhysics(),
      ),
      children: [
        SizedBox(height: MediaQuery.of(context).size.height * 0.28),
        Center(
          child: Container(
            width: 92,
            height: 92,
            decoration: BoxDecoration(
              color: AppColors.primaryBrand.withOpacity(0.10),
              shape: BoxShape.circle,
            ),
            child: const Icon(
              Icons.route_rounded,
              size: 46,
              color: AppColors.primaryBrand,
            ),
          ),
        ),
        const SizedBox(height: 18),
        Center(
          child: Text(
            'no_trips_history'.tr(),
            textAlign: TextAlign.center,
            style: const TextStyle(
              color: AppColors.textPrimary,
              fontSize: 16,
              fontWeight: FontWeight.bold,
            ),
          ),
        ),
        const SizedBox(height: 8),
        Center(
          child: Padding(
            padding: const EdgeInsets.symmetric(horizontal: 40),
            child: Text(
              'empty_trips_history_desc'.tr(),
              textAlign: TextAlign.center,
              style: const TextStyle(
                color: AppColors.textSecondary,
                fontSize: 13,
                height: 1.5,
              ),
            ),
          ),
        ),
      ],
    );
  }
}

class _TripCard extends StatelessWidget {
  final Map<String, dynamic> trip;
  final int tripNumber;

  const _TripCard({
    required this.trip,
    required this.tripNumber,
  });

  String _text(Object? value) {
    if (value == null) return '';

    final String result = value.toString().trim();
    return result == 'null' ? '' : result;
  }

  String _firstText(List<Object?> values) {
    for (final Object? value in values) {
      final String result = _text(value);
      if (result.isNotEmpty) return result;
    }

    return '';
  }

  String _formatFare() {
    final double? amount = _toNumber(
      trip['total_fare'] ??
          trip['fareAmount'] ??
          trip['fare'] ??
          trip['price'] ??
          trip['amount'],
    );

    return amount == null ? _toFaDigits('0') : _formatMoney(amount);
  }

  String _formatDate() {
    final DateTime? date = _tripDate(trip);

    if (date == null) {
      return 'date_not_registered'.tr();
    }

    return TripExtras.formatJalaliDateTime(date);
  }

  String _statusText() {
    final String status = _text(trip['status']).toLowerCase();

    if (status == 'completed' ||
        status == 'complete' ||
        status == 'ended' ||
        status == 'finished') {
      return 'status_completed'.tr();
    }

    return status.isEmpty ? 'status_trip'.tr() : status;
  }

  String _origin() {
    return _firstText([
      trip['originAddress'],
      trip['origin_address'],
      trip['originaddress'],
      trip['pickup_address'],
      trip['pickupaddress'],
      trip['pickUpAddress'],
      trip['pickupAddress'],
      trip['origin'],
    ]);
  }

  String _destination() {
    return _firstText([
      trip['destinationAddress'],
      trip['destination_address'],
      trip['destinationaddress'],
      trip['dropoff_address'],
      trip['dropoffaddress'],
      trip['dropOffAddress'],
      trip['dropoffAddress'],
      trip['destination'],
    ]);
  }

  String _distance() {
    final double? km = _toNumber(
      trip['distance'] ?? trip['distanceInKm'] ?? trip['distanceKm'],
    );

    if (km == null || km <= 0) return '--';

    final String formatted =
        _toFaDigits(km.toStringAsFixed(1)).replaceAll('.', '٫');

    return '$formatted ${'unit_km'.tr()}';
  }

  String _duration() {
    final Object? raw =
        trip['duration'] ?? trip['durationText'] ?? trip['tripDuration'];

    if (raw == null) return '--';

    if (raw is num) {
      return '${_toFaDigits(raw.round())} ${'unit_min'.tr()}';
    }

    final String text = _text(raw);
    if (text.isEmpty) return '--';

    return _toFaDigits(text);
  }

  String _currencyLabel() {
    final String value = 'currency_afg'.tr();
    return value == 'currency_afg' ? 'AFN' : value;
  }

  bool get _hasCommission => _toNumber(trip['commission_amount']) != null;

  bool get _isCommissionSettled =>
      _text(trip['commission_status']).toLowerCase() == 'settled';

  @override
  Widget build(BuildContext context) {
    final String origin =
        _origin().isEmpty ? 'origin_not_registered'.tr() : _origin();

    final String destination = _destination().isEmpty
        ? 'destination_not_registered'.tr()
        : _destination();

    return Container(
      decoration: BoxDecoration(
        color: AppColors.cardBackground,
        borderRadius: BorderRadius.circular(22),
        boxShadow: [
          BoxShadow(
            color: Colors.black.withOpacity(0.06),
            blurRadius: 14,
            offset: const Offset(0, 5),
          ),
        ],
      ),
      child: Padding(
        padding: const EdgeInsets.all(16),
        child: Column(
          children: [
            Row(
              children: [
                Container(
                  width: 42,
                  height: 42,
                  decoration: BoxDecoration(
                    color: AppColors.primaryBrand.withOpacity(0.12),
                    borderRadius: BorderRadius.circular(14),
                  ),
                  child: const Icon(
                    Icons.local_taxi_rounded,
                    color: AppColors.primaryBrand,
                    size: 23,
                  ),
                ),
                const SizedBox(width: 12),
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        'trip_number_format'.tr(args: ['$tripNumber']),
                        style: const TextStyle(
                          fontSize: 14,
                          fontWeight: FontWeight.bold,
                          color: AppColors.textPrimary,
                        ),
                      ),
                      const SizedBox(height: 5),
                      Text(
                        _formatDate(),
                        style: const TextStyle(
                          fontSize: 11,
                          color: AppColors.textSecondary,
                        ),
                      ),
                    ],
                  ),
                ),
                Container(
                  padding: const EdgeInsets.symmetric(
                    horizontal: 10,
                    vertical: 6,
                  ),
                  decoration: BoxDecoration(
                    color: Colors.green.withOpacity(0.10),
                    borderRadius: BorderRadius.circular(20),
                  ),
                  child: Row(
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      const Icon(
                        Icons.check_circle_rounded,
                        size: 14,
                        color: Colors.green,
                      ),
                      const SizedBox(width: 4),
                      Text(
                        _statusText(),
                        style: const TextStyle(
                          color: Colors.green,
                          fontSize: 11,
                          fontWeight: FontWeight.bold,
                        ),
                      ),
                    ],
                  ),
                ),
              ],
            ),
            const SizedBox(height: 18),
            _LocationRow(
              icon: Icons.radio_button_checked_rounded,
              iconColor: Colors.blue,
              label: 'origin_label_text'.tr(),
              value: origin,
              isLast: false,
            ),
            _LocationRow(
              icon: Icons.location_on_rounded,
              iconColor: Colors.redAccent,
              label: 'destination_label_text'.tr(),
              value: destination,
              isLast: true,
            ),
            const SizedBox(height: 15),
            Container(
              height: 1,
              color: Colors.grey.withOpacity(0.14),
            ),
            const SizedBox(height: 14),
            Row(
              children: [
                Expanded(
                  child: _InfoItem(
                    icon: Icons.payments_rounded,
                    title: 'fare_label_title'.tr(),
                    value: '${_formatFare()} ${_currencyLabel()}',
                    valueColor: AppColors.primaryBrand,
                  ),
                ),
                Expanded(
                  child: _InfoItem(
                    icon: Icons.route_rounded,
                    title: 'distance_label_title'.tr(),
                    value: _distance(),
                  ),
                ),
                Expanded(
                  child: _InfoItem(
                    icon: Icons.access_time_rounded,
                    title: 'duration_label_title'.tr(),
                    value: _duration(),
                  ),
                ),
              ],
            ),
            if (_hasCommission) ...[
              const SizedBox(height: 14),
              _buildCommissionBox(),
            ],
          ],
        ),
      ),
    );
  }

  Widget _buildCommissionBox() {
    final double commission = _toNumber(trip['commission_amount']) ?? 0;
    final double? earnings = _toNumber(trip['driver_earnings'];

    final Color statusColor =
        _isCommissionSettled ? Colors.green : Colors.orange.shade800;

    return Container(
      width: double.infinity,
      padding: const EdgeInsets.all(12),
      decoration: BoxDecoration(
        color: const Color(0xFFF7F9F8),
        borderRadius: BorderRadius.circular(14),
        border: Border.all(color: Colors.grey.withOpacity(0.18)),
      ),
      child: Row(
        children: [
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  'driver_earnings_label'.tr(),
                  style: const TextStyle(
                    fontSize: 10.5,
                    color: AppColors.textSecondary,
                  ),
                ),
                const SizedBox(height: 3),
                Text(
                  earnings == null
                      ? '--'
                      : '${_formatMoney(earnings)} ${_currencyLabel()}',
                  style: const TextStyle(
                    fontSize: 12.5,
                    fontWeight: FontWeight.bold,
                    color: AppColors.textPrimary,
                  ),
                ),
              ],
            ),
          ),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  'commission_label'.tr(),
                  style: const TextStyle(
                    fontSize: 10.5,
                    color: AppColors.textSecondary,
                  ),
                ),
                const SizedBox(height: 3),
                Text(
                  '${_formatMoney(commission)} ${_currencyLabel()}',
                  style: const TextStyle(
                    fontSize: 12.5,
                    fontWeight: FontWeight.bold,
                    color: AppColors.textPrimary,
                  ),
                ),
              ],
            ),
          ),
          Container(
            padding: const EdgeInsets.symmetric(
              horizontal: 9,
              vertical: 5,
            ),
            decoration: BoxDecoration(
              color: statusColor.withOpacity(0.12),
              borderRadius: BorderRadius.circular(20),
            ),
            child: Text(
              _isCommissionSettled
                  ? 'commission_settled'.tr()
                  : 'commission_unpaid'.tr(),
              style: TextStyle(
                fontSize: 11,
                fontWeight: FontWeight.bold,
                color: statusColor,
              ),
            ),
          ),
        ],
      ),
    );
  }
}

class _LocationRow extends StatelessWidget {
  final IconData icon;
  final Color iconColor;
  final String label;
  final String value;
  final bool isLast;

  const _LocationRow({
    required this.icon,
    required this.iconColor,
    required this.label,
    required this.value,
    required this.isLast,
  });

  @override
  Widget build(BuildContext context) {
    return Row(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        SizedBox(
          width: 24,
          child: Column(
            children: [
              Icon(
                icon,
                size: 17,
                color: iconColor,
              ),
              if (!isLast)
                Container(
                  width: 1,
                  height: 27,
                  margin: const EdgeInsets.only(top: 3),
                  color: Colors.grey.withOpacity(0.35),
                ),
            ],
          ),
        ),
        const SizedBox(width: 10),
        Expanded(
          child: Padding(
            padding: const EdgeInsets.only(bottom: 12),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  label,
                  style: const TextStyle(
                    fontSize: 11,
                    color: AppColors.textSecondary,
                  ),
                ),
                const SizedBox(height: 3),
                Text(
                  value,
                  maxLines: 2,
                  overflow: TextOverflow.ellipsis,
                  style: const TextStyle(
                    fontSize: 13,
                    height: 1.35,
                    color: AppColors.textPrimary,
                    fontWeight: FontWeight.w600,
                  ),
                ),
              ],
            ),
          ),
        ),
      ],
    );
  }
}

class _InfoItem extends StatelessWidget {
  final IconData icon;
  final String title;
  final String value;
  final Color? valueColor;

  const _InfoItem({
    required this.icon,
    required this.title,
    required this.value,
    this.valueColor,
  });

  @override
  Widget build(BuildContext context) {
    return Column(
      children: [
        Icon(
          icon,
          size: 19,
          color: AppColors.primaryBrand,
        ),
        const SizedBox(height: 5),
        Text(
          title,
          style: const TextStyle(
            fontSize: 10,
            color: AppColors.textSecondary,
          ),
        ),
        const SizedBox(height: 4),
        Text(
          value,
          maxLines: 1,
          overflow: TextOverflow.ellipsis,
          textAlign: TextAlign.center,
          style: TextStyle(
            fontSize: 11,
            fontWeight: FontWeight.bold,
            color: valueColor ?? AppColors.textPrimary,
          ),
        ),
      ],
    );
  }
}
