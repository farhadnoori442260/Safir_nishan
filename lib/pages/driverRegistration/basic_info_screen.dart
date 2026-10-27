import 'dart:io';

import 'package:easy_localization/easy_localization.dart' hide TextDirection;
import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import 'package:shamsi_date/shamsi_date.dart';

import '../../providers/auth_provider.dart';
import '../../providers/registration_provider.dart';
import '../../utils/app_colors.dart';

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

    final AuthenticationProvider authProvider =
        Provider.of<AuthenticationProvider>(
      context,
      listen: false,
    );

    final RegistrationProvider registrationProvider =
        Provider.of<RegistrationProvider>(
      context,
      listen: false,
    );

    registrationProvider.initFields(authProvider);
  }

  String _toAfghanDigits(String value) {
    const List<String> english = <String>[
      '0', '1', '2', '3', '4', '5', '6', '7', '8', '9',
    ];
    const List<String> farsi = <String>[
      '۰', '۱', '۲', '۳', '۴', '۵', '۶', '۷', '۸', '۹',
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
    try {
      final List<String> parts = savedDate.trim().split('/');
      if (parts.length != 3) return today;

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
      if (day > maxDay) return today;

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
          builder: (BuildContext context, StateSetter setSheetState) {
            final int currentJalaliYear = Jalali.now().year;

            return Container(
              decoration: const BoxDecoration(
                color: Colors.white,
                borderRadius: BorderRadius.vertical(top: Radius.circular(24)),
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
                  const Text(
                    'انتخاب تاریخ تولد',
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
                      // سال
                      Expanded(
                        flex: 4,
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: <Widget>[
                            const Text(
                              'سال',
                              style: TextStyle(
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
                                  builder: (BuildContext context, int index) {
                                    if (index < 0 ||
                                        index >
                                            (currentJalaliYear - 1300)) {
                                      return null;
                                    }
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
                                  childCount:
                                      currentJalaliYear - 1300 + 1,
                                ),
                              ),
                            ),
                          ],
                        ),
                      ),
                      const SizedBox(width: 10),
                      // ماه
                      Expanded(
                        flex: 5,
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: <Widget>[
                            const Text(
                              'ماه',
                              style: TextStyle(
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
                                  builder: (BuildContext context, int index) {
                                    if (index < 0 || index > 11) return null;
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
                                  childCount: 12,
                                ),
                              ),
                            ),
                          ],
                        ),
                      ),
                      const SizedBox(width: 10),
                      // روز
                      Expanded(
                        flex: 4,
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: <Widget>[
                            const Text(
                              'روز',
                              style: TextStyle(
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
                                  builder: (BuildContext context, int index) {
                                    final int maxDays =
                                        selectedDate.monthLength;
                                    if (index < 0 || index >= maxDays) {
                                      return null;
                                    }
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
                                  childCount: selectedDate.monthLength,
                                ),
                              ),
                            ),
                          ],
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
                            padding: const EdgeInsets.symmetric(vertical: 12),
                            shape: RoundedRectangleBorder(
                              borderRadius: BorderRadius.circular(12),
                            ),
                          ),
                          child: const Text('لغو'),
                        ),
                      ),
                      const SizedBox(width: 12),
                      Expanded(
                        child: ElevatedButton(
                          onPressed: () {
                            Navigator.pop(sheetContext, selectedDate);
                          },
                          style: ElevatedButton.styleFrom(
                            backgroundColor: AppColors.primaryBrand,
                            foregroundColor: Colors.white,
                            padding: const EdgeInsets.symmetric(vertical: 12),
                            shape: RoundedRectangleBorder(
                              borderRadius: BorderRadius.circular(12),
                            ),
                          ),
                          child: const Text('تأیید'),
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

    if (result == null) return;

    registrationProvider.dobController.text = _formatJalaliStorage(result);
    registrationProvider.checkBasicFormValidity();
  }

  InputDecoration _inputDecoration({
    required String labelText,
    Widget? suffixIcon,
    String? hintText,
  }) {
    return InputDecoration(
      labelText: labelText,
      hintText: hintText,
      labelStyle: const TextStyle(
        fontSize: 14,
        color: AppColors.textSecondary,
      ),
      focusedBorder: const OutlineInputBorder(
        borderRadius: BorderRadius.all(Radius.circular(12)),
        borderSide: BorderSide(
          color: AppColors.primaryBrand,
          width: 2,
        ),
      ),
      enabledBorder: OutlineInputBorder(
        borderRadius: const BorderRadius.all(Radius.circular(12)),
        borderSide: BorderSide(color: Colors.grey.shade300),
      ),
      border: const OutlineInputBorder(
        borderRadius: BorderRadius.all(Radius.circular(12)),
      ),
      contentPadding: const EdgeInsets.symmetric(
        horizontal: 12,
        vertical: 14,
      ),
      suffixIcon: suffixIcon,
    );
  }

  void _submitBasicInfo(RegistrationProvider registrationProvider) {
    FocusScope.of(context).unfocus();

    if (_formKey.currentState?.validate() != true) return;

    registrationProvider.checkBasicFormValidity();

    if (!registrationProvider.isFormValidBasic) return;

    Navigator.pop(context, true);
  }

  @override
  Widget build(BuildContext context) {
    return Consumer<RegistrationProvider>(
      builder: (
        BuildContext context,
        RegistrationProvider registrationProvider,
        Widget? child,
      ) {
        return Scaffold(
          resizeToAvoidBottomInset: false,
          backgroundColor: AppColors.background,
          appBar: AppBar(
            title: Text(
              'basic_info_title'.tr(),
              style: const TextStyle(
                fontWeight: FontWeight.bold,
                color: AppColors.textPrimary,
              ),
            ),
            centerTitle: true,
            elevation: 0,
            backgroundColor: AppColors.cardBackground,
            actions: <Widget>[
              TextButton(
                onPressed: () => Navigator.pop(context),
                child: Text(
                  'close'.tr(),
                  style: const TextStyle(
                    color: AppColors.textPrimary,
                    fontWeight: FontWeight.bold,
                  ),
                ),
              ),
            ],
          ),
          // استفاده از SafeArea ساده بدون AnimatedPadding تداخل‌آفرین
          body: SafeArea(
            child: Padding(
              padding: const EdgeInsets.fromLTRB(16, 12, 16, 16),
              child: Form(
                key: _formKey,
                child: Column(
                  children: <Widget>[
                    Expanded(
                      child: SingleChildScrollView(
                        keyboardDismissBehavior:
                            ScrollViewKeyboardDismissBehavior.onDrag,
                        padding: const EdgeInsets.only(bottom: 12),
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.center,
                          children: <Widget>[
                            Container(
                              width: double.infinity,
                              decoration: BoxDecoration(
                                border: Border.all(
                                  color: Colors.grey.shade200,
                                ),
                                borderRadius: BorderRadius.circular(20),
                                color: AppColors.cardBackground,
                                boxShadow: <BoxShadow>[
                                  BoxShadow(
                                    color: Colors.black.withOpacity(0.04),
                                    offset: const Offset(0, 4),
                                    blurRadius: 12,
                                  ),
                                ],
                              ),
                              child: Column(
                                children: <Widget>[
                                  const SizedBox(height: 16),
                                  CircleAvatar(
                                    radius: 55,
                                    backgroundColor: Colors.grey.shade200,
                                    backgroundImage: registrationProvider
                                                .profilePhoto !=
                                            null
                                        ? FileImage(
                                            File(
                                              registrationProvider
                                                  .profilePhoto!.path,
                                            ),
                                          )
                                        : null,
                                    child: registrationProvider
                                                .profilePhoto ==
                                            null
                                        ? Icon(
                                            Icons.person,
                                            size: 55,
                                            color: Colors.grey.shade400,
                                          )
                                        : null,
                                  ),
                                  const SizedBox(height: 12),
                                  Container(
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
                                        Icons.add_a_photo,
                                        color: AppColors.primaryBrand,
                                        size: 18,
                                      ),
                                      label: Text(
                                        'add_profile_photo'.tr(),
                                        style: const TextStyle(
                                          color: AppColors.primaryBrand,
                                          fontWeight: FontWeight.bold,
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
                                border: Border.all(
                                  color: Colors.grey.shade200,
                                ),
                                borderRadius: BorderRadius.circular(20),
                                color: AppColors.cardBackground,
                                boxShadow: <BoxShadow>[
                                  BoxShadow(
                                    color: Colors.black.withOpacity(0.04),
                                    offset: const Offset(0, 4),
                                    blurRadius: 12,
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
                                    Directionality(
                                      textDirection: TextDirection.ltr,
                                      child: TextFormField(
                                        controller: registrationProvider
                                            .phoneController,
                                        keyboardType: TextInputType.phone,
                                        textInputAction:
                                            TextInputAction.next,
                                        decoration: _inputDecoration(
                                          labelText:
                                              'mobile_number'.tr(),
                                        ),
                                        validator: (String? value) {
                                          if (value == null ||
                                              value.trim().length < 9) {
                                            return 'err_phone'.tr();
                                          }
                                          return null;
                                        },
                                        onChanged: (_) {
                                          registrationProvider
                                              .checkBasicFormValidity();
                                        },
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
                                            'تاریخ تولد (هجری شمسی)',
                                        hintText: 'مثلاً ۱۳۷۹/۰۲/۲۲',
                                        suffixIcon: const Icon(
                                          Icons.calendar_month,
                                          color: AppColors.primaryBrand,
                                        ),
                                      ),
                                      validator: (String? value) {
                                        if (value == null ||
                                            value.trim().isEmpty) {
                                          return 'تاریخ تولد را انتخاب کنید';
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
                    Padding(
                      padding: const EdgeInsets.only(top: 10),
                      child: SizedBox(
                        width: double.infinity,
                        height: 52,
                        child: ElevatedButton(
                          onPressed: registrationProvider.isFormValidBasic
                              ? () => _submitBasicInfo(
                                    registrationProvider,
                                  )
                              : null,
                          style: ElevatedButton.styleFrom(
                            backgroundColor:
                                registrationProvider.isFormValidBasic
                                    ? AppColors.primaryButton
                                    : Colors.grey.shade400,
                            foregroundColor: AppColors.buttonText,
                            elevation: 0,
                            shape: RoundedRectangleBorder(
                              borderRadius: BorderRadius.circular(12),
                            ),
                          ),
                          child: Text(
                            'confirm_and_submit'.tr(),
                            style: const TextStyle(
                              fontSize: 16,
                              fontWeight: FontWeight.bold,
                            ),
                          ),
                        ),
                      ),
                    ),
                  ],
                ),
              ),
            ),
          ),
        );
      },
    );
  }
}
