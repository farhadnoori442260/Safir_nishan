import 'dart:async';

import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:easy_localization/easy_localization.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:flutter/material.dart';

import 'package:safir_drivers/constants/trip_status.dart';
import '../global/global.dart';
import '../methods/common_method.dart';
import '../models/trip_details.dart';
import 'loading_dialog.dart';

class NotificationDialog extends StatefulWidget {
  final TripDetails? tripDetailsInfo;
  final String? fareAmount;
  final String? bidAmount;

  const NotificationDialog({
    super.key,
    this.tripDetailsInfo,
    this.fareAmount,
    this.bidAmount,
  });

  @override
  State<NotificationDialog> createState() => _NotificationDialogState();
}

class _NotificationDialogState extends State<NotificationDialog> {
  String tripRequestStatus = '';
  final CommonMethods cMethods = CommonMethods();

  Timer? _timer;
  bool _isAcceptingTrip = false;

  // ✅ کانتکست دیالوگ لودینگ را نگه می‌داریم تا دقیقاً همان بسته شود
  BuildContext? _loadingDialogContext;

  static const Duration _acceptTimeout = Duration(seconds: 15);

  static const Color brandPrimary = Color(0xFF145A41);
  static const Color btnPrimary = Color(0xFF1B7A57);
  static const Color btnPressed = Color(0xFF0F4A35);
  static const Color cardBgLight = Color(0xFFEAF6F1);
  static const Color textOnBtn = Colors.white;

  @override
  void initState() {
    super.initState();
    driverTripRequestTimeout = 40;
    _startTimeoutTimer();
  }

  @override
  void dispose() {
    _timer?.cancel();
    _stopAudio();
    super.dispose();
  }

  void _startTimeoutTimer() {
    _timer?.cancel();

    _timer = Timer.periodic(
      const Duration(seconds: 1),
      (Timer timer) {
        if (!mounted) {
          timer.cancel();
          return;
        }

        // وقتی راننده در حال قبول کردن است، تایمر نباید دیالوگ را ببندد
        if (_isAcceptingTrip || tripRequestStatus == TripStatus.accepted) {
          timer.cancel();
          driverTripRequestTimeout = 40;
          return;
        }

        if (driverTripRequestTimeout > 0) {
          driverTripRequestTimeout--;
        }

        if (driverTripRequestTimeout <= 0) {
          timer.cancel();
          driverTripRequestTimeout = 40;
          _stopAudio();

          if (mounted) {
            Navigator.of(context).pop();
          }
        }
      },
    );
  }

  void _stopAudio() {
    try {
      audioPlayer.stop();
    } catch (e) {
      debugPrint('Audio stop error: $e');
    }
  }

  // ✅ بدون await: showDialog تا بسته‌شدن دیالوگ تمام نمی‌شود،
  // پس نباید جلوی ادامهٔ کد را بگیرد.
  void _showLoadingDialog() {
    if (!mounted || _loadingDialogContext != null) return;

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

  // ✅ دقیقاً دیالوگ لودینگ را می‌بندد (نه دیالوگ دیگری را)
  void _closeLoadingDialog() {
    final BuildContext? loadingContext = _loadingDialogContext;
    if (loadingContext == null) return;

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
    if (_isAcceptingTrip) return;

    final User? currentUser = FirebaseAuth.instance.currentUser;

    if (currentUser == null) {
      cMethods.displaySnackBar(
        'لطفاً ابتدا وارد حساب راننده شوید.',
        dialogContext,
      );
      return;
    }

    final String tripId = widget.tripDetailsInfo?.tripID?.trim() ?? '';

    if (tripId.isEmpty) {
      cMethods.displaySnackBar(
        'شناسه سفر پیدا نشد.',
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

    _stopAudio();
    _showLoadingDialog(); // ✅ بدون await

    bool accepted = false;
    String? userMessage;

    try {
      final FirebaseFirestore firestore = FirebaseFirestore.instance;

      final DocumentReference<Map<String, dynamic>> tripRef =
          firestore.collection('rides').doc(tripId);

      // ✅ با timeout تا در اینترنت ضعیف / VPN برای همیشه گیر نکند
      accepted = await firestore.runTransaction<bool>(
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
      ).timeout(_acceptTimeout);

      if (!accepted) {
        userMessage = 'این سفر قبلاً توسط راننده دیگری گرفته شده است.';
        return;
      }

      // ✅ شکست این مرحله نباید باعث شود سفرِ قبول‌شده «خطا» نشان داده شود
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
      userMessage = 'اتصال اینترنت ضعیف است. دوباره تلاش کنید.';
    } catch (e, stackTrace) {
      debugPrint('Error accepting trip: $e');
      debugPrintStack(stackTrace: stackTrace);
      accepted = false;
      userMessage = 'خطایی رخ داد. دوباره تلاش کنید.';
    } finally {
      // ✅ در هر حالتی لودینگ بسته می‌شود
      _closeLoadingDialog();

      if (mounted) {
        setState(() {
          _isAcceptingTrip = false;
          if (!accepted) tripRequestStatus = '';
        });
      }

      if (userMessage != null) {
        cMethods.displaySnackBar(userMessage, dialogContext);
      }

      // در همهٔ حالت‌ها (موفق یا ناموفق) دیالوگ اصلی بسته می‌شود
      _closeMainDialog(dialogContext);
    }
  }

  void _declineTrip() {
    if (_isAcceptingTrip) return;

    _stopAudio();

    if (mounted) {
      Navigator.of(context).pop();
    }
  }

  @override
  Widget build(BuildContext context) {
    final String fareAmount = widget.fareAmount ?? '۰';
    final String currencyUnit = 'currency_unit'.tr();

    final String bidAmount =
        widget.bidAmount == null ||
                widget.bidAmount == 'null' ||
                widget.bidAmount!.trim().isEmpty
            ? 'no_bid_offer'.tr()
            : '${widget.bidAmount} $currencyUnit';

    return PopScope(
      // جلوگیری از بستن با دکمهٔ برگشت هنگام قبول سفر
      canPop: !_isAcceptingTrip,
      child: Dialog(
        shape: RoundedRectangleBorder(
          borderRadius: BorderRadius.circular(24),
        ),
        backgroundColor: Colors.white,
        elevation: 10,
        child: Padding(
          padding: const EdgeInsets.symmetric(
            horizontal: 20,
            vertical: 22,
          ),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: <Widget>[
              Container(
                padding: const EdgeInsets.all(14),
                decoration: const BoxDecoration(
                  color: cardBgLight,
                  shape: BoxShape.circle,
                ),
                child: const Icon(
                  Icons.local_taxi_rounded,
                  color: brandPrimary,
                  size: 38,
                ),
              ),
              const SizedBox(height: 12),
              Text(
                'title_new_trip_request'.tr(),
                style: const TextStyle(
                  fontFamily: 'IranYekan',
                  fontWeight: FontWeight.bold,
                  fontSize: 18,
                  color: Colors.black87,
                ),
              ),
              const SizedBox(height: 16),
              Divider(
                height: 1,
                color: Colors.grey.shade200,
              ),
              const SizedBox(height: 16),
              _buildLocations(),
              const SizedBox(height: 16),
              Divider(
                height: 1,
                color: Colors.grey.shade200,
              ),
              const SizedBox(height: 14),
              _buildFareCard(
                fareAmount: fareAmount,
                bidAmount: bidAmount,
                currencyUnit: currencyUnit,
              ),
              const SizedBox(height: 20),
              _buildActionButtons(),
            ],
          ),
        ),
      ),
    );
  }

  Widget _buildLocations() {
    return Column(
      children: <Widget>[
        Row(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: <Widget>[
            const Icon(
              Icons.location_on,
              color: brandPrimary,
              size: 22,
            ),
            const SizedBox(width: 12),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: <Widget>[
                  Text(
                    'label_pickup_location'.tr(),
                    style: TextStyle(
                      fontSize: 11,
                      color: Colors.grey.shade600,
                      fontFamily: 'IranYekan',
                    ),
                  ),
                  const SizedBox(height: 2),
                  Text(
                    widget.tripDetailsInfo?.pickupAddress ??
                        'unknown_address'.tr(),
                    maxLines: 2,
                    overflow: TextOverflow.ellipsis,
                    style: const TextStyle(
                      color: Colors.black87,
                      fontSize: 13,
                      fontWeight: FontWeight.w600,
                    ),
                  ),
                ],
              ),
            ),
          ],
        ),
        const SizedBox(height: 14),
        Row(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: <Widget>[
            const Icon(
              Icons.flag_rounded,
              color: Colors.redAccent,
              size: 22,
            ),
            const SizedBox(width: 12),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: <Widget>[
                  Text(
                    'label_dropoff_location'.tr(),
                    style: TextStyle(
                      fontSize: 11,
                      color: Colors.grey.shade600,
                      fontFamily: 'IranYekan',
                    ),
                  ),
                  const SizedBox(height: 2),
                  Text(
                    widget.tripDetailsInfo?.dropOffAddress ??
                        'unknown_address'.tr(),
                    maxLines: 2,
                    overflow: TextOverflow.ellipsis,
                    style: const TextStyle(
                      color: Colors.black87,
                      fontSize: 13,
                      fontWeight: FontWeight.w600,
                    ),
                  ),
                ],
              ),
            ),
          ],
        ),
      ],
    );
  }

  Widget _buildFareCard({
    required String fareAmount,
    required String bidAmount,
    required String currencyUnit,
  }) {
    return Container(
      padding: const EdgeInsets.symmetric(
        horizontal: 14,
        vertical: 12,
      ),
      decoration: BoxDecoration(
        color: cardBgLight,
        borderRadius: BorderRadius.circular(14),
      ),
      child: Column(
        children: <Widget>[
          Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: <Widget>[
              Text(
                'label_standard_fare'.tr(),
                style: const TextStyle(
                  fontFamily: 'IranYekan',
                  color: Colors.black54,
                  fontSize: 13,
                ),
              ),
              Text(
                '$fareAmount $currencyUnit',
                style: const TextStyle(
                  fontWeight: FontWeight.bold,
                  fontSize: 14,
                  fontFamily: 'IranYekan',
                ),
              ),
            ],
          ),
          const SizedBox(height: 6),
          Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: <Widget>[
              Text(
                'label_passenger_bid'.tr(),
                style: const TextStyle(
                  fontFamily: 'IranYekan',
                  color: Colors.black54,
                  fontSize: 13,
                ),
              ),
              Text(
                bidAmount,
                style: const TextStyle(
                  fontWeight: FontWeight.bold,
                  fontSize: 14,
                  color: brandPrimary,
                  fontFamily: 'IranYekan',
                ),
              ),
            ],
          ),
        ],
      ),
    );
  }

  Widget _buildActionButtons() {
    return Row(
      children: <Widget>[
        Expanded(
          child: SizedBox(
            height: 46,
            child: OutlinedButton(
              onPressed: _isAcceptingTrip ? null : _declineTrip,
              style: OutlinedButton.styleFrom(
                side: BorderSide(
                  color: Colors.grey.shade300,
                ),
                foregroundColor: Colors.grey.shade700,
                shape: RoundedRectangleBorder(
                  borderRadius: BorderRadius.circular(12),
                ),
              ),
              child: Text(
                'btn_decline_trip'.tr(),
                style: const TextStyle(
                  fontFamily: 'IranYekan',
                  fontWeight: FontWeight.bold,
                  fontSize: 13,
                ),
              ),
            ),
          ),
        ),
        const SizedBox(width: 12),
        Expanded(
          child: SizedBox(
            height: 46,
            child: ElevatedButton(
              onPressed: _isAcceptingTrip
                  ? null
                  : () => checkAvailabilityOfTripRequest(context),
              style: ButtonStyle(
                backgroundColor: WidgetStateProperty.resolveWith<Color>(
                  (Set<WidgetState> states) {
                    if (states.contains(WidgetState.pressed)) {
                      return btnPressed;
                    }

                    if (states.contains(WidgetState.disabled)) {
                      return Colors.grey.shade400;
                    }

                    return btnPrimary;
                  },
                ),
                foregroundColor: WidgetStateProperty.all(textOnBtn),
                elevation: WidgetStateProperty.all(0),
                shape: WidgetStateProperty.all(
                  RoundedRectangleBorder(
                    borderRadius: BorderRadius.circular(12),
                  ),
                ),
              ),
              child: _isAcceptingTrip
                  ? const SizedBox(
                      width: 20,
                      height: 20,
                      child: CircularProgressIndicator(
                        strokeWidth: 2,
                        color: Colors.white,
                      ),
                    )
                  : Text(
                      'btn_accept_trip'.tr(),
                      style: const TextStyle(
                        fontFamily: 'IranYekan',
                        fontWeight: FontWeight.bold,
                        fontSize: 13,
                        color: textOnBtn,
                      ),
                    ),
            ),
          ),
        ),
      ],
    );
  }
}
