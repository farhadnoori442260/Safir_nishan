import 'package:easy_localization/easy_localization.dart';
import 'package:flutter/material.dart';

import 'package:safir_drivers/utils/app_colors.dart';
import 'package:safir_drivers/utils/driver_prefs.dart';

String _t(String key, String fallback) {
  final String v = key.tr();
  return (v.trim().isEmpty || v == key) ? fallback : v;
}

PreferredSizeWidget _appBar(String title) {
  return AppBar(
    title: Text(
      title,
      style: TextStyle(
        fontSize: 16,
        fontWeight: FontWeight.bold,
        color: AppColors.textPrimary,
      ),
    ),
    centerTitle: true,
    backgroundColor: AppColors.cardBackground,
    elevation: 0,
    scrolledUnderElevation: 0,
    surfaceTintColor: Colors.transparent,
    shape: Border(bottom: BorderSide(color: AppColors.borderLight, width: 1.0)),
    iconTheme: IconThemeData(color: AppColors.textPrimary),
  );
}

BoxDecoration _card() => BoxDecoration(
      color: AppColors.cardBackground,
      borderRadius: BorderRadius.circular(18),
      border: Border.all(color: AppColors.borderLight, width: 1.0),
    );

/// صدا و لرزش درخواست سفر (مثل بخش «صدا» و «لرزش» اسنپ)
class SoundVibrationPage extends StatelessWidget {
  const SoundVibrationPage({super.key});

  @override
  Widget build(BuildContext context) {
    final DriverPrefs prefs = DriverPrefs.instance;

    return Scaffold(
      backgroundColor: AppColors.background,
      appBar: _appBar(_t('settings_sound_vibration', 'صدا و لرزش')),
      body: ListView(
        padding: const EdgeInsets.fromLTRB(16, 16, 16, 32),
        children: <Widget>[
          _section(_t('settings_sound', 'صدا')),
          Container(
            decoration: _card(),
            child: ValueListenableBuilder<bool>(
              valueListenable: prefs.soundRequest,
              builder: (BuildContext context, bool v, Widget? _) => _switch(
                title: _t('sound_trip_request', 'درخواست سفر'),
                subtitle: _t(
                  'sound_trip_request_desc',
                  'پخش صدا هنگام رسیدن درخواست سفر',
                ),
                value: v,
                onChanged: prefs.setSoundRequest,
              ),
            ),
          ),
          const SizedBox(height: 20),
          _section(_t('settings_vibration', 'لرزش')),
          Container(
            decoration: _card(),
            child: ValueListenableBuilder<bool>(
              valueListenable: prefs.vibrateRequest,
              builder: (BuildContext context, bool v, Widget? _) => _switch(
                title: _t('vibration_trip_request', 'درخواست سفر'),
                subtitle: _t(
                  'vibration_trip_request_desc',
                  'لرزش گوشی هنگام رسیدن درخواست سفر',
                ),
                value: v,
                onChanged: prefs.setVibrateRequest,
              ),
            ),
          ),
          const SizedBox(height: 12),
          Container(
            decoration: _card(),
            child: ValueListenableBuilder<int>(
              valueListenable: prefs.vibrationStrength,
              builder: (BuildContext context, int strength, Widget? _) {
                final List<String> names = <String>[
                  _t('vibration_short', 'لرزش کوتاه'),
                  _t('vibration_medium', 'لرزش متوسط'),
                  _t('vibration_strong', 'لرزش شدید'),
                ];
                return Column(
                  children: <Widget>[
                    for (int i = 0; i < 3; i++) ...<Widget>[
                      InkWell(
                        onTap: () {
                          prefs.setVibrationStrength(i);
                          prefs.buzz(force: true);
                        },
                        child: Padding(
                          padding: const EdgeInsets.symmetric(
                            horizontal: 16,
                            vertical: 15,
                          ),
                          child: Row(
                            children: <Widget>[
                              Expanded(
                                child: Text(
                                  names[i],
                                  style: TextStyle(
                                    fontSize: 14,
                                    fontWeight: strength == i
                                        ? FontWeight.w700
                                        : FontWeight.w500,
                                    color: AppColors.textPrimary,
                                  ),
                                ),
                              ),
                              Icon(
                                strength == i
                                    ? Icons.check_circle
                                    : Icons.radio_button_unchecked,
                                color: strength == i
                                    ? AppColors.primaryBrand
                                    : AppColors.textSecondary,
                              ),
                            ],
                          ),
                        ),
                      ),
                      if (i != 2)
                        Divider(
                          height: 1,
                          thickness: 1.0,
                          color: AppColors.borderLight,
                        ),
                    ],
                  ],
                );
              },
            ),
          ),
        ],
      ),
    );
  }

  Widget _section(String text) {
    return Padding(
      padding: const EdgeInsetsDirectional.fromSTEB(6, 0, 6, 8),
      child: Text(
        text,
        style: TextStyle(
          fontSize: 12,
          fontWeight: FontWeight.w700,
          color: AppColors.textSecondary,
        ),
      ),
    );
  }

  Widget _switch({
    required String title,
    required String subtitle,
    required bool value,
    required ValueChanged<bool> onChanged,
  }) {
    return SwitchListTile(
      value: value,
      onChanged: onChanged,
      activeColor: AppColors.primaryButton,
      contentPadding: const EdgeInsets.symmetric(horizontal: 16, vertical: 4),
      title: Text(
        title,
        style: TextStyle(
          fontSize: 14,
          fontWeight: FontWeight.w600,
          color: AppColors.textPrimary,
        ),
      ),
      subtitle: Text(
        subtitle,
        style: TextStyle(fontSize: 11.5, color: AppColors.textSecondary),
      ),
    );
  }
}

/// اندازهٔ متن‌ها
class TextSizePage extends StatelessWidget {
  const TextSizePage({super.key});

  @override
  Widget build(BuildContext context) {
    final DriverPrefs prefs = DriverPrefs.instance;
    final List<String> names = <String>[
      _t('text_size_small', 'کوچک'),
      _t('text_size_normal', 'معمولی'),
      _t('text_size_large', 'بزرگ'),
      _t('text_size_xlarge', 'خیلی بزرگ'),
      _t('text_size_xxlarge', 'بسیار بزرگ'),
    ];

    return Scaffold(
      backgroundColor: AppColors.background,
      appBar: _appBar(_t('settings_text_size', 'اندازهٔ متن')),
      body: ValueListenableBuilder<double>(
        valueListenable: prefs.textScale,
        builder: (BuildContext context, double scale, Widget? _) {
          int index = DriverPrefs.textScales.indexOf(scale);
          if (index < 0) index = 1;

          return ListView(
            padding: const EdgeInsets.all(16),
            children: <Widget>[
              Container(
                padding: const EdgeInsets.all(16),
                decoration: _card(),
                child: Text(
                  _t(
                    'text_size_preview',
                    'با نوار زیر اندازهٔ نوشته‌ها را تنظیم کنید.',
                  ),
                  style: TextStyle(
                    fontSize: 15 * scale,
                    height: 1.6,
                    color: AppColors.textPrimary,
                  ),
                ),
              ),
              const SizedBox(height: 24),
              Center(
                child: Text(
                  names[index],
                  style: TextStyle(
                    fontSize: 16,
                    fontWeight: FontWeight.w800,
                    color: AppColors.primaryBrand,
                  ),
                ),
              ),
              Slider(
                value: index.toDouble(),
                min: 0,
                max: (DriverPrefs.textScales.length - 1).toDouble(),
                divisions: DriverPrefs.textScales.length - 1,
                activeColor: AppColors.primaryButton,
                onChanged: (double v) =>
                    prefs.setTextScale(DriverPrefs.textScales[v.round()]),
              ),
            ],
          );
        },
      ),
    );
  }
}
