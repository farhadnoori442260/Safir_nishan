import 'dart:ui' as ui;
import 'package:easy_localization/easy_localization.dart';
import 'package:flutter/material.dart';
import 'package:maplibre_gl/maplibre_gl.dart';

import 'package:safir_drivers/constants/trip_status.dart';
import 'package:safir_drivers/pages/chat_page.dart';

class ActiveTripSheet extends StatelessWidget {
  final String tripId;
  final String status;
  final Map<String, dynamic> tripData;
  final bool isTripActionLoading;
  final Function(String tripId, String newStatus) onUpdateTripStatus;
  final Function(String tripId) onCancelTrip;
  final Function(String phoneNumber) onMakePhoneCall;
  final Function(double lat, double lng) onOpenExternalMap;
  final LatLng? Function() getNavigationTarget;

  const ActiveTripSheet({
    super.key,
    required this.tripId,
    required this.status,
    required this.tripData,
    required this.isTripActionLoading,
    required this.onUpdateTripStatus,
    required this.onCancelTrip,
    required this.onMakePhoneCall,
    required this.onOpenExternalMap,
    required this.getNavigationTarget,
  });

  static const Color _primary = Color(0xFF0F766E);
  static const Color _primaryDark = Color(0xFF115E59);
  static const Color _surface = Color(0xFFF8FAFC);
  static const Color _card = Colors.white;
  static const Color _text = Color(0xFF172033);
  static const Color _mutedText = Color(0xFF64748B);
  static const Color _danger = Color(0xFFDC2626);
  static const Color _blue = Color(0xFF2563EB);

  String _formatNumber(dynamic value, {required int decimals}) {
    if (value == null) return '---';

    if (value is num) {
      return value.toDouble().toStringAsFixed(decimals);
    }

    final raw = value.toString().trim();
    if (raw.isEmpty) return '---';

    final cleaned = raw.replaceAll(',', '');
    final number = double.tryParse(cleaned);

    return number == null ? raw : number.toStringAsFixed(decimals);
  }

  String _getActionButtonTitle(String currentStatus) {
    if (currentStatus == TripStatus.accepted) {
      return 'btn_arrived_pickup'.tr();
    }

    if (currentStatus == TripStatus.arrived) {
      return 'btn_start_trip'.tr();
    }

    if (currentStatus == TripStatus.onTrip) {
      return 'btn_end_trip'.tr();
    }

    return 'btn_arrived_pickup'.tr();
  }

  String _getStatusText() {
    if (status == TripStatus.accepted) {
      return 'سفر پذیرفته شد';
    }

    if (status == TripStatus.arrived) {
      return 'به مبدأ رسیدید';
    }

    if (status == TripStatus.onTrip) {
      return 'سفر در جریان است';
    }

    return 'سفر فعال';
  }

  IconData _getStatusIcon() {
    if (status == TripStatus.accepted) {
      return Icons.directions_car_filled_rounded;
    }

    if (status == TripStatus.arrived) {
      return Icons.location_on_rounded;
    }

    if (status == TripStatus.onTrip) {
      return Icons.route_rounded;
    }

    return Icons.local_taxi_rounded;
  }

  void _handleTripAction() {
    if (status == TripStatus.accepted) {
      onUpdateTripStatus(tripId, TripStatus.arrived);
    } else if (status == TripStatus.arrived) {
      onUpdateTripStatus(tripId, TripStatus.onTrip);
    } else if (status == TripStatus.onTrip) {
      onUpdateTripStatus(tripId, TripStatus.completed);
    }
  }

  @override
  Widget build(BuildContext context) {
    final passengerName = tripData['passenger_name']?.toString() ??
        tripData['userName']?.toString() ??
        tripData['full_name']?.toString() ??
        'passenger'.tr();

    final passengerPhone = tripData['passenger_phone']?.toString() ??
        tripData['userPhone']?.toString() ??
        tripData['phone']?.toString() ??
        '';

    final passengerRating =
        '${tripData['userRating'] ?? tripData['rating'] ?? '4.8'}';

    final originAddress = tripData['origin_address']?.toString() ??
        tripData['originAddress']?.toString() ??
        tripData['pickup_address']?.toString() ??
        '-';

    final destinationAddress =
        tripData['destination_address']?.toString() ??
            tripData['destinationAddress']?.toString() ??
            tripData['dropoff_address']?.toString() ??
            '-';

    final duration = _formatNumber(
      tripData['trip_duration'] ??
          tripData['duration'] ??
          tripData['estimatedDuration'] ??
          tripData['durationMinutes'],
      decimals: 0,
    );

    final distance = _formatNumber(
      tripData['distance'] ??
          tripData['estimatedDistance'] ??
          tripData['distanceKm'],
      decimals: 1,
    );

    final price = _formatNumber(
      tripData['total_fare'] ??
          tripData['fare_amount'] ??
          tripData['fareAmount'] ??
          tripData['fare'] ??
          tripData['price'],
      decimals: 0,
    );

    return DraggableScrollableSheet(
      initialChildSize: 0.64,
      minChildSize: 0.25,
      maxChildSize: 0.92,
      snap: true,
      snapSizes: const [0.25, 0.64, 0.92],
      builder: (BuildContext context, ScrollController scrollController) {
        return Container(
          decoration: const BoxDecoration(
            color: _surface,
            borderRadius: BorderRadius.vertical(
              top: Radius.circular(28),
            ),
          ),
          child: SafeArea(
            top: false,
            child: SingleChildScrollView(
              controller: scrollController,
              padding: const EdgeInsets.fromLTRB(16, 10, 16, 20),
              child: Column(
                mainAxisSize: MainAxisSize.min,
                children: [
                  Container(
                    width: 42,
                    height: 5,
                    margin: const EdgeInsets.only(bottom: 14),
                    decoration: BoxDecoration(
                      color: const Color(0xFFCBD5E1),
                      borderRadius: BorderRadius.circular(99),
                    ),
                  ),
                  _buildStatusHeader(),
                  const SizedBox(height: 12),
                  _buildPassengerCard(
                    passengerName: passengerName,
                    passengerPhone: passengerPhone,
                    passengerRating: passengerRating,
                  ),
                  const SizedBox(height: 12),
                  _buildAddressCard(
                    originAddress: originAddress,
                    destinationAddress: destinationAddress,
                  ),
                  const SizedBox(height: 12),
                  _buildTripInformation(
                    duration: duration,
                    distance: distance,
                    price: price,
                  ),
                  const SizedBox(height: 12),
                  _buildNavigationNotice(),
                  const SizedBox(height: 16),
                  _buildMainActionButton(),
                  const SizedBox(height: 10),
                  _buildSecondaryActions(
                    context: context,
                    passengerName: passengerName,
                    passengerPhone: passengerPhone,
                  ),
                  const SizedBox(height: 10),
                  _buildNavigationButton(context),
                ],
              ),
            ),
          ),
        );
      },
    );
  }

  Widget _buildStatusHeader() {
    return Container(
      width: double.infinity,
      padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 12),
      decoration: BoxDecoration(
        gradient: const LinearGradient(
          colors: [_primary, _primaryDark],
          begin: Alignment.centerLeft,
          end: Alignment.centerRight,
        ),
        borderRadius: BorderRadius.circular(16),
        boxShadow: [
          BoxShadow(
            color: _primary.withOpacity(0.22),
            blurRadius: 16,
            offset: const Offset(0, 7),
          ),
        ],
      ),
      child: Row(
        children: [
          Container(
            height: 40,
            width: 40,
            decoration: BoxDecoration(
              color: Colors.white.withOpacity(0.16),
              borderRadius: BorderRadius.circular(12),
            ),
            child: Icon(
              _getStatusIcon(),
              color: Colors.white,
              size: 23,
            ),
          ),
          const SizedBox(width: 11),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  _getStatusText(),
                  style: const TextStyle(
                    color: Colors.white,
                    fontSize: 15,
                    fontWeight: FontWeight.bold,
                  ),
                ),
                const SizedBox(height: 2),
                const Text(
                  'جزئیات سفر و مسیر‌یابی شما',
                  style: TextStyle(
                    color: Color(0xFFD1FAE5),
                    fontSize: 11,
                    fontWeight: FontWeight.w500,
                  ),
                ),
              ],
            ),
          ),
          const Icon(
            Icons.verified_rounded,
            color: Color(0xFFD1FAE5),
            size: 21,
          ),
        ],
      ),
    );
  }

  Widget _buildPassengerCard({
    required String passengerName,
    required String passengerPhone,
    required String passengerRating,
  }) {
    return _cardContainer(
      child: Row(
        children: [
          Container(
            height: 50,
            width: 50,
            decoration: BoxDecoration(
              color: const Color(0xFFCCFBF1),
              borderRadius: BorderRadius.circular(16),
            ),
            child: const Icon(
              Icons.person_rounded,
              color: _primary,
              size: 28,
            ),
          ),
          const SizedBox(width: 12),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  passengerName,
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis,
                  style: const TextStyle(
                    fontWeight: FontWeight.w800,
                    fontSize: 16,
                    color: _text,
                  ),
                ),
                const SizedBox(height: 5),
                Row(
                  children: [
                    const Icon(
                      Icons.star_rounded,
                      color: Color(0xFFF59E0B),
                      size: 17,
                    ),
                    const SizedBox(width: 3),
                    Text(
                      passengerRating,
                      style: const TextStyle(
                        color: _text,
                        fontSize: 12,
                        fontWeight: FontWeight.w700,
                      ),
                    ),
                    const SizedBox(width: 10),
                    Expanded(
                      child: Text(
                        passengerPhone.isEmpty
                            ? 'شماره تماس موجود نیست'
                            : passengerPhone,
                        textDirection: ui.TextDirection.ltr,
                        maxLines: 1,
                        overflow: TextOverflow.ellipsis,
                        style: const TextStyle(
                          color: _mutedText,
                          fontSize: 12,
                        ),
                      ),
                    ),
                  ],
                ),
              ],
            ),
          ),
          const SizedBox(width: 8),
          Semantics(
            label: 'تماس با مسافر',
            button: true,
            child: Material(
              color: passengerPhone.isEmpty
                  ? const Color(0xFFF1F5F9)
                  : const Color(0xFFDCFCE7),
              borderRadius: BorderRadius.circular(14),
              child: InkWell(
                borderRadius: BorderRadius.circular(14),
                onTap: passengerPhone.isEmpty
                    ? null
                    : () => onMakePhoneCall(passengerPhone),
                child: Container(
                  width: 46,
                  height: 46,
                  alignment: Alignment.center,
                  child: Icon(
                    Icons.phone_in_talk_rounded,
                    color: passengerPhone.isEmpty
                        ? const Color(0xFF94A3B8)
                        : const Color(0xFF15803D),
                    size: 22,
                  ),
                ),
              ),
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildAddressCard({
    required String originAddress,
    required String destinationAddress,
  }) {
    return _cardContainer(
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Column(
            children: [
              Container(
                width: 18,
                height: 18,
                decoration: const BoxDecoration(
                  color: Color(0xFFDCFCE7),
                  shape: BoxShape.circle,
                ),
                child: const Icon(
                  Icons.circle,
                  size: 9,
                  color: Color(0xFF16A34A),
                ),
              ),
              Container(
                width: 2,
                height: 38,
                color: const Color(0xFFCBD5E1),
              ),
              Container(
                width: 18,
                height: 18,
                decoration: const BoxDecoration(
                  color: Color(0xFFFEE2E2),
                  shape: BoxShape.circle,
                ),
                child: const Icon(
                  Icons.location_on_rounded,
                  size: 13,
                  color: _danger,
                ),
              ),
            ],
          ),
          const SizedBox(width: 12),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                _buildAddressText(
                  label: 'مبدأ',
                  value: originAddress,
                  labelColor: const Color(0xFF15803D),
                ),
                const SizedBox(height: 16),
                _buildAddressText(
                  label: 'مقصد',
                  value: destinationAddress,
                  labelColor: _danger,
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildAddressText({
    required String label,
    required String value,
    required Color labelColor,
  }) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(
          label,
          style: TextStyle(
            fontSize: 11,
            color: labelColor,
            fontWeight: FontWeight.w800,
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
            fontWeight: FontWeight.w600,
            color: _text,
          ),
        ),
      ],
    );
  }

  Widget _buildTripInformation({
    required String duration,
    required String distance,
    required String price,
  }) {
    return Row(
      children: [
        Expanded(
          child: _buildInfoCard(
            icon: Icons.schedule_rounded,
            label: 'زمان',
            value: duration == '---'
          ? '---'
          : '$duration ${'time_minute'.tr()}',
            color: const Color(0xFFF97316),
            backgroundColor: const Color(0xFFFFEDD5),
          ),
        ),
        const SizedBox(width: 8),
        Expanded(
          child: _buildInfoCard(
            icon: Icons.route_rounded,
            label: 'trip_distance_label'.tr(),
            value: distance == '---'
          ? '---'
          : '$distance ${'km_unit'.tr()}',
            color: _blue,
            backgroundColor: const Color(0xFFDBEAFE),
          ),
        ),
        const SizedBox(width: 8),
        Expanded(
          child: _buildInfoCard(
            icon: Icons.account_balance_wallet_rounded,
            label: 'trip_fare_label'.tr(),
            value: price == '---'
          ? '---'
          : '$price ${'currency_afg'.tr()}',
            color: _primary,
            backgroundColor: const Color(0xFFCCFBF1),
          ),
        ),
      ],
    );
  }

  Widget _buildInfoCard({
    required IconData icon,
    required String label,
    required String value,
    required Color color,
    required Color backgroundColor,
  }) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 11),
      decoration: BoxDecoration(
        color: _card,
        borderRadius: BorderRadius.circular(15),
        border: Border.all(color: const Color(0xFFE2E8F0)),
      ),
      child: Column(
        children: [
          Container(
            width: 29,
            height: 29,
            decoration: BoxDecoration(
              color: backgroundColor,
              borderRadius: BorderRadius.circular(9),
            ),
            child: Icon(icon, size: 17, color: color),
          ),
          const SizedBox(height: 7),
          Text(
            value,
            maxLines: 1,
            overflow: TextOverflow.ellipsis,
            textAlign: TextAlign.center,
            style: const TextStyle(
              fontWeight: FontWeight.w800,
              fontSize: 11,
              color: _text,
            ),
          ),
          const SizedBox(height: 2),
          Text(
            label,
            style: const TextStyle(
              color: _mutedText,
              fontSize: 10,
              fontWeight: FontWeight.w500,
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildNavigationNotice() {
    return Container(
      width: double.infinity,
      padding: const EdgeInsets.symmetric(horizontal: 13, vertical: 11),
      decoration: BoxDecoration(
        color: const Color(0xFFEFF6FF),
        borderRadius: BorderRadius.circular(14),
        border: Border.all(color: const Color(0xFFBFDBFE)),
      ),
      child: Row(
        children: [
          const Icon(
            Icons.info_outline_rounded,
            color: _blue,
            size: 19,
          ),
          const SizedBox(width: 9),
          Expanded(
            child: Text(
              'msg_follow_navigation'.tr(),
              style: const TextStyle(
                color: Color(0xFF1E3A8A),
                fontSize: 12,
                height: 1.35,
                fontWeight: FontWeight.w600,
              ),
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildMainActionButton() {
    return SizedBox(
      width: double.infinity,
      height: 54,
      child: ElevatedButton.icon(
        onPressed: isTripActionLoading ? null : _handleTripAction,
        icon: isTripActionLoading
            ? const SizedBox(
                width: 20,
                height: 20,
                child: CircularProgressIndicator(
                  strokeWidth: 2.4,
                  valueColor: AlwaysStoppedAnimation<Color>(Colors.white),
                ),
              )
            : Icon(
                status == TripStatus.onTrip
                    ? Icons.flag_rounded
                    : Icons.arrow_forward_rounded,
                color: Colors.white,
              ),
        label: Text(
          _getActionButtonTitle(status),
          style: const TextStyle(
            fontSize: 15,
            fontWeight: FontWeight.bold,
            color: Colors.white,
          ),
        ),
        style: ElevatedButton.styleFrom(
          backgroundColor: _primary,
          disabledBackgroundColor: _primary.withOpacity(0.50),
          elevation: 0,
          shape: RoundedRectangleBorder(
            borderRadius: BorderRadius.circular(16),
          ),
        ),
      ),
    );
  }

  Widget _buildSecondaryActions({
    required BuildContext context,
    required String passengerName,
    required String passengerPhone,
  }) {
    final canCancel =
        status != TripStatus.onTrip && status != TripStatus.completed;

    return Row(
      children: [
        Expanded(
          child: _buildOutlineActionButton(
            icon: Icons.chat_bubble_outline_rounded,
            label: 'btn_sms_chat'.tr(),
            color: _blue,
            backgroundColor: const Color(0xFFEFF6FF),
            onPressed: isTripActionLoading
                ? null
                : () {
                    Navigator.push(
                      context,
                      MaterialPageRoute(
                        builder: (_) => ChatPage(
                          tripId: tripId,
                          passengerName: passengerName,
                          passengerPhone: passengerPhone,
                        ),
                      ),
                    );
                  },
          ),
        ),
        if (canCancel) ...[
          const SizedBox(width: 10),
          Expanded(
            child: _buildOutlineActionButton(
              icon: Icons.close_rounded,
              label: 'btn_cancel_trip'.tr(),
              color: _danger,
              backgroundColor: const Color(0xFFFEF2F2),
              onPressed: isTripActionLoading
                  ? null
                  : () => onCancelTrip(tripId),
            ),
          ),
        ],
      ],
    );
  }

  Widget _buildOutlineActionButton({
    required IconData icon,
    required String label,
    required Color color,
    required Color backgroundColor,
    required VoidCallback? onPressed,
  }) {
    return SizedBox(
      height: 46,
      child: ElevatedButton.icon(
        onPressed: onPressed,
        icon: Icon(icon, size: 18, color: color),
        label: Text(
          label,
          style: TextStyle(
            color: color,
            fontSize: 13,
            fontWeight: FontWeight.bold,
          ),
        ),
        style: ElevatedButton.styleFrom(
          backgroundColor: backgroundColor,
          disabledBackgroundColor: backgroundColor.withOpacity(0.55),
          elevation: 0,
          shape: RoundedRectangleBorder(
            borderRadius: BorderRadius.circular(14),
          ),
        ),
      ),
    );
  }

  Widget _buildNavigationButton(BuildContext context) {
    final isGoingToPickup =
        status == TripStatus.accepted || status == TripStatus.arrived;

    return SizedBox(
      width: double.infinity,
      height: 52,
      child: ElevatedButton.icon(
        onPressed: isTripActionLoading
            ? null
            : () {
                final LatLng? targetPosition = getNavigationTarget();

                if (targetPosition == null) {
                  ScaffoldMessenger.of(context).showSnackBar(
                    const SnackBar(
                      content: Text('مختصات مبدأ یا مقصد این سفر پیدا نشد.'),
                    ),
                  );
                  return;
                }

                onOpenExternalMap(
                  targetPosition.latitude,
                  targetPosition.longitude,
                );
              },
        icon: const Icon(
          Icons.navigation_rounded,
          color: Colors.white,
          size: 20,
        ),
        label: Text(
          isGoingToPickup
              ? 'btn_external_navigation_origin'.tr()
              : 'btn_external_navigation_destination'.tr(),
          style: const TextStyle(
            fontSize: 14,
            fontWeight: FontWeight.bold,
            color: Colors.white,
          ),
        ),
        style: ElevatedButton.styleFrom(
          backgroundColor: _blue,
          disabledBackgroundColor: _blue.withOpacity(0.50),
          elevation: 0,
          shape: RoundedRectangleBorder(
            borderRadius: BorderRadius.circular(16),
          ),
        ),
      ),
    );
  }

  Widget _cardContainer({required Widget child}) {
    return Container(
      width: double.infinity,
      padding: const EdgeInsets.all(14),
      decoration: BoxDecoration(
        color: _card,
        borderRadius: BorderRadius.circular(18),
        border: Border.all(color: const Color(0xFFE2E8F0)),
        boxShadow: [
          BoxShadow(
            color: const Color(0xFF0F172A).withOpacity(0.035),
            blurRadius: 14,
            offset: const Offset(0, 5),
          ),
        ],
      ),
      child: child,
    );
  }
}
