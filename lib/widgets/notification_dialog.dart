import 'dart:async';

import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:easy_localization/easy_localization.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:flutter/material.dart';
import 'package:geolocator/geolocator.dart';

import 'package:safir_drivers/constants/trip_status.dart';
import 'package:safir_drivers/utils/app_colors.dart';
import 'package:safir_drivers/utils/driver_prefs.dart';
import 'package:safir_drivers/utils/trip_extras.dart';
import '../global/global.dart';
import '../methods/common_method.dart';
import '../models/trip_details.dart';
import 'loading_dialog.dart';

class NotificationDialog extends StatefulWidget {
  final TripDetails? tripDetailsInfo;
  final String? fareAmount;
  final String? bidAmount;

  final Map<String, dynamic>? rideData;

  const NotificationDialog({
    super.key,
    this.tripDetailsInfo,
    this.fareAmount,
    this.bidAmount,
    this.rideData,
  });

  @override
  State<NotificationDialog> createState() => _NotificationDialogState();
}

String _t(String key, String fallback) {
  final String value = key.tr();
  return value.trim().isEmpty || value == key ? fallback : value;
}

class _NotificationDialogState extends State<NotificationDialog>
    with SingleTickerProviderStateMixin {
  String tripRequestStatus = '';
  final CommonMethods cMethods = CommonMethods();

  bool _isAcceptingTrip = false;

  BuildContext? _loadingDialogContext;

  static const Duration _acceptTimeout = Duration(seconds: 15);

  /// مهلت قبول درخواست (ثانیه). با تمام‌شدن، پنجره بسته می‌شود و
  /// درخواست بعدیِ صف نشان داده می‌شود.
  static const int _requestSeconds = 15;

  late final AnimationController _countdown;
  double? _pickupKm;

  @override
  void initState() {
    super.initState();
    driverTripRequestTimeout = 40;
    DriverPrefs.instance.buzz();

    _countdown = AnimationController(
      vsync: this,
      duration: const Duration(seconds: _requestSeconds),
    )..addStatusListener((AnimationStatus status) {
        if (status != AnimationStatus.completed) return;
        if (_isAcceptingTrip || tripRequestStatus == TripStatus.accepted) {
          return;
        }
        _stopAudio();
        if (mounted) Navigator.of(context).pop();
      });
    _countdown.forward();

    _loadPickupDistance();
  }

  @override
  void dispose() {
    _countdown.dispose();
    _stopAudio();
    super.dispose();
  }

  // فاصلهٔ راننده تا مبدأ (از آخرین موقعیت شناخته‌شده؛ اگر نبود نشان داده نمی‌شود)
  Future<void> _loadPickupDistance() async {
    try {
      final dynamic p = widget.tripDetailsInfo?.pickUpLatLng;
      final Position? me = await Geolocator.getLastKnownPosition();
      if (p == null || me == null) return;

      final double km = Geolocator.distanceBetween(
            me.latitude,
            me.longitude,
            (p.latitude as num).toDouble(),
            (p.longitude as num).toDouble(),
          ) /
          1000;

      if (mounted) setState(() => _pickupKm = km);
    } catch (e) {
      debugPrint('Pickup distance skipped: $e');
    }
  }

  void _stopAudio() {
    try {
      audioPlayer.stop();
    } catch (e) {
      debugPrint('Audio stop error: $e');
    }
  }

  void _showLoadingDialog() {
    if (!mounted || _loadingDialogContext != null) {
      return;
    }

    showDialog<void>(
      context: context,
      barrierDismissible: false,
      builder: (BuildContext dialogContext) {
        _loadingDialogContext = dialogContext;

        return PopScope(
          canPop: false,
          child: LoadingDialog(
            messageText: 'msg_please_wait'.tr(),
          ),
        );
      },
    ).whenComplete(() {
      _loadingDialogContext = null;
    });
  }

  void _closeLoadingDialog() {
    final BuildContext? loadingContext = _loadingDialogContext;

    if (loadingContext == null) {
      return;
    }

    _loadingDialogContext = null;

    try {
      if (loadingContext.mounted) {
        Navigator.of(loadingContext).pop();
      }
    } catch (e) {
      debugPrint('Close loading dialog error: $e');
    }
  }

  void _closeMainDialog(BuildContext dialogContext) {
    try {
      if (dialogContext.mounted && Navigator.of(dialogContext).canPop()) {
        Navigator.of(dialogContext).pop();
      }
    } catch (e) {
      debugPrint('Close main dialog error: $e');
    }
  }

  Future<void> checkAvailabilityOfTripRequest(
    BuildContext dialogContext,
  ) async {
    if (_isAcceptingTrip) {
      return;
    }

    final User? currentUser = FirebaseAuth.instance.currentUser;

    if (currentUser == null) {
      cMethods.displaySnackBar(
        'notification_driver_login_required'.tr(),
        dialogContext,
      );
      return;
    }

    final String tripId = widget.tripDetailsInfo?.tripID?.trim() ?? '';

    if (tripId.isEmpty) {
      cMethods.displaySnackBar(
        'notification_trip_id_not_found'.tr(),
        dialogContext,
      );
      return;
    }

    if (mounted) {
      setState(() {
        _isAcceptingTrip = true;
        tripRequestStatus = TripStatus.accepted;
      });
    }

    _countdown.stop();
    _stopAudio();
    _showLoadingDialog();

    bool accepted = false;
    String? userMessage;

    try {
      final FirebaseFirestore firestore = FirebaseFirestore.instance;

      final DocumentReference<Map<String, dynamic>> tripRef =
          firestore.collection('rides').doc(tripId);

      accepted = await firestore
          .runTransaction<bool>(
            (Transaction transaction) async {
              final DocumentSnapshot<Map<String, dynamic>> snapshot =
                  await transaction.get(tripRef);

              if (!snapshot.exists || snapshot.data() == null) {
                return false;
              }

              final Map<String, dynamic> data = snapshot.data()!;

              final String currentStatus =
                  data['status']?.toString().trim().toLowerCase() ?? '';

              if (currentStatus != TripStatus.searching) {
                return false;
              }

              transaction.update(
                tripRef,
                <String, dynamic>{
                  'status': TripStatus.accepted,
                  'driver_id': currentUser.uid,
                  'accepted_at': FieldValue.serverTimestamp(),
                  'updated_at': FieldValue.serverTimestamp(),
                },
              );

              return true;
            },
          )
          .timeout(_acceptTimeout);

      if (!accepted) {
        userMessage = 'notification_trip_already_taken'.tr();
        return;
      }

      try {
        await firestore
            .collection('drivers')
            .doc(currentUser.uid)
            .set(
              <String, dynamic>{
                'newTripStatus': TripStatus.accepted,
                'activeTripId': tripId,
                'updated_at': FieldValue.serverTimestamp(),
              },
              SetOptions(merge: true),
            )
            .timeout(const Duration(seconds: 8));
      } catch (e) {
        debugPrint('Driver status update after accept failed: $e');
      }

      try {
        cMethods.turnOffLocationUpdatesForHomePage();
      } catch (e) {
        debugPrint('turnOffLocationUpdatesForHomePage error: $e');
      }
    } on TimeoutException catch (e) {
      debugPrint('Accept trip timeout: $e');

      accepted = false;
      userMessage = 'notification_weak_internet_retry'.tr();
    } catch (e, stackTrace) {
      debugPrint('Error accepting trip: $e');
      debugPrintStack(stackTrace: stackTrace);

      accepted = false;
      userMessage = 'notification_trip_accept_error'.tr();
    } finally {
      _closeLoadingDialog();

      if (mounted) {
        setState(() {
          _isAcceptingTrip = false;

          if (!accepted) {
            tripRequestStatus = '';
          }
        });
      }

      if (userMessage != null) {
        cMethods.displaySnackBar(userMessage, dialogContext);
      }

      _closeMainDialog(dialogContext);
    }
  }

  void _declineTrip() {
    if (_isAcceptingTrip) {
      return;
    }

    _stopAudio();

    if (mounted) {
      Navigator.of(context).pop();
    }
  }

  double? _tripKm() {
    final dynamic raw = widget.rideData?['distance'] ??
        widget.rideData?['estimatedDistance'] ??
        widget.rideData?['distanceKm'];
    if (raw == null) return null;
    final double? v = raw is num
        ? raw.toDouble()
        : double.tryParse(raw.toString().replaceAll(',', '').trim());
    return (v == null || v <= 0) ? null : v;
  }

  @override
  Widget build(BuildContext context) {
    final String fareAmount = widget.fareAmount ?? '۰';
    final String currencyUnit = 'currency_unit'.tr();

    final bool hasBid = widget.bidAmount != null &&
        widget.bidAmount != 'null' &&
        widget.bidAmount!.trim().isNotEmpty;

    final String km = _t('unit_km', 'کیلومتر');
    final double? tripKm = _tripKm();

    return PopScope(
      canPop: !_isAcceptingTrip,
      child: Align(
        alignment: Alignment.bottomCenter,
        child: Material(
          color: AppColors.background,
          shape: RoundedRectangleBorder(
            borderRadius: const BorderRadius.vertical(
              top: Radius.circular(28),
            ),
            side: BorderSide(color: AppColors.borderLight),
          ),
          child: SafeArea(
            top: false,
            child: ConstrainedBox(
              constraints: BoxConstraints(
                maxHeight: MediaQuery.of(context).size.height * 0.85,
              ),
              child: SingleChildScrollView(
                padding: const EdgeInsets.fromLTRB(16, 10, 16, 16),
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
                    Text(
                      'title_new_trip_request'.tr(),
                      style: TextStyle(
                        fontWeight: FontWeight.bold,
                        fontSize: 14,
                        color: AppColors.textSecondary,
                      ),
                    ),
                    const SizedBox(height: 6),
                    Text(
                      '$fareAmount $currencyUnit',
                      style: TextStyle(
                        fontWeight: FontWeight.w800,
                        fontSize: 32,
                        color: AppColors.textPrimary,
                      ),
                    ),
                    if (hasBid) ...<Widget>[
                      const SizedBox(height: 2),
                      Text(
                        '${'label_passenger_bid'.tr()}: '
                        '${widget.bidAmount} $currencyUnit',
                        style: TextStyle(
                          fontWeight: FontWeight.w700,
                          fontSize: 12.5,
                          color: AppColors.successDark,
                        ),
                      ),
                    ],
                    const SizedBox(height: 12),
                    Wrap(
                      spacing: 8,
                      runSpacing: 8,
                      alignment: WrapAlignment.center,
                      children: <Widget>[
                        if (_pickupKm != null)
                          _chip(
                            Icons.near_me_rounded,
                            '${_t('request_to_pickup', 'تا مبدأ')} '
                            '${_pickupKm!.toStringAsFixed(1)} $km',
                          ),
                        if (tripKm != null)
                          _chip(
                            Icons.route_rounded,
                            '${_t('request_trip_distance', 'مسافت سفر')} '
                            '${tripKm.toStringAsFixed(1)} $km',
                          ),
                      ],
                    ),
                    const SizedBox(height: 14),
                    _buildLocations(),
                    _buildExtras(),
                    const SizedBox(height: 16),
                    _buildActionButtons(),
                  ],
                ),
              ),
            ),
          ),
        ),
      ),
    );
  }

  Widget _chip(IconData icon, String text) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 11, vertical: 7),
      decoration: BoxDecoration(
        color: AppColors.neutralSoft,
        borderRadius: BorderRadius.circular(20),
      ),
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: <Widget>[
          Icon(icon, size: 15, color: AppColors.iconSecondary),
          const SizedBox(width: 6),
          Text(
            text,
            style: TextStyle(
              fontSize: 12,
              fontWeight: FontWeight.w700,
              color: AppColors.textPrimary,
            ),
          ),
        ],
      ),
    );
  }

  Widget _card({required Widget child}) {
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

  Widget _buildExtras() {
    final TripExtras extras = TripExtras.fromRide(widget.rideData);

    if (!extras.hasContent) {
      return const SizedBox.shrink();
    }

    return Padding(
      padding: const EdgeInsets.only(top: 10),
      child: _card(
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: <Widget>[
            Row(
              children: <Widget>[
                Icon(extras.serviceIcon, size: 19, color: extras.serviceColor),
                const SizedBox(width: 8),
                Text(
                  extras.serviceLabel,
                  style: TextStyle(
                    fontWeight: FontWeight.bold,
                    fontSize: 13.5,
                    color: AppColors.textPrimary,
                  ),
                ),
              ],
            ),
            if (extras.items.isNotEmpty) ...<Widget>[
              const SizedBox(height: 10),
              Wrap(
                spacing: 6,
                runSpacing: 6,
                children: extras.items
                    .map((TripExtraItem item) => _buildExtraChip(item))
                    .toList(),
              ),
            ],
            for (final TripParty party in extras.parties)
              if (party.name.isNotEmpty) ...<Widget>[
                const SizedBox(height: 10),
                Row(
                  children: <Widget>[
                    Icon(
                      Icons.person_outline_rounded,
                      size: 17,
                      color: AppColors.iconSecondary,
                    ),
                    const SizedBox(width: 6),
                    Expanded(
                      child: Text(
                        'notification_party_name'.tr(
                          namedArgs: <String, String>{
                            'role': party.role,
                            'name': party.name,
                          },
                        ),
                        maxLines: 1,
                        overflow: TextOverflow.ellipsis,
                        style: TextStyle(
                          fontSize: 12.5,
                          color: AppColors.textPrimary,
                        ),
                      ),
                    ),
                  ],
                ),
              ],
          ],
        ),
      ),
    );
  }

  Widget _buildExtraChip(TripExtraItem item) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 9, vertical: 5),
      decoration: BoxDecoration(
        color: AppColors.neutralSoft,
        borderRadius: BorderRadius.circular(20),
      ),
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: <Widget>[
          Icon(item.icon, size: 14, color: AppColors.iconSecondary),
          const SizedBox(width: 5),
          Flexible(
            child: Text(
              item.text,
              maxLines: 2,
              overflow: TextOverflow.ellipsis,
              style: TextStyle(
                fontSize: 11.5,
                color: AppColors.textPrimary,
              ),
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildLocations() {
    Widget row(IconData icon, Color color, String label, String value) {
      return Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: <Widget>[
          Icon(icon, color: color, size: 21),
          const SizedBox(width: 12),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: <Widget>[
                Text(
                  label,
                  style: TextStyle(
                    fontSize: 11,
                    color: AppColors.textSecondary,
                  ),
                ),
                const SizedBox(height: 2),
                Text(
                  value,
                  maxLines: 2,
                  overflow: TextOverflow.ellipsis,
                  style: TextStyle(
                    color: AppColors.textPrimary,
                    fontSize: 13.5,
                    fontWeight: FontWeight.w700,
                  ),
                ),
              ],
            ),
          ),
        ],
      );
    }

    return _card(
      child: Column(
        children: <Widget>[
          row(
            Icons.circle,
            AppColors.successDark,
            'label_pickup_location'.tr(),
            widget.tripDetailsInfo?.pickupAddress ?? 'unknown_address'.tr(),
          ),
          const SizedBox(height: 14),
          row(
            Icons.location_on_rounded,
            AppColors.danger,
            'label_dropoff_location'.tr(),
            widget.tripDetailsInfo?.dropOffAddress ?? 'unknown_address'.tr(),
          ),
        ],
      ),
    );
  }

  // دکمهٔ قبول: نوار آن با گذشت زمان خالی می‌شود و عدد ثانیه‌ها کنارش است.
  Widget _buildActionButtons() {
    return Row(
      children: <Widget>[
        SizedBox(
          width: 58,
          height: 58,
          child: OutlinedButton(
            onPressed: _isAcceptingTrip ? null : _declineTrip,
            style: OutlinedButton.styleFrom(
              padding: EdgeInsets.zero,
              side: BorderSide(color: AppColors.borderLight),
              shape: RoundedRectangleBorder(
                borderRadius: BorderRadius.circular(18),
              ),
            ),
            child: Icon(
              Icons.close_rounded,
              color: AppColors.textSecondary,
              size: 26,
            ),
          ),
        ),
        const SizedBox(width: 12),
        Expanded(
          child: SizedBox(
            height: 58,
            child: AnimatedBuilder(
              animation: _countdown,
              builder: (BuildContext context, Widget? _) {
                final double left = (1 - _countdown.value).clamp(0.0, 1.0);
                final int seconds = (left * _requestSeconds).ceil();

                return Material(
                  color: AppColors.primaryButton.withOpacity(0.35),
                  borderRadius: BorderRadius.circular(18),
                  clipBehavior: Clip.antiAlias,
                  child: InkWell(
                    onTap: _isAcceptingTrip
                        ? null
                        : () => checkAvailabilityOfTripRequest(context),
                    child: Stack(
                      children: <Widget>[
                        Positioned.fill(
                          child: Align(
                            alignment: AlignmentDirectional.centerStart,
                            child: FractionallySizedBox(
                              widthFactor: left,
                              heightFactor: 1,
                              child: ColoredBox(
                                color: AppColors.primaryButton,
                              ),
                            ),
                          ),
                        ),
                        Center(
                          child: _isAcceptingTrip
                              ? SizedBox(
                                  width: 22,
                                  height: 22,
                                  child: CircularProgressIndicator(
                                    strokeWidth: 2.4,
                                    color: AppColors.buttonText,
                                  ),
                                )
                              : Row(
                                  mainAxisSize: MainAxisSize.min,
                                  children: <Widget>[
                                    Text(
                                      'btn_accept_trip'.tr(),
                                      style: TextStyle(
                                        fontWeight: FontWeight.bold,
                                        fontSize: 16,
                                        color: AppColors.buttonText,
                                      ),
                                    ),
                                    const SizedBox(width: 10),
                                    Text(
                                      '$seconds',
                                      style: TextStyle(
                                        fontWeight: FontWeight.w800,
                                        fontSize: 16,
                                        color: AppColors.buttonText,
                                      ),
                                    ),
                                  ],
                                ),
                        ),
                      ],
                    ),
                  ),
                );
              },
            ),
          ),
        ),
      ],
    );
  }
}
