import 'package:flutter/material.dart';

import '../utils/app_colors.dart';

class RatingStars extends StatelessWidget {
  final String ratting; // بدون تغییر در نام متغیر برای حفظ اتصال با دیتابیس

  const RatingStars({super.key, required this.ratting});

  @override
  Widget build(BuildContext context) {
    // تبدیل رشته به double برای پشتیبانی از امتیازهای اعشاری
    double ratingValue = double.tryParse(ratting) ?? 0.0;

    // اطمینان از قرار داشتن امتیاز بین 0 و 5
    if (ratingValue > 5) ratingValue = 5.0;
    if (ratingValue < 0) ratingValue = 0.0;

    // ستاره‌های فعال طلایی (در تم تاریک روشن‌تر)؛ خالی‌ها خنثی
    final Color active = AppColors.warning;
    final Color empty = AppColors.fieldBorder;

    return Directionality(
      textDirection: Directionality.of(context),
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: <Widget>[
          for (int i = 1; i <= 5; i++)
            Icon(
              i <= ratingValue
                  ? Icons.star_rounded
                  : (i - 0.5 <= ratingValue
                      ? Icons.star_half_rounded
                      : Icons.star_border_rounded),
              color: i - 0.5 <= ratingValue ? active : empty,
              size: 20,
            ),
        ],
      ),
    );
  }
}
