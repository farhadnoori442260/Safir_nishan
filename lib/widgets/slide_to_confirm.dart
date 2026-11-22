import 'package:flutter/material.dart';
import 'package:flutter/services.dart';

import 'package:safir_drivers/utils/app_colors.dart';

/// تأیید با کشیدن؛ برای مراحل برگشت‌ناپذیر سفر (شروع و پایان).
/// جهت کشیدن با زبان (راست‌به‌چپ / چپ‌به‌راست) خودکار تنظیم می‌شود.
class SlideToConfirm extends StatefulWidget {
  const SlideToConfirm({
    super.key,
    required this.label,
    required this.color,
    required this.onConfirmed,
    this.loading = false,
  });

  final String label;
  final Color color;
  final bool loading;
  final Future<void> Function() onConfirmed;

  @override
  State<SlideToConfirm> createState() => _SlideToConfirmState();
}

class _SlideToConfirmState extends State<SlideToConfirm> {
  static const double _height = 58;
  static const double _handle = 50;
  static const double _pad = 4;

  double _dx = 0;
  bool _dragging = false;
  bool _busy = false;

  Future<void> _finish(double maxDx) async {
    setState(() {
      _dragging = false;
      _dx = maxDx;
      _busy = true;
    });
    HapticFeedback.mediumImpact();

    try {
      await widget.onConfirmed();
    } finally {
      if (mounted) {
        setState(() {
          _dx = 0;
          _busy = false;
        });
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    final bool rtl = Directionality.of(context) == TextDirection.rtl;
    final bool working = _busy || widget.loading;

    return LayoutBuilder(
      builder: (BuildContext context, BoxConstraints constraints) {
        final double maxDx =
            (constraints.maxWidth - _handle - _pad * 2).clamp(0.0, 4000.0);
        final double progress =
            maxDx == 0 ? 0 : (_dx / maxDx).clamp(0.0, 1.0);
        final Duration anim =
            _dragging ? Duration.zero : const Duration(milliseconds: 220);

        return Container(
          height: _height,
          decoration: BoxDecoration(
            color: AppColors.cardBackground,
            borderRadius: BorderRadius.circular(18),
            border: Border.all(color: AppColors.borderLight),
          ),
          child: ClipRRect(
            borderRadius: BorderRadius.circular(17),
            child: Stack(
              children: <Widget>[
                AnimatedPositionedDirectional(
                  duration: anim,
                  start: 0,
                  top: 0,
                  bottom: 0,
                  width: _pad + _dx + _handle,
                  child: ColoredBox(color: widget.color.withOpacity(0.16)),
                ),
                Center(
                  child: Opacity(
                    opacity: (1 - progress * 1.4).clamp(0.0, 1.0),
                    child: Padding(
                      padding: const EdgeInsets.symmetric(horizontal: 64),
                      child: Text(
                        widget.label,
                        maxLines: 1,
                        overflow: TextOverflow.ellipsis,
                        style: TextStyle(
                          color: AppColors.textPrimary,
                          fontSize: 14.5,
                          fontWeight: FontWeight.w800,
                        ),
                      ),
                    ),
                  ),
                ),
                AnimatedPositionedDirectional(
                  duration: anim,
                  start: _pad + _dx,
                  top: (_height - _handle) / 2 - 1,
                  child: GestureDetector(
                    behavior: HitTestBehavior.opaque,
                    onHorizontalDragStart: working
                        ? null
                        : (_) => setState(() => _dragging = true),
                    onHorizontalDragUpdate: working
                        ? null
                        : (DragUpdateDetails d) {
                            final double delta =
                                rtl ? -d.delta.dx : d.delta.dx;
                            setState(() {
                              _dx = (_dx + delta).clamp(0.0, maxDx);
                            });
                          },
                    onHorizontalDragEnd: working
                        ? null
                        : (_) {
                            if (maxDx > 0 && _dx / maxDx >= 0.85) {
                              _finish(maxDx);
                            } else {
                              setState(() {
                                _dragging = false;
                                _dx = 0;
                              });
                            }
                          },
                    child: Container(
                      width: _handle,
                      height: _handle,
                      decoration: BoxDecoration(
                        color: widget.color,
                        borderRadius: BorderRadius.circular(14),
                      ),
                      child: working
                          ? Padding(
                              padding: const EdgeInsets.all(14),
                              child: CircularProgressIndicator(
                                strokeWidth: 2.4,
                                color: AppColors.buttonText,
                              ),
                            )
                          : Icon(
                              rtl
                                  ? Icons.keyboard_double_arrow_left_rounded
                                  : Icons.keyboard_double_arrow_right_rounded,
                              color: AppColors.buttonText,
                              size: 26,
                            ),
                    ),
                  ),
                ),
              ],
            ),
          ),
        );
      },
    );
  }
}
