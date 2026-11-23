import 'dart:async';

import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:easy_localization/easy_localization.dart'
    hide TextDirection;
import 'package:firebase_auth/firebase_auth.dart';
import 'package:flutter/material.dart';

import 'package:safir_drivers/constants/trip_status.dart';
import 'package:safir_drivers/utils/app_colors.dart';
import 'package:safir_drivers/utils/driver_prefs.dart';
import 'package:safir_drivers/utils/trip_extras.dart';
import '../global/global.dart';
import '../methods/common_method.dart';
import '../models/trip_details.dart';
import 'loading_dialog.dart';

/// مهلت نمایش تازهٔ هر درخواست (ثانیه)؛ بعد از آن به «صف انتظار» می‌رود.
const int kTripRequestSeconds = 15;

/// حداکثر ماندن در صف انتظار، از لحظهٔ ساخته‌شدن سفر.
const Duration kTripWaitingLife = Duration(minutes: 5);

/// یک درخواست سفر در انتظار تصمیم راننده.
class PendingTripRequest {
  PendingTripRequest({
    required this.tripId,
    required this.details,
    required this.bidAmount,
    required this.fareAmount,
    required this.rideData,
    this.pickupKm,
  })  : expiresAt = DateTime.now().add(
          const Duration(seconds: kTripRequestSeconds),
        ),
        goneAt = _createdAtOf(rideData).add(kTripWaitingLife);

  static DateTime _createdAtOf(Map<String, dynamic> data) {
    final dynamic raw =
        data['created_at'] ?? data['createdAt'] ?? data['timestamp'];
    if (raw is Timestamp) {
      final DateTime t = raw.toDate();
      // ساعت‌های خیلی غیرعادی را نادیده می‌گیریم
      if (!t.isAfter(DateTime.now().add(const Duration(minutes: 1)))) {
        return t;
      }
    }
    return DateTime.now();
  }

  final String tripId;
  final TripDetails details;
  final String bidAmount;
  final String fareAmount;
  final Map<String, dynamic> rideData;
  final double? pickupKm;
  /// پایان مرحلهٔ «تازه» (۱۵ ثانیه)
  final DateTime expiresAt;

  /// پایان عمر در صف انتظار
  final DateTime goneAt;

  StreamSubscription<DocumentSnapshot<Map<String, dynamic>>>? _watch;

  Duration get remaining => expiresAt.difference(DateTime.now());

  /// هنوز در مهلت ۱۵ ثانیه‌ای است (زنگ و شمارش دارد)
  bool get isFresh => remaining > Duration.zero;

  /// عمر ۵ دقیقه‌ای تمام شده
  bool get isGone => DateTime.now().isAfter(goneAt);
}

/// فهرست درخواست‌های در انتظار. همهٔ درخواست‌ها در یک پنجره جمع می‌شوند
/// و راننده با فلش‌ها بینشان جابه‌جا می‌شود.
class TripRequestQueue {
  TripRequestQueue._();
  static final TripRequestQueue instance = TripRequestQueue._();

  final ValueNotifier<List<PendingTripRequest>> items =
      ValueNotifier<List<PendingTripRequest>>(const <PendingTripRequest>[]);

  /// پنجره باز است؟ (برای نشان صف انتظار روی صفحهٔ اصلی)
  final ValueNotifier<bool> open = ValueNotifier<bool>(false);
  bool get isOpen => open.value;
  Timer? _life;

  void _ensureLifeTimer() {
    _life ??= Timer.periodic(const Duration(seconds: 1), (_) {
      for (final PendingTripRequest r
          in List<PendingTripRequest>.of(items.value)) {
        if (r.isGone) remove(r.tripId);
      }
      if (items.value.isEmpty) {
        _life?.cancel();
        _life = null;
      }
    });
  }

  bool contains(String tripId) =>
      items.value.any((PendingTripRequest r) => r.tripId == tripId);

  /// درخواست را به فهرست اضافه می‌کند و اگر پنجره بسته است، باز می‌کند.
  /// وقتی پنجره بسته شد (قبول، رد همه یا پایان مهلت‌ها) [onClosed] صدا می‌خورد.
  Future<void> add(
    BuildContext context,
    PendingTripRequest request, {
    VoidCallback? onClosed,
  }) async {
    if (contains(request.tripId)) return;

    // اگر سفر در این فاصله قبول/لغو شد، از فهرست حذف می‌شود
    request._watch = FirebaseFirestore.instance
        .collection('rides')
        .doc(request.tripId)
        .snapshots()
        .listen(
      (DocumentSnapshot<Map<String, dynamic>> snap) {
        final String status =
            snap.data()?['status']?.toString().trim().toLowerCase() ?? '';
        if (!snap.exists || status != TripStatus.searching) {
          remove(request.tripId);
        }
      },
      onError: (Object e) => debugPrint('Request watch error: $e'),
    );

    items.value = <PendingTripRequest>[...items.value, request];
    _ensureLifeTimer();

    if (isOpen) return;
    await _openSheet(context, manual: false, onClosed: onClosed);
  }

  /// باز کردن دستی صف انتظار (از نشان روی صفحهٔ اصلی)
  Future<void> openWaiting(BuildContext context) async {
    if (isOpen || items.value.isEmpty) return;
    await _openSheet(context, manual: true);
  }

  Future<void> _openSheet(
    BuildContext context, {
    required bool manual,
    VoidCallback? onClosed,
  }) async {
    open.value = true;
    try {
      await showDialog<void>(
        context: context,
        barrierDismissible: false,
        builder: (BuildContext _) => NotificationDialog(manual: manual),
      );
    } finally {
      open.value = false;
      onClosed?.call();
    }
  }

  void remove(String tripId) {
    final List<PendingTripRequest> list = items.value;
    final int i =
        list.indexWhere((PendingTripRequest r) => r.tripId == tripId);
    if (i < 0) return;

    list[i]._watch?.cancel();
    items.value = <PendingTripRequest>[
      for (final PendingTripRequest r in list)
        if (r.tripId != tripId) r,
    ];
  }

  /// همهٔ درخواست‌ها پاک می‌شوند (آفلاین شدن، قبول سفر یا شروع سفر)
  void clear() {
    for (final PendingTripRequest r in items.value) {
      r._watch?.cancel();
    }
    items.value = const <PendingTripRequest>[];
    _life?.cancel();
    _life = null;
  }
}

class NotificationDialog extends StatefulWidget {
  const NotificationDialog({super.key, this.manual = false});

  /// false: پنجرهٔ درخواست‌های تازه (۱۵ ثانیه‌ای)؛ خودکار بسته می‌شود.
  /// true: صف انتظار که راننده خودش باز کرده؛ همهٔ درخواست‌ها را نشان می‌دهد.
  final bool manual;

  @override
  State<NotificationDialog> createState() => _NotificationDialogState();
}

String _t(String key, String fallback) {
  final String value = key.tr();
  return value.trim().isEmpty || value == key ? fallback : value;
}

class _NotificationDialogState extends State<NotificationDialog> {
  final TripRequestQueue _queue = TripRequestQueue.instance;
  final CommonMethods cMethods = CommonMethods();

  static const Duration _acceptTimeout = Duration(seconds: 15);

  String? _currentId;
  int _lastIndex = 0;
  int _lastCount = 0;
  Timer? _ticker;

  bool _isAcceptingTrip = false;
  bool _closing = false;
  BuildContext? _loadingDialogContext;

  @override
  void initState() {
    super.initState();
    driverTripRequestTimeout = 40;
    DriverPrefs.instance.buzz();

    _lastCount = _queue.items.value.length;
    _queue.items.addListener(_onItemsChanged);

    // هر ۱۲۰ میلی‌ثانیه: نوار زمان را تازه می‌کند
    _ticker = Timer.periodic(const Duration(milliseconds: 120), (_) {
      if (!mounted) return;
      // حالت خودکار: وقتی دیگر درخواست تازه‌ای نیست، پنجره بسته می‌شود
      // (درخواست‌های بی‌پاسخ در صف انتظار می‌مانند)
      if (!widget.manual && !_isAcceptingTrip && _visible().isEmpty) {
        _closeSelf();
        return;
      }
      setState(() {});
    });
  }

  @override
  void dispose() {
    _ticker?.cancel();
    _queue.items.removeListener(_onItemsChanged);
    _stopAudio();
    super.dispose();
  }

  /// درخواست‌هایی که در این پنجره دیده می‌شوند.
  /// خودکار: فقط تازه‌ها به ترتیب رسیدن. دستی: همه، نزدیک‌ترین اول.
  List<PendingTripRequest> _visible() {
    final List<PendingTripRequest> all = _queue.items.value;
    if (!widget.manual) {
      return all.where((PendingTripRequest r) => r.isFresh).toList();
    }
    final List<PendingTripRequest> list = List<PendingTripRequest>.of(all);
    list.sort((PendingTripRequest a, PendingTripRequest b) {
      final double ka = a.pickupKm ?? double.infinity;
      final double kb = b.pickupKm ?? double.infinity;
      return ka.compareTo(kb);
    });
    return list;
  }

  void _onItemsChanged() {
    if (!mounted) return;

    final int count = _queue.items.value.length;
    if (count > _lastCount && !widget.manual) DriverPrefs.instance.buzz();
    _lastCount = count;

    if (_visible().isEmpty && !_isAcceptingTrip) {
      _closeSelf();
      return;
    }
    setState(() {});
  }

  void _closeSelf() {
    if (_closing) return;
    _closing = true;
    _stopAudio();
    WidgetsBinding.instance.addPostFrameCallback((_) {
      if (!mounted) return;
      final NavigatorState nav = Navigator.of(context);
      if (nav.canPop()) nav.pop();
    });
  }

  void _stopAudio() {
    try {
      audioPlayer.stop();
    } catch (e) {
      debugPrint('Audio stop error: $e');
    }
  }

  void _go(int delta) {
    final List<PendingTripRequest> list = _visible();
    final int next = (_lastIndex + delta).clamp(0, list.length - 1);
    if (next == _lastIndex || list.isEmpty) return;
    setState(() => _currentId = list[next].tripId);
  }

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

  Future<void> _accept(PendingTripRequest req) async {
    if (_isAcceptingTrip) return;

    final BuildContext dialogContext = context;
    final User? currentUser = FirebaseAuth.instance.currentUser;

    if (currentUser == null) {
      cMethods.displaySnackBar(
        'notification_driver_login_required'.tr(),
        dialogContext,
      );
      return;
    }

    final String tripId = req.tripId.trim();

    if (tripId.isEmpty) {
      cMethods.displaySnackBar(
        'notification_trip_id_not_found'.tr(),
        dialogContext,
      );
      return;
    }

    if (mounted) setState(() => _isAcceptingTrip = true);

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

      if (mounted) setState(() => _isAcceptingTrip = false);

      if (userMessage != null) {
        cMethods.displaySnackBar(userMessage, dialogContext);
      }

      if (accepted) {
        // راننده سفر دارد؛ بقیهٔ درخواست‌ها دیگر معنی ندارند
        _closeSelf();
        _queue.clear();
      } else {
        // این درخواست گرفته شده/خطا داد؛ بقیه می‌مانند، اگر نبود پنجره بسته می‌شود
        _queue.remove(req.tripId);
        if (_visible().isEmpty) _closeSelf();
      }
    }
  }

  void _decline(PendingTripRequest req) {
    if (_isAcceptingTrip) return;
    _queue.remove(req.tripId); // درخواست بعدی خودکار نشان داده می‌شود
  }

  double? _tripKm(PendingTripRequest r) {
    final dynamic raw = r.rideData['distance'] ??
        r.rideData['estimatedDistance'] ??
        r.rideData['distanceKm'];
    if (raw == null) return null;
    final double? v = raw is num
        ? raw.toDouble()
        : double.tryParse(raw.toString().replaceAll(',', '').trim());
    return (v == null || v <= 0) ? null : v;
  }

  @override
  Widget build(BuildContext context) {
    final List<PendingTripRequest> list = _visible();

    if (list.isEmpty) {
      return const SizedBox.shrink();
    }

    int idx = list.indexWhere(
      (PendingTripRequest r) => r.tripId == _currentId,
    );
    if (idx < 0) {
      idx = _lastIndex.clamp(0, list.length - 1);
      _currentId = list[idx].tripId;
    }
    _lastIndex = idx;

    final PendingTripRequest req = list[idx];
    final String fareAmount = req.fareAmount.isEmpty ? '۰' : req.fareAmount;
    final String currencyUnit = 'currency_unit'.tr();

    final bool hasBid = req.bidAmount != 'null' &&
        req.bidAmount.trim().isNotEmpty;

    final String km = _t('unit_km', 'کیلومتر');
    final double? tripKm = _tripKm(req);
    final bool isRtl = Directionality.of(context) == TextDirection.rtl;

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
              child: GestureDetector(
                behavior: HitTestBehavior.translucent,
                // کشیدن افقی = جابه‌جایی بین درخواست‌ها
                onHorizontalDragEnd: (DragEndDetails d) {
                  final double v = d.primaryVelocity ?? 0;
                  if (v.abs() < 300) return;
                  final bool toNext = isRtl ? v > 0 : v < 0;
                  _go(toNext ? 1 : -1);
                },
                child: SingleChildScrollView(
                  padding: const EdgeInsets.fromLTRB(16, 10, 16, 16),
                  child: Column(
                    mainAxisSize: MainAxisSize.min,
                    children: <Widget>[
                      Container(
                        width: 42,
                        height: 5,
                        margin: const EdgeInsets.only(bottom: 12),
                        decoration: BoxDecoration(
                          color: AppColors.handle,
                          borderRadius: BorderRadius.circular(99),
                        ),
                      ),
                      _buildPager(idx, list.length, isRtl),
                      const SizedBox(height: 8),
                      AnimatedSwitcher(
                        duration: const Duration(milliseconds: 180),
                        child: KeyedSubtree(
                          key: ValueKey<String>(req.tripId),
                          child: Column(
                            mainAxisSize: MainAxisSize.min,
                            children: <Widget>[
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
                                  '${req.bidAmount} $currencyUnit',
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
                                  if (req.pickupKm != null)
                                    _chip(
                                      Icons.near_me_rounded,
                                      '${_t('request_to_pickup', 'تا مبدأ')} '
                                      '${req.pickupKm!.toStringAsFixed(1)} $km',
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
                              _buildLocations(req),
                              _buildExtras(req),
                            ],
                          ),
                        ),
                      ),
                      const SizedBox(height: 16),
                      _buildActionButtons(req),
                    ],
                  ),
                ),
              ),
            ),
          ),
        ),
      ),
    );
  }

  /// بالای پنجره: عنوان یا (وقتی چند درخواست هست) فلش‌ها و شمارنده.
  Widget _buildPager(int index, int total, bool isRtl) {
    final bool counter = total > 1 || widget.manual;
    final String counterText = widget.manual
        ? _t('request_waiting_counter', 'در انتظار {n} از {total}')
        : _t('request_counter', 'درخواست {n} از {total}');

    final Widget title = Text(
      counter
          ? counterText
              .replaceAll('{n}', '${index + 1}')
              .replaceAll('{total}', '$total')
          : 'title_new_trip_request'.tr(),
      textAlign: TextAlign.center,
      style: TextStyle(
        fontWeight: FontWeight.bold,
        fontSize: 14,
        color: AppColors.textSecondary,
      ),
    );

    if (total <= 1) return title;

    final bool hasPrev = index > 0;
    final bool hasNext = index < total - 1;

    return Row(
      children: <Widget>[
        _navButton(
          icon: isRtl
              ? Icons.chevron_right_rounded
              : Icons.chevron_left_rounded,
          enabled: hasPrev,
          onTap: () => _go(-1),
        ),
        Expanded(child: title),
        _navButton(
          icon: isRtl
              ? Icons.chevron_left_rounded
              : Icons.chevron_right_rounded,
          enabled: hasNext,
          onTap: () => _go(1),
        ),
      ],
    );
  }

  Widget _navButton({
    required IconData icon,
    required bool enabled,
    required VoidCallback onTap,
  }) {
    return Opacity(
      opacity: enabled ? 1 : 0.3,
      child: Material(
        color: AppColors.neutralSoft,
        shape: const CircleBorder(),
        clipBehavior: Clip.antiAlias,
        child: InkWell(
          onTap: enabled && !_isAcceptingTrip ? onTap : null,
          child: SizedBox(
            width: 40,
            height: 40,
            child: Icon(icon, size: 26, color: AppColors.textPrimary),
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

  Widget _buildExtras(PendingTripRequest req) {
    final TripExtras extras = TripExtras.fromRide(req.rideData);

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

  Widget _buildLocations(PendingTripRequest req) {
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
            req.details.pickupAddress ?? 'unknown_address'.tr(),
          ),
          const SizedBox(height: 14),
          row(
            Icons.location_on_rounded,
            AppColors.danger,
            'label_dropoff_location'.tr(),
            req.details.dropOffAddress ?? 'unknown_address'.tr(),
          ),
        ],
      ),
    );
  }

  // دکمهٔ قبول: نوار آن با گذشت زمان خالی می‌شود و عدد ثانیه‌ها کنارش است.
  Widget _buildActionButtons(PendingTripRequest req) {
    return Row(
      children: <Widget>[
        SizedBox(
          width: 58,
          height: 58,
          child: OutlinedButton(
            onPressed: _isAcceptingTrip ? null : () => _decline(req),
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
            child: Builder(
              builder: (BuildContext context) {
                final bool fresh = req.isFresh;
                final double left = fresh
                    ? (req.remaining.inMilliseconds /
                            (kTripRequestSeconds * 1000))
                        .clamp(0.0, 1.0)
                    : 1.0;
                final int seconds = (left * kTripRequestSeconds).ceil();

                return Material(
                  color: AppColors.primaryButton.withOpacity(0.35),
                  borderRadius: BorderRadius.circular(18),
                  clipBehavior: Clip.antiAlias,
                  child: InkWell(
                    onTap: _isAcceptingTrip
                        ? null
                        : () => _accept(req),
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
                                    if (fresh) const SizedBox(width: 10),
                                    if (fresh)
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
