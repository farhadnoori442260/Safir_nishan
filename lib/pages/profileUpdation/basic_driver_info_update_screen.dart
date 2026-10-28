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
                  color: Colors.white,
                  borderRadius: BorderRadius.vertical(
                    top: Radius.circular(24),
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
                          color: Colors.grey.shade300,
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
                        color: AppColors.primaryBrand.withOpacity(0.08),
                        borderRadius: BorderRadius.circular(14),
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
                                            : Colors.black87,
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
                                            : Colors.black87,
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
                                            : Colors.black87,
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
                              padding: const EdgeInsets.symmetric(
                                vertical: 12,
                              ),
                              shape: RoundedRectangleBorder(
                                borderRadius: BorderRadius.circular(12),
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
                              backgroundColor: AppColors.primaryBrand,
                              foregroundColor: Colors.white,
                              padding: const EdgeInsets.symmetric(
                                vertical: 12,
                              ),
                              shape: RoundedRectangleBorder(
                                borderRadius: BorderRadius.circular(12),
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
            fontWeight: FontWeight.bold,
            color: Colors.grey,
          ),
        ),
        const SizedBox(height: 6),
        Container(
          height: 160,
          decoration: BoxDecoration(
            border: Border.all(color: Colors.grey.shade300),
            borderRadius: BorderRadius.circular(12),
            color: Colors.grey.shade50,
          ),
          child: child,
        ),
      ],
    );
  }

  InputDecoration _inputDecoration({
    required String labelText,
    String? hintText,
    Widget? suffixIcon,
  }) {
    return InputDecoration(
      labelText: labelText,
      hintText: hintText,
      labelStyle: const TextStyle(fontSize: 13),
      border: const OutlineInputBorder(
        borderRadius: BorderRadius.all(Radius.circular(12)),
      ),
      contentPadding: const EdgeInsets.symmetric(
        horizontal: 12,
        vertical: 10,
      ),
      suffixIcon: suffixIcon,
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
    final double keyboardHeight = MediaQuery.viewInsetsOf(context).bottom;

    return Scaffold(
      resizeToAvoidBottomInset: false,
      backgroundColor: AppColors.background,
      appBar: AppBar(
        backgroundColor: AppColors.cardBackground,
        elevation: 0,
        title: Text(
          'basic_info_title'.tr(),
          style: const TextStyle(
            fontSize: 16,
            fontWeight: FontWeight.bold,
            color: AppColors.textPrimary,
          ),
        ),
        centerTitle: true,
        leading: TextButton(
          onPressed: () => Navigator.pop(context),
          child: Text(
            'close'.tr(),
            style: const TextStyle(
              color: AppColors.textPrimary,
              fontWeight: FontWeight.bold,
            ),
          ),
        ),
        leadingWidth: 70,
      ),
      body: AnimatedPadding(
        duration: const Duration(milliseconds: 180),
        curve: Curves.easeOutCubic,
        padding: EdgeInsets.only(bottom: keyboardHeight),
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
                            decoration: BoxDecoration(
                              borderRadius: BorderRadius.circular(16),
                              color: AppColors.cardBackground,
                              boxShadow: const <BoxShadow>[
                                BoxShadow(
                                  color: Colors.black12,
                                  offset: Offset(0, 2),
                                  blurRadius: 6,
                                ),
                              ],
                            ),
                            child: Column(
                              children: <Widget>[
                                const SizedBox(height: 16),
                                Selector<
                                    RegistrationProvider,
                                    File?>(
                                  selector: (
                                    BuildContext context,
                                    RegistrationProvider provider,
                                  ) {
                                    return provider.profilePhoto;
                                  },
                                  builder: (
                                    BuildContext context,
                                    File? profilePhoto,
                                    Widget? child,
                                  ) {
                                    return CircleAvatar(
                                      radius: 55,
                                      backgroundColor:
                                          Colors.grey.shade200,
                                      backgroundImage:
                                          profilePhoto != null
                                              ? FileImage(profilePhoto)
                                              : const AssetImage(
                                                  'assets/auth/user.jpg',
                                                ) as ImageProvider,
                                    );
                                  },
                                ),
                                const SizedBox(height: 12),
                                Container(
                                  height: 40,
                                  decoration: BoxDecoration(
                                    border: Border.all(
                                      color: AppColors.primaryBrand,
                                    ),
                                    borderRadius:
                                        BorderRadius.circular(12),
                                  ),
                                  child: TextButton.icon(
                                    onPressed: registrationProvider
                                        .pickProfileImageFromGallary,
                                    icon: const Icon(
                                      Icons.add_a_photo_outlined,
                                      color: AppColors.primaryBrand,
                                      size: 16,
                                    ),
                                    label: Text(
                                      'add_profile_photo'.tr(),
                                      style: const TextStyle(
                                        color: AppColors.primaryBrand,
                                        fontWeight: FontWeight.bold,
                                        fontSize: 13,
                                      ),
                                    ),
                                  ),
                                ),
                                const SizedBox(height: 16),
                              ],
                            ),
                          ),
                          const SizedBox(height: 16),
                          Container(
                            decoration: BoxDecoration(
                              borderRadius: BorderRadius.circular(16),
                              color: AppColors.cardBackground,
                              boxShadow: const <BoxShadow>[
                                BoxShadow(
                                  color: Colors.black12,
                                  offset: Offset(0, 2),
                                  blurRadius: 6,
                                ),
                              ],
                            ),
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
                                      suffixIcon: const Icon(
                                        Icons.calendar_month,
                                        size: 18,
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
                        height: 52,
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
                            backgroundColor: AppColors.primaryBrand,
                            disabledBackgroundColor:
                                Colors.grey.shade400,
                            shape: RoundedRectangleBorder(
                              borderRadius: BorderRadius.circular(12),
                            ),
                          ),
                          child: state.isLoading
                              ? const SizedBox(
                                  height: 24,
                                  width: 24,
                                  child: CircularProgressIndicator(
                                    color: Colors.white,
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
