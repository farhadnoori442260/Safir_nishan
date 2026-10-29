import 'dart:io';

import 'package:easy_localization/easy_localization.dart';
import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import 'package:shamsi_date/shamsi_date.dart';

import 'package:safir_drivers/methods/common_method.dart';
import 'package:safir_drivers/providers/registration_provider.dart';
import 'package:safir_drivers/utils/app_colors.dart';

class BasicDriverInfoUpdateScreen extends StatefulWidget {
  const BasicDriverInfoUpdateScreen({super.key});

  @override
  State<BasicDriverInfoUpdateScreen> createState() =>
      _BasicDriverInfoUpdateScreenState();
}

class _BasicDriverInfoUpdateScreenState
    extends State<BasicDriverInfoUpdateScreen> {
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

    const List<String> afghan = <String>[
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

    for (int index = 0; index < english.length; index++) {
      value = value.replaceAll(english[index], afghan[index]);
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

    try {
      final List<String> parts = savedDate.trim().split('/');

      if (parts.length != 3) {
        return today;
      }

      final int year = int.parse(parts[0]);
      final int month = int.parse(parts[1]);
      final int day = int.parse(parts[2]);

      if (year < 1300 ||
          year > today.year ||
          month < 1 ||
          month > 12 ||
          day < 1) {
        return today;
      }

      final int maxDay = Jalali(year, month, 1).monthLength;

      if (day > maxDay) {
        return today;
      }

      return Jalali(year, month, day);
    } catch (_) {
      return today;
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
            final int currentJalaliYear = Jalali.now().year;

            return SafeArea(
              top: false,
              child: Container(
                decoration: const BoxDecoration(
                  color: AppColors.cardBackground,
                  borderRadius: BorderRadius.vertical(
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
                          color: AppColors.textSecondary.withOpacity(0.25),
                          borderRadius: BorderRadius.circular(2),
                        ),
                      ),
                    ),
                    const SizedBox(height: 16),
                    Text(
                      'dob_picker_title'.tr(),
                      style: const TextStyle(
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
                        style: const TextStyle(
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
                          child: _buildPickerColumn(
                            label: 'dob_year_label'.tr(),
                            child: ListWheelScrollView.useDelegate(
                              controller: FixedExtentScrollController(
                                initialItem: selectedDate.year - 1300,
                              ),
                              itemExtent: 40,
                              perspective: 0.005,
                              diameterRatio: 1.2,
                              physics: const FixedExtentScrollPhysics(),
                              onSelectedItemChanged: (int index) {
                                final int year = 1300 + index;
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
                              childDelegate: ListWheelChildBuilderDelegate(
                                childCount: currentJalaliYear - 1300 + 1,
                                builder: (
                                  BuildContext context,
                                  int index,
                                ) {
                                  final int year = 1300 + index;
                                  final bool isSelected =
                                      year == selectedDate.year;

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
                              ),
                            ),
                          ),
                        ),
                        const SizedBox(width: 10),
                        Expanded(
                          flex: 5,
                          child: _buildPickerColumn(
                            label: 'dob_month_label'.tr(),
                            child: ListWheelScrollView.useDelegate(
                              controller: FixedExtentScrollController(
                                initialItem: selectedDate.month - 1,
                              ),
                              itemExtent: 40,
                              perspective: 0.005,
                              diameterRatio: 1.2,
                              physics: const FixedExtentScrollPhysics(),
                              onSelectedItemChanged: (int index) {
                                final int month = index + 1;
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
                              childDelegate: ListWheelChildBuilderDelegate(
                                childCount: 12,
                                builder: (
                                  BuildContext context,
                                  int index,
                                ) {
                                  final int month = index + 1;
                                  final bool isSelected =
                                      month == selectedDate.month;

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
                              ),
                            ),
                          ),
                        ),
                        const SizedBox(width: 10),
                        Expanded(
                          flex: 4,
                          child: _buildPickerColumn(
                            label: 'dob_day_label'.tr(),
                            child: ListWheelScrollView.useDelegate(
                              controller: FixedExtentScrollController(
                                initialItem: selectedDate.day - 1,
                              ),
                              itemExtent: 40,
                              perspective: 0.005,
                              diameterRatio: 1.2,
                              physics: const FixedExtentScrollPhysics(),
                              onSelectedItemChanged: (int index) {
                                final int day = index + 1;

                                setSheetState(() {
                                  selectedDate = Jalali(
                                    selectedDate.year,
                                    selectedDate.month,
                                    day,
                                  );
                                });
                              },
                              childDelegate: ListWheelChildBuilderDelegate(
                                childCount: selectedDate.monthLength,
                                builder: (
                                  BuildContext context,
                                  int index,
                                ) {
                                  final int day = index + 1;
                                  final bool isSelected =
                                      day == selectedDate.day;

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
                              ),
                            ),
                          ),
                        ),
                      ],
                    ),
                    const SizedBox(height: 24),
                    Row(
                      children: <Widget>[
                        Expanded(
                          child: OutlinedButton(
                            onPressed: () {
                              Navigator.pop(sheetContext);
                            },
                            style: OutlinedButton.styleFrom(
                              foregroundColor: AppColors.textPrimary,
                              side: BorderSide(
                                color: AppColors.textSecondary
                                    .withOpacity(0.25),
                              ),
                              padding: const EdgeInsets.symmetric(
                                vertical: 14,
                              ),
                              shape: RoundedRectangleBorder(
                                borderRadius: BorderRadius.circular(16),
                              ),
                            ),
                            child: Text('cancel'.tr()),
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
                            child: Text('confirm'.tr()),
                          ),
                        ),
                      ],
                    ),
                  ],
                ),
              ),
            );
          },
        );
      },
    );

    if (result == null) {
      return;
    }

    registrationProvider.dobController.text = _formatJalaliStorage(result);
    registrationProvider.checkBasicFormValidity();
  }

  Widget _buildPickerColumn({
    required String label,
    required Widget child,
  }) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: <Widget>[
        Text(
          label,
          style: const TextStyle(
            fontSize: 12,
            fontWeight: FontWeight.w600,
            color: AppColors.textSecondary,
          ),
        ),
        const SizedBox(height: 6),
        Container(
          height: 160,
          decoration: BoxDecoration(
            border: Border.all(
              color: AppColors.textSecondary.withOpacity(0.14),
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
        color: AppColors.textSecondary.withOpacity(0.30),
      ),
    );

    const Color errorColor = Color(0xFFD64545);

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
      disabledBorder: baseBorder.copyWith(
        borderSide: BorderSide(
          color: AppColors.textSecondary.withOpacity(0.15),
        ),
      ),
      focusedBorder: baseBorder.copyWith(
        borderSide: const BorderSide(
          color: AppColors.primaryBrand,
          width: 2,
        ),
      ),
      errorBorder: baseBorder.copyWith(
        borderSide: const BorderSide(color: errorColor),
      ),
      focusedErrorBorder: baseBorder.copyWith(
        borderSide: const BorderSide(color: errorColor, width: 2),
      ),
      contentPadding: const EdgeInsets.symmetric(
        horizontal: 14,
        vertical: 15,
      ),
      suffixIcon: suffixIcon,
    );
  }

  /// ظاهر مشترک کارت‌ها؛ سایه‌ی سبک تا هنگام باز شدن کیبورد سنگین نشود.
  BoxDecoration _cardDecoration() {
    return BoxDecoration(
      color: AppColors.cardBackground,
      borderRadius: BorderRadius.circular(24),
      border: Border.all(
        color: AppColors.textSecondary.withOpacity(0.10),
      ),
      boxShadow: <BoxShadow>[
        BoxShadow(
          color: Colors.black.withOpacity(0.03),
          offset: const Offset(0, 3),
          blurRadius: 10,
        ),
      ],
    );
  }

  Future<void> _saveBasicInfo(
    RegistrationProvider registrationProvider,
    CommonMethods commonMethods,
  ) async {
    FocusScope.of(context).unfocus();

    if (_formKey.currentState?.validate() != true) {
      return;
    }

    registrationProvider.checkBasicFormValidity();

    if (!registrationProvider.isFormValidBasic) {
      return;
    }

    try {
      await registrationProvider.updateBasicDriverInfo(context);

      if (!mounted) {
        return;
      }

      commonMethods.displaySnackBar(
        'driver_info_update_success'.tr(),
        context,
      );
    } catch (error, stackTrace) {
      debugPrint('Error while saving driver data: $error');
      debugPrintStack(stackTrace: stackTrace);
    }
  }

  @override
  Widget build(BuildContext context) {
    final RegistrationProvider registrationProvider =
        context.read<RegistrationProvider>();

    final CommonMethods commonMethods = CommonMethods();

    return Scaffold(
      resizeToAvoidBottomInset: false,
      backgroundColor: AppColors.background,
      appBar: AppBar(
        backgroundColor: AppColors.cardBackground,
        elevation: 0,
        scrolledUnderElevation: 0,
        surfaceTintColor: Colors.transparent,
        shape: Border(
          bottom: BorderSide(
            color: AppColors.textSecondary.withOpacity(0.10),
          ),
        ),
        title: Text(
          'basic_info_title'.tr(),
          style: const TextStyle(
            fontSize: 17,
            fontWeight: FontWeight.w700,
            color: AppColors.textPrimary,
          ),
        ),
        centerTitle: true,
        leading: TextButton(
          onPressed: () => Navigator.pop(context),
          child: Text(
            'close'.tr(),
            style: const TextStyle(
              color: AppColors.textSecondary,
              fontWeight: FontWeight.w600,
            ),
          ),
        ),
        leadingWidth: 70,
      ),
      body: _KeyboardAwareBody(
        child: SafeArea(
          top: false,
          child: Padding(
            padding: const EdgeInsets.fromLTRB(16, 12, 16, 16),
            child: Form(
              key: _formKey,
              child: Column(
                children: <Widget>[
                  Expanded(
                    child: SingleChildScrollView(
                      // با اسکرول فرم، کیبورد خودکار پنهان نمی‌شود.
                      keyboardDismissBehavior:
                          ScrollViewKeyboardDismissBehavior.manual,
                      padding: const EdgeInsets.only(bottom: 12),
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.center,
                        children: <Widget>[
                          Container(
                            width: double.infinity,
                            decoration: _cardDecoration(),
                            child: Column(
                              children: <Widget>[
                                const SizedBox(height: 20),
                                Selector<
                                    RegistrationProvider,
                                    String?>(
                                  selector: (
                                    BuildContext context,
                                    RegistrationProvider provider,
                                  ) {
                                    return provider.profilePhoto?.path;
                                  },
                                  builder: (
                                    BuildContext context,
                                    String? profilePhoto,
                                    Widget? child,
                                  ) {
                                    return Container(
                                      padding: const EdgeInsets.all(3),
                                      decoration: BoxDecoration(
                                        shape: BoxShape.circle,
                                        border: Border.all(
                                          color: AppColors.primaryBrand
                                              .withOpacity(0.35),
                                          width: 2,
                                        ),
                                      ),
                                      child: CircleAvatar(
                                        radius: 52,
                                        backgroundColor: AppColors.background,
                                        backgroundImage:
                                            profilePhoto != null
                                                ? FileImage(File(profilePhoto))
                                                : const AssetImage(
                                                    'assets/auth/user.jpg',
                                                  ) as ImageProvider,
                                      ),
                                    );
                                  },
                                ),
                                const SizedBox(height: 12),
                                TextButton.icon(
                                  onPressed: registrationProvider
                                      .pickProfileImageFromGallary,
                                  style: TextButton.styleFrom(
                                    backgroundColor: AppColors.primaryBrand
                                        .withOpacity(0.10),
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
                          ),
                          const SizedBox(height: 16),
                          Container(
                            decoration: _cardDecoration(),
                            child: Padding(
                              padding: const EdgeInsets.all(16),
                              child: Column(
                                children: <Widget>[
                                  TextFormField(
                                    controller: registrationProvider
                                        .firstNameController,
                                    textInputAction:
                                        TextInputAction.next,
                                    decoration: _inputDecoration(
                                      labelText: 'first_name'.tr(),
                                      icon: Icons.person_outline_rounded,
                                    ),
                                    validator: (String? value) {
                                      if (value == null ||
                                          value.trim().isEmpty) {
                                        return 'err_first_name'.tr();
                                      }

                                      return null;
                                    },
                                    onChanged: (_) {
                                      registrationProvider
                                          .checkBasicFormValidity();
                                    },
                                  ),
                                  const SizedBox(height: 16),
                                  TextFormField(
                                    controller: registrationProvider
                                        .lastNameController,
                                    textInputAction:
                                        TextInputAction.next,
                                    decoration: _inputDecoration(
                                      labelText: 'last_name'.tr(),
                                      icon: Icons.badge_outlined,
                                    ),
                                    validator: (String? value) {
                                      if (value == null ||
                                          value.trim().isEmpty) {
                                        return 'err_last_name'.tr();
                                      }

                                      return null;
                                    },
                                    onChanged: (_) {
                                      registrationProvider
                                          .checkBasicFormValidity();
                                    },
                                  ),
                                  const SizedBox(height: 16),
                                  TextFormField(
                                    controller: registrationProvider
                                        .emailController,
                                    keyboardType:
                                        TextInputType.emailAddress,
                                    textInputAction:
                                        TextInputAction.next,
                                    decoration: _inputDecoration(
                                      labelText: 'email'.tr(),
                                      icon: Icons.mail_outline_rounded,
                                    ),
                                    validator: (String? value) {
                                      final String email =
                                          value?.trim() ?? '';

                                      if (email.isEmpty ||
                                          !email.contains('@')) {
                                        return 'invalid_email_error'.tr();
                                      }

                                      return null;
                                    },
                                    onChanged: (_) {
                                      registrationProvider
                                          .checkBasicFormValidity();
                                    },
                                  ),
                                  const SizedBox(height: 16),
                                  TextFormField(
                                    controller: registrationProvider
                                        .addressController,
                                    textInputAction:
                                        TextInputAction.next,
                                    minLines: 1,
                                    maxLines: 2,
                                    decoration: _inputDecoration(
                                      labelText: 'home_address'.tr(),
                                      icon: Icons.home_outlined,
                                    ),
                                    validator: (String? value) {
                                      if (value == null ||
                                          value.trim().length < 5) {
                                        return 'err_address'.tr();
                                      }

                                      return null;
                                    },
                                    onChanged: (_) {
                                      registrationProvider
                                          .checkBasicFormValidity();
                                    },
                                  ),
                                  const SizedBox(height: 16),
                                  TextFormField(
                                    controller: registrationProvider
                                        .phoneController,
                                    enabled: false,
                                    decoration: _inputDecoration(
                                      labelText:
                                          '${'phone'.tr()} (${'not_registered'.tr()})',
                                      icon: Icons.phone_outlined,
                                    ),
                                  ),
                                  const SizedBox(height: 16),
                                  TextFormField(
                                    controller:
                                        registrationProvider.dobController,
                                    readOnly: true,
                                    showCursor: false,
                                    decoration: _inputDecoration(
                                      labelText:
                                          'dob_jalali_label'.tr(),
                                      hintText:
                                          'dob_jalali_hint'.tr(),
                                      icon: Icons.cake_outlined,
                                      suffixIcon: const Icon(
                                        Icons.calendar_month_outlined,
                                        size: 20,
                                        color: AppColors.primaryBrand,
                                      ),
                                    ),
                                    validator: (String? value) {
                                      if (value == null ||
                                          value.trim().isEmpty) {
                                        return 'err_dob_required'.tr();
                                      }

                                      return null;
                                    },
                                    onTap: () {
                                      FocusScope.of(context).unfocus();
                                      _showAfghanDatePicker(
                                        registrationProvider,
                                      );
                                    },
                                  ),
                                ],
                              ),
                            ),
                          ),
                        ],
                      ),
                    ),
                  ),
                  const SizedBox(height: 10),
                  Selector<
                      RegistrationProvider,
                      ({bool isLoading, bool isFormValid})>(
                    selector: (
                      BuildContext context,
                      RegistrationProvider provider,
                    ) {
                      return (
                        isLoading: provider.isLoading,
                        isFormValid: provider.isFormValidBasic,
                      );
                    },
                    builder: (
                      BuildContext context,
                      ({bool isLoading, bool isFormValid}) state,
                      Widget? child,
                    ) {
                      return SizedBox(
                        width: double.infinity,
                        height: 54,
                        child: ElevatedButton(
                          onPressed: !state.isLoading && state.isFormValid
                              ? () {
                                  _saveBasicInfo(
                                    registrationProvider,
                                    commonMethods,
                                  );
                                }
                              : null,
                          style: ElevatedButton.styleFrom(
                            backgroundColor: AppColors.primaryButton,
                            foregroundColor: AppColors.buttonText,
                            disabledBackgroundColor:
                                AppColors.textSecondary.withOpacity(0.15),
                            disabledForegroundColor:
                                AppColors.textSecondary.withOpacity(0.6),
                            elevation: 0,
                            shadowColor: Colors.transparent,
                            shape: RoundedRectangleBorder(
                              borderRadius: BorderRadius.circular(16),
                            ),
                          ),
                          child: state.isLoading
                              ? const SizedBox(
                                  height: 24,
                                  width: 24,
                                  child: CircularProgressIndicator(
                                    color: AppColors.buttonText,
                                    strokeWidth: 2.5,
                                  ),
                                )
                              : Text(
                                  'driver_info_update_btn'.tr(),
                                  style: const TextStyle(
                                    color: AppColors.buttonText,
                                    fontWeight: FontWeight.bold,
                                    fontSize: 15,
                                  ),
                                ),
                        ),
                      );
                    },
                  ),
                ],
              ),
            ),
          ),
        ),
      ),
    );
  }
}

/// فضای کیبورد را فقط در همین ویجت می‌خواند؛ پس با هر فریم انیمیشن کیبورد
/// کل صفحه دوباره ساخته نمی‌شود ([child] همان نمونهٔ قبلی است).
/// ارتفاع نوار پایین سیستم را [SafeArea] داخلی حساب می‌کند، بنابراین اینجا
/// از ارتفاع کیبورد کم می‌شود تا دو بار شمرده نشود.
class _KeyboardAwareBody extends StatelessWidget {
  const _KeyboardAwareBody({required this.child});

  final Widget child;

  @override
  Widget build(BuildContext context) {
    final double keyboard = MediaQuery.viewInsetsOf(context).bottom;
    final double systemBottom = MediaQuery.paddingOf(context).bottom;

    return AnimatedPadding(
      // مدت کوتاه تا دکمه همراه کیبورد سنگین و دیرجنب حرکت نکند.
      duration: const Duration(milliseconds: 80),
      curve: Curves.easeOut,
      padding: EdgeInsets.only(
        bottom: keyboard > systemBottom ? keyboard - systemBottom : 0,
      ),
      child: child,
    );
  }
}
