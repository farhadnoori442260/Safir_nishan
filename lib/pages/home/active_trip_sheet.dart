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
import 'package:safir_drivers/utils/app_colors.dart';
import 'package:safir_drivers/utils/trip_extras.dart';
import 'package:safir_drivers/widgets/slide_to_confirm.dart';

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
          style: TextStyle(
            fontWeight: FontWeight.w800,
            color: AppColors.textPrimary,
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
          style: TextStyle(color: AppColors.textSecondary, height: 1.5),
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
                style: TextStyle(color: AppColors.danger),
              ),
            ),
          ElevatedButton(
            onPressed: () =>
                Navigator.pop(ctx, awaiting ? 'pay_and_end' : 'end'),
            style: ElevatedButton.styleFrom(
              backgroundColor: awaiting ? AppColors.primaryButton : AppColors.endTrip,
              foregroundColor: AppColors.buttonText,
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
              backgroundColor: AppColors.danger,
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
    // قبلاً اگر امتیازی نبود، عدد ساختگی «4.8» نشان داده می‌شد؛ حالا خالی می‌ماند
    final String passengerRating =
        (tripData['userRating'] ?? tripData['rating'] ?? '').toString().trim();

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
      initialChildSize: 0.5,
      minChildSize: 0.2,
      maxChildSize: 0.9,
      snap: true,
      snapSizes: const <double>[0.2, 0.5, 0.9],
      builder: (
        BuildContext context,
        ScrollController scrollController,
      ) {
        return Container(
          decoration: BoxDecoration(
            color: AppColors.background,
            borderRadius: const BorderRadius.vertical(
              top: Radius.circular(28),
            ),
            border: Border(top: BorderSide(color: AppColors.borderLight)),
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
                      color: AppColors.handle,
                      borderRadius: BorderRadius.circular(99),
                    ),
                  ),
                  _buildStatusHeader(),
                  const SizedBox(height: 10),
                  _buildPassengerCard(
                    passengerName,
                    passengerPhone,
                    passengerRating,
                    openChat,
                  ),
                  const SizedBox(height: 10),
                  _buildAddressCard(originAddress, destinationAddress),
                  const SizedBox(height: 12),
                  _buildMainActionButton(context),
                  const SizedBox(height: 12),
                  _buildTripInformation(duration, distance, price),
                  const SizedBox(height: 10),
                  if (extras.hasContent) ...<Widget>[
                    _buildExtrasCard(extras),
                    const SizedBox(height: 10),
                  ],
                  _PaymentConfirmCard(
                    tripId: tripId,
                    fallbackPrice: price,
                  ),
                  const SizedBox(height: 10),
                  _buildSecondaryActions(),
                ],
              ),
            ),
          ),
        );
      },
    );
  }

  Color _statusColor() {
    if (status == TripStatus.onTrip) return AppColors.primaryBrand;
    if (status == TripStatus.arrived) return AppColors.warningIcon;
    return AppColors.originBlue;
  }

  // هدر وضعیت: سه مرحلهٔ سفر (به مبدأ ← سوار شد ← پایان) + زمان انتظار.
  Widget _buildStatusHeader() {
    final Color accent = _statusColor();
    final int step = status == TripStatus.onTrip
        ? 2
        : status == TripStatus.arrived
            ? 1
            : 0;

    final List<String> labels = <String>[
      _t('trip_step_pickup', 'رفتن به مبدأ'),
      _t('trip_step_boarded', 'سوار شد'),
      _t('trip_step_finish', 'پایان سفر'),
    ];

    return _cardContainer(
      child: Column(
        children: <Widget>[
          Row(
            children: <Widget>[
              Icon(_getStatusIcon(), color: accent, size: 24),
              const SizedBox(width: 10),
              Expanded(
                child: Text(
                  _getStatusText(),
                  style: TextStyle(
                    color: AppColors.textPrimary,
                    fontSize: 15,
                    fontWeight: FontWeight.bold,
                  ),
                ),
              ),
              if (status == TripStatus.arrived)
                _WaitTimer(since: tripData['arrived_at']),
            ],
          ),
          const SizedBox(height: 12),
          Row(
            children: List<Widget>.generate(3, (int i) {
              final bool done = i <= step;
              return Expanded(
                child: Padding(
                  padding: EdgeInsetsDirectional.only(end: i == 2 ? 0 : 6),
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: <Widget>[
                      Container(
                        height: 4,
                        decoration: BoxDecoration(
                          color: done ? accent : AppColors.borderLight,
                          borderRadius: BorderRadius.circular(4),
                        ),
                      ),
                      const SizedBox(height: 5),
                      Text(
                        labels[i],
                        maxLines: 1,
                        overflow: TextOverflow.ellipsis,
                        style: TextStyle(
                          fontSize: 10.5,
                          fontWeight:
                              i == step ? FontWeight.w800 : FontWeight.w500,
                          color: i == step
                              ? AppColors.textPrimary
                              : AppColors.textSecondary,
                        ),
                      ),
                    ],
                  ),
                ),
              );
            }),
          ),
        ],
      ),
    );
  }

  Widget _buildPassengerCard(
    String name,
    String phone,
    String rating,
    VoidCallback openChat,
  ) {
    return _cardContainer(
      child: Row(
        children: <Widget>[
          Container(
            height: 50,
            width: 50,
            decoration: BoxDecoration(
              color: AppColors.neutralSoft,
              shape: BoxShape.circle,
              border: Border.all(color: AppColors.borderLight),
            ),
            child: Icon(
              Icons.person_rounded,
              color: AppColors.textSecondary,
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
                  style: TextStyle(
                    fontWeight: FontWeight.w800,
                    fontSize: 16,
                    color: AppColors.textPrimary,
                  ),
                ),
                const SizedBox(height: 5),
                Row(
                  children: <Widget>[
                    if (rating.isNotEmpty && rating != 'null') ...<Widget>[
                      Icon(
                        Icons.star_rounded,
                        color: AppColors.warning,
                        size: 17,
                      ),
                      const SizedBox(width: 3),
                      Text(
                        rating,
                        style: TextStyle(
                          color: AppColors.textPrimary,
                          fontSize: 12,
                          fontWeight: FontWeight.w700,
                        ),
                      ),
                      const SizedBox(width: 10),
                    ],
                    Expanded(
                      child: Text(
                        phone.isEmpty
                            ? 'active_trip_phone_unavailable'.tr()
                            : phone,
                        textDirection: ui.TextDirection.ltr,
                        maxLines: 1,
                        overflow: TextOverflow.ellipsis,
                        style: TextStyle(
                          color: AppColors.textSecondary,
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
          _buildChatButton(openChat),
          const SizedBox(width: 8),
          _buildCallButton(
            phone: phone,
            label: 'active_trip_call_passenger'.tr(),
          ),
        ],
      ),
    );
  }

  Widget _buildChatButton(VoidCallback openChat) {
    return Semantics(
      label: 'btn_sms_chat'.tr(),
      button: true,
      child: Material(
        color: AppColors.neutralSoft,
        shape: const CircleBorder(),
        child: InkWell(
          customBorder: const CircleBorder(),
          onTap: isTripActionLoading ? null : openChat,
          child: SizedBox(
            width: 46,
            height: 46,
            child: Icon(
              Icons.chat_bubble_outline_rounded,
              color: AppColors.textPrimary,
              size: 21,
            ),
          ),
        ),
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
        color: hasPhone ? AppColors.successSoft : AppColors.neutralSoft,
        shape: const CircleBorder(),
        child: InkWell(
          customBorder: const CircleBorder(),
          onTap: hasPhone ? () => onMakePhoneCall(phone.trim()) : null,
          child: SizedBox(
            width: size,
            height: size,
            child: Icon(
              Icons.phone_in_talk_rounded,
              color: hasPhone
                  ? AppColors.successDark
                  : AppColors.textSecondary,
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
              Icon(
                Icons.circle,
                size: 18,
                color: AppColors.successDark,
              ),
              Container(
                width: 2,
                height: 38,
                color: AppColors.borderLight,
              ),
              Icon(
                Icons.location_on_rounded,
                size: 18,
                color: AppColors.danger,
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
                  AppColors.successDark,
                ),
                const SizedBox(height: 16),
                _buildAddressText(
                  'destination_label'.tr(),
                  destination,
                  AppColors.danger,
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
          style: TextStyle(
            fontSize: 13,
            height: 1.35,
            fontWeight: FontWeight.w600,
            color: AppColors.textPrimary,
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
              Icon(
                extras.serviceIcon,
                color: extras.serviceColor,
                size: 24,
              ),
              const SizedBox(width: 10),
              Expanded(
                child: Text(
                  extras.serviceLabel,
                  style: TextStyle(
                    fontWeight: FontWeight.w800,
                    fontSize: 14.5,
                    color: AppColors.textPrimary,
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
                    color: AppColors.neutralSoft,
                    borderRadius: BorderRadius.circular(20),
                  ),
                  child: Row(
                    mainAxisSize: MainAxisSize.min,
                    children: <Widget>[
                      Icon(item.icon, size: 15, color: AppColors.iconSecondary),
                      const SizedBox(width: 6),
                      Flexible(
                        child: Text(
                          item.text,
                          maxLines: 2,
                          overflow: TextOverflow.ellipsis,
                          style: TextStyle(
                            fontSize: 12,
                            fontWeight: FontWeight.w600,
                            color: AppColors.textPrimary,
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
            Divider(height: 1, color: AppColors.borderLight),
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
                      ? AppColors.successDark
                      : AppColors.danger,
                ),
              ),
              const SizedBox(height: 3),
              Text(
                party.name.isEmpty
                    ? 'active_trip_name_not_registered'.tr()
                    : party.name,
                maxLines: 1,
                overflow: TextOverflow.ellipsis,
                style: TextStyle(
                  fontSize: 14,
                  fontWeight: FontWeight.w800,
                  color: AppColors.textPrimary,
                ),
              ),
              if (party.phone.isNotEmpty)
                Text(
                  party.phone,
                  textDirection: ui.TextDirection.ltr,
                  style: TextStyle(
                    fontSize: 12,
                    color: AppColors.textSecondary,
                  ),
                ),
              if (party.detail.isNotEmpty)
                Text(
                  party.detail,
                  style: TextStyle(
                    fontSize: 12,
                    color: AppColors.textSecondary,
                  ),
                ),
              if (party.note.isNotEmpty)
                Text(
                  'active_trip_note_prefix'.tr(
                    namedArgs: <String, String>{'note': party.note},
                  ),
                  maxLines: 3,
                  overflow: TextOverflow.ellipsis,
                  style: TextStyle(
                    fontSize: 12,
                    height: 1.35,
                    color: AppColors.textSecondary,
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
            AppColors.accentOrange,
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
            AppColors.originBlue,
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
            AppColors.primaryBrand,
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
  ) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 12),
      decoration: BoxDecoration(
        color: AppColors.cardBackground,
        borderRadius: BorderRadius.circular(15),
        border: Border.all(color: AppColors.borderLight),
      ),
      child: Column(
        children: <Widget>[
          Icon(icon, size: 22, color: color),
          const SizedBox(height: 7),
          Text(
            value,
            maxLines: 1,
            overflow: TextOverflow.ellipsis,
            textAlign: TextAlign.center,
            style: TextStyle(
              fontWeight: FontWeight.w800,
              fontSize: 12.5,
              color: AppColors.textPrimary,
            ),
          ),
          const SizedBox(height: 2),
          Text(
            label,
            style: TextStyle(
              color: AppColors.textSecondary,
              fontSize: 11,
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildMainActionButton(BuildContext context) {
    // مراحل برگشت‌ناپذیر (شروع و پایان سفر) با کشیدن تأیید می‌شوند؛
    // «به مبدأ رسیدم» با یک لمس.
    if (status == TripStatus.arrived || status == TripStatus.onTrip) {
      final bool ending = status == TripStatus.onTrip;
      return SlideToConfirm(
        label: ending
            ? _t('slide_end_trip', 'برای پایان سفر بکشید')
            : _t('slide_start_trip', 'مسافر سوار شد؛ برای شروع بکشید'),
        color: ending ? AppColors.endTrip : AppColors.primaryButton,
        loading: isTripActionLoading,
        onConfirmed: () => _handleTripAction(context),
      );
    }

    return SizedBox(
      width: double.infinity,
      height: 58,
      child: ElevatedButton.icon(
        onPressed:
            isTripActionLoading ? null : () => _handleTripAction(context),
        icon: isTripActionLoading
            ? SizedBox(
                width: 20,
                height: 20,
                child: CircularProgressIndicator(
                  strokeWidth: 2.4,
                  color: AppColors.buttonText,
                ),
              )
            : Icon(Icons.location_on_rounded, color: AppColors.buttonText),
        label: Text(
          _getActionButtonTitle(),
          style: TextStyle(
            fontSize: 15.5,
            fontWeight: FontWeight.bold,
            color: AppColors.buttonText,
          ),
        ),
        style: ElevatedButton.styleFrom(
          backgroundColor: AppColors.primaryButton,
          disabledBackgroundColor: AppColors.primaryButton.withOpacity(0.5),
          elevation: 0,
          shape: RoundedRectangleBorder(
            borderRadius: BorderRadius.circular(18),
          ),
        ),
      ),
    );
  }

  // لغو سفر: دکمهٔ کم‌اهمیت پایین برگه (چت و تماس کنار مسافر آمده‌اند).
  Widget _buildSecondaryActions() {
    final bool canCancel =
        status != TripStatus.onTrip && status != TripStatus.completed;

    if (!canCancel) return const SizedBox.shrink();

    return SizedBox(
      width: double.infinity,
      height: 46,
      child: TextButton.icon(
        onPressed: isTripActionLoading ? null : () => onCancelTrip(tripId),
        icon: Icon(Icons.close_rounded, size: 18, color: AppColors.danger),
        label: Text(
          'btn_cancel_trip'.tr(),
          style: TextStyle(
            color: AppColors.danger,
            fontSize: 13.5,
            fontWeight: FontWeight.bold,
          ),
        ),
        style: TextButton.styleFrom(
          backgroundColor: AppColors.dangerSoft,
          shape: RoundedRectangleBorder(
            borderRadius: BorderRadius.circular(14),
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
        color: AppColors.cardBackground,
        borderRadius: BorderRadius.circular(18),
        border: Border.all(color: AppColors.borderLight),
      ),
      child: child,
    );
  }
}

// زمان انتظار مسافر در مبدأ (از لحظهٔ «رسیدم»).
class _WaitTimer extends StatefulWidget {
  const _WaitTimer({required this.since});

  final dynamic since;

  @override
  State<_WaitTimer> createState() => _WaitTimerState();
}

class _WaitTimerState extends State<_WaitTimer> {
  Timer? _timer;
  final DateTime _fallbackStart = DateTime.now();

  @override
  void initState() {
    super.initState();
    _timer = Timer.periodic(const Duration(seconds: 1), (_) {
      if (mounted) setState(() {});
    });
  }

  @override
  void dispose() {
    _timer?.cancel();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final DateTime start = widget.since is Timestamp
        ? (widget.since as Timestamp).toDate()
        : _fallbackStart;

    int sec = DateTime.now().difference(start).inSeconds;
    if (sec < 0) sec = 0;

    final String mm = (sec ~/ 60).toString().padLeft(2, '0');
    final String ss = (sec % 60).toString().padLeft(2, '0');

    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 5),
      decoration: BoxDecoration(
        color: AppColors.neutralSoft,
        borderRadius: BorderRadius.circular(14),
      ),
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: <Widget>[
          Icon(Icons.timer_outlined, size: 15, color: AppColors.warningIcon),
          const SizedBox(width: 5),
          Text(
            '$mm:$ss',
            textDirection: ui.TextDirection.ltr,
            style: TextStyle(
              color: AppColors.textPrimary,
              fontSize: 13,
              fontWeight: FontWeight.w800,
            ),
          ),
        ],
      ),
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
                      color: AppColors.cardBackground,
                      padding: const EdgeInsetsDirectional.only(
                        start: 14,
                        end: 4,
                      ),
                      child: Row(
                        children: <Widget>[
                          Expanded(
                            child: Text(
                              _t('chat', 'گفتگو'),
                              style: TextStyle(
                                color: AppColors.textPrimary,
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
                            icon: Icon(
                              Icons.close_rounded,
                              color: AppColors.textPrimary,
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
            style: TextStyle(
              fontWeight: FontWeight.w800,
              color: AppColors.textPrimary,
            ),
          ),
          content: Text(
            '${_t('payment_confirm_msg', 'آیا مبلغ')} $amountText '
            '${_t('payment_confirm_msg_tail', 'را نقداً از مسافر دریافت کرده‌اید؟')}',
            style: TextStyle(
              color: AppColors.textSecondary,
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
                backgroundColor: AppColors.primaryButton,
                foregroundColor: AppColors.buttonText,
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
        backgroundColor: ok ? AppColors.successDark : AppColors.danger,
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
            ? AppColors.successDark
            : awaiting
                ? AppColors.warningIcon
                : AppColors.textSecondary;

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
                      style: TextStyle(
                        color: AppColors.textPrimary,
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
                  style: TextStyle(
                    color: AppColors.textSecondary,
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
                        ? SizedBox(
                            width: 18,
                            height: 18,
                            child: CircularProgressIndicator(
                              strokeWidth: 2.2,
                              color: AppColors.buttonText,
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
                      backgroundColor: AppColors.primaryButton,
                      foregroundColor: AppColors.buttonText,
                      disabledBackgroundColor:
                          AppColors.primaryButton.withOpacity(0.5),
                      disabledForegroundColor: AppColors.buttonText,
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
