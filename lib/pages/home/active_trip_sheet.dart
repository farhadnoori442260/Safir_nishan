import 'dart:async';
import 'dart:ui' as ui;

import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:easy_localization/easy_localization.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:maplibre_gl/maplibre_gl.dart';

import 'package:safir_drivers/constants/trip_status.dart';
import 'package:safir_drivers/pages/chat_page.dart';
import 'package:safir_drivers/utils/trip_extras.dart';

String _t(String key, String fallback) {
  final String value = key.tr();
  return value.trim().isEmpty || value == key ? fallback : value;
}

Future<bool> _confirmPaymentReceived(String tripId) async {
  try {
    await FirebaseFirestore.instance
        .collection('rides')
        .doc(tripId)
        .update(<String, dynamic>{
      'payment_status': 'paid',
      'payment_confirmed_at': FieldValue.serverTimestamp(),
      'payment_confirmed_by':
          FirebaseAuth.instance.currentUser?.uid ?? '',
      'updated_at': FieldValue.serverTimestamp(),
    });
    return true;
  } catch (error) {
    debugPrint('Confirm payment error: $error');
    return false;
  }
}

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
  static const Color _endTrip = Color(0xFFEA580C);

  String _firstText(List<String> keys, String fallback) {
    for (final String key in keys) {
      final String value = tripData[key]?.toString().trim() ?? '';
      if (value.isNotEmpty && value != 'null') return value;
    }
    return fallback;
  }

  String _formatNumber(dynamic value, {required int decimals}) {
    if (value == null) return '---';
    if (value is num) return value.toDouble().toStringAsFixed(decimals);

    final String raw = value.toString().trim();
    if (raw.isEmpty) return '---';

    final double? number = double.tryParse(raw.replaceAll(',', ''));
    return number == null ? raw : number.toStringAsFixed(decimals);
  }

  String _getActionButtonTitle() {
    if (status == TripStatus.arrived) return 'btn_start_trip'.tr();
    if (status == TripStatus.onTrip) return 'btn_end_trip'.tr();
    return 'btn_arrived_pickup'.tr();
  }

  String _getStatusText() {
    if (status == TripStatus.accepted) {
      return 'active_trip_status_accepted'.tr();
    }
    if (status == TripStatus.arrived) {
      return 'active_trip_status_arrived'.tr();
    }
    if (status == TripStatus.onTrip) {
      return 'active_trip_status_on_trip'.tr();
    }
    return 'active_trip_status_active'.tr();
  }

  IconData _getStatusIcon() {
    if (status == TripStatus.arrived) return Icons.location_on_rounded;
    if (status == TripStatus.onTrip) return Icons.route_rounded;
    if (status == TripStatus.accepted) {
      return Icons.directions_car_filled_rounded;
    }
    return Icons.local_taxi_rounded;
  }

  Future<void> _handleTripAction(BuildContext context) async {
    HapticFeedback.mediumImpact();

    if (status == TripStatus.accepted) {
      onUpdateTripStatus(tripId, TripStatus.arrived);
    } else if (status == TripStatus.arrived) {
      onUpdateTripStatus(tripId, TripStatus.onTrip);
    } else if (status == TripStatus.onTrip) {
      if (await _confirmEndTrip(context)) {
        onUpdateTripStatus(tripId, TripStatus.completed);
      }
    }
  }

  Future<bool> _confirmEndTrip(BuildContext context) async {
    String? paymentStatus;
    dynamic amount;

    try {
      final snapshot = await FirebaseFirestore.instance
          .collection('rides')
          .doc(tripId)
          .get();

      paymentStatus = snapshot.data()?['payment_status']?.toString();
      amount = snapshot.data()?['payment_requested_amount'];
    } catch (error) {
      debugPrint('Read payment before ending trip: $error');
    }

    if (!context.mounted) return false;

    final bool awaiting =
        paymentStatus == 'awaiting_driver_confirmation';

    final String? choice = await showDialog<String>(
      context: context,
      builder: (BuildContext ctx) => AlertDialog(
        shape: RoundedRectangleBorder(
          borderRadius: BorderRadius.circular(20),
        ),
        title: Text(
          _t('end_trip_confirm_title', 'پایان سفر'),
          style: const TextStyle(
            fontWeight: FontWeight.w800,
            color: _text,
          ),
        ),
        content: Text(
          awaiting
              ? '${_t('end_trip_payment_pending', 'مسافر اعلام کرده کرایه را پرداخت کرده است')}'
                  '${amount != null ? ' ($amount)' : ''}. '
                  '${_t('end_trip_payment_question', 'دریافت پول را تایید می‌کنید؟')}'
              : _t(
                  'end_trip_confirm_msg',
                  'آیا سفر به مقصد رسیده و می‌خواهید آن را تمام کنید؟',
                ),
          style: const TextStyle(color: _mutedText, height: 1.5),
        ),
        actionsOverflowDirection: VerticalDirection.down,
        actions: <Widget>[
          TextButton(
            onPressed: () => Navigator.pop(ctx, 'cancel'),
            child: Text(_t('cancel', 'انصراف')),
          ),
          if (awaiting)
            TextButton(
              onPressed: () => Navigator.pop(ctx, 'end'),
              child: Text(
                _t('end_trip_without_confirm', 'پایان بدون تایید پول'),
                style: const TextStyle(color: _danger),
              ),
            ),
          ElevatedButton(
            onPressed: () =>
                Navigator.pop(ctx, awaiting ? 'pay_and_end' : 'end'),
            style: ElevatedButton.styleFrom(
              backgroundColor: awaiting ? _primary : _endTrip,
              foregroundColor: Colors.white,
            ),
            child: Text(
              awaiting
                  ? _t('end_trip_confirm_and_end', 'تایید پول و پایان سفر')
                  : _t('btn_end_trip', 'پایان سفر'),
            ),
          ),
        ],
      ),
    );

    if (choice == 'pay_and_end') {
      final bool ok = await _confirmPaymentReceived(tripId);

      if (!ok) {
        if (context.mounted) {
          ScaffoldMessenger.of(context).showSnackBar(
            SnackBar(
              backgroundColor: _danger,
              content: Text(
                _t(
                  'payment_confirm_failed',
                  'تایید پرداخت ثبت نشد. دوباره تلاش کنید.',
                ),
              ),
            ),
          );
        }
        return false;
      }
      return true;
    }

    return choice == 'end';
  }

  @override
  Widget build(BuildContext context) {
    final String passengerName = _firstText(
      <String>['passenger_name', 'userName', 'full_name'],
      _t('passenger', 'مسافر'),
    );

    final String passengerPhone = _firstText(
      <String>['passenger_phone', 'userPhone', 'phone'],
      '',
    );

    return _ActiveTripChatHost(
      tripId: tripId,
      status: status,
      passengerName: passengerName,
      passengerPhone: passengerPhone,
      builder: (BuildContext context, VoidCallback openChat) {
        return _buildTripContent(
          context,
          passengerName,
          passengerPhone,
          openChat,
        );
      },
    );
  }

  Widget _buildTripContent(
    BuildContext context,
    String passengerName,
    String passengerPhone,
    VoidCallback openChat,
  ) {
    final String passengerRating =
        '${tripData['userRating'] ?? tripData['rating'] ?? '4.8'}';

    final String originAddress = _firstText(
      <String>['origin_address', 'originAddress', 'pickup_address'],
      '-',
    );

    final String destinationAddress = _firstText(
      <String>[
        'destination_address',
        'destinationAddress',
        'dropoff_address',
      ],
      '-',
    );

    final String duration = _formatNumber(
      tripData['trip_duration'] ??
          tripData['duration'] ??
          tripData['estimatedDuration'] ??
          tripData['durationMinutes'],
      decimals: 0,
    );

    final String distance = _formatNumber(
      tripData['distance'] ??
          tripData['estimatedDistance'] ??
          tripData['distanceKm'],
      decimals: 1,
    );

    final String price = _formatNumber(
      tripData['total_fare'] ??
          tripData['fare_amount'] ??
          tripData['fareAmount'] ??
          tripData['fare'] ??
          tripData['price'],
      decimals: 0,
    );

    final TripExtras extras = TripExtras.fromRide(tripData);

    return DraggableScrollableSheet(
      initialChildSize: 0.64,
      minChildSize: 0.25,
      maxChildSize: 0.92,
      snap: true,
      snapSizes: const <double>[0.25, 0.64, 0.92],
      builder: (
        BuildContext context,
        ScrollController scrollController,
      ) {
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
                children: <Widget>[
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
                    passengerName,
                    passengerPhone,
                    passengerRating,
                  ),
                  const SizedBox(height: 12),
                  _buildAddressCard(originAddress, destinationAddress),
                  const SizedBox(height: 12),
                  if (extras.hasContent) ...<Widget>[
                    _buildExtrasCard(extras),
                    const SizedBox(height: 12),
                  ],
                  _buildTripInformation(duration, distance, price),
                  const SizedBox(height: 12),
                  _PaymentConfirmCard(
                    tripId: tripId,
                    fallbackPrice: price,
                  ),
                  const SizedBox(height: 12),
                  _buildNavigationNotice(),
                  const SizedBox(height: 16),
                  _buildMainActionButton(context),
                  const SizedBox(height: 10),
                  _buildSecondaryActions(openChat),
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
          colors: <Color>[_primary, _primaryDark],
          begin: Alignment.centerLeft,
          end: Alignment.centerRight,
        ),
        borderRadius: BorderRadius.circular(16),
        boxShadow: <BoxShadow>[
          BoxShadow(
            color: _primary.withOpacity(0.22),
            blurRadius: 16,
            offset: const Offset(0, 7),
          ),
        ],
      ),
      child: Row(
        children: <Widget>[
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
              children: <Widget>[
                Text(
                  _getStatusText(),
                  style: const TextStyle(
                    color: Colors.white,
                    fontSize: 15,
                    fontWeight: FontWeight.bold,
                  ),
                ),
                const SizedBox(height: 2),
                Text(
                  'active_trip_header_subtitle'.tr(),
                  style: const TextStyle(
                    color: Color(0xFFD1FAE5),
                    fontSize: 11,
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

  Widget _buildPassengerCard(
    String name,
    String phone,
    String rating,
  ) {
    return _cardContainer(
      child: Row(
        children: <Widget>[
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
              children: <Widget>[
                Text(
                  name,
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
                  children: <Widget>[
                    const Icon(
                      Icons.star_rounded,
                      color: Color(0xFFF59E0B),
                      size: 17,
                    ),
                    const SizedBox(width: 3),
                    Text(
                      rating,
                      style: const TextStyle(
                        color: _text,
                        fontSize: 12,
                        fontWeight: FontWeight.w700,
                      ),
                    ),
                    const SizedBox(width: 10),
                    Expanded(
                      child: Text(
                        phone.isEmpty
                            ? 'active_trip_phone_unavailable'.tr()
                            : phone,
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
          _buildCallButton(
            phone: phone,
            label: 'active_trip_call_passenger'.tr(),
          ),
        ],
      ),
    );
  }

  Widget _buildCallButton({
    required String phone,
    required String label,
    double size = 46,
  }) {
    final bool hasPhone = phone.trim().isNotEmpty;

    return Semantics(
      label: label,
      button: true,
      child: Material(
        color: hasPhone
            ? const Color(0xFFDCFCE7)
            : const Color(0xFFF1F5F9),
        borderRadius: BorderRadius.circular(14),
        child: InkWell(
          borderRadius: BorderRadius.circular(14),
          onTap: hasPhone ? () => onMakePhoneCall(phone.trim()) : null,
          child: SizedBox(
            width: size,
            height: size,
            child: Icon(
              Icons.phone_in_talk_rounded,
              color: hasPhone
                  ? const Color(0xFF15803D)
                  : const Color(0xFF94A3B8),
              size: 22,
            ),
          ),
        ),
      ),
    );
  }

  Widget _buildAddressCard(String origin, String destination) {
    return _cardContainer(
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: <Widget>[
          Column(
            children: <Widget>[
              const Icon(
                Icons.circle,
                size: 18,
                color: Color(0xFF16A34A),
              ),
              Container(
                width: 2,
                height: 38,
                color: const Color(0xFFCBD5E1),
              ),
              const Icon(
                Icons.location_on_rounded,
                size: 18,
                color: _danger,
              ),
            ],
          ),
          const SizedBox(width: 12),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: <Widget>[
                _buildAddressText(
                  'origin_label'.tr(),
                  origin,
                  const Color(0xFF15803D),
                ),
                const SizedBox(height: 16),
                _buildAddressText(
                  'destination_label'.tr(),
                  destination,
                  _danger,
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildAddressText(
    String label,
    String value,
    Color color,
  ) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: <Widget>[
        Text(
          label,
          style: TextStyle(
            fontSize: 11,
            color: color,
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

  Widget _buildExtrasCard(TripExtras extras) {
    return _cardContainer(
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: <Widget>[
          Row(
            children: <Widget>[
              Container(
                height: 36,
                width: 36,
                decoration: BoxDecoration(
                  color: const Color(0xFFCCFBF1),
                  borderRadius: BorderRadius.circular(11),
                ),
                child: Icon(
                  extras.serviceIcon,
                  color: _primary,
                  size: 20,
                ),
              ),
              const SizedBox(width: 10),
              Expanded(
                child: Text(
                  extras.serviceLabel,
                  style: const TextStyle(
                    fontWeight: FontWeight.w800,
                    fontSize: 14.5,
                    color: _text,
                  ),
                ),
              ),
            ],
          ),
          if (extras.items.isNotEmpty) ...<Widget>[
            const SizedBox(height: 12),
            Wrap(
              spacing: 8,
              runSpacing: 8,
              children: extras.items.map((TripExtraItem item) {
                return Container(
                  padding: const EdgeInsets.symmetric(
                    horizontal: 10,
                    vertical: 6,
                  ),
                  decoration: BoxDecoration(
                    color: const Color(0xFFF1F5F9),
                    borderRadius: BorderRadius.circular(20),
                  ),
                  child: Row(
                    mainAxisSize: MainAxisSize.min,
                    children: <Widget>[
                      Icon(item.icon, size: 15, color: _primary),
                      const SizedBox(width: 6),
                      Flexible(
                        child: Text(
                          item.text,
                          maxLines: 2,
                          overflow: TextOverflow.ellipsis,
                          style: const TextStyle(
                            fontSize: 12,
                            fontWeight: FontWeight.w600,
                            color: _text,
                          ),
                        ),
                      ),
                    ],
                  ),
                );
              }).toList(),
            ),
          ],
          for (final TripParty party in extras.parties) ...<Widget>[
            const SizedBox(height: 12),
            const Divider(height: 1, color: Color(0xFFE2E8F0)),
            const SizedBox(height: 12),
            _buildPartyRow(party),
          ],
        ],
      ),
    );
  }

  Widget _buildPartyRow(TripParty party) {
    return Row(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: <Widget>[
        Expanded(
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: <Widget>[
              Text(
                party.role,
                style: TextStyle(
                  fontSize: 11,
                  fontWeight: FontWeight.w800,
                  color: party.isSender
                      ? const Color(0xFF15803D)
                      : _danger,
                ),
              ),
              const SizedBox(height: 3),
              Text(
                party.name.isEmpty
                    ? 'active_trip_name_not_registered'.tr()
                    : party.name,
                maxLines: 1,
                overflow: TextOverflow.ellipsis,
                style: const TextStyle(
                  fontSize: 14,
                  fontWeight: FontWeight.w800,
                  color: _text,
                ),
              ),
              if (party.phone.isNotEmpty)
                Text(
                  party.phone,
                  textDirection: ui.TextDirection.ltr,
                  style: const TextStyle(
                    fontSize: 12,
                    color: _mutedText,
                  ),
                ),
              if (party.detail.isNotEmpty)
                Text(
                  party.detail,
                  style: const TextStyle(
                    fontSize: 12,
                    color: _mutedText,
                  ),
                ),
              if (party.note.isNotEmpty)
                Text(
                  'active_trip_note_prefix'.tr(
                    namedArgs: <String, String>{'note': party.note},
                  ),
                  maxLines: 3,
                  overflow: TextOverflow.ellipsis,
                  style: const TextStyle(
                    fontSize: 12,
                    height: 1.35,
                    color: _mutedText,
                  ),
                ),
            ],
          ),
        ),
        const SizedBox(width: 8),
        _buildCallButton(
          phone: party.phone,
          label: 'active_trip_call_party'.tr(
            namedArgs: <String, String>{'role': party.role},
          ),
          size: 42,
        ),
      ],
    );
  }

  Widget _buildTripInformation(
    String duration,
    String distance,
    String price,
  ) {
    return Row(
      children: <Widget>[
        Expanded(
          child: _buildInfoCard(
            Icons.schedule_rounded,
            'active_trip_duration_label'.tr(),
            duration == '---'
                ? '---'
                : 'active_trip_minutes'.tr(
                    namedArgs: <String, String>{'value': duration},
                  ),
            const Color(0xFFF97316),
            const Color(0xFFFFEDD5),
          ),
        ),
        const SizedBox(width: 8),
        Expanded(
          child: _buildInfoCard(
            Icons.route_rounded,
            'active_trip_distance_label'.tr(),
            distance == '---'
                ? '---'
                : 'active_trip_kilometers'.tr(
                    namedArgs: <String, String>{'value': distance},
                  ),
            _blue,
            const Color(0xFFDBEAFE),
          ),
        ),
        const SizedBox(width: 8),
        Expanded(
          child: _buildInfoCard(
            Icons.account_balance_wallet_rounded,
            'active_trip_fare_label'.tr(),
            price == '---'
                ? '---'
                : 'active_trip_afghanis'.tr(
                    namedArgs: <String, String>{'value': price},
                  ),
            _primary,
            const Color(0xFFCCFBF1),
          ),
        ),
      ],
    );
  }

  Widget _buildInfoCard(
    IconData icon,
    String label,
    String value,
    Color color,
    Color backgroundColor,
  ) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 11),
      decoration: BoxDecoration(
        color: _card,
        borderRadius: BorderRadius.circular(15),
        border: Border.all(color: const Color(0xFFE2E8F0)),
      ),
      child: Column(
        children: <Widget>[
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
              fontSize: 12.5,
              color: _text,
            ),
          ),
          const SizedBox(height: 2),
          Text(
            label,
            style: const TextStyle(
              color: _mutedText,
              fontSize: 11,
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
        children: <Widget>[
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

  Widget _buildMainActionButton(BuildContext context) {
    final Color color = status == TripStatus.onTrip ? _endTrip : _primary;

    return SizedBox(
      width: double.infinity,
      height: 54,
      child: ElevatedButton.icon(
        onPressed: isTripActionLoading
            ? null
            : () => _handleTripAction(context),
        icon: isTripActionLoading
            ? const SizedBox(
                width: 20,
                height: 20,
                child: CircularProgressIndicator(
                  strokeWidth: 2.4,
                  color: Colors.white,
                ),
              )
            : Icon(
                status == TripStatus.onTrip
                    ? Icons.flag_rounded
                    : Icons.arrow_forward_rounded,
                color: Colors.white,
              ),
        label: Text(
          _getActionButtonTitle(),
          style: const TextStyle(
            fontSize: 15,
            fontWeight: FontWeight.bold,
            color: Colors.white,
          ),
        ),
        style: ElevatedButton.styleFrom(
          backgroundColor: color,
          disabledBackgroundColor: color.withOpacity(0.5),
          elevation: 0,
          shape: RoundedRectangleBorder(
            borderRadius: BorderRadius.circular(16),
          ),
        ),
      ),
    );
  }

  Widget _buildSecondaryActions(VoidCallback openChat) {
    final bool canCancel =
        status != TripStatus.onTrip && status != TripStatus.completed;

    return Row(
      children: <Widget>[
        Expanded(
          child: _buildOutlineActionButton(
            icon: Icons.chat_bubble_outline_rounded,
            label: 'btn_sms_chat'.tr(),
            color: _blue,
            backgroundColor: const Color(0xFFEFF6FF),
            onPressed: isTripActionLoading ? null : openChat,
          ),
        ),
        if (canCancel) ...<Widget>[
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
    final bool pickup =
        status == TripStatus.accepted || status == TripStatus.arrived;

    return SizedBox(
      width: double.infinity,
      height: 52,
      child: ElevatedButton.icon(
        onPressed: isTripActionLoading
            ? null
            : () {
                final LatLng? target = getNavigationTarget();

                if (target == null) {
                  ScaffoldMessenger.of(context).showSnackBar(
                    SnackBar(
                      content: Text(
                        'active_trip_location_not_found'.tr(),
                      ),
                    ),
                  );
                  return;
                }

                onOpenExternalMap(target.latitude, target.longitude);
              },
        icon: const Icon(
          Icons.navigation_rounded,
          color: Colors.white,
          size: 20,
        ),
        label: Text(
          pickup
              ? 'btn_external_navigation_origin'.tr()
              : 'btn_external_navigation_destination'.tr(),
          style: const TextStyle(
            fontSize: 14,
            fontWeight: FontWeight.bold,
          ),
        ),
        style: ElevatedButton.styleFrom(
          backgroundColor: _blue,
          foregroundColor: Colors.white,
          disabledBackgroundColor: _blue.withOpacity(0.5),
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
        boxShadow: <BoxShadow>[
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

// دریافت پیام جدید و بازکردن چت شناور در صفحهٔ سفر.
class _ActiveTripChatHost extends StatefulWidget {
  const _ActiveTripChatHost({
    required this.tripId,
    required this.status,
    required this.passengerName,
    required this.passengerPhone,
    required this.builder,
  });

  final String tripId;
  final String status;
  final String passengerName;
  final String passengerPhone;
  final Widget Function(BuildContext, VoidCallback) builder;

  @override
  State<_ActiveTripChatHost> createState() => _ActiveTripChatHostState();
}

class _ActiveTripChatHostState extends State<_ActiveTripChatHost>
    with WidgetsBindingObserver {
  StreamSubscription<QuerySnapshot<Map<String, dynamic>>>? _subscription;

  final Set<String> _knownIds = <String>{};

  bool _ready = false;
  bool _scheduled = false;
  int _generation = 0;

  DialogRoute<void>? _chatRoute;

  bool get _isActive {
    return widget.status == TripStatus.accepted ||
        widget.status == TripStatus.arrived ||
        widget.status == TripStatus.onTrip;
  }

  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addObserver(this);
    _listen();
  }

  @override
  void didUpdateWidget(covariant _ActiveTripChatHost oldWidget) {
    super.didUpdateWidget(oldWidget);

    if (oldWidget.tripId != widget.tripId ||
        oldWidget.status != widget.status) {
      if (oldWidget.tripId != widget.tripId || !_isActive) {
        _closeChatLater();
      }
      _listen();
    }
  }

  void _listen() {
    _subscription?.cancel();
    _subscription = null;

    final int generation = ++_generation;
    _knownIds.clear();
    _ready = false;
    _scheduled = false;

    if (!_isActive || widget.tripId.trim().isEmpty) return;

    _subscription = FirebaseFirestore.instance
        .collection('rides')
        .doc(widget.tripId)
        .collection('chats')
        .snapshots(includeMetadataChanges: true)
        .listen(
      (QuerySnapshot<Map<String, dynamic>> snapshot) {
        if (!mounted || generation != _generation) return;

        // پاسخ اولیه شامل پیام‌های قبلی است.
        if (!_ready) {
          for (final document in snapshot.docs) {
            _knownIds.add(document.id);
          }
          if (!snapshot.metadata.isFromCache) {
            _ready = true;
          }
          return;
        }

        final String uid = FirebaseAuth.instance.currentUser?.uid ?? '';
        if (uid.isEmpty) return;

        bool incoming = false;

        for (final document in snapshot.docs) {
          if (!_knownIds.add(document.id)) continue;

          final Map<String, dynamic> data = document.data();

          final String sender =
              data['senderId']?.toString().trim() ?? '';
          final String type =
              data['senderType']?.toString().trim().toLowerCase() ?? '';
          final String text =
              data['message']?.toString().trim() ?? '';

          if (text.isEmpty ||
              sender.isEmpty ||
              sender == uid ||
              type == 'driver' ||
              document.metadata.hasPendingWrites) {
            continue;
          }

          incoming = true;
        }

        if (incoming) _scheduleOpen(generation);
      },
      onError: (Object error) {
        debugPrint('Active trip chat listener error: $error');
      },
    );
  }

  void _scheduleOpen(int generation) {
    if (_scheduled ||
        _chatRoute != null ||
        WidgetsBinding.instance.lifecycleState !=
            AppLifecycleState.resumed) {
      return;
    }

    _scheduled = true;

    WidgetsBinding.instance.addPostFrameCallback((_) {
      if (!mounted || generation != _generation) return;

      _scheduled = false;

      if (WidgetsBinding.instance.lifecycleState ==
          AppLifecycleState.resumed) {
        unawaited(_openChat());
      }
    });

    WidgetsBinding.instance.ensureVisualUpdate();
  }

  Future<void> _openChat() async {
    if (!mounted ||
        !_isActive ||
        _chatRoute != null ||
        widget.tripId.trim().isEmpty) {
      return;
    }

    final String tripId = widget.tripId;
    final String name = widget.passengerName;
    final String phone = widget.passengerPhone;

    final NavigatorState navigator =
        Navigator.of(context, rootNavigator: true);

    final DialogRoute<void> route = DialogRoute<void>(
      context: context,
      barrierDismissible: false,
      builder: (BuildContext dialogContext) {
        return Dialog(
          insetPadding: const EdgeInsets.symmetric(
            horizontal: 12,
            vertical: 20,
          ),
          clipBehavior: Clip.antiAlias,
          shape: RoundedRectangleBorder(
            borderRadius: BorderRadius.circular(20),
          ),
          child: LayoutBuilder(
            builder: (BuildContext context, BoxConstraints constraints) {
              final double preferredHeight =
                  MediaQuery.sizeOf(context).height * 0.78;

              final double height =
                  constraints.maxHeight < preferredHeight
                      ? constraints.maxHeight
                      : preferredHeight;

              // خود Dialog فضای کیبورد را حساب می‌کند؛
              // ChatPage نباید دوباره همان فاصله را اضافه کند.
              return SizedBox(
                width: 520,
                height: height,
                child: Column(
                  children: <Widget>[
                    Container(
                      height: 48,
                      color: const Color(0xFF12304F),
                      padding: const EdgeInsetsDirectional.only(
                        start: 14,
                        end: 4,
                      ),
                      child: Row(
                        children: <Widget>[
                          Expanded(
                            child: Text(
                              _t('chat', 'گفتگو'),
                              style: const TextStyle(
                                color: Colors.white,
                                fontSize: 15,
                                fontWeight: FontWeight.bold,
                              ),
                            ),
                          ),
                          IconButton(
                            tooltip: _t('close', 'بستن'),
                            onPressed: () {
                              Navigator.of(dialogContext).pop();
                            },
                            icon: const Icon(
                              Icons.close_rounded,
                              color: Colors.white,
                            ),
                          ),
                        ],
                      ),
                    ),
                    Expanded(
                      child: MediaQuery(
                        data: MediaQuery.of(context).copyWith(
                          viewInsets: EdgeInsets.zero,
                          padding: EdgeInsets.zero,
                        ),
                        child: ChatPage(
                          tripId: tripId,
                          passengerName: name,
                          passengerPhone: phone,
                        ),
                      ),
                    ),
                  ],
                ),
              );
            },
          ),
        );
      },
    );

    _chatRoute = route;

    try {
      await navigator.push<void>(route);
    } catch (error) {
      debugPrint('Open trip chat error: $error');
    } finally {
      if (identical(_chatRoute, route)) {
        _chatRoute = null;
      }
    }
  }

  void _closeChatLater() {
    final DialogRoute<void>? route = _chatRoute;
    _chatRoute = null;

    if (route == null) return;

    WidgetsBinding.instance.addPostFrameCallback((_) {
      final NavigatorState? navigator = route.navigator;
      if (navigator != null && navigator.mounted && route.isActive) {
        navigator.removeRoute(route);
      }
    });

    WidgetsBinding.instance.ensureVisualUpdate();
  }

  @override
  void dispose() {
    ++_generation;
    _subscription?.cancel();
    WidgetsBinding.instance.removeObserver(this);
    _closeChatLater();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return widget.builder(
      context,
      () => unawaited(_openChat()),
    );
  }
}

// کارت تایید پرداخت نقدی.
class _PaymentConfirmCard extends StatefulWidget {
  const _PaymentConfirmCard({
    required this.tripId,
    required this.fallbackPrice,
  });

  final String tripId;
  final String fallbackPrice;

  @override
  State<_PaymentConfirmCard> createState() => _PaymentConfirmCardState();
}

class _PaymentConfirmCardState extends State<_PaymentConfirmCard> {
  bool _busy = false;

  Future<void> _onConfirm(String amountText) async {
    if (_busy) return;

    final bool? yes = await showDialog<bool>(
      context: context,
      builder: (BuildContext ctx) {
        return AlertDialog(
          shape: RoundedRectangleBorder(
            borderRadius: BorderRadius.circular(20),
          ),
          title: Text(
            _t('payment_confirm_title', 'تایید دریافت پول'),
            style: const TextStyle(
              fontWeight: FontWeight.w800,
              color: ActiveTripSheet._text,
            ),
          ),
          content: Text(
            '${_t('payment_confirm_msg', 'آیا مبلغ')} $amountText '
            '${_t('payment_confirm_msg_tail', 'را نقداً از مسافر دریافت کرده‌اید؟')}',
            style: const TextStyle(
              color: ActiveTripSheet._mutedText,
              height: 1.5,
            ),
          ),
          actions: <Widget>[
            TextButton(
              onPressed: () => Navigator.pop(ctx, false),
              child: Text(_t('cancel', 'انصراف')),
            ),
            ElevatedButton(
              onPressed: () => Navigator.pop(ctx, true),
              style: ElevatedButton.styleFrom(
                backgroundColor: ActiveTripSheet._primary,
                foregroundColor: Colors.white,
              ),
              child: Text(
                _t('payment_confirm_yes', 'بله، دریافت کردم'),
              ),
            ),
          ],
        );
      },
    );

    if (yes != true || !mounted) return;

    HapticFeedback.mediumImpact();
    setState(() => _busy = true);

    final bool ok = await _confirmPaymentReceived(widget.tripId);

    if (!mounted) return;
    setState(() => _busy = false);

    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(
        backgroundColor:
            ok ? const Color(0xFF16A34A) : ActiveTripSheet._danger,
        content: Text(
          ok
              ? _t('payment_confirmed_ok', 'دریافت پول تایید شد.')
              : _t(
                  'payment_confirm_failed',
                  'تایید پرداخت ثبت نشد. دوباره تلاش کنید.',
                ),
        ),
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    if (widget.tripId.isEmpty) return const SizedBox.shrink();

    return StreamBuilder<DocumentSnapshot<Map<String, dynamic>>>(
      stream: FirebaseFirestore.instance
          .collection('rides')
          .doc(widget.tripId)
          .snapshots(),
      builder: (
        BuildContext context,
        AsyncSnapshot<DocumentSnapshot<Map<String, dynamic>>> snapshot,
      ) {
        final Map<String, dynamic> data =
            snapshot.data?.data() ?? <String, dynamic>{};

        final String status =
            data['payment_status']?.toString() ?? 'unpaid';

        final dynamic requested = data['payment_requested_amount'];

        final String amountText =
            '${requested ?? widget.fallbackPrice} '
            '${_t('currency_afg', 'افغانی')}';

        final bool awaiting =
            status == 'awaiting_driver_confirmation';
        final bool paid = status == 'paid';
        final bool settled = status == 'settled';

        final Color color = paid || settled
            ? const Color(0xFF16A34A)
            : awaiting
                ? const Color(0xFFD97706)
                : ActiveTripSheet._mutedText;

        final IconData icon = paid || settled
            ? Icons.check_circle_rounded
            : awaiting
                ? Icons.payments_rounded
                : Icons.hourglass_empty_rounded;

        final String title = settled
            ? _t('payment_status_settled', 'پرداخت تسویه شد')
            : paid
                ? _t('payment_status_paid', 'دریافت پول تایید شد')
                : awaiting
                    ? _t(
                        'payment_status_awaiting',
                        'مسافر پرداخت را اعلام کرد',
                      )
                    : _t(
                        'payment_status_unpaid',
                        'منتظر پرداخت نقدی مسافر',
                      );

        return AnimatedContainer(
          duration: const Duration(milliseconds: 200),
          width: double.infinity,
          padding: const EdgeInsets.all(14),
          decoration: BoxDecoration(
            color: color.withOpacity(awaiting ? 0.10 : 0.07),
            borderRadius: BorderRadius.circular(16),
            border: Border.all(
              color: color.withOpacity(awaiting ? 0.55 : 0.28),
            ),
          ),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: <Widget>[
              Row(
                children: <Widget>[
                  Icon(icon, color: color, size: 22),
                  const SizedBox(width: 10),
                  Expanded(
                    child: Text(
                      title,
                      style: TextStyle(
                        color: color,
                        fontSize: 14,
                        fontWeight: FontWeight.w800,
                      ),
                    ),
                  ),
                  Flexible(
                    child: Text(
                      amountText,
                      textAlign: TextAlign.end,
                      style: const TextStyle(
                        color: ActiveTripSheet._text,
                        fontSize: 13,
                        fontWeight: FontWeight.w800,
                      ),
                    ),
                  ),
                ],
              ),
              if (awaiting) ...<Widget>[
                const SizedBox(height: 6),
                Text(
                  _t(
                    'payment_awaiting_hint',
                    'بعد از دریافت پول نقد، تایید کنید تا پرداخت ثبت و برای تسویه ارسال شود.',
                  ),
                  style: const TextStyle(
                    color: ActiveTripSheet._mutedText,
                    fontSize: 12,
                    height: 1.45,
                  ),
                ),
                const SizedBox(height: 10),
                SizedBox(
                  width: double.infinity,
                  height: 46,
                  child: ElevatedButton.icon(
                    onPressed: _busy
                        ? null
                        : () => _onConfirm(amountText),
                    icon: _busy
                        ? const SizedBox(
                            width: 18,
                            height: 18,
                            child: CircularProgressIndicator(
                              strokeWidth: 2.2,
                              color: Colors.white,
                            ),
                          )
                        : const Icon(Icons.check_rounded, size: 20),
                    label: Text(
                      _t('btn_confirm_payment', 'تایید دریافت پول'),
                      style: const TextStyle(
                        fontSize: 14,
                        fontWeight: FontWeight.w700,
                      ),
                    ),
                    style: ElevatedButton.styleFrom(
                      backgroundColor: ActiveTripSheet._primary,
                      foregroundColor: Colors.white,
                      disabledBackgroundColor:
                          ActiveTripSheet._primary.withOpacity(0.5),
                      disabledForegroundColor: Colors.white,
                      elevation: 0,
                      shape: RoundedRectangleBorder(
                        borderRadius: BorderRadius.circular(14),
                      ),
                    ),
                  ),
                ),
              ],
            ],
          ),
        );
      },
    );
  }
}
