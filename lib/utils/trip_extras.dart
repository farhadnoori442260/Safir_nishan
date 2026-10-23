import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:flutter/material.dart';

/// یک مورد کوتاه برای نمایش (آیکن + متن)
class TripExtraItem {
  final IconData icon;
  final String text;

  const TripExtraItem(this.icon, this.text);
}

/// فرستنده یا گیرندهٔ سفر باربری
class TripParty {
  final String role;
  final String name;
  final String phone;
  final String detail; // پلاک / واحد
  final String note;

  const TripParty({
    required this.role,
    required this.name,
    required this.phone,
    required this.detail,
    required this.note,
  });

  bool get hasContent => name.isNotEmpty || phone.isNotEmpty;
}

enum TripServiceKind { taxi, vip, bike, cargo, intercity }

/// اطلاعات اضافی یک سفر (باربری، بین‌شهری، گزینه‌های سفر) که اپ مسافر
/// در سند rides ذخیره کرده، به‌شکل آمادهٔ نمایش برای راننده.
class TripExtras {
  final TripServiceKind kind;
  final String serviceLabel;
  final IconData serviceIcon;
  final List<TripExtraItem> items;
  final List<TripParty> parties;

  const TripExtras._({
    required this.kind,
    required this.serviceLabel,
    required this.serviceIcon,
    required this.items,
    required this.parties,
  });

  /// تاکسی معمولی بدون هیچ گزینهٔ اضافه، چیزی برای نمایش ندارد
  bool get hasContent =>
      kind != TripServiceKind.taxi || items.isNotEmpty || parties.isNotEmpty;

  factory TripExtras.fromRide(Map<String, dynamic>? data) {
    if (data == null) {
      return const TripExtras._(
        kind: TripServiceKind.taxi,
        serviceLabel: 'تاکسی',
        serviceIcon: Icons.local_taxi_rounded,
        items: <TripExtraItem>[],
        parties: <TripParty>[],
      );
    }

    final String service = _str(data, <String>['service_type']).toLowerCase();
    final String vehicle = _str(data, <String>['vehicle_type']);

    TripServiceKind kind;
    if (service == 'cargo') {
      kind = TripServiceKind.cargo;
    } else if (service == 'intercity') {
      kind = TripServiceKind.intercity;
    } else if (vehicle == 'Bike' || service == 'bike') {
      kind = TripServiceKind.bike;
    } else if (vehicle == 'Auto' || service == 'auto') {
      kind = TripServiceKind.vip;
    } else {
      kind = TripServiceKind.taxi;
    }

    String label;
    IconData icon;
    switch (kind) {
      case TripServiceKind.cargo:
        label = 'باربری';
        icon = Icons.local_shipping_rounded;
        break;
      case TripServiceKind.intercity:
        label = 'سفر بین‌شهری';
        icon = Icons.route_rounded;
        break;
      case TripServiceKind.bike:
        label = 'موتورسایکل';
        icon = Icons.two_wheeler_rounded;
        break;
      case TripServiceKind.vip:
        label = 'تاکسی ویژه';
        icon = Icons.workspace_premium_rounded;
        break;
      case TripServiceKind.taxi:
        label = 'تاکسی';
        icon = Icons.local_taxi_rounded;
        break;
    }

    final List<TripExtraItem> items = <TripExtraItem>[];
    final List<TripParty> parties = <TripParty>[];

    // مسافت
    final double km = _num(data['distance']);
    if (km > 0) {
      items.add(
        TripExtraItem(
          Icons.straighten_rounded,
          'مسافت ${_fa(km.toStringAsFixed(1)).replaceAll('.', '٫')} کیلومتر',
        ),
      );
    }

    // ───── باربری ─────
    if (kind == TripServiceKind.cargo) {
      final String cargoVehicle = _cargoVehicleLabel(
        _str(data, <String>['cargo_vehicle']),
      );
      if (cargoVehicle.isNotEmpty) {
        items.add(TripExtraItem(Icons.local_shipping_outlined, cargoVehicle));
      }

      final String packageType = _str(data, <String>['cargo_package_type']);
      if (packageType.isNotEmpty) {
        items.add(TripExtraItem(Icons.inventory_2_outlined, packageType));
      }

      final String insurance = _str(data, <String>['cargo_insurance']);
      if (insurance.isNotEmpty) {
        items.add(TripExtraItem(Icons.verified_user_outlined, insurance));
      }

      final String payer = _str(data, <String>['cargo_payer']);
      if (payer.isNotEmpty) {
        items.add(
          TripExtraItem(Icons.payments_outlined, 'پرداخت‌کننده: $payer'),
        );
      }

      parties.add(
        TripParty(
          role: 'فرستنده',
          name: _str(data, <String>['cargo_sender_name']),
          phone: _str(data, <String>['cargo_sender_phone']),
          detail: _partyDetail(
            _str(data, <String>['cargo_sender_floor']),
            _str(data, <String>['cargo_sender_unit']),
          ),
          note: _str(data, <String>['cargo_sender_note']),
        ),
      );

      parties.add(
        TripParty(
          role: 'گیرنده',
          name: _str(data, <String>['cargo_receiver_name']),
          phone: _str(data, <String>['cargo_receiver_phone']),
          detail: _partyDetail(
            _str(data, <String>['cargo_receiver_floor']),
            _str(data, <String>['cargo_receiver_unit']),
          ),
          note: _str(data, <String>['cargo_receiver_note']),
        ),
      );
    }

    // ───── بین‌شهری ─────
    if (kind == TripServiceKind.intercity) {
      final DateTime? travelDate = _date(data['intercity_date']);
      if (travelDate != null) {
        items.add(
          TripExtraItem(
            Icons.calendar_month_rounded,
            'تاریخ حرکت: ${formatJalaliDate(travelDate)}',
          ),
        );
      }

      final int passengers = _num(data['intercity_passengers']).round();
      if (passengers > 0) {
        items.add(
          TripExtraItem(
            Icons.groups_rounded,
            '${_fa(passengers)} مسافر',
          ),
        );
      }
    }

    // ───── گزینه‌های سفر ─────
    if (_bool(data['is_round_trip'])) {
      items.add(const TripExtraItem(Icons.swap_horiz_rounded, 'رفت‌وبرگشت'));
    }

    if (_bool(data['has_extra_luggage'])) {
      items.add(const TripExtraItem(Icons.luggage_rounded, 'بار اضافه'));
    }

    if (_bool(data['prefer_silence'])) {
      items.add(
        const TripExtraItem(Icons.volume_off_rounded, 'ترجیح سکوت'),
      );
    }

    final int stopMinutes = _num(data['stop_duration_minutes']).round();
    if (stopMinutes > 0) {
      items.add(
        TripExtraItem(
          Icons.timer_outlined,
          'توقف ${_fa(stopMinutes)} دقیقه',
        ),
      );
    }

    final String secondDestination =
        _str(data, <String>['second_destination_address']);
    if (secondDestination.isNotEmpty) {
      items.add(
        TripExtraItem(
          Icons.add_location_alt_outlined,
          'مقصد دوم: $secondDestination',
        ),
      );
    }

    if (_bool(data['is_scheduled'])) {
      final DateTime? scheduledAt = _date(data['scheduled_at']);
      if (scheduledAt != null) {
        items.add(
          TripExtraItem(
            Icons.event_available_rounded,
            'زمان‌بندی‌شده: ${formatJalaliDateTime(scheduledAt)}',
          ),
        );
      }
    }

    return TripExtras._(
      kind: kind,
      serviceLabel: label,
      serviceIcon: icon,
      items: items,
      parties: parties.where((TripParty p) => p.hasContent).toList(),
    );
  }

  // ════════════════════════════════════════════════════════════
  //  ابزارها
  // ════════════════════════════════════════════════════════════

  static String _cargoVehicleLabel(String id) {
    final String v = id.toLowerCase();
    if (v.contains('zaranj')) return 'زرنج';
    if (v.contains('suzuki')) return 'سوزوکی';
    if (v.contains('mazda')) return 'مازدا';
    return id;
  }

  static String _partyDetail(String plaque, String unit) {
    final List<String> parts = <String>[];
    if (plaque.isNotEmpty) parts.add('پلاک/طبقه $plaque');
    if (unit.isNotEmpty) parts.add('واحد $unit');
    return parts.join('، ');
  }

  static String _str(Map<String, dynamic> data, List<String> keys) {
    for (final String key in keys) {
      final Object? value = data[key];
      if (value == null) continue;

      final String text = value.toString().trim();
      if (text.isNotEmpty && text != 'null') return text;
    }
    return '';
  }

  static bool _bool(Object? value) {
    if (value is bool) return value;
    if (value is num) return value != 0;
    if (value is String) return value.trim().toLowerCase() == 'true';
    return false;
  }

  static double _num(Object? value) {
    if (value == null) return 0;
    if (value is num) return value.toDouble();

    return double.tryParse(_en(value.toString().replaceAll(',', '').trim())) ??
        0;
  }

  static DateTime? _date(Object? value) {
    if (value is Timestamp) return value.toDate();
    if (value is DateTime) return value;
    if (value is String) return DateTime.tryParse(value);
    return null;
  }

  static String _en(String input) {
    const String en = '0123456789';
    const String fa = '۰۱۲۳۴۵۶۷۸۹';
    const String ar = '٠١٢٣٤٥٦٧٨٩';

    String s = input;
    for (int i = 0; i < 10; i++) {
      s = s.replaceAll(fa[i], en[i]).replaceAll(ar[i], en[i]);
    }
    return s;
  }

  static String _fa(Object value) {
    const String en = '0123456789';
    const String fa = '۰۱۲۳۴۵۶۷۸۹';

    String s = value.toString();
    for (int i = 0; i < 10; i++) {
      s = s.replaceAll(en[i], fa[i]);
    }
    return s;
  }

  // ════════════════════════════════════════════════════════════
  //  تاریخ شمسی (ماه‌های افغانی)
  // ════════════════════════════════════════════════════════════

  static const List<String> _afghanMonths = <String>[
    'حمل',
    'ثور',
    'جوزا',
    'سرطان',
    'اسد',
    'سنبله',
    'میزان',
    'عقرب',
    'قوس',
    'جدی',
    'دلو',
    'حوت',
  ];

  static List<int> _gregorianToJalali(int gy, int gm, int gd) {
    const List<int> gDaysBefore = <int>[
      0, 31, 59, 90, 120, 151, 181, 212, 243, 273, 304, 334,
    ];

    int jy = gy <= 1600 ? 0 : 979;
    final int y = gy <= 1600 ? gy - 621 : gy - 1600;
    final int y2 = gm > 2 ? y + 1 : y;

    int days = (365 * y) +
        ((y2 + 3) ~/ 4) -
        ((y2 + 99) ~/ 100) +
        ((y2 + 399) ~/ 400) -
        80 +
        gd +
        gDaysBefore[gm - 1];

    jy += 33 * (days ~/ 12053);
    days %= 12053;

    jy += 4 * (days ~/ 1461);
    days %= 1461;

    if (days > 365) {
      jy += (days - 1) ~/ 365;
      days = (days - 1) % 365;
    }

    final int jm = days < 186 ? 1 + days ~/ 31 : 7 + (days - 186) ~/ 30;
    final int jd = 1 + (days < 186 ? days % 31 : (days - 186) % 30);

    return <int>[jy, jm, jd];
  }

  /// مثلاً «۲۸ میزان ۱۴۰۵»
  static String formatJalaliDate(DateTime date) {
    final DateTime local = date.toLocal();
    final List<int> j = _gregorianToJalali(local.year, local.month, local.day);

    return '${_fa(j[2])} ${_afghanMonths[j[1] - 1]} ${_fa(j[0])}';
  }

  /// مثلاً «۲۸ میزان ۱۴۰۵ • ۲:۴۸ بعد از ظهر»
  static String formatJalaliDateTime(DateTime date) {
    final DateTime local = date.toLocal();
    final int hour24 = local.hour;
    final int hour12 = hour24 % 12 == 0 ? 12 : hour24 % 12;
    final String minute = local.minute.toString().padLeft(2, '0');

    String period;
    if (hour24 < 12) {
      period = 'صبح';
    } else if (hour24 < 16) {
      period = 'بعد از ظهر';
    } else if (hour24 < 19) {
      period = 'عصر';
    } else {
      period = 'شب';
    }

    return '${formatJalaliDate(local)} • ${_fa(hour12)}:${_fa(minute)} $period';
  }
}
