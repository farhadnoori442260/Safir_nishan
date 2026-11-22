import 'package:flutter/material.dart';

import 'package:safir_drivers/utils/driver_prefs.dart';

/// اندازهٔ متن انتخابی راننده را روی همهٔ فرزندان اعمال می‌کند.
/// برای پوشش کل برنامه در MaterialApp:
///   builder: (context, child) => DriverTextScale(child: child ?? const SizedBox()),
class DriverTextScale extends StatelessWidget {
  const DriverTextScale({super.key, required this.child});

  final Widget child;

  @override
  Widget build(BuildContext context) {
    return ValueListenableBuilder<double>(
      valueListenable: DriverPrefs.instance.textScale,
      builder: (BuildContext context, double scale, Widget? _) {
        final MediaQueryData mq = MediaQuery.of(context);
        return MediaQuery(
          data: mq.copyWith(
            textScaler: TextScaler.linear(mq.textScaler.scale(1) * scale),
          ),
          child: child,
        );
      },
    );
  }
}
