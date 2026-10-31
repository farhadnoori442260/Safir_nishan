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
  final String v = key.tr();
  return (v.trim().isEmpty || v == key) ? fallback : v;
}

/// راننده دریافت پول نقد را تایید می‌کند (payment_status: paid).
/// تسویه‌ی نهایی (settled) با پنل ادمین است.
Future<bool> _confirmPaymentReceived(String tripId) async {
  try {
    await FirebaseFirestore.instance.collection('rides').doc(tripId).update(
      <String, dynamic>{
        'payment_status': 'paid',
        'payment_confirmed_at': FieldValue.serverTimestamp(),
        'payment_confirmed_by': FirebaseAuth.instance.currentUser?.uid ?? '',
        'updated_at': FieldValue.serverTimestamp(),
      },
    );
    return true;
  } on FirebaseException catch (e) {
    debugPrint('Confirm payment error: ${e.code} | ${e.message}');
    return false;
  } catch (e) {
    debugPrint('Confirm payment error: $e');
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

  String _formatNumber(dynamic value, {required int decimals}) {
    if (value == null) return '---';

    if (value is num) {
      return value.toDouble().toStringAsFixed(decimals);
    }

    final String raw = value.toString().trim();

    if (raw.isEmpty) return '---';

    final String cleaned = raw.replaceAll(',', '');
    final double? number = double.tryParse(cleaned);

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

  Future<void> _handleTripAction(BuildContext context) async {
    HapticFeedback.mediumImpact();

    if (status == TripStatus.accepted) {
      onUpdateTripStatus(tripId, TripStatus.arrived);
    } else if (status == TripStatus.arrived) {
      onUpdateTripStatus(tripId, TripStatus.onTrip);
    } else if (status == TripStatus.onTrip) {
      // پایان سفر برگشت‌ناپذیر است؛ قبلاً با یک لمس تمام می‌شد
      final bool shouldEnd = await _confirmEndTrip(context);
      if (shouldEnd) {
        onUpdateTripStatus(tripId, TripStatus.completed);
      }
    }
  }

  /// قبل از پایان سفر تایید می‌گیرد؛ اگر مسافر «پرداخت کردم» زده باشد،
  /// همان‌جا می‌شود دریافت پول را هم تایید کرد (بعد از پایان سفر دیگر ممکن نیست).
  Future<bool> _confirmEndTrip(BuildContext context) async {
    String? paymentStatus;
    dynamic amount;

    try {
      final DocumentSnapshot<Map<String, dynamic>> snap =
          await FirebaseFirestore.instance
              .collection('rides')
              .doc(tripId)
              .get();
      paymentStatus = snap.data()?['payment_status']?.toString();
      amount = snap.data()?['payment_requested_amount'];
    } catch (_) {
      // بدون اطلاعات پرداخت هم می‌شود سفر را تمام کرد
    }

    if (!context.mounted) return false;

    final bool awaiting = paymentStatus == 'awaiting_driver_confirmation';

    final String? choice = await showDialog<String>(
      context: context,
      builder: (BuildContext ctx) {
        return AlertDialog(
          shape: RoundedRectangleBorder(
            borderRadius: BorderRadius.circular(20),
          ),
          title: Text(
            _t('end_trip_confirm_title', 'پایان سفر'),
            style: const TextStyle(fontWeight: FontWeight.w800, color: _text),
          ),
          content: Text(
            awaiting
                ? '${_t('end_trip_payment_pending', 'مسافر اعلام کرده کرایه را پرداخت کرده است')}'
                    '${amount != null ? ' ($amount)' : ''}. '
                    '${_t('end_trip_payment_question', 'دریافت پول را تایید می‌کنید؟')}'
                : _t('end_trip_confirm_msg',
                    'آیا سفر به مقصد رسیده و می‌خواهید آن را تمام کنید؟'),
            style: const TextStyle(color: _mutedText, height: 1.5),
          ),
          actionsOverflowDirection: VerticalDirection.down,
          actions: <Widget>[
            TextButton(
              onPressed: () => Navigator.pop(ctx, 'cancel'),
              child: Text(
                _t('cancel', 'انصراف'),
                style: const TextStyle(color: _mutedText),
              ),
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
                elevation: 0,
                shape: RoundedRectangleBorder(
                  borderRadius: BorderRadius.circular(12),
                ),
              ),
              child: Text(
                awaiting
                    ? _t('end_trip_confirm_and_end', 'تایید پول و پایان سفر')
                    : _t('btn_end_trip', 'پایان سفر'),
              ),
            ),
          ],
        );
      },
    );

    if (choice == 'pay_and_end') {
      final bool ok = await _confirmPaymentReceived(tripId);

      if (!ok && context.mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            backgroundColor: _danger,
            content: Text(
              _t('payment_confirm_failed',
                  'تایید پرداخت ثبت نشد. دوباره تلاش کنید.'),
            ),
          ),
        );
        return false;
      }
      return true;
    }

    return choice == 'end';
  }

  @override
  Widget build(BuildContext context) {
    final String passengerName = tripData['passenger_name']?.toString() ??
        tripData['userName']?.toString() ??
        tripData['full_name']?.toString() ??
        'passenger'.tr();

    final String passengerPhone = tripData['passenger_phone']?.toString() ??
        tripData['userPhone']?.toString() ??
        tripData['phone']?.toString() ??
        '';

    final String passengerRating =
        '${tripData['userRating'] ?? tripData['rating'] ?? '4.8'}';

    final String originAddress = tripData['origin_address']?.toString() ??
        tripData['originAddress']?.toString() ??
        tripData['pickup_address']?.toString() ??
        '-';

    final String destinationAddress =
        tripData['destination_address']?.toString() ??
            tripData['destinationAddress']?.toString() ??
            tripData['dropoff_address']?.toString() ??
            '-';

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
                  if (extras.hasContent) ...<Widget>[
                    _buildExtrasCard(extras),
                    const SizedBox(height: 12),
                  ],
                  _buildTripInformation(
                    duration: duration,
                    distance: distance,
                    price: price,
                  ),
                  const SizedBox(height: 12),
                  _PaymentConfirmCard(tripId: tripId, fallbackPrice: price),
                  const SizedBox(height: 12),
                  _buildNavigationNotice(),
                  const SizedBox(height: 16),
                  _buildMainActionButton(context),
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
                  children: <Widget>[
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
                            ? 'active_trip_phone_unavailable'.tr()
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
          _buildCallButton(
            phone: passengerPhone,
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
        color: hasPhone ? const Color(0xFFDCFCE7) : const Color(0xFFF1F5F9),
        borderRadius: BorderRadius.circular(14),
        child: InkWell(
          borderRadius: BorderRadius.circular(14),
          onTap: hasPhone ? () => onMakePhoneCall(phone.trim()) : null,
          child: Container(
            width: size,
            height: size,
            alignment: Alignment.center,
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

  Widget _buildAddressCard({
    required String originAddress,
    required String destinationAddress,
  }) {
    return _cardContainer(
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: <Widget>[
          Column(
            children: <Widget>[
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
              children: <Widget>[
                _buildAddressText(
                  label: 'origin_label'.tr(),
                  value: originAddress,
                  labelColor: const Color(0xFF15803D),
                ),
                const SizedBox(height: 16),
                _buildAddressText(
                  label: 'destination_label'.tr(),
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
      children: <Widget>[
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
              children: extras.items
                  .map(
                    (TripExtraItem item) => _buildExtraChip(item),
                  )
                  .toList(),
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

  Widget _buildExtraChip(TripExtraItem item) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 6),
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
  }

  Widget _buildPartyRow(TripParty party) {
    final bool isSender = party.isSender;

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
                  color: isSender ? const Color(0xFF15803D) : _danger,
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
              if (party.phone.isNotEmpty) ...<Widget>[
                const SizedBox(height: 2),
                Text(
                  party.phone,
                  textDirection: ui.TextDirection.ltr,
                  style: const TextStyle(
                    fontSize: 12,
                    color: _mutedText,
                  ),
                ),
              ],
              if (party.detail.isNotEmpty) ...<Widget>[
                const SizedBox(height: 3),
                Text(
                  party.detail,
                  style: const TextStyle(
                    fontSize: 12,
                    color: _mutedText,
                  ),
                ),
              ],
              if (party.note.isNotEmpty) ...<Widget>[
                const SizedBox(height: 3),
                Text(
                  'active_trip_note_prefix'.tr(
                    namedArgs: <String, String>{
                      'note': party.note,
                    },
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
            ],
          ),
        ),
        const SizedBox(width: 8),
        _buildCallButton(
          phone: party.phone,
          label: 'active_trip_call_party'.tr(
            namedArgs: <String, String>{
              'role': party.role,
            },
          ),
          size: 42,
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
      children: <Widget>[
        Expanded(
          child: _buildInfoCard(
            icon: Icons.schedule_rounded,
            label: 'active_trip_duration_label'.tr(),
            value: duration == '---'
                ? '---'
                : 'active_trip_minutes'.tr(
                    namedArgs: <String, String>{
                      'value': duration,
                    },
                  ),
            color: const Color(0xFFF97316),
            backgroundColor: const Color(0xFFFFEDD5),
          ),
        ),
        const SizedBox(width: 8),
        Expanded(
          child: _buildInfoCard(
            icon: Icons.route_rounded,
            label: 'active_trip_distance_label'.tr(),
            value: distance == '---'
                ? '---'
                : 'active_trip_kilometers'.tr(
                    namedArgs: <String, String>{
                      'value': distance,
                    },
                  ),
            color: _blue,
            backgroundColor: const Color(0xFFDBEAFE),
          ),
        ),
        const SizedBox(width: 8),
        Expanded(
          child: _buildInfoCard(
            icon: Icons.account_balance_wallet_rounded,
            label: 'active_trip_fare_label'.tr(),
            value: price == '---'
                ? '---'
                : 'active_trip_afghanis'.tr(
                    namedArgs: <String, String>{
                      'value': price,
                    },
                  ),
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
    final Color buttonColor = status == TripStatus.onTrip ? _endTrip : _primary;

    return SizedBox(
      width: double.infinity,
      height: 54,
      child: ElevatedButton.icon(
        onPressed: isTripActionLoading ? null : () => _handleTripAction(context),
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
          backgroundColor: buttonColor,
          disabledBackgroundColor: buttonColor.withOpacity(0.50),
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
    final bool isGoingToPickup =
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
                    SnackBar(
                      content: Text(
                        'active_trip_location_not_found'.tr(),
                      ),
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

/// کارت پرداخت نقدی: وضعیت را زنده از سند سفر می‌خواند و بعد از درخواست مسافر،
/// دکمه‌ی «تایید دریافت پول» را نشان می‌دهد.
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
              child: Text(
                _t('cancel', 'انصراف'),
                style: const TextStyle(color: ActiveTripSheet._mutedText),
              ),
            ),
            ElevatedButton(
              onPressed: () => Navigator.pop(ctx, true),
              style: ElevatedButton.styleFrom(
                backgroundColor: ActiveTripSheet._primary,
                foregroundColor: Colors.white,
                elevation: 0,
                shape: RoundedRectangleBorder(
                  borderRadius: BorderRadius.circular(12),
                ),
              ),
              child: Text(_t('payment_confirm_yes', 'بله، دریافت کردم')),
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
        backgroundColor: ok ? const Color(0xFF16A34A) : ActiveTripSheet._danger,
        content: Text(
          ok
              ? _t('payment_confirmed_ok', 'دریافت پول تایید شد.')
              : _t('payment_confirm_failed',
                  'تایید پرداخت ثبت نشد. دوباره تلاش کنید.'),
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
      builder: (BuildContext context,
          AsyncSnapshot<DocumentSnapshot<Map<String, dynamic>>> snapshot) {
        final Map<String, dynamic> data =
            snapshot.data?.data() ?? <String, dynamic>{};

        final String status = data['payment_status']?.toString() ?? 'unpaid';
        final dynamic requested = data['payment_requested_amount'];
        final String amountText =
            '${requested ?? widget.fallbackPrice} ${_t('currency_afg', 'افغانی')}';

        final bool awaiting = status == 'awaiting_driver_confirmation';
        final bool paid = status == 'paid';
        final bool settled = status == 'settled';

        final Color color = (paid || settled)
            ? const Color(0xFF16A34A)
            : awaiting
                ? const Color(0xFFD97706)
                : ActiveTripSheet._mutedText;

        final IconData icon = (paid || settled)
            ? Icons.check_circle_rounded
            : awaiting
                ? Icons.payments_rounded
                : Icons.hourglass_empty_rounded;

        final String title = settled
            ? _t('payment_status_settled', 'پرداخت تسویه شد')
            : paid
                ? _t('payment_status_paid', 'دریافت پول تایید شد')
                : awaiting
                    ? _t('payment_status_awaiting',
                        'مسافر پرداخت را اعلام کرد')
                    : _t('payment_status_unpaid',
                        'منتظر پرداخت نقدی مسافر');

        return AnimatedContainer(
          duration: const Duration(milliseconds: 200),
          width: double.infinity,
          padding: const EdgeInsets.all(14),
          decoration: BoxDecoration(
            color: color.withOpacity(awaiting ? 0.10 : 0.07),
            borderRadius: BorderRadius.circular(16),
            border: Border.all(color: color.withOpacity(awaiting ? 0.55 : 0.28)),
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
                  Text(
                    amountText,
                    style: const TextStyle(
                      color: ActiveTripSheet._text,
                      fontSize: 13,
                      fontWeight: FontWeight.w800,
                    ),
                  ),
                ],
              ),
              if (awaiting) ...<Widget>[
                const SizedBox(height: 6),
                Text(
                  _t('payment_awaiting_hint',
                      'بعد از دریافت پول نقد، تایید کنید تا پرداخت ثبت و برای تسویه ارسال شود.'),
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
                    onPressed: _busy ? null : () => _onConfirm(amountText),
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
