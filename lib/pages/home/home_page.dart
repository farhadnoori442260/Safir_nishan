import 'dart:async';
import 'dart:math';
import 'package:flutter/services.dart';

import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:easy_localization/easy_localization.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:flutter/material.dart';
import 'package:geolocator/geolocator.dart';
import 'package:maplibre_gl/maplibre_gl.dart';
import 'package:provider/provider.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:url_launcher/url_launcher.dart';

import 'package:safir_drivers/constants/trip_status.dart';
import 'package:safir_drivers/controllers/navigation_controller.dart';
import 'package:safir_drivers/pages/chat_page.dart';
import 'package:safir_drivers/providers/registration_provider.dart';
import 'package:safir_drivers/services/app_config_service.dart';
import 'package:safir_drivers/utils/app_colors.dart';
import '../../push_notifications/push_notification_system.dart';
import 'active_trip_sheet.dart';

class HomePage extends StatefulWidget {
  const HomePage({super.key});

  @override
  State<HomePage> createState() => _HomePageState();
}

class _HomePageState extends State<HomePage> with TickerProviderStateMixin {
  MapLibreMapController? mapController;
  Symbol? _driverNavigationSymbol;
  bool _isDriverArrowImageAdded = false;
  bool _isMapStyleReady = false;
  bool _isNavArrowVisible = false;
  Position? currentPositionOfDriver;

  // ───────── حرکت آیکن روی مسیر ─────────
  late AnimationController _arrowAnimationController;
  List<LatLng> _navRoutePoints = <LatLng>[];
  int _lastSyncedRouteVersion = -1;
  int _navProgressIndex = 0;
  int _navLastRenderedSegment = -1;
  LatLng? _navLastRenderedPoint;
  Line? _navRemainingLine; // خط سبز (باقی‌ماندهٔ مسیر)
  Line? _navTraveledLine; // خط خاکستری (طی‌شده)

  Position? _pendingNavPosition;
  bool _isProcessingNavUpdate = false;

  LatLng? _arrowAnimStart;
  LatLng? _arrowAnimEnd;
  LatLng? _arrowDisplayLatLng;
  LatLng? _arrowLastTarget;
  double _arrowAnimStartBearing = 0.0;
  double _arrowAnimEndBearing = 0.0;
  double _arrowDisplayBearing = 0.0;
  DateTime? _lastArrowUpdateAt;

  // کنترل فریم‌های انیمیشن تا درخواست‌ها روی هم انباشته نشوند
  bool _isArrowFrameInFlight = false;
  int _lastArrowFrameMs = 0;
  static const int _arrowFrameGapMs = 33; // حدود ۳۰ فریم بر ثانیه

  static const double _offRouteThresholdMeters = 25.0;

  // نوشتن لوکیشن در Firestore حداکثر هر ۲ ثانیه (با ارسال آخرین مقدار)
  static const Duration _locationWriteInterval = Duration(seconds: 2);
  DateTime? _lastLocationWriteAt;
  Timer? _locationWriteTimer;
  Position? _queuedLocation;

  bool isDriverAvailable = false;
  bool isLoading = false;

  String? activeTripId;
  String? activeTripStatus;

  DateTime? driverOnlineTimestamp;

  bool _isTripActionLoading = false;
  bool _isStartingRoute = false;
  bool _isDisposing = false;

  // جلوگیری از پایان کاذب سفر
  bool _isLocalTripEnding = false;
  bool _isHandlingRemoteEnd = false;

  StreamSubscription<Position>? positionStreamHomePage;
  StreamSubscription<QuerySnapshot<Map<String, dynamic>>>? tripRequestStream;

  // ✅ استریم سفر فعال یک بار ساخته می‌شود (نه داخل build)
  Stream<QuerySnapshot<Map<String, dynamic>>>? _activeTripStream;

  final FirebaseFirestore _firestore = FirebaseFirestore.instance;

  @override
  void initState() {
    super.initState();
    AppConfigService.instance.start();
    _arrowAnimationController = AnimationController(
      vsync: this,
      duration: const Duration(milliseconds: 1000),
    )..addListener(_animateNavArrow);
    _loadDriverStatus();
    initializePushNotificationSystem();

    WidgetsBinding.instance.addPostFrameCallback((_) async {
      if (!mounted) return;

      await Provider.of<RegistrationProvider>(
        context,
        listen: false,
      ).retrieveCurrentDriverInfo();

      await getCurrentLiveLocationOfDriver();
    });
  }

  @override
  void dispose() {
    _isDisposing = true;
    positionStreamHomePage?.cancel();
    tripRequestStream?.cancel();
    _locationWriteTimer?.cancel();
    _arrowAnimationController.dispose();
    super.dispose();
  }

  void _onMapCreated(MapLibreMapController controller) {
    mapController = controller;
  }

  // ════════════════════════════════════════════════════════════
  //  تبدیل مبلغ (پشتیبانی از ارقام فارسی/عربی و جداکنندهٔ هزارگان)
  // ════════════════════════════════════════════════════════════

  double _parseMoney(dynamic raw) {
    if (raw == null) return 0.0;
    if (raw is num) return raw.toDouble();

    String s = raw.toString();
    const String fa = '۰۱۲۳۴۵۶۷۸۹';
    const String ar = '٠١٢٣٤٥٦٧٨٩';

    for (int i = 0; i < 10; i++) {
      s = s.replaceAll(fa[i], '$i').replaceAll(ar[i], '$i');
    }

    // حذف جداکننده‌های هزارگان و هر کاراکتر غیرعددی
    s = s
        .replaceAll(RegExp(r'[,،٬\.٫\s]'), '')
        .replaceAll(RegExp(r'[^\d]'), '');

    return double.tryParse(s) ?? 0.0;
  }

  // ════════════════════════════════════════════════════════════
  //  استریم سفر فعال
  // ════════════════════════════════════════════════════════════

  void _ensureActiveTripStream() {
    if (_activeTripStream != null) return;

    final String? uid = FirebaseAuth.instance.currentUser?.uid;
    if (uid == null) return;

    _activeTripStream = _firestore
        .collection('rides')
        .where('driver_id', isEqualTo: uid)
        .where(
          'status',
          whereIn: [
            TripStatus.accepted,
            TripStatus.arrived,
            TripStatus.onTrip,
          ],
        )
        .snapshots();

    if (mounted) setState(() {});
  }

  // ════════════════════════════════════════════════════════════
  //  نقشه و دوربین
  // ════════════════════════════════════════════════════════════

  Future<void> _centerMapOnDriver() async {
    if (mapController == null) return;

    final Position? livePosition = await getCurrentLiveLocationOfDriver();
    if (livePosition == null || mapController == null) return;

    LatLng target = LatLng(livePosition.latitude, livePosition.longitude);

    if (mounted) {
      final NavigationController navController =
          context.read<NavigationController>();

      if (navController.isNavigating && _arrowLastTarget != null) {
        target = _arrowLastTarget!;
      }
    }

    await mapController!.animateCamera(
      CameraUpdate.newCameraPosition(
        CameraPosition(
          target: target,
          zoom: 17,
          bearing: 0,
          tilt: 0,
        ),
      ),
    );
  }

  /// منتظر می‌ماند تا استایل نقشه کامل لود شود (حداکثر ۱۰ ثانیه)
  Future<bool> _waitForMapReady() async {
    for (int i = 0; i < 50; i++) {
      if (_isMapStyleReady && mapController != null) return true;
      if (!mounted) return false;
      await Future.delayed(const Duration(milliseconds: 200));
    }
    return _isMapStyleReady && mapController != null;
  }

  bool _isTripOwnedByCurrentDriver(Map<String, dynamic> tripData) {
    final String? currentDriverId = FirebaseAuth.instance.currentUser?.uid;
    if (currentDriverId == null) return false;

    final String tripDriverId = tripData['driver_id']?.toString() ??
        tripData['driverId']?.toString() ??
        '';

    return tripDriverId == currentDriverId;
  }

  // ════════════════════════════════════════════════════════════
  //  استخراج مختصات
  // ════════════════════════════════════════════════════════════

  double? _toDouble(dynamic value) {
    if (value == null) return null;
    if (value is num) return value.toDouble();
    return double.tryParse(value.toString().trim());
  }

  bool _isValidLatLng(double? lat, double? lng) {
    if (lat == null || lng == null) return false;
    if (lat < -90 || lat > 90 || lng < -180 || lng > 180) return false;
    if (lat == 0 && lng == 0) return false;
    return true;
  }

  LatLng? _extractLatLng(
    Map<String, dynamic> data,
    List<String> keys, {
    List<String> latKeys = const <String>[],
    List<String> lngKeys = const <String>[],
  }) {
    for (final String key in keys) {
      final dynamic value = data[key];

      if (value is GeoPoint) {
        if (_isValidLatLng(value.latitude, value.longitude)) {
          return LatLng(value.latitude, value.longitude);
        }
      }

      if (value is Map) {
        final double? lat = _toDouble(value['latitude'] ?? value['lat']);
        final double? lng =
            _toDouble(value['longitude'] ?? value['lng'] ?? value['lon']);

        if (_isValidLatLng(lat, lng)) {
          return LatLng(lat!, lng!);
        }
      }
    }

    final int count = min(latKeys.length, lngKeys.length);
    for (int i = 0; i < count; i++) {
      final double? lat = _toDouble(data[latKeys[i]]);
      final double? lng = _toDouble(data[lngKeys[i]]);

      if (_isValidLatLng(lat, lng)) {
        return LatLng(lat!, lng!);
      }
    }

    return null;
  }

  LatLng? _pickupLatLng(Map<String, dynamic> tripData) {
    return _extractLatLng(
      tripData,
      const <String>[
        'originLatLng',
        'pickup_location',
        'pickupLatLng',
        'origin',
        'pickup',
        'origin_location',
        'from_location',
        'from',
      ],
      latKeys: const <String>[
        'from_lat',
        'pickup_lat',
        'origin_lat',
        'originLat',
        'pickupLat',
      ],
      lngKeys: const <String>[
        'from_lng',
        'pickup_lng',
        'origin_lng',
        'originLng',
        'pickupLng',
      ],
    );
  }

  LatLng? _destinationLatLng(Map<String, dynamic> tripData) {
    return _extractLatLng(
      tripData,
      const <String>[
        'destinationLatLng',
        'dropoff_location',
        'dropoffLatLng',
        'destination',
        'dropoff',
        'destination_location',
        'to_location',
        'to',
      ],
      latKeys: const <String>[
        'to_lat',
        'dropoff_lat',
        'destination_lat',
        'destinationLat',
        'dropoffLat',
      ],
      lngKeys: const <String>[
        'to_lng',
        'dropoff_lng',
        'destination_lng',
        'destinationLng',
        'dropoffLng',
      ],
    );
  }

  Future<void> _prepareDriverNavigationArrow() async {
    if (mapController == null) return;

    try {
      final ByteData imageData = await rootBundle.load(
        'assets/images/driver_navigation_arrow.png',
      );

      await mapController!.addImage(
        'driver_navigation_arrow',
        imageData.buffer.asUint8List(),
      );

      _isDriverArrowImageAdded = true;
    } catch (e) {
      if (e.toString().contains('already exists') ||
          e.toString().contains('mIsSubscribed')) {
        _isDriverArrowImageAdded = true;
      } else {
        debugPrint('Error preparing driver navigation arrow: $e');
      }
    }
  }

  // ════════════════════════════════════════════════════════════
  //  🧭 حرکت آیکن راننده روی مسیر
  // ════════════════════════════════════════════════════════════

  Future<void> _animateNavArrow() async {
    if (!mounted ||
        mapController == null ||
        _driverNavigationSymbol == null ||
        _arrowAnimStart == null ||
        _arrowAnimEnd == null) {
      return;
    }

    final double t = _arrowAnimationController.value;

    final int nowMs = DateTime.now().millisecondsSinceEpoch;
    if (_isArrowFrameInFlight) return;
    if (t < 1.0 && nowMs - _lastArrowFrameMs < _arrowFrameGapMs) return;

    _lastArrowFrameMs = nowMs;

    final double latitude = _arrowAnimStart!.latitude +
        (_arrowAnimEnd!.latitude - _arrowAnimStart!.latitude) * t;
    final double longitude = _arrowAnimStart!.longitude +
        (_arrowAnimEnd!.longitude - _arrowAnimStart!.longitude) * t;

    double diff = _arrowAnimEndBearing - _arrowAnimStartBearing;
    if (diff.abs() > 180) diff -= 360 * diff.sign;
    final double bearing = (_arrowAnimStartBearing + diff * t + 360) % 360;

    _arrowDisplayLatLng = LatLng(latitude, longitude);
    _arrowDisplayBearing = bearing;

    _isArrowFrameInFlight = true;
    try {
      await mapController!.updateSymbol(
        _driverNavigationSymbol!,
        SymbolOptions(
          geometry: LatLng(latitude, longitude),
          iconRotate: bearing,
          iconAnchor: 'center',
        ),
      );
    } catch (e) {
      debugPrint('Nav arrow animation error: $e');
      // اگر Symbol از دست رفته باشد، در آپدیت بعدی از نو ساخته می‌شود
      _driverNavigationSymbol = null;
    } finally {
      _isArrowFrameInFlight = false;
    }
  }

  Future<void> _processPendingNavPosition() async {
    if (_isProcessingNavUpdate) return;
    _isProcessingNavUpdate = true;

    try {
      while (_pendingNavPosition != null && mounted) {
        final Position p = _pendingNavPosition!;
        _pendingNavPosition = null;

        await _updateNavArrow(LatLng(p.latitude, p.longitude), p.heading);
      }
    } finally {
      _isProcessingNavUpdate = false;
    }
  }

  Future<void> _updateNavArrow(LatLng rawPosition, double rawHeading) async {
    if (mapController == null || !_isMapStyleReady || !mounted) return;

    final NavigationController navController =
        context.read<NavigationController>();

    if (navController.routeVersion != _lastSyncedRouteVersion &&
        navController.routePoints.length >= 2) {
      _lastSyncedRouteVersion = navController.routeVersion;
      _navRoutePoints = List<LatLng>.of(navController.routePoints);
      _navProgressIndex = 0;
      _navLastRenderedSegment = -1;
      _navLastRenderedPoint = null;

      await _renderNavLines(
        traveled: <LatLng>[],
        remaining: _navRoutePoints,
      );
    }

    final List<LatLng> route = _navRoutePoints;

    LatLng target = rawPosition;
    _NavSnap? onRouteSnap;

    if (route.length >= 2) {
      final _NavSnap? snap = _snapToNavRoute(
        rawPosition,
        route,
        startIndex: _navProgressIndex,
      );

      if (snap != null && snap.distance <= _offRouteThresholdMeters) {
        onRouteSnap = snap;
        target = snap.point;
        _navProgressIndex = max(_navProgressIndex, snap.segmentIndex);
      }
    }

    if (!_isDriverArrowImageAdded) {
      await _prepareDriverNavigationArrow();
    }

    if (mapController != null && _isDriverArrowImageAdded) {
      try {
        final LatLng? previousTarget = _arrowLastTarget;

        // ───── زاویه ─────
        double bearing = _arrowAnimEndBearing;

        if (_driverNavigationSymbol == null) {
          if (onRouteSnap != null &&
              route.length > onRouteSnap.segmentIndex + 1) {
            bearing = _calculateBearing(
              route[onRouteSnap.segmentIndex],
              route[onRouteSnap.segmentIndex + 1],
            );
          } else if (rawHeading >= 0) {
            bearing = rawHeading;
          }
        } else if (previousTarget != null &&
            Geolocator.distanceBetween(
                  previousTarget.latitude,
                  previousTarget.longitude,
                  target.latitude,
                  target.longitude,
                ) >
                3) {
          bearing = _calculateBearing(previousTarget, target);
        }

        final DateTime now = DateTime.now();
        final int dtMs = _lastArrowUpdateAt == null
            ? 1000
            : now.difference(_lastArrowUpdateAt!).inMilliseconds;
        _lastArrowUpdateAt = now;

        if (_driverNavigationSymbol == null) {
          _arrowAnimationController.stop();

          _driverNavigationSymbol = await mapController!.addSymbol(
            SymbolOptions(
              geometry: target,
              iconImage: 'driver_navigation_arrow',
              iconSize: 0.55,
              iconRotate: bearing,
              iconAnchor: 'center',
            ),
          );

          _arrowLastTarget = target;
          _arrowDisplayLatLng = target;
          _arrowDisplayBearing = bearing;
          _arrowAnimStartBearing = bearing;
          _arrowAnimEndBearing = bearing;
          _arrowAnimStart = target;
          _arrowAnimEnd = target;

          if (mounted && !_isNavArrowVisible) {
            setState(() {
              _isNavArrowVisible = true;
            });
          }
        } else {
          _arrowAnimStart = _arrowDisplayLatLng ?? previousTarget ?? target;
          _arrowAnimEnd = target;
          _arrowAnimStartBearing = _arrowDisplayBearing;
          _arrowAnimEndBearing = bearing;

          _arrowAnimationController.stop();
          _arrowAnimationController.duration = Duration(
            milliseconds: dtMs.clamp(400, 2500).toInt(),
          );
          _arrowAnimationController.forward(from: 0.0);

          _arrowLastTarget = target;
        }
      } catch (e) {
        debugPrint('Error updating driver navigation arrow: $e');
        _driverNavigationSymbol = null;
      }
    }

    if (onRouteSnap != null) {
      await _renderNavProgress(onRouteSnap, route);
    }
  }

  Future<void> _renderNavProgress(_NavSnap snap, List<LatLng> route) async {
    if (mapController == null) return;
    if (!identical(route, _navRoutePoints)) return;
    if (snap.segmentIndex + 1 >= route.length) return;

    final LatLng? lastPoint = _navLastRenderedPoint;
    if (snap.segmentIndex == _navLastRenderedSegment &&
        lastPoint != null &&
        Geolocator.distanceBetween(
              lastPoint.latitude,
              lastPoint.longitude,
              snap.point.latitude,
              snap.point.longitude,
            ) <
            3) {
      return;
    }

    _navLastRenderedSegment = snap.segmentIndex;
    _navLastRenderedPoint = snap.point;

    final List<LatLng> traveled = <LatLng>[
      for (int i = 0; i <= snap.segmentIndex; i++) route[i],
      snap.point,
    ];
    final List<LatLng> remaining = <LatLng>[
      snap.point,
      for (int i = snap.segmentIndex + 1; i < route.length; i++) route[i],
    ];

    await _renderNavLines(traveled: traveled, remaining: remaining);
  }

  Future<void> _renderNavLines({
    required List<LatLng> traveled,
    required List<LatLng> remaining,
  }) async {
    if (mapController == null || remaining.isEmpty) return;

    final List<LatLng> grey = traveled.length >= 2
        ? traveled
        : <LatLng>[remaining.first, remaining.first];

    try {
      if (_navRemainingLine != null && _navTraveledLine != null) {
        await mapController!.updateLine(
          _navTraveledLine!,
          LineOptions(geometry: grey),
        );
        await mapController!.updateLine(
          _navRemainingLine!,
          LineOptions(geometry: remaining),
        );
        return;
      }
    } catch (_) {
      _navRemainingLine = null;
      _navTraveledLine = null;
    }

    try {
      await mapController!.clearLines();

      _navTraveledLine = await mapController!.addLine(
        LineOptions(
          geometry: grey,
          lineColor: '#B0B7C3',
          lineWidth: 6.0,
          lineJoin: 'round',
        ),
      );

      _navRemainingLine = await mapController!.addLine(
        LineOptions(
          geometry: remaining,
          lineColor: '#0F7D55',
          lineWidth: 6.0,
          lineOpacity: 0.85,
          lineJoin: 'round',
        ),
      );
    } catch (e) {
      debugPrint('Error rendering navigation lines: $e');
      _navRemainingLine = null;
      _navTraveledLine = null;
    }
  }

  _NavSnap? _snapToNavRoute(
    LatLng gpsPoint,
    List<LatLng> polyline, {
    int startIndex = 0,
    double maxAheadMeters = 150,
  }) {
    if (polyline.length < 2) return null;

    final int from = max(0, min(startIndex - 1, polyline.length - 2));

    double minDistance = double.infinity;
    LatLng closestPoint = polyline[from];
    int bestIndex = from;
    double travelled = 0;

    for (int i = from; i < polyline.length - 1; i++) {
      final LatLng a = polyline[i];
      final LatLng b = polyline[i + 1];

      final LatLng projected = _getClosestPointOnSegment(gpsPoint, a, b);

      final double distance = Geolocator.distanceBetween(
        gpsPoint.latitude,
        gpsPoint.longitude,
        projected.latitude,
        projected.longitude,
      );

      if (distance < minDistance) {
        minDistance = distance;
        closestPoint = projected;
        bestIndex = i;
      }

      travelled += Geolocator.distanceBetween(
        a.latitude,
        a.longitude,
        b.latitude,
        b.longitude,
      );
      if (travelled > maxAheadMeters) break;
    }

    return _NavSnap(closestPoint, minDistance, bestIndex);
  }

  LatLng _getClosestPointOnSegment(LatLng p, LatLng a, LatLng b) {
    final double x = p.longitude, y = p.latitude;
    final double x1 = a.longitude, y1 = a.latitude;
    final double x2 = b.longitude, y2 = b.latitude;

    final double dx = x2 - x1;
    final double dy = y2 - y1;

    if (dx == 0 && dy == 0) return a;

    double t = ((x - x1) * dx + (y - y1) * dy) / (dx * dx + dy * dy);
    t = t.clamp(0.0, 1.0).toDouble();

    return LatLng(y1 + t * dy, x1 + t * dx);
  }

  double _calculateBearing(LatLng start, LatLng end) {
    final double startLatRad = start.latitude * pi / 180;
    final double startLngRad = start.longitude * pi / 180;
    final double endLatRad = end.latitude * pi / 180;
    final double endLngRad = end.longitude * pi / 180;

    final double dLng = endLngRad - startLngRad;

    final double y = sin(dLng) * cos(endLatRad);
    final double x = cos(startLatRad) * sin(endLatRad) -
        sin(startLatRad) * cos(endLatRad) * cos(dLng);

    return (atan2(y, x) * 180 / pi + 360) % 360;
  }

  // ════════════════════════════════════════════════════════════
  //  ارسال لوکیشن به Firestore
  // ════════════════════════════════════════════════════════════

  void _queueDriverLocationWrite(Position position) {
    final DateTime now = DateTime.now();
    final DateTime? last = _lastLocationWriteAt;

    if (last == null || now.difference(last) >= _locationWriteInterval) {
      _lastLocationWriteAt = now;
      _queuedLocation = null;
      unawaited(_updateDriverLiveLocation(position));
      return;
    }

    _queuedLocation = position;

    _locationWriteTimer ??= Timer(
      _locationWriteInterval - now.difference(last),
      () {
        _locationWriteTimer = null;
        final Position? queued = _queuedLocation;
        _queuedLocation = null;

        if (queued != null && mounted && isDriverAvailable) {
          _lastLocationWriteAt = DateTime.now();
          unawaited(_updateDriverLiveLocation(queued));
        }
      },
    );
  }

  bool _hasWarnedBackgroundLocation = false;

  Future<void> _promptEnableBackgroundLocation() async {
    if (!mounted) return;

    final SharedPreferences prefs = await SharedPreferences.getInstance();
    final bool hasPromptedBefore =
        prefs.getBool('has_prompted_bg_location') ?? false;

    if (hasPromptedBefore) return;

    await prefs.setBool('has_prompted_bg_location', true);

    if (!mounted) return;

    ScaffoldMessenger.of(context).hideCurrentSnackBar();
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(
        duration: const Duration(seconds: 8),
        content: Text('bg_location_prompt_msg'.tr()), // 🌐 اصلاح‌شده با کلید ترجمه
        action: SnackBarAction(
          label: 'settings_label'.tr(), // 🌐 اصلاح‌شده با کلید ترجمه
          onPressed: () {
            unawaited(Geolocator.openAppSettings());
          },
        ),
      ),
    );
  }

  Future<void> _showMessage(String message) async {
    if (!mounted) return;

    ScaffoldMessenger.of(context).hideCurrentSnackBar();
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(content: Text(message)),
    );
  }

  Future<Position?> getCurrentLiveLocationOfDriver() async {
    try {
      final bool serviceEnabled = await Geolocator.isLocationServiceEnabled();

      if (!serviceEnabled) {
        await _showMessage('gps_disabled_msg'.tr()); // 🌐 اصلاح‌شده با کلید ترجمه
        return null;
      }

      LocationPermission permission = await Geolocator.checkPermission();

      if (permission == LocationPermission.denied) {
        permission = await Geolocator.requestPermission();
      }

      if (permission == LocationPermission.denied ||
          permission == LocationPermission.deniedForever) {
        await _showMessage('location_permission_denied_msg'.tr()); // 🌐 اصلاح‌شده با کلید ترجمه
        return null;
      }

      if (permission == LocationPermission.whileInUse &&
          !_hasWarnedBackgroundLocation) {
        _hasWarnedBackgroundLocation = true;
        unawaited(_promptEnableBackgroundLocation());
      }

      final Position position = await Geolocator.getCurrentPosition(
        desiredAccuracy: LocationAccuracy.bestForNavigation,
        timeLimit: const Duration(seconds: 10),
      );

      currentPositionOfDriver = position;

      return position;
    } catch (e) {
      debugPrint('Error fetching driver location: $e');
      await _showMessage('location_fetch_error_msg'.tr()); // 🌐 اصلاح‌شده با کلید ترجمه
      return null;
    }
  }

  Future<void> _loadDriverStatus() async {
    try {
      final SharedPreferences prefs = await SharedPreferences.getInstance();
      final bool savedStatus = prefs.getBool('isDriverAvailable') ?? false;

      if (!mounted) return;

      setState(() {
        isDriverAvailable = savedStatus;
      });

      if (savedStatus) {
        _ensureActiveTripStream();
        listenForTripRequests();
        setAndGetLocationUpdates();
        try {
          await goOnlineNow();
        } catch (e) {
          debugPrint('goOnlineNow failed: $e');
        }
      }
    } catch (e) {
      debugPrint('Error loading driver status: $e');
    }
  }

  Future<void> _saveDriverStatus(bool status) async {
    final SharedPreferences prefs = await SharedPreferences.getInstance();
    await prefs.setBool('isDriverAvailable', status);
  }

  Future<void> _setDriverStatus({
    required String status,
    required bool isOnline,
  }) async {
    final User? user = FirebaseAuth.instance.currentUser;
    if (user == null) return;

    await _firestore.collection('drivers').doc(user.uid).set(
      {
        'newTripStatus': status,
        'isOnline': isOnline,
        'updated_at': FieldValue.serverTimestamp(),
      },
      SetOptions(merge: true),
    );
  }

  Future<void> _updateDriverLiveLocation(Position position) async {
    final User? user = FirebaseAuth.instance.currentUser;
    if (user == null || !isDriverAvailable) return;

    try {
      await _firestore.collection('driver_locations').doc(user.uid).set(
        {
          'driver_id': user.uid,
          'latitude': position.latitude,
          'longitude': position.longitude,
          'heading': position.heading,
          'is_online': true,
          'active_trip_id': activeTripId,
          'updated_at': FieldValue.serverTimestamp(),
        },
        SetOptions(merge: true),
      );
    } catch (e) {
      debugPrint('Error updating driver live location: $e');
    }
  }

  Future<void> goOnlineNow() async {
    final User? user = FirebaseAuth.instance.currentUser;
    if (user == null) return;

    _ensureActiveTripStream();

    driverOnlineTimestamp = DateTime.now();
    currentPositionOfDriver ??= await getCurrentLiveLocationOfDriver();

    if (currentPositionOfDriver != null) {
      await _updateDriverLiveLocation(currentPositionOfDriver!);
    }

    await _setDriverStatus(status: 'waiting', isOnline: true);
  }

  Future<void> goOfflineNow() async {
    if (activeTripId != null) {
      await _showMessage('cannot_offline_active_trip_msg'.tr()); // 🌐 اصلاح‌شده با کلید ترجمه
      return;
    }

    await positionStreamHomePage?.cancel();
    positionStreamHomePage = null;

    await tripRequestStream?.cancel();
    tripRequestStream = null;

    _activeTripStream = null;

    _locationWriteTimer?.cancel();
    _locationWriteTimer = null;
    _queuedLocation = null;

    final User? user = FirebaseAuth.instance.currentUser;
    if (user == null) return;

    try {
      await _firestore.collection('driver_locations').doc(user.uid).set(
        {
          'is_online': false,
          'updated_at': FieldValue.serverTimestamp(),
        },
        SetOptions(merge: true),
      );
    } catch (e) {
      debugPrint('Error setting driver offline location: $e');
    }

    try {
      await _setDriverStatus(status: 'offline', isOnline: false);
    } catch (e) {
      debugPrint('Error setting driver offline: $e');
    }
  }

  void setAndGetLocationUpdates() {
    positionStreamHomePage?.cancel();

    positionStreamHomePage = Geolocator.getPositionStream(
      locationSettings: AndroidSettings(
        accuracy: LocationAccuracy.bestForNavigation,
        distanceFilter: 1,
        intervalDuration: const Duration(seconds: 1),
        foregroundNotificationConfig: ForegroundNotificationConfig(
          notificationTitle: 'notif_active_trip_title'.tr(), // 🌐 اصلاح‌شده با کلید ترجمه
          notificationText: 'notif_active_trip_text'.tr(), // 🌐 اصلاح‌شده با کلید ترجمه
          enableWakeLock: true,
          notificationIcon: const AndroidResource(
            name: 'ic_launcher',
            defType: 'mipmap',
          ),
        ),
      ),
    ).listen(
      (Position position) {
        if (_isDisposing) return;

        currentPositionOfDriver = position;

        if (!mounted) return;

        _queueDriverLocationWrite(position);

        final NavigationController navController =
            context.read<NavigationController>();

        if (navController.isNavigating) {
          navController.updateDriverPosition(
            LatLng(position.latitude, position.longitude),
            langCode: context.locale.languageCode,
          );
        }

        if (_navRoutePoints.length >= 2 || navController.isNavigating) {
          _pendingNavPosition = position;
          unawaited(_processPendingNavPosition());
        }
      },
      onError: (Object error) {
        debugPrint('Location stream error: $error');
      },
    );
  }

  void listenForTripRequests() {
    tripRequestStream?.cancel();
    debugPrint('RIDES: listener started');

    tripRequestStream = _firestore
        .collection('rides')
        .where('status', isEqualTo: TripStatus.searching)
        .snapshots()
        .listen(
      (QuerySnapshot<Map<String, dynamic>> snapshot) {
        debugPrint('RIDES: docs=${snapshot.docs.length} '
            'changes=${snapshot.docChanges.length} '
            'online=$isDriverAvailable activeTripId=$activeTripId');

        if (!mounted || !isDriverAvailable || activeTripId != null) return;

        for (final DocumentChange<Map<String, dynamic>> change
            in snapshot.docChanges) {
          if (change.type != DocumentChangeType.added) continue;

          final String tripId = change.doc.id;
          debugPrint('RIDES: new trip $tripId');

          final AppConfig config = AppConfigService.instance.config;

          if (!config.isServiceActive) {
            debugPrint('RIDES: service inactive, skip $tripId');
            continue;
          }

          final Map<String, dynamic>? rideData = change.doc.data();
          final LatLng? pickupPoint =
              rideData == null ? null : _pickupLatLng(rideData);
          final Position? driverPosition = currentPositionOfDriver;

          if (pickupPoint != null && driverPosition != null) {
            final double distanceKm = Geolocator.distanceBetween(
                  driverPosition.latitude,
                  driverPosition.longitude,
                  pickupPoint.latitude,
                  pickupPoint.longitude,
                ) /
                1000;

            if (distanceKm > config.searchRadiusKm) {
              debugPrint(
                'RIDES: $tripId is ${distanceKm.toStringAsFixed(1)} km away '
                '(radius ${config.searchRadiusKm} km), skip',
              );
              continue;
            }
          }

          PushNotificationSystem().retrieveTripRequestInfo(
            tripId,
            context,
          );
        }
      },
      onError: (Object error, StackTrace stackTrace) {
        debugPrint('RIDES ERROR: $error');
        debugPrintStack(stackTrace: stackTrace);
      },
    );
  }

  void initializePushNotificationSystem() {
    final PushNotificationSystem notificationSystem = PushNotificationSystem();

    notificationSystem.generateDeviceRegistrationToken();
    notificationSystem.startListeningForNewNotification(context);
  }

  Future<void> _makePhoneCall(String phoneNumber) async {
    final String number = phoneNumber.trim();

    if (number.isEmpty) {
      await _showMessage('passenger_phone_not_found_msg'.tr()); // 🌐 اصلاح‌شده با کلید ترجمه
      return;
    }

    final Uri phoneUri = Uri(scheme: 'tel', path: number);

    try {
      final bool launched = await launchUrl(phoneUri);

      if (!launched) {
        await _showMessage('phone_launch_error_msg'.tr()); // 🌐 اصلاح‌شده با کلید ترجمه
      }
    } catch (e) {
      debugPrint('Phone launch error: $e');
      await _showMessage('phone_launch_error_msg'.tr()); // 🌐 اصلاح‌شده با کلید ترجمه
    }
  }

  Future<void> _openExternalMap(double lat, double lng) async {
    final Uri mapUri = Uri.parse(
      'https://www.google.com/maps/search/?api=1&query=$lat,$lng',
    );

    try {
      final bool launched = await launchUrl(
        mapUri,
        mode: LaunchMode.externalApplication,
      );

      if (!launched) {
        await _showMessage('map_launch_error_msg'.tr()); // 🌐 اصلاح‌شده با کلید ترجمه
      }
    } catch (e) {
      debugPrint('External map launch error: $e');
      await _showMessage('map_launch_error_msg'.tr()); // 🌐 اصلاح‌شده با کلید ترجمه
    }
  }

  Future<void> _clearRouteAndNavigation() async {
    try {
      if (mounted) {
        context.read<NavigationController>().stopNavigation();
      }

      _arrowAnimationController.stop();
      _pendingNavPosition = null;
      _navRoutePoints = <LatLng>[];
      _lastSyncedRouteVersion = -1;
      _navProgressIndex = 0;
      _navLastRenderedSegment = -1;
      _navLastRenderedPoint = null;
      _navRemainingLine = null;
      _navTraveledLine = null;
      _arrowAnimStart = null;
      _arrowAnimEnd = null;
      _arrowDisplayLatLng = null;
      _arrowLastTarget = null;
      _lastArrowUpdateAt = null;
      _arrowAnimEndBearing = 0.0;
      _arrowDisplayBearing = 0.0;

      if (mapController != null) {
        try {
          await mapController!.clearLines();
        } catch (_) {}

        if (_driverNavigationSymbol != null) {
          try {
            await mapController!.removeSymbol(_driverNavigationSymbol!);
          } catch (_) {}
          _driverNavigationSymbol = null;
        }
      }

      if (mounted && _isNavArrowVisible) {
        setState(() {
          _isNavArrowVisible = false;
        });
      }
    } catch (e) {
      debugPrint('Error clearing route: $e');
    }
  }

  Future<void> _saveDriverDataToTripInfo(String tripId) async {
    final User? currentUser = FirebaseAuth.instance.currentUser;
    if (currentUser == null || tripId.isEmpty) return;

    try {
      final DocumentSnapshot<Map<String, dynamic>> driverDoc =
          await _firestore.collection('drivers').doc(currentUser.uid).get();

      String realDriverName = '';
      String realDriverPhone = '';
      String realDriverPhoto = '';
      String carModelName = '';
      String carColorName = '';
      String rawPlateNumber = '';
      String plateProvince = '';
      String plateCategory = '';
      String plateType = '';

      if (driverDoc.exists && driverDoc.data() != null) {
        final Map<String, dynamic> data = driverDoc.data()!;

        final String firstName = data['firstName']?.toString() ?? '';
        final String secondName = data['secondName']?.toString() ?? '';
        realDriverName = '$firstName $secondName'.trim();
        realDriverPhone = data['phoneNumber']?.toString() ?? '';
        realDriverPhoto = data['profilePicture']?.toString() ?? '';

        final dynamic vehicle = data['vehicleInfo'];
        if (vehicle is Map) {
          carModelName = vehicle['brand']?.toString() ?? '';
          carColorName = vehicle['color']?.toString() ?? '';
          rawPlateNumber = vehicle['registrationPlateNumber']?.toString() ?? '';
          plateProvince = vehicle['plateProvince']?.toString() ?? '';
          plateCategory = vehicle['plateCategory']?.toString() ?? '';
          plateType = vehicle['plateType']?.toString() ?? '';
        }
      }

      final String fullCarPlate =
          (plateProvince.isNotEmpty && rawPlateNumber.isNotEmpty)
              ? '$plateProvince - $plateCategory $rawPlateNumber ($plateType)'
              : rawPlateNumber;

      final Map<String, dynamic> driverDataMap = {
        'driver_id': currentUser.uid,
        'driverId': currentUser.uid,

        'driver_name': realDriverName,
        'driverName': realDriverName,
        'driver_phone': realDriverPhone,
        'driverPhone': realDriverPhone,
        'driver_photo': realDriverPhoto,
        'driverPhoto': realDriverPhoto,

        'car_details': '$carModelName - $carColorName',
        'carDetails': '$carModelName - $carColorName',
        'car_color': carColorName,
        'carColor': carColorName,
        'car_number': fullCarPlate,
        'carNumber': fullCarPlate,

        'plate_province': plateProvince,
        'plate_category': plateCategory,
        'plate_num': rawPlateNumber,
        'plate_farsi_num': rawPlateNumber,
        'is_temp_plate': false,

        'driver_data_updated_at': FieldValue.serverTimestamp(),
      };

      if (currentPositionOfDriver != null) {
        driverDataMap['driverLocation'] = {
          'latitude': currentPositionOfDriver!.latitude,
          'longitude': currentPositionOfDriver!.longitude,
        };
        driverDataMap['driver_lat'] = currentPositionOfDriver!.latitude;
        driverDataMap['driver_lng'] = currentPositionOfDriver!.longitude;
      }

      await _firestore.collection('rides').doc(tripId).set(
            driverDataMap,
            SetOptions(merge: true),
          );
    } catch (e) {
      debugPrint('Error saving driver data into trip: $e');
    }
  }

  // ════════════════════════════════════════════════════════════
  //  مسیریابی
  // ════════════════════════════════════════════════════════════

  Future<void> _startPickupRoute(
    String tripId,
    Map<String, dynamic> tripData,
  ) async {
    if (_isStartingRoute) return;

    _isStartingRoute = true;

    try {
      unawaited(_saveDriverDataToTripInfo(tripId));

      currentPositionOfDriver ??= await getCurrentLiveLocationOfDriver();
      if (currentPositionOfDriver == null) return;

      final LatLng? pickupLatLng = _pickupLatLng(tripData);

      if (pickupLatLng == null) {
        debugPrint('PICKUP: origin not found. keys=${tripData.keys.toList()}');
        await _showMessage('pickup_coords_not_found_msg'.tr()); // 🌐 اصلاح‌شده با کلید ترجمه
        return;
      }

      activeTripId = tripId;
      activeTripStatus = TripStatus.accepted;

      await startTripNavigation(
        LatLng(
          currentPositionOfDriver!.latitude,
          currentPositionOfDriver!.longitude,
        ),
        pickupLatLng,
      );
    } catch (e) {
      debugPrint('Error starting pickup route: $e');
    } finally {
      _isStartingRoute = false;
    }
  }

  Future<void> _startDestinationRoute(
    String tripId,
    Map<String, dynamic> tripData,
  ) async {
    if (_isStartingRoute) return;

    _isStartingRoute = true;

    try {
      currentPositionOfDriver ??= await getCurrentLiveLocationOfDriver();
      if (currentPositionOfDriver == null) return;

      final LatLng? destinationLatLng = _destinationLatLng(tripData);

      if (destinationLatLng == null) {
        debugPrint(
          'DESTINATION: not found. keys=${tripData.keys.toList()}',
        );
        await _showMessage('destination_coords_not_found_msg'.tr()); // 🌐 اصلاح‌شده با کلید ترجمه
        return;
      }

      activeTripId = tripId;
      activeTripStatus = TripStatus.onTrip;

      await startTripNavigation(
        LatLng(
          currentPositionOfDriver!.latitude,
          currentPositionOfDriver!.longitude,
        ),
        destinationLatLng,
      );
    } catch (e) {
      debugPrint('Error starting destination route: $e');
    } finally {
      _isStartingRoute = false;
    }
  }

  Future<void> startTripNavigation(
    LatLng driverPos,
    LatLng destinationPos,
  ) async {
    if (!mounted) return;

    final bool ready = await _waitForMapReady();
    if (!ready || !mounted) {
      debugPrint('Map not ready; navigation skipped.');
      return;
    }

    final NavigationController navController =
        context.read<NavigationController>();

    _navRemainingLine = null;
    _navTraveledLine = null;

    List<LatLng> routePoints = <LatLng>[];
    try {
      routePoints = await navController.startNavigation(
        driverPos,
        destinationPos,
        context.locale.languageCode,
      );
    } catch (e) {
      debugPrint('startNavigation error: $e');
    }

    if (!mounted) return;

    if (routePoints.length < 2) {
      debugPrint('Route empty → using straight-line fallback');
      routePoints = <LatLng>[driverPos, destinationPos];
    }

    _lastSyncedRouteVersion = navController.routeVersion;
    _navRoutePoints = List<LatLng>.of(routePoints);
    _navProgressIndex = 0;
    _navLastRenderedSegment = -1;
    _navLastRenderedPoint = null;

    await _renderNavLines(
      traveled: <LatLng>[],
      remaining: _navRoutePoints,
    );

    if (currentPositionOfDriver != null) {
      _pendingNavPosition = currentPositionOfDriver;
      await _processPendingNavPosition();
    }
  }

  // ════════════════════════════════════════════════════════════
  //  تغییر وضعیت سفر
  // ════════════════════════════════════════════════════════════

  Future<void> _updateTripStatus(
    String tripId,
    String newStatus,
    Map<String, dynamic> tripData,
  ) async {
    if (_isTripActionLoading || tripId.isEmpty) return;

    final User? driver = FirebaseAuth.instance.currentUser;
    if (driver == null) return;

    if (newStatus == TripStatus.completed) {
      _isLocalTripEnding = true;
    }

    if (mounted) {
      setState(() {
        _isTripActionLoading = true;
      });
    }

    try {
      final DocumentReference<Map<String, dynamic>> tripRef =
          _firestore.collection('rides').doc(tripId);

      final DocumentReference<Map<String, dynamic>> driverRef =
          _firestore.collection('drivers').doc(driver.uid);

      double commissionPercentForTrip =
          AppConfigService.instance.config.commissionPercent;

      if (newStatus == TripStatus.completed) {
        final AppConfig latest = await AppConfigService.instance.refresh();
        commissionPercentForTrip = latest.commissionPercent;
      }

      final bool updated = await _firestore.runTransaction<bool>(
        (Transaction transaction) async {
          final DocumentSnapshot<Map<String, dynamic>> snapshot =
              await transaction.get(tripRef);

          if (!snapshot.exists) return false;

          final Map<String, dynamic> data = snapshot.data() ?? {};
          final String currentStatus = data['status']?.toString() ?? '';

          final String assignedDriverId = data['driver_id']?.toString() ??
              data['driverId']?.toString() ??
              '';

          if (assignedDriverId != driver.uid) return false;

          final bool canArrive = currentStatus == TripStatus.accepted &&
              newStatus == TripStatus.arrived;

          final bool canStart = currentStatus == TripStatus.arrived &&
              newStatus == TripStatus.onTrip;

          final bool canComplete = currentStatus == TripStatus.onTrip &&
              newStatus == TripStatus.completed;

          if (!canArrive && !canStart && !canComplete) return false;

          final Map<String, dynamic> updateData = {
            'status': newStatus,
            'updated_at': FieldValue.serverTimestamp(),
          };

          double earnedForDriver = 0.0;

          if (newStatus == TripStatus.arrived) {
            updateData['arrived_at'] = FieldValue.serverTimestamp();
          } else if (newStatus == TripStatus.onTrip) {
            updateData['started_at'] = FieldValue.serverTimestamp();
          } else if (newStatus == TripStatus.completed) {
            final double totalFare = _parseMoney(
              data['final_fare'] ??
                  data['total_fare'] ??
                  data['fare_amount'] ??
                  data['fareAmount'] ??
                  data['fare'] ??
                  data['price'],
            );

            final double commissionPercent = commissionPercentForTrip;

            final double commissionAmount = double.parse(
              (totalFare * commissionPercent / 100).toStringAsFixed(2),
            );

            final double driverEarnings = double.parse(
              (totalFare - commissionAmount).toStringAsFixed(2),
            );
            earnedForDriver = driverEarnings;

            updateData['completed_at'] = FieldValue.serverTimestamp();

            updateData['total_fare'] = totalFare;
            updateData['commission_percent'] = commissionPercent;
            updateData['commission_amount'] = commissionAmount;
            updateData['driver_earnings'] = driverEarnings;

            updateData['payment_method'] = 'cash';
            updateData['commission_status'] = 'unpaid';
          }

          transaction.update(tripRef, updateData);

          if (newStatus == TripStatus.completed && earnedForDriver > 0) {
            transaction.set(
              driverRef,
              {
                'earnings': FieldValue.increment(earnedForDriver),
                'totalEarnings': FieldValue.increment(earnedForDriver),
                'lastEarningTripId': tripId,
                'updatedAt': FieldValue.serverTimestamp(),
              },
              SetOptions(merge: true),
            );
          }

          return true;
        },
      );

      if (!updated) {
        await _showMessage('trip_status_update_failed_msg'.tr()); // 🌐 اصلاح‌شده با کلید ترجمه
        return;
      }

      if (newStatus == TripStatus.arrived) {
        if (mounted) {
          setState(() {
            activeTripId = tripId;
            activeTripStatus = TripStatus.arrived;
          });
        }
        return;
      }

      if (newStatus == TripStatus.onTrip) {
        activeTripStatus = TripStatus.onTrip;
        await _startDestinationRoute(tripId, tripData);
        return;
      }

      if (newStatus == TripStatus.completed) {
        await _clearRouteAndNavigation();
        await _setDriverStatus(status: 'waiting', isOnline: true);

        if (mounted) {
          setState(() {
            activeTripId = null;
            activeTripStatus = null;
          });
        }

        if (mounted) {
          unawaited(
            context.read<RegistrationProvider>().fetchDriverEarnings(),
          );
        }

        await _showMessage('trip_completed_success_msg'.tr()); // 🌐 اصلاح‌شده با کلید ترجمه
      }
    } catch (e, stackTrace) {
      debugPrint('Error updating trip status: $e');
      debugPrintStack(stackTrace: stackTrace);

      await _showMessage('trip_status_error_msg'.tr()); // 🌐 اصلاح‌شده با کلید ترجمه
    } finally {
      _isLocalTripEnding = false;
      if (mounted) {
        setState(() {
          _isTripActionLoading = false;
        });
      }
    }
  }

  Future<void> _cancelTrip(String tripId) async {
    if (_isTripActionLoading || tripId.isEmpty) return;

    final User? driver = FirebaseAuth.instance.currentUser;
    if (driver == null) return;

    final String status = activeTripStatus ?? '';
    final bool cancellable = status == TripStatus.accepted ||
        status == TripStatus.arrived ||
        status == TripStatus.onTrip;

    if (!cancellable) {
      await _showMessage('trip_cancel_not_allowed_msg'.tr()); // 🌐 اصلاح‌شده با کلید ترجمه
      return;
    }

    _isLocalTripEnding = true;

    if (mounted) {
      setState(() {
        _isTripActionLoading = true;
      });
    }

    try {
      final DocumentReference<Map<String, dynamic>> tripRef =
          _firestore.collection('rides').doc(tripId);

      final StreamSubscription<DocumentSnapshot>? oldSubscription =
          tripRequestStream as StreamSubscription<DocumentSnapshot>?;
      unawaited(oldSubscription?.cancel());

      unawaited(
        tripRef.update({
          'status': TripStatus.cancelledByDriver,
          'cancelled_by': 'driver',
          'cancelled_by_driver_id': driver.uid,
          'cancelled_at': FieldValue.serverTimestamp(),
          'updated_at': FieldValue.serverTimestamp(),
        }).catchError((Object e) {
          debugPrint('Cancel trip server error: $e');
          unawaited(
            _showMessage('trip_cancel_server_error_msg'.tr()), // 🌐 اصلاح‌شده با کلید ترجمه
          );
        }),
      );

      await _clearRouteAndNavigation();

      unawaited(
        _setDriverStatus(status: 'waiting', isOnline: true).catchError((Object e) {
          debugPrint('Error resetting driver status after cancel: $e');
        }),
      );

      if (mounted) {
        setState(() {
          activeTripId = null;
          activeTripStatus = null;
        });
      }

      await _showMessage('trip_cancelled_msg'.tr()); // 🌐 اصلاح‌شده با کلید ترجمه
    } catch (e, stackTrace) {
      debugPrint('Error cancelling trip: $e');
      debugPrintStack(stackTrace: stackTrace);

      await _showMessage('trip_cancel_error_msg'.tr()); // 🌐 اصلاح‌شده با کلید ترجمه
    } finally {
      _isLocalTripEnding = false;
      if (mounted) {
        setState(() {
          _isTripActionLoading = false;
        });
      }
    }
  }

  Future<void> _handleRemoteTripEnd() async {
    if (_isHandlingRemoteEnd || _isLocalTripEnding) return;
    _isHandlingRemoteEnd = true;

    try {
      await _clearRouteAndNavigation();

      try {
        await _setDriverStatus(status: 'waiting', isOnline: true);
      } catch (e) {
        debugPrint('Error resetting driver status after remote trip end: $e');
      }

      if (!mounted) return;

      setState(() {
        activeTripId = null;
        activeTripStatus = null;
      });

      await _showMessage('trip_cancelled_by_passenger_msg'.tr()); // 🌐 اصلاح‌شده با کلید ترجمه
    } finally {
      _isHandlingRemoteEnd = false;
    }
  }

  LatLng? _getNavigationTarget(
    String status,
    Map<String, dynamic> tripData,
  ) {
    final bool goingToPickup =
        status == TripStatus.accepted || status == TripStatus.arrived;

    return goingToPickup
        ? _pickupLatLng(tripData)
        : _destinationLatLng(tripData);
  }

  // ════════════════════════════════════════════════════════════
  //  رابط کاربری
  // ════════════════════════════════════════════════════════════

  void _showStatusChangeModal() {
    if (_isTripActionLoading) return;

    showModalBottomSheet(
      context: context,
      isDismissible: !isLoading,
      backgroundColor: Colors.transparent,
      builder: (BuildContext modalContext) {
        return StatefulBuilder(
          builder: (BuildContext context, StateSetter setModalState) {
            return Container(
              padding: const EdgeInsets.symmetric(
                horizontal: 24,
                vertical: 20,
              ),
              decoration: const BoxDecoration(
                color: Colors.white,
                borderRadius: BorderRadius.vertical(
                  top: Radius.circular(32),
                ),
              ),
              child: Column(
                mainAxisSize: MainAxisSize.min,
                children: [
                  Container(
                    width: 48,
                    height: 5,
                    decoration: BoxDecoration(
                      color: Colors.grey.shade300,
                      borderRadius: BorderRadius.circular(10),
                    ),
                  ),
                  const SizedBox(height: 20),
                  Text(
                    !isDriverAvailable
                        ? 'change_to_online_title'.tr()
                        : 'change_to_offline_title'.tr(),
                    textAlign: TextAlign.center,
                    style: const TextStyle(
                      fontSize: 18,
                      fontWeight: FontWeight.bold,
                    ),
                  ),
                  const SizedBox(height: 24),
                  Row(
                    children: [
                      Expanded(
                        child: ElevatedButton(
                          onPressed: isLoading
                              ? null
                              : () async {
                                  if (isDriverAvailable &&
                                      activeTripId != null) {
                                    await _showMessage(
                                      'cannot_offline_active_trip_msg'.tr(), // 🌐 اصلاح‌شده با کلید ترجمه
                                    );
                                    return;
                                  }

                                  setModalState(() {
                                    isLoading = true;
                                  });

                                  try {
                                    if (!isDriverAvailable) {
                                      if (mounted) {
                                        setState(() {
                                          isDriverAvailable = true;
                                        });
                                      } else {
                                        isDriverAvailable = true;
                                      }

                                      _ensureActiveTripStream();
                                      listenForTripRequests();
                                      setAndGetLocationUpdates();
                                      await _saveDriverStatus(true);
                                      await goOnlineNow();
                                    } else {
                                      if (mounted) {
                                        setState(() {
                                          isDriverAvailable = false;
                                        });
                                      } else {
                                        isDriverAvailable = false;
                                      }

                                      await goOfflineNow();
                                      await _saveDriverStatus(false);
                                    }
                                  } catch (e) {
                                    debugPrint('Status update error: $e');
                                    await _showMessage(
                                      'driver_status_update_error_msg'.tr(), // 🌐 اصلاح‌شده با کلید ترجمه
                                    );
                                  } finally {
                                    isLoading = false;

                                    if (modalContext.mounted) {
                                      Navigator.pop(modalContext);
                                    }
                                  }
                                },
                          style: ElevatedButton.styleFrom(
                            backgroundColor: isDriverAvailable
                                ? const Color(0xFFE53935)
                                : const Color(0xFF0F7D55),
                            padding: const EdgeInsets.symmetric(vertical: 14),
                            shape: RoundedRectangleBorder(
                              borderRadius: BorderRadius.circular(12),
                            ),
                            elevation: 0,
                          ),
                          child: Text(
                            'btn_confirm'.tr(),
                            style: const TextStyle(
                              fontSize: 15,
                              fontWeight: FontWeight.bold,
                              color: Colors.white,
                            ),
                          ),
                        ),
                      ),
                      const SizedBox(width: 12),
                      Expanded(
                        child: OutlinedButton(
                          onPressed: isLoading
                              ? null
                              : () => Navigator.pop(modalContext),
                          style: OutlinedButton.styleFrom(
                            padding: const EdgeInsets.symmetric(vertical: 14),
                            side: BorderSide(color: Colors.grey.shade300),
                            shape: RoundedRectangleBorder(
                              borderRadius: BorderRadius.circular(12),
                            ),
                          ),
                          child: Text(
                            'btn_cancel'.tr(),
                            style: TextStyle(
                              fontSize: 15,
                              fontWeight: FontWeight.bold,
                              color: Colors.grey.shade700,
                            ),
                          ),
                        ),
                      ),
                    ],
                  ),
                ],
              ),
            );
          },
        );
      },
    );
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      resizeToAvoidBottomInset: false,
      backgroundColor: AppColors.background,
      body: SafeArea(
        child: Stack(
          children: [
            RepaintBoundary(
  child: MapLibreMap(
    initialCameraPosition: CameraPosition(
      target: LatLng(
        currentPositionOfDriver?.latitude ?? 34.5553,
        currentPositionOfDriver?.longitude ?? 69.2075,
      ),
      zoom: 15,
    ),
    styleString: 'assets/map/style.json',
    rotateGesturesEnabled: false,
    tiltGesturesEnabled: false,
    myLocationEnabled: !_isNavArrowVisible,
    myLocationTrackingMode: MyLocationTrackingMode.none,
    onMapCreated: _onMapCreated,
    onStyleLoadedCallback: () async {
      _isMapStyleReady = true;
      _isDriverArrowImageAdded = false;
      _driverNavigationSymbol = null;
      _navRemainingLine = null;
      _navTraveledLine = null;
      _navLastRenderedSegment = -1;
      _navLastRenderedPoint = null;

      await _prepareDriverNavigationArrow();

      if (_navRoutePoints.length >= 2) {
        await _renderNavLines(
          traveled: <LatLng>[],
          remaining: _navRoutePoints,
        );

        final Position? p = currentPositionOfDriver;
        if (p != null) {
          _pendingNavPosition = p;
          unawaited(_processPendingNavPosition());
        }
      }
    },
  ),
),
            Positioned(
              top: 20,
              right: 16,
              child: FloatingActionButton.small(
                heroTag: 'recenter_btn',
                elevation: 1,
                backgroundColor: Colors.white,
                onPressed: _centerMapOnDriver,
                child: const Icon(
                  Icons.my_location_rounded,
                  color: Color(0xFF0F7D55),
                ),
              ),
            ),
            Positioned(
              top: 20,
              left: 16,
              child: Material(
                elevation: 4,
                borderRadius: BorderRadius.circular(30),
                child: InkWell(
                  onTap: isLoading ? null : _showStatusChangeModal,
                  borderRadius: BorderRadius.circular(30),
                  child: Container(
                    padding: const EdgeInsets.symmetric(
                      horizontal: 20,
                      vertical: 12,
                    ),
                    decoration: BoxDecoration(
                      color: isDriverAvailable
                          ? const Color(0xFFE53935)
                          : const Color(0xFF0F7D55),
                      borderRadius: BorderRadius.circular(30),
                    ),
                    child: Row(
                      mainAxisSize: MainAxisSize.min,
                      children: [
                        const Icon(
                          Icons.circle,
                          color: Colors.white,
                          size: 10,
                        ),
                        const SizedBox(width: 8),
                        Text(
                          isDriverAvailable
                              ? 'go_offline'.tr()
                              : 'go_online'.tr(),
                          style: const TextStyle(
                            color: Colors.white,
                            fontWeight: FontWeight.bold,
                          ),
                        ),
                      ],
                    ),
                  ),
                ),
              ),
            ),
            if (isDriverAvailable && _activeTripStream != null)
              StreamBuilder<QuerySnapshot<Map<String, dynamic>>>(
                stream: _activeTripStream,
                builder: (
                  BuildContext context,
                  AsyncSnapshot<QuerySnapshot<Map<String, dynamic>>> snapshot,
                ) {
                  if (snapshot.hasError) {
                    debugPrint('Active trip stream error: ${snapshot.error}');
                    return const SizedBox.shrink();
                  }

                  if (!snapshot.hasData) {
                    return const SizedBox.shrink();
                  }

                  final QuerySnapshot<Map<String, dynamic>> data =
                      snapshot.data!;

                  if (data.docs.isEmpty) {
                    final bool uncertain = data.metadata.isFromCache;

                    if (!uncertain &&
                        activeTripId != null &&
                        !_isLocalTripEnding &&
                        !_isHandlingRemoteEnd) {
                      WidgetsBinding.instance.addPostFrameCallback((_) {
                        if (mounted && activeTripId != null) {
                          _handleRemoteTripEnd();
                        }
                      });
                    }

                    return const SizedBox.shrink();
                  }

                  final QueryDocumentSnapshot<Map<String, dynamic>> tripDoc =
                      data.docs.first;

                  final String tripId = tripDoc.id;
                  final Map<String, dynamic> tripData = tripDoc.data();
                  final String status =
                      tripData['status']?.toString() ?? TripStatus.accepted;

                  if (!_isTripOwnedByCurrentDriver(tripData)) {
                    return const SizedBox.shrink();
                  }

                  if (activeTripId != tripId || activeTripStatus != status) {
                    final String? previousTripId = activeTripId;

                    activeTripId = tripId;
                    activeTripStatus = status;

                    WidgetsBinding.instance.addPostFrameCallback((_) async {
                      if (!mounted) return;

                      if (previousTripId != null && previousTripId != tripId) {
                        await _clearRouteAndNavigation();
                      }

                      if (status == TripStatus.accepted) {
                        await _startPickupRoute(tripId, tripData);
                      } else if (status == TripStatus.onTrip) {
                        await _startDestinationRoute(tripId, tripData);
                      }
                    });
                  }

                  return ActiveTripSheet(
                    tripId: tripId,
                    status: status,
                    tripData: tripData,
                    isTripActionLoading: _isTripActionLoading,
                    onUpdateTripStatus: (tId, newStatus) {
                      _updateTripStatus(tId, newStatus, tripData);
                    },
                    onCancelTrip: _cancelTrip,
                    onMakePhoneCall: _makePhoneCall,
                    onOpenExternalMap: (lat, lng) => _openExternalMap(lat, lng),
                    getNavigationTarget: () =>
                        _getNavigationTarget(status, tripData),
                  );
                },
              ),
          ],
        ),
      ),
    );
  }
}

class _NavSnap {
  final LatLng point;
  final double distance;
  final int segmentIndex;

  const _NavSnap(this.point, this.distance, this.segmentIndex);
}
