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
  final _formKey = GlobalKey<FormState>();

  static const List<String> _afghanMonths = [
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

    final authProvider = Provider.of<AuthenticationProvider>(
      context,
      listen: false,
    );

    final registrationProvider = Provider.of<RegistrationProvider>(
      context,
      listen: false,
    );

    registrationProvider.initFields(authProvider);
  }

  String _toAfghanDigits(String value) {
    const english = ['0', '1', '2', '3', '4', '5', '6', '7', '8', '9'];
    const farsi = ['۰', '۱', '۲', '۳', '۴', '۵', '۶', '۷', '۸', '۹'];

    for (int i = 0; i < 10; i++) {
      value = value.replaceAll(english[i], farsi[i]);
    }

    return value;
  }

  String _formatJalaliDate(Jalali date) {
    final day = date.day.toString().padLeft(2, '0');
    final year = date.year.toString();

    return '${_toAfghanDigits(day)} ${_afghanMonths[date.month - 1]} ${_toAfghanDigits(year)}';
  }

  String _formatJalaliStorage(Jalali date) {
    final year = date.year.toString().padLeft(4, '0');
    final month = date.month.toString().padLeft(2, '0');
    final day = date.day.toString().padLeft(2, '0');

    return '$year/$month/$day';
  }

  Jalali _getInitialJalaliDate(String savedDate) {
    try {
      final parts = savedDate.split('/');

      if (parts.length == 3) {
        final year = int.parse(parts[0]);
        final month = int.parse(parts[1]);
        final day = int.parse(parts[2]);

        if (year >= 1200 && year <= 1500) {
          return Jalali(year, month, day);
        }
      }
    } catch (_) {}

    return Jalali(1379, 1, 1);
  }

  Future<void> _showAfghanDatePicker(
    RegistrationProvider registrationProvider,
  ) async {
    Jalali selectedDate = _getInitialJalaliDate(
      registrationProvider.dobController.text,
    );

    final Jalali? result = await showDialog<Jalali>(
      context: context,
      builder: (dialogContext) {
        return StatefulBuilder(
          builder: (context, setDialogState) {
            return AlertDialog(
              titlePadding: const EdgeInsets.fromLTRB(20, 20, 20, 4),
              contentPadding: const EdgeInsets.fromLTRB(20, 12, 20, 8),
              actionsPadding: const EdgeInsets.fromLTRB(12, 0, 12, 12),
              title: Text(
                'انتخاب تاریخ تولد',
                style: const TextStyle(
                  fontWeight: FontWeight.bold,
                  color: AppColors.textPrimary,
                ),
              ),
              content: SizedBox(
                width: 330,
                child: Column(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    Container(
                      width: double.infinity,
                      padding: const EdgeInsets.symmetric(
                        horizontal: 12,
                        vertical: 14,
                      ),
                      decoration: BoxDecoration(
                        color: AppColors.primaryBrand.withOpacity(0.08),
                        borderRadius: BorderRadius.circular(12),
                      ),
                      child: Text(
                        _formatJalaliDate(selectedDate),
                        textAlign: TextAlign.center,
                        style: const TextStyle(
                          fontSize: 17,
                          color: AppColors.primaryBrand,
                          fontWeight: FontWeight.bold,
                        ),
                      ),
                    ),
                    const SizedBox(height: 18),
                    Row(
                      children: [
                        Expanded(
                          flex: 4,
                          child: DropdownButtonFormField<int>(
                            value: selectedDate.year,
                            isExpanded: true,
                            decoration: InputDecoration(
                              labelText: 'سال',
                              border: OutlineInputBorder(
                                borderRadius: BorderRadius.circular(12),
                              ),
                              contentPadding: const EdgeInsets.symmetric(
                                horizontal: 10,
                                vertical: 10,
                              ),
                            ),
                            items: List.generate(91, (index) {
                              final year = 1315 + index;

                              return DropdownMenuItem<int>(
                                value: year,
                                child: Text(
                                  _toAfghanDigits(year.toString()),
                                  textAlign: TextAlign.center,
                                ),
                              );
                            }),
                            onChanged: (year) {
                              if (year == null) return;

                              final maxDay = Jalali(year, selectedDate.month, 1)
                                  .monthLength;

                              setDialogState(() {
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
                        const SizedBox(width: 8),
                        Expanded(
                          flex: 5,
                          child: DropdownButtonFormField<int>(
                            value: selectedDate.month,
                            isExpanded: true,
                            decoration: InputDecoration(
                              labelText: 'ماه',
                              border: OutlineInputBorder(
                                borderRadius: BorderRadius.circular(12),
                              ),
                              contentPadding: const EdgeInsets.symmetric(
                                horizontal: 10,
                                vertical: 10,
                              ),
                            ),
                            items: List.generate(12, (index) {
                              return DropdownMenuItem<int>(
                                value: index + 1,
                                child: Text(_afghanMonths[index]),
                              );
                            }),
                            onChanged: (month) {
                              if (month == null) return;

                              final maxDay =
                                  Jalali(selectedDate.year, month, 1)
                                      .monthLength;

                              setDialogState(() {
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
                      ],
                    ),
                    const SizedBox(height: 12),
                    DropdownButtonFormField<int>(
                      value: selectedDate.day,
                      isExpanded: true,
                      decoration: InputDecoration(
                        labelText: 'روز',
                        border: OutlineInputBorder(
                          borderRadius: BorderRadius.circular(12),
                        ),
                        contentPadding: const EdgeInsets.symmetric(
                          horizontal: 10,
                          vertical: 10,
                        ),
                      ),
                      items: List.generate(selectedDate.monthLength, (index) {
                        final day = index + 1;

                        return DropdownMenuItem<int>(
                          value: day,
                          child: Text(_toAfghanDigits(day.toString())),
                        );
                      }),
                      onChanged: (day) {
                        if (day == null) return;

                        setDialogState(() {
                          selectedDate = Jalali(
                            selectedDate.year,
                            selectedDate.month,
                            day,
                          );
                        });
                      },
                    ),
                  ],
                ),
              ),
              actions: [
                TextButton(
                  onPressed: () => Navigator.pop(dialogContext),
                  child: const Text('لغو'),
                ),
                ElevatedButton(
                  onPressed: () => Navigator.pop(
                    dialogContext,
                    selectedDate,
                  ),
                  style: ElevatedButton.styleFrom(
                    backgroundColor: AppColors.primaryBrand,
                    foregroundColor: Colors.white,
                  ),
                  child: const Text('تأیید'),
                ),
              ],
            );
          },
        );
      },
    );

    if (result != null) {
      registrationProvider.dobController.text = _formatJalaliStorage(result);
      registrationProvider.checkBasicFormValidity();
    }
  }

  @override
  Widget build(BuildContext context) {
    return Consumer<RegistrationProvider>(
      builder: (context, registrationProvider, child) {
        return Scaffold(
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
            actions: [
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
          body: Padding(
            padding: const EdgeInsets.all(16),
            child: SingleChildScrollView(
              child: Form(
                key: _formKey,
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.center,
                  children: [
                    Container(
                      width: double.infinity,
                      decoration: BoxDecoration(
                        border: Border.all(color: Colors.grey.shade200),
                        borderRadius: BorderRadius.circular(20),
                        color: AppColors.cardBackground,
                        boxShadow: [
                          BoxShadow(
                            color: Colors.black.withOpacity(0.04),
                            offset: const Offset(0, 4),
                            blurRadius: 12,
                          ),
                        ],
                      ),
                      child: Column(
                        children: [
                          const SizedBox(height: 16),
                          CircleAvatar(
                            radius: 55,
                            backgroundColor: Colors.grey.shade200,
                            backgroundImage:
                                registrationProvider.profilePhoto != null
                                    ? FileImage(
                                        File(
                                          registrationProvider
                                              .profilePhoto!
                                              .path,
                                        ),
                                      )
                                    : null,
                            child: registrationProvider.profilePhoto == null
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
                              borderRadius: BorderRadius.circular(12),
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
                        border: Border.all(color: Colors.grey.shade200),
                        borderRadius: BorderRadius.circular(20),
                        color: AppColors.cardBackground,
                        boxShadow: [
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
                          children: [
                            TextFormField(
                              controller:
                                  registrationProvider.firstNameController,
                              decoration: InputDecoration(
                                labelText: 'first_name'.tr(),
                                labelStyle: const TextStyle(
                                  fontSize: 14,
                                  color: AppColors.textSecondary,
                                ),
                                focusedBorder: const OutlineInputBorder(
                                  borderRadius: BorderRadius.all(
                                    Radius.circular(12),
                                  ),
                                  borderSide: BorderSide(
                                    color: AppColors.primaryBrand,
                                    width: 2,
                                  ),
                                ),
                                enabledBorder: OutlineInputBorder(
                                  borderRadius: const BorderRadius.all(
                                    Radius.circular(12),
                                  ),
                                  borderSide: BorderSide(
                                    color: Colors.grey.shade300,
                                  ),
                                ),
                                contentPadding: const EdgeInsets.symmetric(
                                  horizontal: 12,
                                  vertical: 14,
                                ),
                              ),
                              validator: (value) =>
                                  value == null || value.isEmpty
                                      ? 'err_first_name'.tr()
                                      : null,
                              onChanged: (_) => registrationProvider
                                  .checkBasicFormValidity(),
                            ),
                            const SizedBox(height: 16),
                            TextFormField(
                              controller:
                                  registrationProvider.lastNameController,
                              decoration: InputDecoration(
                                labelText: 'last_name'.tr(),
                                labelStyle: const TextStyle(
                                  fontSize: 14,
                                  color: AppColors.textSecondary,
                                ),
                                focusedBorder: const OutlineInputBorder(
                                  borderRadius: BorderRadius.all(
                                    Radius.circular(12),
                                  ),
                                  borderSide: BorderSide(
                                    color: AppColors.primaryBrand,
                                    width: 2,
                                  ),
                                ),
                                enabledBorder: OutlineInputBorder(
                                  borderRadius: const BorderRadius.all(
                                    Radius.circular(12),
                                  ),
                                  borderSide: BorderSide(
                                    color: Colors.grey.shade300,
                                  ),
                                ),
                                contentPadding: const EdgeInsets.symmetric(
                                  horizontal: 12,
                                  vertical: 14,
                                ),
                              ),
                              validator: (value) =>
                                  value == null || value.isEmpty
                                      ? 'err_last_name'.tr()
                                      : null,
                              onChanged: (_) => registrationProvider
                                  .checkBasicFormValidity(),
                            ),
                            const SizedBox(height: 16),
                            TextFormField(
                              controller: registrationProvider.emailController,
                              keyboardType: TextInputType.emailAddress,
                              decoration: InputDecoration(
                                labelText: 'email'.tr(),
                                labelStyle: const TextStyle(
                                  fontSize: 14,
                                  color: AppColors.textSecondary,
                                ),
                                focusedBorder: const OutlineInputBorder(
                                  borderRadius: BorderRadius.all(
                                    Radius.circular(12),
                                  ),
                                  borderSide: BorderSide(
                                    color: AppColors.primaryBrand,
                                    width: 2,
                                  ),
                                ),
                                enabledBorder: OutlineInputBorder(
                                  borderRadius: const BorderRadius.all(
                                    Radius.circular(12),
                                  ),
                                  borderSide: BorderSide(
                                    color: Colors.grey.shade300,
                                  ),
                                ),
                                contentPadding: const EdgeInsets.symmetric(
                                  horizontal: 12,
                                  vertical: 14,
                                ),
                              ),
                              validator: (value) {
                                if (value == null ||
                                    value.isEmpty ||
                                    !value.contains('@')) {
                                  return 'invalid_email_error'.tr();
                                }

                                return null;
                              },
                              onChanged: (_) => registrationProvider
                                  .checkBasicFormValidity(),
                            ),
                            const SizedBox(height: 16),
                            TextFormField(
                              controller:
                                  registrationProvider.addressController,
                              decoration: InputDecoration(
                                labelText: 'home_address'.tr(),
                                labelStyle: const TextStyle(
                                  fontSize: 14,
                                  color: AppColors.textSecondary,
                                ),
                                focusedBorder: const OutlineInputBorder(
                                  borderRadius: BorderRadius.all(
                                    Radius.circular(12),
                                  ),
                                  borderSide: BorderSide(
                                    color: AppColors.primaryBrand,
                                    width: 2,
                                  ),
                                ),
                                enabledBorder: OutlineInputBorder(
                                  borderRadius: const BorderRadius.all(
                                    Radius.circular(12),
                                  ),
                                  borderSide: BorderSide(
                                    color: Colors.grey.shade300,
                                  ),
                                ),
                                contentPadding: const EdgeInsets.symmetric(
                                  horizontal: 12,
                                  vertical: 14,
                                ),
                              ),
                              validator: (value) =>
                                  value == null ||
                                          value.isEmpty ||
                                          value.length < 5
                                      ? 'err_address'.tr()
                                      : null,
                              onChanged: (_) => registrationProvider
                                  .checkBasicFormValidity(),
                            ),
                            const SizedBox(height: 16),
                            Directionality(
                              textDirection: TextDirection.ltr,
                              child: TextFormField(
                                controller:
                                    registrationProvider.phoneController,
                                keyboardType: TextInputType.phone,
                                decoration: InputDecoration(
                                  labelText: 'mobile_number'.tr(),
                                  labelStyle: const TextStyle(
                                    fontSize: 14,
                                    color: AppColors.textSecondary,
                                  ),
                                  focusedBorder: const OutlineInputBorder(
                                    borderRadius: BorderRadius.all(
                                      Radius.circular(12),
                                    ),
                                    borderSide: BorderSide(
                                      color: AppColors.primaryBrand,
                                      width: 2,
                                    ),
                                  ),
                                  enabledBorder: OutlineInputBorder(
                                    borderRadius: const BorderRadius.all(
                                      Radius.circular(12),
                                    ),
                                    borderSide: BorderSide(
                                      color: Colors.grey.shade300,
                                    ),
                                  ),
                                  contentPadding: const EdgeInsets.symmetric(
                                    horizontal: 12,
                                    vertical: 14,
                                  ),
                                ),
                                validator: (value) =>
                                    value == null ||
                                            value.isEmpty ||
                                            value.length < 9
                                        ? 'err_phone'.tr()
                                        : null,
                                onChanged: (_) => registrationProvider
                                    .checkBasicFormValidity(),
                              ),
                            ),
                            const SizedBox(height: 16),
                            TextFormField(
                              controller: registrationProvider.dobController,
                              readOnly: true,
                              decoration: InputDecoration(
                                labelText: 'تاریخ تولد (هجری شمسی)',
                                hintText: 'مثلاً ۱۳۷۹/۰۲/۲۲',
                                labelStyle: const TextStyle(
                                  fontSize: 14,
                                  color: AppColors.textSecondary,
                                ),
                                focusedBorder: const OutlineInputBorder(
                                  borderRadius: BorderRadius.all(
                                    Radius.circular(12),
                                  ),
                                  borderSide: BorderSide(
                                    color: AppColors.primaryBrand,
                                    width: 2,
                                  ),
                                ),
                                enabledBorder: OutlineInputBorder(
                                  borderRadius: const BorderRadius.all(
                                    Radius.circular(12),
                                  ),
                                  borderSide: BorderSide(
                                    color: Colors.grey.shade300,
                                  ),
                                ),
                                contentPadding: const EdgeInsets.symmetric(
                                  horizontal: 12,
                                  vertical: 14,
                                ),
                                suffixIcon: const Icon(
                                  Icons.calendar_month,
                                  color: AppColors.primaryBrand,
                                ),
                              ),
                              validator: (value) => value == null ||
                                      value.trim().isEmpty
                                  ? 'تاریخ تولد را انتخاب کنید'
                                  : null,
                              onTap: () {
                                _showAfghanDatePicker(registrationProvider);
                              },
                            ),
                          ],
                        ),
                      ),
                    ),
                    const SizedBox(height: 25),
                    SizedBox(
                      width: double.infinity,
                      height: 50,
                      child: ElevatedButton(
                        onPressed: registrationProvider.isFormValidBasic
                            ? () async {
                                if (_formKey.currentState?.validate() ==
                                    true) {
                                  Navigator.pop(context, true);
                                }
                              }
                            : null,
                        style: ElevatedButton.styleFrom(
                          backgroundColor: registrationProvider
                                  .isFormValidBasic
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
