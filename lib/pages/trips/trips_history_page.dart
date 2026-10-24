import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:easy_localization/easy_localization.dart';
import 'package:flutter/material.dart';
import 'package:provider/provider.dart';

import 'package:safir_drivers/providers/trip_provider.dart';
import 'package:safir_drivers/utils/app_colors.dart';

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
    final TripProvider tripProvider =
        context.watch<TripProvider>();

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
      body: tripProvider.isLoading &&
              tripProvider.completedTrips.isEmpty
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
              child: tripProvider.completedTrips.isEmpty
                  ? _buildEmptyState()
                  : ListView.separated(
                      physics: const AlwaysScrollableScrollPhysics(
                        parent: BouncingScrollPhysics(),
                      ),
                      padding: const EdgeInsets.fromLTRB(
                        16,
                        16,
                        16,
                        28,
                      ),
                      itemCount: tripProvider.completedTrips.length,
                      separatorBuilder: (_, __) =>
                          const SizedBox(height: 14),
                      itemBuilder: (context, index) {
                        final Map<String, dynamic> trip =
                            tripProvider.completedTrips[index];

                        return _TripCard(
                          trip: trip,
                          index: index,
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
        SizedBox(
          height: MediaQuery.of(context).size.height * 0.28,
        ),
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
  final int index;

  const _TripCard({
    required this.trip,
    required this.index,
  });

  String _text(Object? value) {
    if (value == null) return '';
    return value.toString().trim();
  }

  String _firstText(List<Object?> values) {
    for (final Object? value in values) {
      final String result = _text(value);
      if (result.isNotEmpty) return result;
    }
    return '';
  }

  String _formatAmount() {
    final Object? rawAmount = trip['fareAmount'] ??
        trip['fare'] ??
        trip['price'] ??
        trip['amount'];

    if (rawAmount == null) {
      return '0';
    }

    if (rawAmount is num) {
      return rawAmount
          .toStringAsFixed(0)
          .replaceAllMapped(
            RegExp(r'(d)(?=(d{3})+(?!d))'),
            (Match match) => '${match[1]},',
          );
    }

    return _text(rawAmount);
  }

  DateTime? _dateValue() {
    final Object? rawDate = trip['completedAt'] ??
        trip['endedAt'] ??
        trip['updatedAt'] ??
        trip['createdAt'];

    if (rawDate is Timestamp) {
      return rawDate.toDate();
    }

    if (rawDate is DateTime) {
      return rawDate;
    }

    if (rawDate is String) {
      return DateTime.tryParse(rawDate);
    }

    return null;
  }

  String _formatDate() {
    final DateTime? date = _dateValue();

    if (date == null) {
      return 'date_not_registered'.tr();
    }

    return DateFormat(
      'yyyy/MM/dd - HH:mm',
      'fa',
    ).format(date);
  }

  String _statusText() {
    final String status =
        _text(trip['status']).toLowerCase();

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
      trip['originaddress'],
      trip['pickupaddress'],
      trip['pickUpAddress'],
      trip['pickupAddress'],
      trip['origin'],
    ]);
  }

  String _destination() {
    return _firstText([
      trip['destinationAddress'],
      trip['destinationaddress'],
      trip['dropoffaddress'],
      trip['dropOffAddress'],
      trip['dropoffAddress'],
      trip['destination'],
    ]);
  }

  String _distance() {
    final String value = _firstText([
      trip['distance'],
      trip['distanceInKm'],
      trip['distanceKm'],
    ]);

    if (value.isEmpty) return '--';
    return '$value km';
  }

  String _duration() {
    return _firstText([
          trip['duration'],
          trip['durationText'],
          trip['tripDuration'],
        ]).isEmpty
        ? '--'
        : _firstText([
            trip['duration'],
            trip['durationText'],
            trip['tripDuration'],
          ]);
  }

  @override
  Widget build(BuildContext context) {
    final String origin = _origin().isEmpty
        ? 'origin_not_registered'.tr()
        : _origin();

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
                    crossAxisAlignment:
                        CrossAxisAlignment.start,
                    children: [
                      Text(
                        'trip_number_format'.tr(args: ['${index + 1}']),
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
                    value:
                        '${_formatAmount()} ${_currencyAfgLabel()}',
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
          ],
        ),
      ),
    );
  }

  String _currencyAfgLabel() {
    try {
      return 'currency_afg'.tr();
    } catch (_) {
      return 'افغانی';
    }
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
              crossAxisAlignment:
                  CrossAxisAlignment.start,
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
