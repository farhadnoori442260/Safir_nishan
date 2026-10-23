import 'dart:async';
import 'dart:developer';

import 'package:audioplayers/audioplayers.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:firebase_messaging/firebase_messaging.dart';
import 'package:flutter/material.dart';
import 'package:flutter_notification_channel/flutter_notification_channel.dart';
import 'package:flutter_notification_channel/notification_importance.dart';
import 'package:geolocator/geolocator.dart';
import 'package:latlong2/latlong.dart';

import 'package:safir_drivers/constants/trip_status.dart';
import 'package:safir_drivers/global/global.dart';
import 'package:safir_drivers/main.dart';
import 'package:safir_drivers/models/trip_details.dart';
import 'package:safir_drivers/services/app_config_service.dart';
import 'package:safir_drivers/widgets/notification_dialog.dart';

class PushNotificationSystem {
  static final PushNotificationSystem _instance =
      PushNotificationSystem._internal();

  factory PushNotificationSystem() => _instance;

  PushNotificationSystem._internal();

  final FirebaseMessaging firebaseCloudMessaging = FirebaseMessaging.instance;
  final AudioPlayer _audioPlayer = AudioPlayer();

  /// درخواست سفر هر چند ثانیه‌ای ممکن است از دو مسیر برسد
  /// (Firestore و push)؛ شنونده‌ها فقط یک بار ثبت می‌شوند.
  bool _areMessageListenersRegistered = false;
  StreamSubscription<String>? _tokenRefreshSubscription;
  StreamSubscription<RemoteMessage>? _onMessageSubscription;
  StreamSubscription<RemoteMessage>? _onMessageOpenedSubscription;

  /// فقط یک دیالوگ درخواست سفر هم‌زمان باز می‌ماند؛
  /// درخواست‌های بعدی در صف می‌روند و بعد از بسته‌شدن نشان داده می‌شوند.
  bool _isTripDialogOpen = false;
  String? _shownTripId;
  final List<String> _queuedTripIds = <String>[];

  // ════════════════════════════════════════════════════════════
  //  توکن و اشتراک
  // ════════════════════════════════════════════════════════════

  Future<String?> generateDeviceRegistrationToken() async {
    try {
      final NotificationSettings settings =
          await firebaseCloudMessaging.requestPermission(
        alert: true,
        badge: true,
        sound: true,
      );

      log('Notification permission: ${settings.authorizationStatus}');

      final String? deviceRecognitionToken =
          await firebaseCloudMessaging.getToken();

      final User? currentUser = FirebaseAuth.instance.currentUser;

      if (currentUser != null && deviceRecognitionToken != null) {
        await FirebaseFirestore.instance
            .collection('drivers')
            .doc(currentUser.uid)
            .set(
          {
            'deviceToken': deviceRecognitionToken,
            'token': deviceRecognitionToken,
          },
          SetOptions(merge: true),
        );
      }

      // ✅ شنوندهٔ تازه‌شدن توکن فقط یک بار ثبت می‌شود
      _tokenRefreshSubscription ??=
          FirebaseMessaging.instance.onTokenRefresh.listen(
        (String newToken) async {
          final User? user = FirebaseAuth.instance.currentUser;
          if (user == null) return;

          try {
            await FirebaseFirestore.instance
                .collection('drivers')
                .doc(user.uid)
                .set(
              {
                'deviceToken': newToken,
                'token': newToken,
              },
              SetOptions(merge: true),
            );

            log('FCM token refreshed and saved for driver: ${user.uid}');
          } catch (e) {
            log('FCM token refresh save error: $e');
          }
        },
      );

      await firebaseCloudMessaging.subscribeToTopic('drivers');

      log('Driver FCM token: $deviceRecognitionToken');

      return deviceRecognitionToken;
    } catch (e) {
      log('generateDeviceRegistrationToken error: $e');
      return null;
    }
  }

  // ════════════════════════════════════════════════════════════
  //  شنیدن نوتیفیکیشن‌ها
  // ════════════════════════════════════════════════════════════

  Future<void> startListeningForNewNotification(
    BuildContext context,
  ) async {
    // ✅ قبلاً با هر بار ساخته‌شدن صفحهٔ اصلی، شنونده‌ها دوباره اضافه می‌شدند
    // و برای یک سفر چند دیالوگ باز می‌شد.
    if (_areMessageListenersRegistered) return;
    _areMessageListenersRegistered = true;

    try {
      final result =
          await FlutterNotificationChannel().registerNotificationChannel(
        description: 'برای نمایش نوتیفیکیشن‌های درخواست سفر سفیر',
        id: 'safirDriversApp',
        importance: NotificationImportance.IMPORTANCE_HIGH,
        name: 'Safir Drivers',
      );

      log('Notification Channel Result: $result');
    } catch (e) {
      log('Notification channel error: $e');
    }

    FirebaseMessaging.instance.getInitialMessage().then(
      (RemoteMessage? messageRemote) {
        if (messageRemote == null) return;

        final String? tripID = _extractTripId(messageRemote);
        if (tripID != null) {
          log('Terminated Trip ID: $tripID');
          retrieveTripRequestInfo(tripID, context, fromPush: true);
        }
      },
    );

    _onMessageSubscription =
        FirebaseMessaging.onMessage.listen((RemoteMessage messageRemote) {
      final String? tripID = _extractTripId(messageRemote);

      if (tripID != null) {
        log('Foreground Trip ID: $tripID');
        retrieveTripRequestInfo(tripID, context, fromPush: true);
      }
    });

    _onMessageOpenedSubscription =
        FirebaseMessaging.onMessageOpenedApp.listen(
      (RemoteMessage messageRemote) {
        final String? tripID = _extractTripId(messageRemote);

        if (tripID != null) {
          log('Background Trip ID: $tripID');
          retrieveTripRequestInfo(tripID, context, fromPush: true);
        }
      },
    );
  }

  Future<void> stopListening() async {
    await _onMessageSubscription?.cancel();
    await _onMessageOpenedSubscription?.cancel();
    await _tokenRefreshSubscription?.cancel();

    _onMessageSubscription = null;
    _onMessageOpenedSubscription = null;
    _tokenRefreshSubscription = null;
    _areMessageListenersRegistered = false;
  }

  String? _extractTripId(RemoteMessage message) {
    return message.data['tripID'] ??
        message.data['trip_id'] ??
        message.data['ride_id'];
  }

  // ════════════════════════════════════════════════════════════
  //  ابزارها
  // ════════════════════════════════════════════════════════════

  double? _parseDouble(dynamic value) {
    if (value == null) return null;
    if (value is num) return value.toDouble();
    return double.tryParse(value.toString().trim());
  }

  LatLng? _readPoint(
    Map<String, dynamic> data, {
    required List<String> latKeys,
    required List<String> lngKeys,
    required List<String> geoPointKeys,
    required List<String> mapKeys,
  }) {
    for (int i = 0; i < latKeys.length && i < lngKeys.length; i++) {
      final double? lat = _parseDouble(data[latKeys[i]]);
      final double? lng = _parseDouble(data[lngKeys[i]]);

      if (lat != null && lng != null) return LatLng(lat, lng);
    }

    for (final String key in geoPointKeys) {
      final dynamic value = data[key];

      if (value is GeoPoint) {
        return LatLng(value.latitude, value.longitude);
      }
    }

    for (final String key in mapKeys) {
      final dynamic value = data[key];

      if (value is Map) {
        final double? lat = _parseDouble(value['latitude'] ?? value['lat']);
        final double? lng = _parseDouble(
          value['longitude'] ?? value['lng'] ?? value['lon'],
        );

        if (lat != null && lng != null) return LatLng(lat, lng);
      }
    }

    return null;
  }

  String _firstText(
    Map<String, dynamic> data,
    List<String> keys,
    String fallback,
  ) {
    for (final String key in keys) {
      final String text = data[key]?.toString().trim() ?? '';
      if (text.isNotEmpty && text != 'null') return text;
    }
    return fallback;
  }

  /// مبلغ با جداکنندهٔ هزارگان؛ «1234.0» می‌شود «1,234»
  String _formatMoney(List<dynamic> candidates) {
    for (final dynamic raw in candidates) {
      final double? value = _parseDouble(raw);
      if (value == null) continue;

      final String digits = value.round().abs().toString();
      final StringBuffer buffer = StringBuffer();

      for (int i = 0; i < digits.length; i++) {
        if (i > 0 && (digits.length - i) % 3 == 0) buffer.write(',');
        buffer.write(digits[i]);
      }

      return (value < 0 ? '-' : '') + buffer.toString();
    }

    return '';
  }

  Future<void> _startTripAlertSound() async {
    try {
      await _audioPlayer.stop();
      await _audioPlayer.setReleaseMode(ReleaseMode.loop);

      await _audioPlayer.play(
        AssetSource('audio/fa/alert-sound.mp3'),
        volume: 1.0,
      );
    } catch (e) {
      log('Audio error: $e');
    }
  }

  Future<void> _stopTripAlertSound() async {
    try {
      await _audioPlayer.stop();
      await _audioPlayer.setReleaseMode(ReleaseMode.stop);
    } catch (e) {
      log('Stop audio error: $e');
    }
  }

  /// برای درخواست‌هایی که از push می‌رسند (مسیر Firestore خودش آنلاین بودن
  /// و نداشتن سفر فعال را بررسی کرده): راننده آنلاین است و سفر فعال ندارد؟
  Future<bool> _isDriverReadyForTrips() async {
    final User? user = FirebaseAuth.instance.currentUser;
    if (user == null) return false;

    try {
      final DocumentSnapshot<Map<String, dynamic>> snapshot =
          await FirebaseFirestore.instance
              .collection('drivers')
              .doc(user.uid)
              .get();

      final Map<String, dynamic>? driver = snapshot.data();
      if (driver == null) return true;

      final bool isOnline =
          driver.containsKey('isOnline') ? driver['isOnline'] == true : true;

      final bool hasActiveTrip =
          driver['newTripStatus']?.toString() == TripStatus.accepted;

      return isOnline && !hasActiveTrip;
    } catch (e) {
      // اگر نتوانستیم بخوانیم، درخواست را از دست نمی‌دهیم
      log('Driver readiness check failed: $e');
      return true;
    }
  }

  // ════════════════════════════════════════════════════════════
  //  نمایش درخواست سفر
  // ════════════════════════════════════════════════════════════

  Future<void> retrieveTripRequestInfo(
    String tripID,
    BuildContext context, {
    bool fromPush = false,
  }) async {
    if (tripID.trim().isEmpty) return;

    // ✅ فقط یک دیالوگ هم‌زمان؛ بقیه در صف می‌مانند
    if (_isTripDialogOpen) {
      if (_shownTripId != tripID && !_queuedTripIds.contains(tripID)) {
        _queuedTripIds.add(tripID);
        log('Trip $tripID queued (dialog already open)');
      }
      return;
    }

    // جایگاه را همین الان رزرو کن تا دو درخواست هم‌زمان از هم عبور نکنند
    _isTripDialogOpen = true;
    _shownTripId = tripID;

    try {
      await _prepareAndShowTrip(tripID, context, fromPush: fromPush);
    } catch (e, stackTrace) {
      log('Error showing trip request: $e', stackTrace: stackTrace);
    } finally {
      await _stopTripAlertSound();
      _isTripDialogOpen = false;
      _shownTripId = null;

      _showNextQueuedTrip(context);
    }
  }

  void _showNextQueuedTrip(BuildContext context) {
    if (_queuedTripIds.isEmpty) return;

    final String nextTripId = _queuedTripIds.removeAt(0);

    // وضعیت و انقضای سفر دوباره بررسی می‌شود
    unawaited(retrieveTripRequestInfo(nextTripId, context));
  }

  Future<void> _prepareAndShowTrip(
    String tripID,
    BuildContext context, {
    required bool fromPush,
  }) async {
    final AppConfig config = AppConfigService.instance.config;

    // سرویس از پنل ادمین خاموش شده
    if (!config.isServiceActive) {
      log('Service is inactive. Trip $tripID ignored.');
      return;
    }

    if (fromPush && !await _isDriverReadyForTrips()) {
      log('Driver is offline or busy. Push trip $tripID ignored.');
      return;
    }

    final DocumentSnapshot<Map<String, dynamic>> tripSnapshot =
        await FirebaseFirestore.instance.collection('rides').doc(tripID).get();

    final Map<String, dynamic>? data = tripSnapshot.data();

    if (!tripSnapshot.exists || data == null) {
      log('No document found in Firestore for tripID: $tripID');
      return;
    }

    final String tripStatus =
        data['status']?.toString().trim().toLowerCase() ?? '';

    if (tripStatus != TripStatus.searching) {
      log('Trip $tripID ignored. Current status: $tripStatus');
      return;
    }

    final dynamic createdAtValue =
        data['created_at'] ?? data['createdAt'] ?? data['timestamp'];

    if (createdAtValue is Timestamp) {
      final DateTime createdAt = createdAtValue.toDate();

      if (DateTime.now().difference(createdAt).inMinutes > 5) {
        log('Trip $tripID is expired. Ignoring.');
        return;
      }
    }

    final TripDetails tripDetailsInfo = TripDetails();

    final LatLng? pickup = _readPoint(
      data,
      latKeys: const <String>['from_lat'],
      lngKeys: const <String>['from_lng'],
      geoPointKeys: const <String>['from', 'originLatLng'],
      mapKeys: const <String>['origin'],
    );

    final LatLng? dropOff = _readPoint(
      data,
      latKeys: const <String>['to_lat'],
      lngKeys: const <String>['to_lng'],
      geoPointKeys: const <String>['to', 'destinationLatLng'],
      mapKeys: const <String>['destination'],
    );

    if (pickup != null) tripDetailsInfo.pickUpLatLng = pickup;
    if (dropOff != null) tripDetailsInfo.dropOffLatLng = dropOff;

    // فقط درخواست‌های داخل «شعاع جستجوی راننده» (از پنل ادمین)

    if (pickup != null) {
      try {
        final Position? lastKnown = await Geolocator.getLastKnownPosition();

        if (lastKnown != null) {
          final double distanceKm = Geolocator.distanceBetween(
                lastKnown.latitude,
                lastKnown.longitude,
                pickup.latitude,
                pickup.longitude,
              ) /
              1000;

          if (distanceKm > config.searchRadiusKm) {
            log(
              'Trip $tripID is ${distanceKm.toStringAsFixed(1)} km away '
              '(radius ${config.searchRadiusKm} km). Ignoring.',
            );
            return;
          }
        }
      } catch (e) {
        log('Radius check skipped: $e');
      }
    }

    tripDetailsInfo.pickupAddress = _firstText(
      data,
      const <String>[
        'pickup_address',
        'pickUpAddress',
        'originAddress',
        'origin_address',
      ],
      'مبدأ نامشخص',
    );

    tripDetailsInfo.dropOffAddress = _firstText(
      data,
      const <String>[
        'dropoff_address',
        'dropOffAddress',
        'destinationAddress',
        'destination_address',
      ],
      'مقصد نامشخص',
    );

    tripDetailsInfo.userName = _firstText(
      data,
      const <String>[
        'userName',
        'passenger_name',
        'full_name',
        'passengerName',
      ],
      'مسافر',
    );

    tripDetailsInfo.userPhone = _firstText(
      data,
      const <String>[
        'userPhone',
        'passenger_phone',
        'phone',
        'passengerPhone',
      ],
      '',
    );

    tripDetailsInfo.tripID = tripID;

    // ✅ مقدارها محلی‌اند و با درخواست بعدی روی هم نوشته نمی‌شوند
    final String bidText = _firstText(
      data,
      const <String>['bidAmount', 'bid_amount'],
      '',
    );

    final String fareText = _formatMoney(
      <dynamic>[data['fare'], data['fareAmount'], data['price']],
    );

    // سازگاری با بقیهٔ برنامه که ممکن است این متغیرهای سراسری را بخواند
    bidAmount = bidText;
    fareAmount = fareText;

    final BuildContext currentContext = navigatorKey.currentContext ?? context;

    if (!currentContext.mounted) {
      log('Context is not mounted. Trip $tripID ignored.');
      return;
    }

    await _startTripAlertSound();

    await showDialog(
      context: currentContext,
      barrierDismissible: false,
      builder: (BuildContext dialogContext) {
        return NotificationDialog(
          tripDetailsInfo: tripDetailsInfo,
          bidAmount: bidText,
          fareAmount: fareText,
          rideData: Map<String, dynamic>.from(data),
        );
      },
    );
  }
}
