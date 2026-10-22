import 'dart:async';

import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:flutter/foundation.dart';

/// تنظیمات کرایه و کمیسیون؛ همان چیزی که از پنل ادمین در
/// settings/app_config ذخیره می‌شود.
///
/// این فایل در اپ مسافر و اپ راننده دقیقاً یکی است
/// (مثلاً در lib/services/app_config_service.dart).
class AppConfig {
  final double commissionPercent;
  final bool isServiceActive;

  final double baseFareTaxi;
  final double perKmTaxi;

  final double baseFareBike;
  final double perKmBike;

  final double perKmFreight;
  final double perKmIntercity;

  final double searchRadiusKm;

  /// ضریب قیمت «ویژه» نسبت به تاکسی معمولی
  /// (اگر در پنل فیلدی به نام vip_multiplier ساختید، از همان خوانده می‌شود)
  final double vipMultiplier;

  /// ضریب کرایه هر نوع خودروی باربری نسبت به «کرایه هر کیلومتر باربری» پنل.
  /// (اگر در پنل فیلدی به این نام‌ها ساختید، از همان خوانده می‌شود)
  final double freightMultiplierZaranj;
  final double freightMultiplierSuzuki;
  final double freightMultiplierMazda;

  /// اگر true باشد، کرایه بین‌شهری در تعداد مسافر ضرب می‌شود.
  /// (در پنل/Firestore فیلد منطقی intercity_per_passenger را بسازید)
  final bool intercityPerPassenger;

  const AppConfig({
    required this.commissionPercent,
    required this.isServiceActive,
    required this.baseFareTaxi,
    required this.perKmTaxi,
    required this.baseFareBike,
    required this.perKmBike,
    required this.perKmFreight,
    required this.perKmIntercity,
    required this.searchRadiusKm,
    required this.vipMultiplier,
    required this.freightMultiplierZaranj,
    required this.freightMultiplierSuzuki,
    required this.freightMultiplierMazda,
    required this.intercityPerPassenger,
  });

  /// مقدار پیش‌فرض تا وقتی تنظیمات از سرور نرسیده (یا خوانده نشده)
  static const AppConfig defaults = AppConfig(
    commissionPercent: 10,
    isServiceActive: true,
    baseFareTaxi: 100,
    perKmTaxi: 35,
    baseFareBike: 70,
    perKmBike: 25,
    perKmFreight: 60,
    perKmIntercity: 45,
    searchRadiusKm: 5,
    vipMultiplier: 1.35,
    freightMultiplierZaranj: 0.5,
    freightMultiplierSuzuki: 1.0,
    freightMultiplierMazda: 1.67,
    intercityPerPassenger: false,
  );

  factory AppConfig.fromMap(Map<String, dynamic>? data) {
    if (data == null) return defaults;

    final double commission = _readNum(
      data['commission_percent'] ?? data['admin_commission_percent'],
      defaults.commissionPercent,
    ).clamp(0, 100).toDouble();

    return AppConfig(
      commissionPercent: commission,
      isServiceActive: _readBool(data['is_service_active'], defaults.isServiceActive),
      baseFareTaxi: _readNum(data['base_fare_taxi'], defaults.baseFareTaxi),
      perKmTaxi: _readNum(data['per_km_taxi'], defaults.perKmTaxi),
      baseFareBike: _readNum(data['base_fare_bike'], defaults.baseFareBike),
      perKmBike: _readNum(data['per_km_bike'], defaults.perKmBike),
      perKmFreight: _readNum(data['per_km_freight'], defaults.perKmFreight),
      perKmIntercity: _readNum(data['per_km_intercity'], defaults.perKmIntercity),
      searchRadiusKm: _readNum(data['search_radius_km'], defaults.searchRadiusKm),
      vipMultiplier: _readNum(data['vip_multiplier'], defaults.vipMultiplier),
      freightMultiplierZaranj: _readNum(
        data['freight_multiplier_zaranj'],
        defaults.freightMultiplierZaranj,
      ),
      freightMultiplierSuzuki: _readNum(
        data['freight_multiplier_suzuki'],
        defaults.freightMultiplierSuzuki,
      ),
      freightMultiplierMazda: _readNum(
        data['freight_multiplier_mazda'],
        defaults.freightMultiplierMazda,
      ),
      intercityPerPassenger: _readBool(
        data['intercity_per_passenger'],
        defaults.intercityPerPassenger,
      ),
    );
  }

  // ───────── محاسبهٔ کرایه (به افغانی، رُند‌شده) ─────────

  double _fare(double base, double perKm, double km) {
    final double safeKm = km.isNaN || km < 0 ? 0 : km;
    return (base + perKm * safeKm).roundToDouble();
  }

  /// تاکسی معمولی
  double taxiFare(double km) => _fare(baseFareTaxi, perKmTaxi, km);

  /// تاکسی ویژه
  double vipFare(double km) => (taxiFare(km) * vipMultiplier).roundToDouble();

  /// موتورسایکل
  double bikeFare(double km) => _fare(baseFareBike, perKmBike, km);

  /// باربری (فقط کرایه به‌ازای کیلومتر)
  double freightFare(double km) => _fare(0, perKmFreight, km);

  /// ضریب نوع خودروی باربری (زرنج، سوزوکی، مازدا)
  double freightMultiplier(String vehicleId) {
    final String id = vehicleId.toLowerCase();

    if (id.contains('mazda') || id.contains('مازدا') || id.contains('کامیون')) {
      return freightMultiplierMazda;
    }

    if (id.contains('suzuki') || id.contains('سوزوکی') || id.contains('پیکاپ')) {
      return freightMultiplierSuzuki;
    }

    // زرنج و هر نوع ناشناخته
    return freightMultiplierZaranj;
  }

  /// کرایهٔ باربری برای یک نوع خودرو: کرایه هر کیلومتر × ضریب خودرو × کیلومتر
  /// (حداقل کرایه معادل یک کیلومتر است)
  double freightFareForVehicle(String vehicleId, double km) {
    final double safeKm = km.isNaN || km < 0 ? 0 : km;
    final double billableKm = safeKm < 1 ? 1 : safeKm;

    return (perKmFreight * freightMultiplier(vehicleId) * billableKm)
        .roundToDouble();
  }

  /// بین‌شهری (فقط کرایه به‌ازای کیلومتر)
  /// (اگر intercity_per_passenger فعال باشد، در تعداد مسافر ضرب می‌شود)
  double intercityFare(double km, {int passengers = 1}) {
    final double base = _fare(0, perKmIntercity, km);

    if (!intercityPerPassenger) return base;

    final int count = passengers < 1 ? 1 : passengers;
    return (base * count).roundToDouble();
  }

  /// بر اساس نوع وسیله‌ای که در اپ مسافر انتخاب شده: Car، Auto، Bike
  double fareForVehicle(String vehicleType, double km) {
    switch (vehicleType) {
      case 'Bike':
        return bikeFare(km);
      case 'Auto':
        return vipFare(km);
      default:
        return taxiFare(km);
    }
  }

  /// سهم کمیسیون از یک مبلغ
  double commissionOf(double totalFare) =>
      (totalFare * commissionPercent / 100);

  // ───────── تبدیل مقدارها ─────────

  static double _readNum(Object? value, double fallback) {
    if (value == null) return fallback;

    if (value is num) {
      final double v = value.toDouble();
      return v.isNaN || v < 0 ? fallback : v;
    }

    String s = value.toString();
    const String fa = '۰۱۲۳۴۵۶۷۸۹';
    const String ar = '٠١٢٣٤٥٦٧٨٩';
    for (int i = 0; i < 10; i++) {
      s = s.replaceAll(fa[i], '$i').replaceAll(ar[i], '$i');
    }
    s = s.replaceAll(RegExp(r'[,،٬\s]'), '').replaceAll('٫', '.');

    final double? parsed = double.tryParse(s);
    if (parsed == null || parsed < 0) return fallback;
    return parsed;
  }

  static bool _readBool(Object? value, bool fallback) {
    if (value is bool) return value;
    if (value is num) return value != 0;

    if (value is String) {
      final String s = value.trim().toLowerCase();
      if (s == 'true' || s == '1') return true;
      if (s == 'false' || s == '0') return false;
    }

    return fallback;
  }
}

/// خواندن زندهٔ تنظیمات از Firestore.
/// با تغییر مقدار در پنل ادمین، همهٔ اپ‌ها همان لحظه به‌روز می‌شوند.
class AppConfigService {
  AppConfigService._();

  static final AppConfigService instance = AppConfigService._();

  static const String _collection = 'settings';
  static const String _document = 'app_config';

  final ValueNotifier<AppConfig> notifier =
      ValueNotifier<AppConfig>(AppConfig.defaults);

  StreamSubscription<DocumentSnapshot<Map<String, dynamic>>>? _subscription;

  AppConfig get config => notifier.value;

  DocumentReference<Map<String, dynamic>> get _ref =>
      FirebaseFirestore.instance.collection(_collection).doc(_document);

  /// بعد از ورود کاربر صدا زده شود (چند بار صدا زدن اشکالی ندارد)
  void start() {
    if (_subscription != null) return;

    _subscription = _ref.snapshots().listen(
      (DocumentSnapshot<Map<String, dynamic>> snapshot) {
        if (!snapshot.exists) return;
        notifier.value = AppConfig.fromMap(snapshot.data());
      },
      onError: (Object error) {
        // اگر قوانین Firestore اجازهٔ خواندن ندهند، اینجا خطا چاپ می‌شود
        debugPrint('AppConfig stream error: $error');
        _subscription?.cancel();
        _subscription = null;
      },
    );
  }

  /// آخرین مقدار را مستقیم از سرور می‌خواند (مثلاً قبل از ثبت سفر
  /// یا پایان سفر). اگر نشد، همان مقدار فعلی برمی‌گردد.
  Future<AppConfig> refresh() async {
    try {
      final DocumentSnapshot<Map<String, dynamic>> snapshot = await _ref
          .get(const GetOptions(source: Source.server))
          .timeout(const Duration(seconds: 6));

      if (snapshot.exists) {
        notifier.value = AppConfig.fromMap(snapshot.data());
      }
    } catch (e) {
      debugPrint('AppConfig refresh error: $e');
    }

    return config;
  }

  Future<void> stop() async {
    await _subscription?.cancel();
    _subscription = null;
  }
}
