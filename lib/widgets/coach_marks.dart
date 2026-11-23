import 'package:easy_localization/easy_localization.dart';
import 'package:flutter/material.dart';
import 'package:shared_preferences/shared_preferences.dart';

import 'package:safir_drivers/utils/app_colors.dart';

String _t(String key, String fallback) {
  final String v = key.tr();
  return (v.trim().isEmpty || v == key) ? fallback : v;
}

/// کلیدهای جاهایی که راهنما روی آن‌ها نور می‌اندازد.
class CoachKeys {
  static final GlobalKey power = GlobalKey(debugLabel: 'coach_power');
  static final GlobalKey earnings = GlobalKey(debugLabel: 'coach_earnings');
  static final GlobalKey drawer = GlobalKey(debugLabel: 'coach_drawer');
  static final GlobalKey messages = GlobalKey(debugLabel: 'coach_messages');
}

class _Step {
  const _Step(this.key, this.title, this.text);
  final GlobalKey key;
  final String title;
  final String text;
}

/// راهنمای اولین ورود: چند مرحله، هر مرحله یک بخش را روشن می‌کند.
/// فقط یک بار نشان داده می‌شود؛ از تنظیمات می‌توان دوباره دید.
class CoachMarks {
  static const String _kDone = 'coach_done_v1';

  /// با هر افزایش، Dashboard راهنما را دوباره نشان می‌دهد.
  static final ValueNotifier<int> replayTick = ValueNotifier<int>(0);

  static bool _showing = false;

  static Future<void> maybeStart(
    BuildContext context, {
    bool force = false,
  }) async {
    if (_showing) return;

    final SharedPreferences prefs = await SharedPreferences.getInstance();
    if (!force && prefs.getBool(_kDone) == true) return;
    if (!context.mounted) return;

    final List<_Step> all = <_Step>[
      _Step(
        CoachKeys.power,
        _t('coach_power_title', 'آنلاین و آفلاین'),
        _t(
          'coach_power_text',
          'برای دریافت درخواست سفر از اینجا آنلاین شوید. وقتی کارتان تمام شد، همین‌جا آفلاین شوید.',
        ),
      ),
      _Step(
        CoachKeys.earnings,
        _t('coach_earnings_title', 'درآمد شما'),
        _t(
          'coach_earnings_text',
          'مجموع درآمدتان اینجا دیده می‌شود. با لمس آن به صفحهٔ درآمد می‌روید.',
        ),
      ),
      _Step(
        CoachKeys.drawer,
        _t('coach_drawer_title', 'منو'),
        _t(
          'coach_drawer_text',
          'پروفایل، تنظیمات، تاریخچهٔ سفرها و پشتیبانی از اینجا باز می‌شوند.',
        ),
      ),
      _Step(
        CoachKeys.messages,
        _t('coach_messages_title', 'پیام‌ها'),
        _t(
          'coach_messages_text',
          'اطلاعیه‌های سفیر برای رانندگان را اینجا ببینید.',
        ),
      ),
    ].where((_Step s) => s.key.currentContext != null).toList();

    if (all.isEmpty || !context.mounted) return;

    _showing = true;
    try {
      await showGeneralDialog<void>(
        context: context,
        barrierDismissible: false,
        barrierLabel: 'coach',
        barrierColor: Colors.transparent,
        transitionDuration: const Duration(milliseconds: 220),
        pageBuilder: (BuildContext c, Animation<double> a, Animation<double> b) =>
            _CoachOverlay(steps: all),
        transitionBuilder: (BuildContext c, Animation<double> a,
                Animation<double> b, Widget child) =>
            FadeTransition(opacity: a, child: child),
      );
    } finally {
      _showing = false;
      await prefs.setBool(_kDone, true);
    }
  }

  /// از تنظیمات: راهنما را دوباره فعال می‌کند.
  static Future<void> requestReplay() async {
    final SharedPreferences prefs = await SharedPreferences.getInstance();
    await prefs.setBool(_kDone, false);
    replayTick.value++;
  }
}

class _CoachOverlay extends StatefulWidget {
  const _CoachOverlay({required this.steps});
  final List<_Step> steps;

  @override
  State<_CoachOverlay> createState() => _CoachOverlayState();
}

class _CoachOverlayState extends State<_CoachOverlay> {
  int _index = 0;

  Rect? _rectOf(GlobalKey key) {
    final BuildContext? c = key.currentContext;
    if (c == null) return null;
    final RenderObject? ro = c.findRenderObject();
    if (ro is! RenderBox || !ro.attached) return null;
    return ro.localToGlobal(Offset.zero) & ro.size;
  }

  void _next() {
    if (_index >= widget.steps.length - 1) {
      Navigator.of(context).pop();
    } else {
      setState(() => _index++);
    }
  }

  @override
  Widget build(BuildContext context) {
    final _Step step = widget.steps[_index];
    final Size size = MediaQuery.of(context).size;
    final Rect rect = (_rectOf(step.key) ??
            Rect.fromCenter(
              center: size.center(Offset.zero),
              width: 0,
              height: 0,
            ))
        .inflate(8);

    final bool below = rect.center.dy < size.height / 2;
    final bool last = _index == widget.steps.length - 1;

    return Stack(
      children: <Widget>[
        Positioned.fill(
          child: GestureDetector(
            behavior: HitTestBehavior.opaque,
            onTap: () {},
            child: CustomPaint(painter: _HolePainter(rect)),
          ),
        ),
        Positioned(
          left: 16,
          right: 16,
          top: below ? rect.bottom + 14 : null,
          bottom: below ? null : size.height - rect.top + 14,
          child: Material(
            color: AppColors.cardBackground,
            shape: RoundedRectangleBorder(
              borderRadius: BorderRadius.circular(20),
              side: BorderSide(color: AppColors.borderLight),
            ),
            child: Padding(
              padding: const EdgeInsets.all(16),
              child: Column(
                mainAxisSize: MainAxisSize.min,
                crossAxisAlignment: CrossAxisAlignment.start,
                children: <Widget>[
                  Text(
                    step.title,
                    style: TextStyle(
                      fontSize: 16,
                      fontWeight: FontWeight.w800,
                      color: AppColors.textPrimary,
                    ),
                  ),
                  const SizedBox(height: 6),
                  Text(
                    step.text,
                    style: TextStyle(
                      fontSize: 13.5,
                      height: 1.6,
                      color: AppColors.textSecondary,
                    ),
                  ),
                  const SizedBox(height: 14),
                  Row(
                    children: <Widget>[
                      Text(
                        '${_index + 1} / ${widget.steps.length}',
                        style: TextStyle(
                          fontSize: 12,
                          fontWeight: FontWeight.w700,
                          color: AppColors.textSecondary,
                        ),
                      ),
                      const Spacer(),
                      if (!last)
                        TextButton(
                          onPressed: () => Navigator.of(context).pop(),
                          child: Text(
                            _t('coach_skip', 'رد کردن'),
                            style: TextStyle(color: AppColors.textSecondary),
                          ),
                        ),
                      const SizedBox(width: 6),
                      ElevatedButton(
                        onPressed: _next,
                        style: ElevatedButton.styleFrom(
                          backgroundColor: AppColors.primaryButton,
                          foregroundColor: AppColors.buttonText,
                          elevation: 0,
                          shape: RoundedRectangleBorder(
                            borderRadius: BorderRadius.circular(12),
                          ),
                        ),
                        child: Text(
                          last
                              ? _t('coach_done', 'شروع')
                              : _t('coach_next', 'بعدی'),
                          style: const TextStyle(fontWeight: FontWeight.bold),
                        ),
                      ),
                    ],
                  ),
                ],
              ),
            ),
          ),
        ),
      ],
    );
  }
}

class _HolePainter extends CustomPainter {
  _HolePainter(this.hole);
  final Rect hole;

  @override
  void paint(Canvas canvas, Size size) {
    final Path path = Path()
      ..fillType = PathFillType.evenOdd
      ..addRect(Offset.zero & size)
      ..addRRect(RRect.fromRectAndRadius(hole, const Radius.circular(18)));
    canvas.drawPath(path, Paint()..color = Colors.black.withOpacity(0.72));
  }

  @override
  bool shouldRepaint(covariant _HolePainter old) => old.hole != hole;
}
