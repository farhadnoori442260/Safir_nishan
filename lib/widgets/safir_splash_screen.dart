import 'dart:math' as math;
import 'dart:ui' as ui;

import 'package:flutter/material.dart';

// ─────────────────────────────────────────────────────────────
// پیش‌نیاز: فونت Oswald در pubspec.yaml (زیر بخش flutter: fonts:)
//
//   - family: Oswald
//     fonts:
//       - asset: assets/fonts/Oswald-VariableFont_wght.ttf
//
// اگر فونت نبود، با فونت پیش‌فرض سیستم نمایش داده می‌شود و
// تراز نوشته با S باز هم دقیق است.
// ─────────────────────────────────────────────────────────────

/// نشان ثابت سفیر، بدون نوشته و انیمیشن.
class SafirLogoMark extends StatelessWidget {
  const SafirLogoMark({
    super.key,
    this.size = 160,
    this.backgroundColor = const Color(0xFF12304F),
  });

  final double size;
  final Color backgroundColor;

  @override
  Widget build(BuildContext context) {
    return SizedBox(
      width: size,
      height: size,
      child: CustomPaint(
        painter: _SafirLogoPainter(
          roadProgress: 1,
          pinProgress: 1,
          bgColor: backgroundColor,
        ),
      ),
    );
  }
}

/// لوگوی متحرک:
/// ابتدا مسیر S، سپس پین و در آخر نوشته از چپ به راست.
/// نوشته دقیقاً هم‌عرض خود S است (لبهٔ چپ و راست یکی).
class SafirLogoAnimation extends StatefulWidget {
  const SafirLogoAnimation({
    super.key,
    this.onCompleted,
    this.backgroundColor = const Color(0xFF12304F),
    this.title = 'Safir',
    this.subtitle,
    this.textHeight,
    this.holdAfterFinish = const Duration(milliseconds: 450),
  });

  final VoidCallback? onCompleted;
  final Color backgroundColor;
  final String title;

  /// نوشتهٔ کنار عنوان (مثلاً «Driver» برای اپ راننده)
  final String? subtitle;

  /// ارتفاع نوشته نسبت به بوم ۱۰۲۴؛ پیش‌فرض: ۱۸۰ (بدون زیرعنوان) یا ۱۱۸ (با زیرعنوان)
  final double? textHeight;
  final Duration holdAfterFinish;

  @override
  State<SafirLogoAnimation> createState() => _SafirLogoAnimationState();
}

class _SafirLogoAnimationState extends State<SafirLogoAnimation>
    with SingleTickerProviderStateMixin {
  late final AnimationController _controller;

  late final Animation<double> _road;
  late final Animation<double> _pin;
  late final Animation<double> _text;

  _TextInk? _ink;

  @override
  void initState() {
    super.initState();

    _controller = AnimationController(
      vsync: this,
      duration: const Duration(milliseconds: 2400),
    );

    _road = CurvedAnimation(
      parent: _controller,
      curve: const Interval(0.00, 0.55, curve: Curves.easeInOutCubic),
    );

    _pin = CurvedAnimation(
      parent: _controller,
      curve: const Interval(0.55, 0.76, curve: Curves.easeOutBack),
    );

    _text = CurvedAnimation(
      parent: _controller,
      curve: const Interval(0.72, 1.00, curve: Curves.easeInOutCubic),
    );

    _measureText();
    _playAnimation();
  }

  /// ابعاد واقعی «جوهر» نوشته را اندازه می‌گیرد تا هر فونتی
  /// دقیقاً هم‌عرض S شود.
  Future<void> _measureText() async {
    try {
      final _TextInk? ink =
          await _TextInk.measure(widget.title, widget.subtitle);
      if (!mounted) return;
      setState(() => _ink = ink);
    } catch (e) {
      debugPrint('Safir splash text measure error: $e');
    }
  }

  Future<void> _playAnimation() async {
    try {
      await _controller.forward().orCancel;

      if (!mounted) return;

      await Future<void>.delayed(widget.holdAfterFinish);

      if (!mounted) return;

      widget.onCompleted?.call();
    } on TickerCanceled {
      // صفحه قبل از پایان انیمیشن بسته شده است.
    }
  }

  @override
  void dispose() {
    _controller.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final double screenWidth = MediaQuery.of(context).size.width;
    final double logoSize = math.min(screenWidth * 0.52, 260.0);

    return SizedBox(
      width: logoSize,
      height: logoSize,
      child: AnimatedBuilder(
        animation: _controller,
        builder: (context, _) {
          return Semantics(
            label: widget.subtitle == null
                ? widget.title
                : '${widget.title} ${widget.subtitle}',
            child: CustomPaint(
              painter: _SafirLogoPainter(
                roadProgress: _road.value,
                pinProgress: _pin.value,
                bgColor: widget.backgroundColor,
                title: widget.title,
                subtitle: widget.subtitle,
                textHeight: widget.textHeight ??
                    (widget.subtitle == null ? 180.0 : 118.0),
                ink: _ink,
                textProgress: _text.value.clamp(0.0, 1.0).toDouble(),
                showText: true,
              ),
            ),
          );
        },
      ),
    );
  }
}

/// صفحهٔ اسپلش مستقل.
class SafirSplashScreen extends StatelessWidget {
  const SafirSplashScreen({
    super.key,
    required this.onFinished,
    this.backgroundColor = const Color(0xFF12304F),
  });

  final VoidCallback onFinished;
  final Color backgroundColor;

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: backgroundColor,
      body: Center(
        child: SafirLogoAnimation(
          backgroundColor: backgroundColor,
          onCompleted: onFinished,
        ),
      ),
    );
  }
}

/// استایل نوشتهٔ لوگو (تخت و ضخیم، هماهنگ با جادهٔ S)
const TextStyle _wordmarkStyle = TextStyle(
  inherit: false,
  color: Colors.white,
  fontFamily: 'Oswald',
  fontFamilyFallback: <String>['sans-serif'],
  fontWeight: FontWeight.w700,
  fontVariations: <FontVariation>[FontVariation('wght', 700)],
  height: 1,
  decoration: TextDecoration.none,
);

/// زیرعنوان (مثلاً Driver): همان فونت ولی سبک‌تر
const TextStyle _subtitleStyle = TextStyle(
  inherit: false,
  color: Colors.white,
  fontFamily: 'Oswald',
  fontFamilyFallback: <String>['sans-serif'],
  fontWeight: FontWeight.w400,
  fontVariations: <FontVariation>[FontVariation('wght', 400)],
  height: 1,
  decoration: TextDecoration.none,
);

TextSpan _wordmarkSpan(
  String title,
  String? subtitle,
  double fontSize,
  double letterSpacing,
) {
  return TextSpan(
    text: title,
    style: _wordmarkStyle.copyWith(
      fontSize: fontSize,
      letterSpacing: letterSpacing,
    ),
    children: subtitle == null
        ? null
        : <InlineSpan>[
            TextSpan(
              text: ' $subtitle',
              style: _subtitleStyle.copyWith(
                fontSize: fontSize,
                letterSpacing: letterSpacing,
              ),
            ),
          ],
  );
}

/// ابعاد واقعی جوهر نوشته (بدون حاشیهٔ خالی کنار حروف)، در فونت‌سایز مرجع.
class _TextInk {
  const _TextInk({
    required this.left,
    required this.top,
    required this.width,
    required this.height,
    required this.fontSize,
  });

  final double left; // فاصلهٔ جوهر از مبدأ نوشته
  final double top;
  final double width;
  final double height;
  final double fontSize;

  static Future<_TextInk?> measure(String text, String? subtitle) async {
    const double fontSize = 200;
    const double pad = 24;

    final TextPainter tp = TextPainter(
      text: _wordmarkSpan(text, subtitle, fontSize, 0),
      textDirection: TextDirection.ltr,
      textScaler: TextScaler.noScaling,
    )..layout();

    final int w = (tp.width + pad * 2).ceil();
    final int h = (tp.height + pad * 2).ceil();

    final ui.PictureRecorder recorder = ui.PictureRecorder();
    final Canvas canvas = Canvas(recorder);
    tp.paint(canvas, const Offset(pad, pad));

    final ui.Image image = await recorder.endRecording().toImage(w, h);
    final ByteData? data =
        await image.toByteData(format: ui.ImageByteFormat.rawRgba);
    image.dispose();

    if (data == null) return null;

    int minX = w, maxX = -1, minY = h, maxY = -1;

    for (int y = 0; y < h; y++) {
      for (int x = 0; x < w; x++) {
        final int alpha = data.getUint8((y * w + x) * 4 + 3);
        if (alpha > 40) {
          if (x < minX) minX = x;
          if (x > maxX) maxX = x;
          if (y < minY) minY = y;
          if (y > maxY) maxY = y;
        }
      }
    }

    if (maxX < 0 || maxY < 0) return null;

    return _TextInk(
      left: minX - pad,
      top: minY - pad,
      width: (maxX - minX + 1).toDouble(),
      height: (maxY - minY + 1).toDouble(),
      fontSize: fontSize,
    );
  }
}

/// رسم نشان اصلی روی بوم ۱۰۲۴×۱۰۲۴.
class _SafirLogoPainter extends CustomPainter {
  _SafirLogoPainter({
    required this.roadProgress,
    required this.pinProgress,
    required this.bgColor,
    this.title = '',
    this.subtitle,
    this.textHeight = 180,
    this.ink,
    this.textProgress = 0,
    this.showText = false,
  });

  final double roadProgress;
  final double pinProgress;
  final Color bgColor;
  final String title;
  final String? subtitle;
  final double textHeight;
  final _TextInk? ink;
  final double textProgress;
  final bool showText;

  static const double _stroke = 112;
  static const double _k = 0.88;
  static const double _pinCx = 735;
  static const double _pinCy = 300;

  // لبهٔ چپ و راست بدنهٔ S (بدون پین) و محل نوشته
  static const double _sLeft = 238; // 400 - 106 - 56
  static const double _sRight = 786; // 624 + 106 + 56
  static const double _textTop = 852; // ۷۲ واحد پایین‌تر از لبهٔ پایین S

  // وقتی نوشته هست، کل گروه را بالا می‌بریم تا (نشان + نوشته) وسط کادر بماند
  // بالای پین ≈ 222.6 ؛ پایین نوشته = _textTop + textHeight
  double get _groupShiftY => 512 - (222.6 + _textTop + textHeight) / 2;

  Path _roadPath() {
    return Path()
      ..moveTo(330, 724)
      ..lineTo(624, 724)
      ..arcToPoint(
        const Offset(624, 512),
        radius: const Radius.circular(106),
        clockwise: false,
      )
      ..lineTo(400, 512)
      ..arcToPoint(
        const Offset(400, 300),
        radius: const Radius.circular(106),
        clockwise: true,
      )
      ..lineTo(690, 300);
  }

  Path _pinPath() {
    const double r = 88 * _k;
    const double cx = _pinCx;
    const double cy = _pinCy;

    return Path()
      ..moveTo(cx, cy - r)
      ..arcToPoint(
        const Offset(cx + r, cy),
        radius: const Radius.circular(r),
        clockwise: true,
      )
      ..cubicTo(
        cx + r,
        cy + 52 * _k,
        cx + r - 56 * _k,
        cy + 104 * _k,
        cx,
        cy + 148 * _k,
      )
      ..cubicTo(
        cx - 32 * _k,
        cy + 104 * _k,
        cx - 88 * _k,
        cy + 52 * _k,
        cx - r,
        cy,
      )
      ..arcToPoint(
        const Offset(cx, cy - r),
        radius: const Radius.circular(r),
        clockwise: true,
      )
      ..close();
  }

  void _paintWordmark(Canvas canvas) {
    final _TextInk? m = ink;
    if (m == null || textProgress <= 0 || title.isEmpty) return;

    const double targetW = _sRight - _sLeft;

    // اندازهٔ فونت طوری که ارتفاع جوهر = _textHeight شود
    final double scale = textHeight / m.height;
    final double fontSize = m.fontSize * scale;

    // فاصلهٔ حروف طوری که عرض جوهر دقیقاً = عرض S شود
    final String full = subtitle == null ? title : '$title $subtitle';
    final int gaps = math.max(full.runes.length - 1, 1);
    final double letterSpacing = (targetW - m.width * scale) / gaps;

    final TextPainter tp = TextPainter(
      text: _wordmarkSpan(title, subtitle, fontSize, letterSpacing),
      textDirection: TextDirection.ltr,
      textScaler: TextScaler.noScaling,
    )..layout();

    final Offset origin = Offset(
      _sLeft - m.left * scale,
      _textTop - m.top * scale,
    );

    canvas.save();
    // آشکارشدن از چپ به راست؛ اندازه و جای نوشته ثابت می‌ماند
    canvas.clipRect(
      Rect.fromLTWH(
        _sLeft - 6,
        _textTop - 20,
        (targetW + 12) * textProgress.clamp(0.0, 1.0),
        textHeight + 40,
      ),
    );
    tp.paint(canvas, origin);
    canvas.restore();
  }

  @override
  void paint(Canvas canvas, Size size) {
    final double scale = size.shortestSide / 1024;

    canvas.save();
    canvas.scale(scale);
    canvas.translate(-1.2, -1.3 + (showText ? _groupShiftY : 0));

    final Paint white = Paint()
      ..color = Colors.white
      ..isAntiAlias = true;

    // رسم مسیر S.
    if (roadProgress > 0) {
      canvas.drawRRect(
        RRect.fromRectAndRadius(
          const Rect.fromLTWH(330, 724 - _stroke / 2, 90, _stroke),
          const Radius.circular(14),
        ),
        white,
      );

      final Path road = _roadPath();
      final List<ui.PathMetric> metrics = road.computeMetrics().toList();

      final double total = metrics.fold<double>(
        0,
        (sum, metric) => sum + metric.length,
      );

      double remaining = total * roadProgress.clamp(0.0, 1.0).toDouble();

      final Path drawn = Path();

      for (final ui.PathMetric metric in metrics) {
        if (remaining <= 0) break;

        final double take = math.min(remaining, metric.length);

        drawn.addPath(metric.extractPath(0, take), Offset.zero);

        remaining -= take;
      }

      canvas.drawPath(
        drawn,
        Paint()
          ..color = Colors.white
          ..style = PaintingStyle.stroke
          ..strokeWidth = _stroke
          ..strokeCap = StrokeCap.butt
          ..strokeJoin = StrokeJoin.round
          ..isAntiAlias = true,
      );
    }

    // ظاهرشدن پین از نوک آن.
    if (pinProgress > 0) {
      canvas.save();

      const double tipY = _pinCy + 148 * _k;

      canvas.translate(_pinCx, tipY);
      canvas.scale(pinProgress.clamp(0.0, 1.25).toDouble());
      canvas.translate(-_pinCx, -tipY);

      canvas.drawPath(_pinPath(), white);

      canvas.drawCircle(
        const Offset(_pinCx, _pinCy),
        30 * _k,
        Paint()
          ..color = bgColor
          ..isAntiAlias = true,
      );

      canvas.restore();
    }

    // نوشتهٔ Safir
    if (showText) {
      _paintWordmark(canvas);
    }

    canvas.restore();
  }

  @override
  bool shouldRepaint(covariant _SafirLogoPainter oldDelegate) {
    return oldDelegate.roadProgress != roadProgress ||
        oldDelegate.pinProgress != pinProgress ||
        oldDelegate.bgColor != bgColor ||
        oldDelegate.textProgress != textProgress ||
        oldDelegate.ink != ink ||
        oldDelegate.title != title ||
        oldDelegate.subtitle != subtitle ||
        oldDelegate.textHeight != textHeight ||
        oldDelegate.showText != showText;
  }
}
