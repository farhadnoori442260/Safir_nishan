import 'dart:io';

import 'package:easy_localization/easy_localization.dart' hide TextDirection;
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:provider/provider.dart';
import 'package:shamsi_date/shamsi_date.dart';

import '../../providers/auth_provider.dart';
import '../../providers/registration_provider.dart';
import '../../utils/app_colors.dart';
import '../../widgets/province_city_fields.dart';

class BasicInfoScreen extends StatefulWidget {
  const BasicInfoScreen({super.key});

  @override
  State<BasicInfoScreen> createState() => _BasicInfoScreenState();
}

class _BasicInfoScreenState extends State<BasicInfoScreen> {
  final GlobalKey<FormState> _formKey = GlobalKey<FormState>();

  static const List<String> _afghanMonths = <String>[
    'حمل',
    'ثور',
    'جوزا',
    'سرطان',
    'اسد',
    'سنبله',
    'میزان',
    'عقرب',
    'قوس',
    'جدی',
    'دلو',
    'حوت',
  ];

  @override
  void initState() {
    super.initState();

    WidgetsBinding.instance.addPostFrameCallback((_) {
      if (!mounted) return;

      final AuthenticationProvider authProvider =
          context.read<AuthenticationProvider>();

      final RegistrationProvider registrationProvider =
          context.read<RegistrationProvider>();

      registrationProvider.initFields(authProvider);
    });
  }

  // اگر ترجمه نبود، .tr() خود کلید را برمی‌گرداند؛ آن‌وقت متن پیش‌فرض
  String _t(String key, String fallback) {
    final String v = key.tr();
    return v == key ? fallback : v;
  }

  // حداقل سن برای راننده شدن
  static const int _minAge = 18;

  int get _maxBirthYear => Jalali.now().year - _minAge;

  static final RegExp _emailRe =
      RegExp(r'^[\w.+\-]+@[\w\-]+(\.[\w\-]+)+$');

  String _toAfghanDigits(String value) {
    const List<String> english = <String>[
      '0',
      '1',
      '2',
      '3',
      '4',
      '5',
      '6',
      '7',
      '8',
      '9',
    ];

    const List<String> farsi = <String>[
      '۰',
      '۱',
      '۲',
      '۳',
      '۴',
      '۵',
      '۶',
      '۷',
      '۸',
      '۹',
    ];

    for (int index = 0; index < 10; index++) {
      value = value.replaceAll(english[index], farsi[index]);
    }

    return value;
  }

  String _formatJalaliDate(Jalali date) {
    final String day = date.day.toString().padLeft(2, '0');
    final String year = date.year.toString();

    return '${_toAfghanDigits(day)} '
        '${_afghanMonths[date.month - 1]} '
        '${_toAfghanDigits(year)}';
  }

  String _formatJalaliStorage(Jalali date) {
    final String year = date.year.toString().padLeft(4, '0');
    final String month = date.month.toString().padLeft(2, '0');
    final String day = date.day.toString().padLeft(2, '0');

    return '$year/$month/$day';
  }

  Jalali _getInitialJalaliDate(String savedDate) {
    final Jalali today = Jalali.now();
    // پیش‌فرض: حدود ۳۰ ساله، تا راننده مجبور نباشد سال‌ها را از امسال عقب بیاید
    final Jalali fallback = Jalali(today.year - 30, 1, 1);

    try {
      final List<String> parts = savedDate.trim().split('/');

      if (parts.length != 3) {
        return fallback;
      }

      final int year = int.parse(parts[0]);
      final int month = int.parse(parts[1]);
      final int day = int.parse(parts[2]);

      if (year < 1300 ||
          year > _maxBirthYear ||
          month < 1 ||
          month > 12 ||
          day < 1) {
        return fallback;
      }

      final int maxDay = Jalali(year, month, 1).monthLength;

      if (day > maxDay) {
        return fallback;
      }

      return Jalali(year, month, day);
    } catch (_) {
      return fallback;
    }
  }

  Future<void> _showAfghanDatePicker(
    RegistrationProvider registrationProvider,
  ) async {
    Jalali selectedDate = _getInitialJalaliDate(
      registrationProvider.dobController.text,
    );

    final Jalali? result = await showModalBottomSheet<Jalali>(
      context: context,
      isScrollControlled: true,
      backgroundColor: Colors.transparent,
      builder: (BuildContext sheetContext) {
        return StatefulBuilder(
          builder: (
            BuildContext context,
            StateSetter setSheetState,
          ) {
            final int currentJalaliYear = _maxBirthYear;

            return Container(
              decoration: BoxDecoration(
                color: AppColors.cardBackground,
                borderRadius: const BorderRadius.vertical(
                  top: Radius.circular(28),
                ),
              ),
              padding: EdgeInsets.fromLTRB(
                20,
                16,
                20,
                MediaQuery.viewInsetsOf(context).bottom + 20,
              ),
              child: Column(
                mainAxisSize: MainAxisSize.min,
                crossAxisAlignment: CrossAxisAlignment.stretch,
                children: <Widget>[
                  Center(
                    child: Container(
                      width: 40,
                      height: 4,
                      decoration: BoxDecoration(
                        color: AppColors.handle,
                        borderRadius: BorderRadius.circular(2),
                      ),
                    ),
                  ),
                  const SizedBox(height: 16),
                  Text(
                    _t('pick_birth_date', 'انتخاب تاریخ تولد'),
                    style: TextStyle(
                      fontSize: 18,
                      fontWeight: FontWeight.bold,
                      color: AppColors.textPrimary,
                    ),
                  ),
                  const SizedBox(height: 16),
                  Container(
                    width: double.infinity,
                    padding: const EdgeInsets.symmetric(
                      horizontal: 16,
                      vertical: 14,
                    ),
                    decoration: BoxDecoration(
                      color: AppColors.primaryBrand.withOpacity(0.10),
                      borderRadius: BorderRadius.circular(16),
                    ),
                    child: Text(
                      _formatJalaliDate(selectedDate),
                      textAlign: TextAlign.center,
                      style: TextStyle(
                        fontSize: 18,
                        color: AppColors.primaryBrand,
                        fontWeight: FontWeight.bold,
                      ),
                    ),
                  ),
                  const SizedBox(height: 20),
                  Row(
                    children: <Widget>[
                      Expanded(
                        flex: 4,
                        child: _buildYearPicker(
                          selectedDate: selectedDate,
                          currentJalaliYear: currentJalaliYear,
                          onChanged: (int year) {
                            final int maxDay = Jalali(
                              year,
                              selectedDate.month,
                              1,
                            ).monthLength;

                            setSheetState(() {
                              selectedDate = Jalali(
                                year,
                                selectedDate.month,
                                selectedDate.day > maxDay
                                    ? maxDay
                                    : selectedDate.day,
                              );
                            });
                          },
                        ),
                      ),
                      const SizedBox(width: 10),
                      Expanded(
                        flex: 5,
                        child: _buildMonthPicker(
                          selectedDate: selectedDate,
                          onChanged: (int month) {
                            final int maxDay = Jalali(
                              selectedDate.year,
                              month,
                              1,
                            ).monthLength;

                            setSheetState(() {
                              selectedDate = Jalali(
                                selectedDate.year,
                                month,
                                selectedDate.day > maxDay
                                    ? maxDay
                                    : selectedDate.day,
                              );
                            });
                          },
                        ),
                      ),
                      const SizedBox(width: 10),
                      Expanded(
                        flex: 4,
                        child: _buildDayPicker(
                          selectedDate: selectedDate,
                          onChanged: (int day) {
                            setSheetState(() {
                              selectedDate = Jalali(
                                selectedDate.year,
                                selectedDate.month,
                                day,
                              );
                            });
                          },
                        ),
                      ),
                    ],
                  ),
                  const SizedBox(height: 24),
                  Row(
                    children: <Widget>[
                      Expanded(
                        child: OutlinedButton(
                          onPressed: () => Navigator.pop(sheetContext),
                          style: OutlinedButton.styleFrom(
                            foregroundColor: AppColors.textPrimary,
                            side: BorderSide(
                              color: AppColors.borderLight,
                            ),
                            padding: const EdgeInsets.symmetric(
                              vertical: 14,
                            ),
                            shape: RoundedRectangleBorder(
                              borderRadius: BorderRadius.circular(16),
                            ),
                          ),
                          child: Text(_t('cancel', 'لغو')),
                        ),
                      ),
                      const SizedBox(width: 12),
                      Expanded(
                        child: ElevatedButton(
                          onPressed: () {
                            Navigator.pop(
                              sheetContext,
                              selectedDate,
                            );
                          },
                          style: ElevatedButton.styleFrom(
                            backgroundColor: AppColors.primaryButton,
                            foregroundColor: AppColors.buttonText,
                            elevation: 0,
                            padding: const EdgeInsets.symmetric(
                              vertical: 14,
                            ),
                            shape: RoundedRectangleBorder(
                              borderRadius: BorderRadius.circular(16),
                            ),
                          ),
                          child: Text(_t('confirm', 'تأیید')),
                        ),
                      ),
                    ],
                  ),
                ],
              ),
            );
          },
        );
      },
    );

    if (result == null) {
      return;
    }

    registrationProvider.dobController.text =
        _formatJalaliStorage(result);

    registrationProvider.checkBasicFormValidity();
  }

  Widget _wheelContainer({
    required Widget child,
  }) {
    return Container(
      height: 160,
      decoration: BoxDecoration(
        border: Border.all(
          color: AppColors.borderLight,
        ),
        borderRadius: BorderRadius.circular(16),
        color: AppColors.background,
      ),
      clipBehavior: Clip.antiAlias,
      child: Stack(
        children: <Widget>[
          // نوار ملایم پشت مقدار انتخاب‌شده
          Center(
            child: IgnorePointer(
              child: Container(
                height: 40,
                margin: const EdgeInsets.symmetric(horizontal: 6),
                decoration: BoxDecoration(
                  color: AppColors.primaryBrand.withOpacity(0.08),
                  borderRadius: BorderRadius.circular(10),
                ),
              ),
            ),
          ),
          Positioned.fill(child: child),
        ],
      ),
    );
  }

  Widget _pickerTitle(String title) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: <Widget>[
        Text(
          title,
          style: TextStyle(
            fontSize: 12,
            fontWeight: FontWeight.w600,
            color: AppColors.textSecondary,
          ),
        ),
        const SizedBox(height: 6),
      ],
    );
  }

  Widget _buildYearPicker({
    required Jalali selectedDate,
    required int currentJalaliYear,
    required ValueChanged<int> onChanged,
  }) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: <Widget>[
        _pickerTitle(_t('year', 'سال')),
        _wheelContainer(
          child: ListWheelScrollView.useDelegate(
            key: ValueKey<int>(selectedDate.year),
            controller: FixedExtentScrollController(
              initialItem: selectedDate.year - 1300,
            ),
            itemExtent: 40,
            perspective: 0.005,
            diameterRatio: 1.2,
            physics: const FixedExtentScrollPhysics(),
            onSelectedItemChanged: (int index) {
              onChanged(1300 + index);
            },
            childDelegate: ListWheelChildBuilderDelegate(
              builder: (BuildContext context, int index) {
                if (index < 0 || index > currentJalaliYear - 1300) {
                  return null;
                }

                final int year = 1300 + index;
                final bool isSelected = year == selectedDate.year;

                return Center(
                  child: Text(
                    _toAfghanDigits(year.toString()),
                    style: TextStyle(
                      fontSize: isSelected ? 16 : 14,
                      fontWeight: isSelected
                          ? FontWeight.bold
                          : FontWeight.normal,
                      color: isSelected
                          ? AppColors.primaryBrand
                          : AppColors.textPrimary.withOpacity(0.55),
                    ),
                  ),
                );
              },
              childCount: currentJalaliYear - 1300 + 1,
            ),
          ),
        ),
      ],
    );
  }

  Widget _buildMonthPicker({
    required Jalali selectedDate,
    required ValueChanged<int> onChanged,
  }) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: <Widget>[
        _pickerTitle(_t('month', 'ماه')),
        _wheelContainer(
          child: ListWheelScrollView.useDelegate(
            key: ValueKey<int>(selectedDate.month),
            controller: FixedExtentScrollController(
              initialItem: selectedDate.month - 1,
            ),
            itemExtent: 40,
            perspective: 0.005,
            diameterRatio: 1.2,
            physics: const FixedExtentScrollPhysics(),
            onSelectedItemChanged: (int index) {
              onChanged(index + 1);
            },
            childDelegate: ListWheelChildBuilderDelegate(
              builder: (BuildContext context, int index) {
                if (index < 0 || index > 11) {
                  return null;
                }

                final int month = index + 1;
                final bool isSelected = month == selectedDate.month;

                return Center(
                  child: Text(
                    _afghanMonths[index],
                    style: TextStyle(
                      fontSize: isSelected ? 16 : 14,
                      fontWeight: isSelected
                          ? FontWeight.bold
                          : FontWeight.normal,
                      color: isSelected
                          ? AppColors.primaryBrand
                          : AppColors.textPrimary.withOpacity(0.55),
                    ),
                  ),
                );
              },
              childCount: 12,
            ),
          ),
        ),
      ],
    );
  }

  Widget _buildDayPicker({
    required Jalali selectedDate,
    required ValueChanged<int> onChanged,
  }) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: <Widget>[
        _pickerTitle(_t('day', 'روز')),
        _wheelContainer(
          child: ListWheelScrollView.useDelegate(
            key: ValueKey<String>(
              '${selectedDate.year}-${selectedDate.month}-${selectedDate.day}',
            ),
            controller: FixedExtentScrollController(
              initialItem: selectedDate.day - 1,
            ),
            itemExtent: 40,
            perspective: 0.005,
            diameterRatio: 1.2,
            physics: const FixedExtentScrollPhysics(),
            onSelectedItemChanged: (int index) {
              onChanged(index + 1);
            },
            childDelegate: ListWheelChildBuilderDelegate(
              builder: (BuildContext context, int index) {
                final int maxDays = selectedDate.monthLength;

                if (index < 0 || index >= maxDays) {
                  return null;
                }

                final int day = index + 1;
                final bool isSelected = day == selectedDate.day;

                return Center(
                  child: Text(
                    _toAfghanDigits(day.toString()),
                    style: TextStyle(
                      fontSize: isSelected ? 16 : 14,
                      fontWeight: isSelected
                          ? FontWeight.bold
                          : FontWeight.normal,
                      color: isSelected
                          ? AppColors.primaryBrand
                          : AppColors.textPrimary.withOpacity(0.55),
                    ),
                  ),
                );
              },
              childCount: selectedDate.monthLength,
            ),
          ),
        ),
      ],
    );
  }

  InputDecoration _inputDecoration({
    required String labelText,
    IconData? icon,
    Widget? suffixIcon,
    String? hintText,
  }) {
    // چوکات مثل قبل: بدون پس‌زمینهٔ رنگی تا برچسب دقیقاً داخل بریدگی خط بنشیند.
    final OutlineInputBorder baseBorder = OutlineInputBorder(
      borderRadius: BorderRadius.circular(12),
      borderSide: BorderSide(
        color: AppColors.fieldBorder,
      ),
    );

    final Color errorColor = AppColors.danger;

    // مهم: اندازه و ضخامت فونت برچسب در حالت عادی و شناور یکی است، وگرنه
    // عرض بریدگی خط با عرض متن نمی‌خواند و خط از روی برچسب رد می‌شود.
    // رنگ: خاکستری؛ فقط هنگام تایپ (فوکوس) سبز می‌شود.
    final TextStyle labelBase = TextStyle(
      fontSize: 14,
      color: AppColors.textSecondary,
    );

    return InputDecoration(
      labelText: labelText,
      hintText: hintText,
      labelStyle: labelBase,
      floatingLabelStyle: MaterialStateTextStyle.resolveWith(
        (Set<MaterialState> states) {
          if (states.contains(MaterialState.error)) {
            return labelBase.copyWith(color: errorColor);
          }

          if (states.contains(MaterialState.focused)) {
            return labelBase.copyWith(color: AppColors.primaryBrand);
          }

          return labelBase;
        },
      ),
      prefixIcon: icon == null ? null : Icon(icon, size: 20),
      prefixIconColor: MaterialStateColor.resolveWith(
        (Set<MaterialState> states) {
          return states.contains(MaterialState.focused)
              ? AppColors.primaryBrand
              : AppColors.textSecondary;
        },
      ),
      border: baseBorder,
      enabledBorder: baseBorder,
      focusedBorder: baseBorder.copyWith(
        borderSide: BorderSide(
          color: AppColors.primaryBrand,
          width: 2,
        ),
      ),
      errorBorder: baseBorder.copyWith(
        borderSide: BorderSide(color: errorColor),
      ),
      focusedErrorBorder: baseBorder.copyWith(
        borderSide: BorderSide(color: errorColor, width: 2),
      ),
      contentPadding: const EdgeInsets.symmetric(
        horizontal: 14,
        vertical: 15,
      ),
      suffixIcon: suffixIcon,
    );
  }

  /// ظاهر مشترک کارت‌ها؛ بدون سایه (هم سبک‌تر است، هم در حالت تاریک تمیز).
  BoxDecoration _cardDecoration() {
    return BoxDecoration(
      color: AppColors.cardBackground,
      borderRadius: BorderRadius.circular(24),
      border: Border.all(
        color: AppColors.borderLight,
      ),
    );
  }

  void _submitBasicInfo() {
    FocusScope.of(context).unfocus();

    if (_formKey.currentState?.validate() != true) {
      return;
    }

    final RegistrationProvider registrationProvider =
        context.read<RegistrationProvider>();

    final String email = registrationProvider.emailController.text.trim();

    final bool isValid =
        registrationProvider.firstNameController.text.trim().isNotEmpty &&
            registrationProvider.lastNameController.text.trim().isNotEmpty &&
            _emailRe.hasMatch(email) &&
            registrationProvider.province.isNotEmpty &&
            registrationProvider.city.isNotEmpty &&
            registrationProvider.addressController.text.trim().length >= 5 &&
            registrationProvider.phoneController.text.trim().length >= 9 &&
            registrationProvider.dobController.text.trim().isNotEmpty;

    registrationProvider.checkBasicFormValidity();

    if (!isValid) {
      return;
    }

    Navigator.pop(context, true);
  }

  @override
  Widget build(BuildContext context) {
    final RegistrationProvider registrationProvider =
        context.read<RegistrationProvider>();

    return Scaffold(
      // کیبورد فقط یک‌بار و به‌صورت نرم در _KeyboardAwareBody مدیریت می‌شود.
      resizeToAvoidBottomInset: false,
      backgroundColor: AppColors.background,
      appBar: AppBar(
        title: Text(
          'basic_info_title'.tr(),
          style: TextStyle(
            fontSize: 17,
            fontWeight: FontWeight.w700,
            color: AppColors.textPrimary,
          ),
        ),
        centerTitle: true,
        elevation: 0,
        scrolledUnderElevation: 0,
        surfaceTintColor: Colors.transparent,
        backgroundColor: AppColors.cardBackground,
        shape: Border(
          bottom: BorderSide(
            color: AppColors.borderLight,
          ),
        ),
        actions: <Widget>[
          TextButton(
            onPressed: () => Navigator.pop(context),
            child: Text(
              'close'.tr(),
              style: TextStyle(
                color: AppColors.textSecondary,
                fontWeight: FontWeight.w600,
              ),
            ),
          ),
        ],
      ),
      body: _KeyboardAwareBody(
        child: Padding(
          padding: const EdgeInsets.fromLTRB(16, 12, 16, 16),
          child: Form(
            key: _formKey,
            child: Column(
              children: <Widget>[
                Expanded(
                  child: SingleChildScrollView(
                    keyboardDismissBehavior:
                        ScrollViewKeyboardDismissBehavior.manual,
                    padding: const EdgeInsets.only(bottom: 12),
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.center,
                      children: <Widget>[
                        RepaintBoundary(child: _buildProfilePhotoCard()),
                        const SizedBox(height: 16),
                        RepaintBoundary(
                          child: _buildFormCard(registrationProvider),
                        ),
                      ],
                    ),
                  ),
                ),
                const SizedBox(height: 10),
                _buildSubmitButton(),
              ],
            ),
          ),
        ),
      ),
    );
  }

  Widget _buildProfilePhotoCard() {
    return Selector<RegistrationProvider, String?>(
      selector: (
        BuildContext context,
        RegistrationProvider provider,
      ) {
        return provider.profilePhoto?.path;
      },
      builder: (
        BuildContext context,
        String? photoPath,
        Widget? child,
      ) {
        final RegistrationProvider registrationProvider =
            context.read<RegistrationProvider>();

        return Container(
          width: double.infinity,
          decoration: _cardDecoration(),
          child: Column(
            children: <Widget>[
              const SizedBox(height: 20),
              Container(
                padding: const EdgeInsets.all(3),
                decoration: BoxDecoration(
                  shape: BoxShape.circle,
                  border: Border.all(
                    color: AppColors.borderLight,
                    width: 1.5,
                  ),
                ),
                child: CircleAvatar(
                  radius: 52,
                  backgroundColor: AppColors.background,
                  backgroundImage:
                      photoPath != null ? FileImage(File(photoPath)) : null,
                  child: photoPath == null
                      ? Icon(
                          Icons.person_rounded,
                          size: 52,
                          color: AppColors.textSecondary.withOpacity(0.5),
                        )
                      : null,
                ),
              ),
              const SizedBox(height: 14),
              TextButton.icon(
                onPressed: registrationProvider.pickProfileImageFromGallary,
                style: TextButton.styleFrom(
                  backgroundColor: AppColors.primaryBrand.withOpacity(0.10),
                  foregroundColor: AppColors.primaryBrand,
                  padding: const EdgeInsets.symmetric(
                    horizontal: 18,
                    vertical: 10,
                  ),
                  shape: const StadiumBorder(),
                ),
                icon: const Icon(
                  Icons.add_a_photo_outlined,
                  size: 18,
                ),
                label: Text(
                  'add_profile_photo'.tr(),
                  style: const TextStyle(
                    fontWeight: FontWeight.w600,
                    fontSize: 13.5,
                  ),
                ),
              ),
              const SizedBox(height: 18),
            ],
          ),
        );
      },
    );
  }

  Widget _buildFormCard(
    RegistrationProvider registrationProvider,
  ) {
    return Container(
      decoration: _cardDecoration(),
      child: Padding(
        padding: const EdgeInsets.all(16),
        child: Column(
          children: <Widget>[
            TextFormField(
              controller: registrationProvider.firstNameController,
              textInputAction: TextInputAction.next,
              textCapitalization: TextCapitalization.words,
              decoration: _inputDecoration(
                labelText: 'first_name'.tr(),
                icon: Icons.person_outline_rounded,
              ),
              validator: (String? value) {
                if (value == null || value.trim().isEmpty) {
                  return 'err_first_name'.tr();
                }
                return null;
              },
              onChanged: (_) {
                registrationProvider.checkBasicFormValidity();
              },
            ),
            const SizedBox(height: 16),
            TextFormField(
              controller: registrationProvider.lastNameController,
              textInputAction: TextInputAction.next,
              textCapitalization: TextCapitalization.words,
              decoration: _inputDecoration(
                labelText: 'last_name'.tr(),
                icon: Icons.badge_outlined,
              ),
              validator: (String? value) {
                if (value == null || value.trim().isEmpty) {
                  return 'err_last_name'.tr();
                }
                return null;
              },
              onChanged: (_) {
                registrationProvider.checkBasicFormValidity();
              },
            ),
            const SizedBox(height: 16),
            TextFormField(
              controller: registrationProvider.emailController,
              keyboardType: TextInputType.emailAddress,
              textInputAction: TextInputAction.next,
              autocorrect: false,
              enableSuggestions: false,
              decoration: _inputDecoration(
                labelText: 'email'.tr(),
                icon: Icons.mail_outline_rounded,
              ),
              validator: (String? value) {
                final String email = value?.trim() ?? '';

                if (!_emailRe.hasMatch(email)) {
                  return 'invalid_email_error'.tr();
                }

                return null;
              },
              onChanged: (_) {
                registrationProvider.checkBasicFormValidity();
              },
            ),
            const SizedBox(height: 16),
            const ProvinceCityFields(),
            const SizedBox(height: 16),
            TextFormField(
              controller: registrationProvider.addressController,
              textInputAction: TextInputAction.next,
              minLines: 1,
              maxLines: 2,
              decoration: _inputDecoration(
                labelText: 'home_address'.tr(),
                icon: Icons.home_outlined,
              ),
              validator: (String? value) {
                if (value == null || value.trim().length < 5) {
                  return 'err_address'.tr();
                }

                return null;
              },
              onChanged: (_) {
                registrationProvider.checkBasicFormValidity();
              },
            ),
            const SizedBox(height: 16),
            Directionality(
              textDirection: TextDirection.ltr,
              child: TextFormField(
                controller: registrationProvider.phoneController,
                keyboardType: TextInputType.phone,
                textInputAction: TextInputAction.next,
                inputFormatters: <TextInputFormatter>[_AsciiDigitsFormatter()],
                decoration: _inputDecoration(
                  labelText: 'mobile_number'.tr(),
                  icon: Icons.phone_outlined,
                ),
                validator: (String? value) {
                  if (value == null || value.trim().length < 9) {
                    return 'err_phone'.tr();
                  }

                  return null;
                },
                onChanged: (_) {
                  registrationProvider.checkBasicFormValidity();
                },
              ),
            ),
            const SizedBox(height: 16),
            TextFormField(
              controller: registrationProvider.dobController,
              readOnly: true,
              showCursor: false,
              decoration: _inputDecoration(
                labelText: _t('birth_date_label', 'تاریخ تولد (هجری شمسی)'),
                hintText: _t('birth_date_hint', 'مثلاً ۱۳۷۰/۰۲/۲۲'),
                icon: Icons.cake_outlined,
                suffixIcon: Icon(
                  Icons.calendar_month_outlined,
                  size: 20,
                  color: AppColors.primaryBrand,
                ),
              ),
              validator: (String? value) {
                if (value == null || value.trim().isEmpty) {
                  return _t('err_birth_date', 'تاریخ تولد را انتخاب کنید');
                }

                return null;
              },
              onTap: () {
                FocusScope.of(context).unfocus();
                _showAfghanDatePicker(registrationProvider);
              },
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildSubmitButton() {
    return Selector<RegistrationProvider, bool>(
      selector: (
        BuildContext context,
        RegistrationProvider provider,
      ) {
        return provider.isFormValidBasic;
      },
      builder: (
        BuildContext context,
        bool isFormValid,
        Widget? child,
      ) {
        return SizedBox(
          width: double.infinity,
          height: 54,
          child: ElevatedButton(
            onPressed: isFormValid ? _submitBasicInfo : null,
            style: ElevatedButton.styleFrom(
              backgroundColor: AppColors.primaryButton,
              foregroundColor: AppColors.buttonText,
              disabledBackgroundColor: AppColors.borderLight,
              disabledForegroundColor: AppColors.textSecondary,
              elevation: 0,
              shadowColor: Colors.transparent,
              shape: RoundedRectangleBorder(
                borderRadius: BorderRadius.circular(16),
              ),
            ),
            child: Text(
              'confirm_and_submit'.tr(),
              style: const TextStyle(
                fontSize: 16,
                fontWeight: FontWeight.w700,
              ),
            ),
          ),
        );
      },
    );
  }
}

/// فضای کیبورد و نوار پایین سیستم را یک‌بار و با انیمیشن کوتاه حساب می‌کند.
/// فقط همین ویجت به viewInsets گوش می‌دهد؛ [child] هر فریم دوباره ساخته نمی‌شود.
class _KeyboardAwareBody extends StatelessWidget {
  const _KeyboardAwareBody({required this.child});

  final Widget child;

  @override
  Widget build(BuildContext context) {
    final double keyboard = MediaQuery.viewInsetsOf(context).bottom;
    final EdgeInsets safe = MediaQuery.paddingOf(context);

    return AnimatedPadding(
      // مدت کوتاه تا دکمه همراه کیبورد سنگین و دیرجنب حرکت نکند.
      duration: const Duration(milliseconds: 80),
      curve: Curves.easeOut,
      padding: EdgeInsets.only(
        left: safe.left,
        right: safe.right,
        bottom: keyboard > safe.bottom ? keyboard : safe.bottom,
      ),
      child: child,
    );
  }
}
/// ارقام فارسی/عربی را به لاتین تبدیل می‌کند و فقط رقم و + می‌پذیرد؛
/// تا شماره همیشه در Firebase و سرور یک‌شکل ذخیره شود.
class _AsciiDigitsFormatter extends TextInputFormatter {
  @override
  TextEditingValue formatEditUpdate(
    TextEditingValue oldValue,
    TextEditingValue newValue,
  ) {
    const String fa = '۰۱۲۳۴۵۶۷۸۹';
    const String ar = '٠١٢٣٤٥٦٧٨٩';
    final StringBuffer out = StringBuffer();
    for (final int r in newValue.text.runes) {
      final String c = String.fromCharCode(r);
      final int fi = fa.indexOf(c);
      final int ai = ar.indexOf(c);
      if (fi >= 0) {
        out.write(fi);
      } else if (ai >= 0) {
        out.write(ai);
      } else if (RegExp(r'[0-9+]').hasMatch(c)) {
        out.write(c);
      }
    }
    final String text = out.toString();
    return TextEditingValue(
      text: text,
      selection: TextSelection.collapsed(
        offset: newValue.selection.baseOffset.clamp(0, text.length),
      ),
    );
  }
}
