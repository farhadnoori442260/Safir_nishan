import 'package:flutter/foundation.dart';
import 'package:flutter/services.dart';
import 'package:shared_preferences/shared_preferences.dart';

/// تنظیمات صدا، لرزش و اندازهٔ متن راننده (روی گوشی ذخیره می‌شود).
class DriverPrefs {
  DriverPrefs._();
  static final DriverPrefs instance = DriverPrefs._();

  static const String _kSound = 'pref_sound_request';
  static const String _kVibrate = 'pref_vibrate_request';
  static const String _kStrength = 'pref_vibrate_strength';
  static const String _kScale = 'pref_text_scale';

  /// پله‌های اندازهٔ متن
  static const List<double> textScales = <double>[0.9, 1.0, 1.1, 1.2, 1.3];

  final ValueNotifier<bool> soundRequest = ValueNotifier<bool>(true);
  final ValueNotifier<bool> vibrateRequest = ValueNotifier<bool>(true);

  /// 0 کوتاه، 1 متوسط، 2 شدید
  final ValueNotifier<int> vibrationStrength = ValueNotifier<int>(1);
  final ValueNotifier<double> textScale = ValueNotifier<double>(1.0);

  Future<void>? _loading;

  Future<void> ensureLoaded() => _loading ??= _load();

  Future<void> _load() async {
    try {
      final SharedPreferences p = await SharedPreferences.getInstance();
      soundRequest.value = p.getBool(_kSound) ?? true;
      vibrateRequest.value = p.getBool(_kVibrate) ?? true;
      vibrationStrength.value = (p.getInt(_kStrength) ?? 1).clamp(0, 2);
      textScale.value = p.getDouble(_kScale) ?? 1.0;
    } catch (e) {
      debugPrint('DriverPrefs load error: $e');
    }
  }

  Future<void> setSoundRequest(bool v) async {
    soundRequest.value = v;
    (await SharedPreferences.getInstance()).setBool(_kSound, v);
  }

  Future<void> setVibrateRequest(bool v) async {
    vibrateRequest.value = v;
    (await SharedPreferences.getInstance()).setBool(_kVibrate, v);
  }

  Future<void> setVibrationStrength(int v) async {
    vibrationStrength.value = v.clamp(0, 2);
    (await SharedPreferences.getInstance()).setInt(_kStrength, vibrationStrength.value);
  }

  Future<void> setTextScale(double v) async {
    textScale.value = v;
    (await SharedPreferences.getInstance()).setDouble(_kScale, v);
  }

  /// لرزش با شدت انتخاب‌شده (برای نمونه در تنظیمات و هنگام درخواست سفر)
  void buzz({bool force = false}) {
    if (!force && !vibrateRequest.value) return;
    switch (vibrationStrength.value) {
      case 0:
        HapticFeedback.lightImpact();
        break;
      case 2:
        HapticFeedback.heavyImpact();
        break;
      default:
        HapticFeedback.mediumImpact();
    }
  }
}
