import 'package:flutter/material.dart';

/// رنگ‌های سفیر راننده — روشن و تاریک (خنثی: مشکی/خاکستری، سبز فقط تأکید).
/// نام‌ها همان نام‌های قبلی‌اند؛ فقط دیگر `static const` نیستند و بر اساس
/// [isDark] مقدار می‌دهند. [isDark] را main.dart (با ThemeController) تنظیم می‌کند.
///
/// نکته: جلوی عبارت‌هایی که AppColors دارند نباید `const` باشد
/// (tools/fix_const.py این کار را خودکار انجام می‌دهد).
class AppColors {
  AppColors._();

  /// true وقتی برنامه در حالت تاریک است.
  static bool isDark = false;

  static Color _p(int light, int dark) => Color(isDark ? dark : light);

  // 🟢 رنگ برند: فقط تأکید (دکمه، فوکوس، انتخاب‌شده، مسیر نقشه)
  static Color get primaryBrand => _p(0xFF1B7A57, 0xFF34B27F);
  static Color get primaryDark => _p(0xFF0E5F44, 0xFF0B4A36);

  // 📦 پس‌زمینه‌ها و کارت‌ها
  static Color get background => _p(0xFFF6F7F9, 0xFF0E0F11);
  static Color get backgroundLight => _p(0xFFF6F7F9, 0xFF0E0F11);
  static Color get cardBackground => _p(0xFFFFFFFF, 0xFF1A1C1F);
  static Color get cardLightBg => _p(0xFFFFFFFF, 0xFF1A1C1F);
  static Color get cardBgLight => _p(0xFFFFFFFF, 0xFF1A1C1F);
  static Color get borderLight => _p(0xFFE5E7EB, 0xFF2C2F34);
  static Color get fieldBorder => _p(0xFFE2E8F0, 0xFF2C2F34);
  static Color get handle => _p(0xFFD1D5DB, 0xFF3D4147);
  static Color get appBarDivider => _p(0xFFD6DADF, 0xFF2C2F34);
  static Color get sectionDivider => _p(0xFFF1F5F9, 0xFF16181B);
  static Color get cardBorder => _p(0xFFE8ECEF, 0xFF2A2D32);

  // 🟩 دکمه اصلی و حالت لمس
  static Color get primaryButton => _p(0xFF169365, 0xFF169365);
  static Color get primaryButtonPressed => _p(0xFF0F4A35, 0xFF0F6B4A);
  static Color get primaryPressed => primaryButtonPressed;
  static Color get buttonPressed => primaryButtonPressed;
  static Color get buttonText => _p(0xFFFFFFFF, 0xFFFFFFFF);

  // ✅ وضعیت‌ها
  static Color get success => _p(0xFF22C55E, 0xFF2FCB6C);
  static Color get successDark => _p(0xFF16A34A, 0xFF22A858);
  static Color get error => _p(0xFFEF4444, 0xFFFF5A55);
  static Color get danger => _p(0xFFE53935, 0xFFFF5A55);
  static Color get dangerSoft => _p(0xFFFFEBEE, 0xFF3A1B1D);
  static Color get warningBg => _p(0xFFFFF7ED, 0xFF33260F);
  static Color get warning => _p(0xFFF59E0B, 0xFFF5B33C);
  static Color get warningIcon => _p(0xFFD97706, 0xFFFBBF24);
  static Color get warningText => _p(0xFF92400E, 0xFFFCD38A);

  // 📝 متن‌ها و آیکون‌ها
  static Color get textPrimary => _p(0xFF1A1D29, 0xFFECEEF1);
  static Color get textSecondary => _p(0xFF6B7280, 0xFF9BA1AA);
  static Color get iconPrimary => _p(0xFF1A1D29, 0xFFECEEF1);
  static Color get iconSecondary => _p(0xFF6B7280, 0xFF9BA1AA);

  // 🧩 سطح‌های نرم برای هشدار/اطلاع/چیپ و رنگ دکمه پایان سفر
  static Color get endTrip => _p(0xFFC2570C, 0xFFE0701F);
  // کلید تم (تاریک/روشن): زیر کلید مشکی، مستطیل انتخاب‌شده هم‌رنگ کارت
  static Color get toggleTrack => _p(0xFFECEEF2, 0xFF08090B);
  static Color get toggleTrackBorder => _p(0xFFD4D7E2, 0xFF33363C);
  static Color get toggleThumbBorder => _p(0xFFB5BAC8, 0xFF4A4E55);
  static Color get neutralSoft => _p(0xFFF1F5F9, 0xFF121417);
  static Color get successSoft => _p(0xFFDCFCE7, 0xFF11301E);
  static Color get infoSoft => _p(0xFFEFF6FF, 0xFF16243A);
  static Color get infoBorder => _p(0xFFBFDBFE, 0xFF254468);
  static Color get infoText => _p(0xFF1E3A8A, 0xFF9DC2FF);

  // 📍 نقشه
  static Color get originBlue => _p(0xFF2563EB, 0xFF5B8DEF);

  // 🎨 رنگ‌های موضوعی آیکن‌ها (هر بخش رنگ خودش؛ سبز فقط برند/دکمه)
  static Color get accentPurple => _p(0xFF8158CF, 0xFFB49AFF);
  static Color get accentOrange => _p(0xFFC97A14, 0xFFF5B65B);
  static Color get accentTeal => _p(0xFF0E8F9C, 0xFF4FD1DC);

  /// رنگ خط مسیر روی نقشه (hex، چون MapLibre رشته می‌خواهد)
  static String get routeLineHex => isDark ? '#5B8DEF' : '#0066FF';
  static String get routeTraveledHex => isDark ? '#5A6660' : '#B0B7C3';

  /// استایل نقشه
  static String get mapStyleAsset =>
      isDark ? 'assets/map/style_dark.json' : 'assets/map/style.json';
}

typedef SafirColors = AppColors;
