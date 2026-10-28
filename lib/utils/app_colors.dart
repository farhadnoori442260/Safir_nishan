import 'package:flutter/material.dart';

class AppColors {
  AppColors._();

  // 🟢 رنگ برند سفیر: فقط به‌عنوان «رنگ تأکید» (دکمهٔ اصلی، فوکوس فیلد،
  // آیکن‌های انتخاب‌شده، لوگو و مسیر نقشه). بقیهٔ رابط عمداً خنثی است.
  static const Color primaryBrand = Color(0xFF1B7A57);

  // 📦 پس‌زمینه‌ها و کارت‌ها: خاکستری روشن خنثی + کارت سفید (بدون رنگ سبز)
  static const Color background = Color(0xFFF6F7F9);
  static const Color cardBackground = Color(0xFFFFFFFF);
  static const Color cardLightBg = Color(0xFFFFFFFF);
  static const Color cardBgLight = Color(0xFFFFFFFF);
  static const Color backgroundLight = Color(0xFFF6F7F9);
  static const Color borderLight = Color(0xFFE5E7EB);

  // 🟩 دکمه اصلی و حالت‌های لمس (همان سبز برند)
  static const Color primaryButton = Color(0xFF169365);
  static const Color primaryButtonPressed = Color(0xFF0F4A35);
  static const Color primaryPressed = Color(0xFF0F4A35);
  static const Color buttonPressed = Color(0xFF0F4A35);

  // ✅ وضعیت‌ها
  static const Color success = Color(0xFF22C55E);
  static const Color error = Color(0xFFEF4444);

  // 📝 متن‌ها و آیکون‌ها (سرمه‌ای-تیره به‌جای مشکی خالص)
  static const Color buttonText = Color(0xFFFFFFFF);
  static const Color textPrimary = Color(0xFF1A1D29);
  static const Color textSecondary = Color(0xFF6B7280);
  static const Color iconPrimary = Color(0xFF1A1D29);
  static const Color iconSecondary = Color(0xFF6B7280);

  // 📍 نقشه
  static const Color originBlue = Color(0xFF2563EB);
}

// 👈 Typedef دقیقاً خارج از آکلوپ کلاس قرار گرفت
typedef SafirColors = AppColors;
