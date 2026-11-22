import 'package:flutter/foundation.dart';

/// پلِ بین دکمهٔ مرکزی نوار پایین (Dashboard) و منطق آنلاین/آفلاین (HomePage).
/// منطق اصلی همان‌جا در HomePage می‌ماند؛ این کلاس فقط وضعیت را نشان می‌دهد
/// و درخواست تغییر را به HomePage می‌رساند.
class DriverOnlineController {
  DriverOnlineController._();
  static final DriverOnlineController instance = DriverOnlineController._();

  final ValueNotifier<bool> online = ValueNotifier<bool>(false);
  final ValueNotifier<bool> busy = ValueNotifier<bool>(false);
  final ValueNotifier<bool> onTrip = ValueNotifier<bool>(false);

  /// کشوی کناری را باز می‌کند؛ Dashboard آن را ثبت می‌کند.
  VoidCallback? openDrawer;

  VoidCallback? _toggle;

  void attach(VoidCallback toggle) => _toggle = toggle;

  void detach(VoidCallback toggle) {
    if (_toggle == toggle) _toggle = null;
  }

  void toggle() => _toggle?.call();
}
