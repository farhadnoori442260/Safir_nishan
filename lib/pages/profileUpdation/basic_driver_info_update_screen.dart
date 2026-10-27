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

  static const List<String> _afghanMonthKeys = <String>[
    'jalali_month_hamal',
    'jalali_month_sawr',
    'jalali_month_jawza',
    'jalali_month_saratan',
    'jalali_month_asad',
    'jalali_month_sunbula',
    'jalali_month_mizan',
    'jalali_month_aqrab',
    'jalali_month_qaws',
    'jalali_month_jadi',
    'jalali_month_dalw',
    'jalali_month_hut',
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

  String _monthName(BuildContext context, int month) {
    return _afghanMonthKeys[month - 1].tr();
  }

  String _formatJalaliDate(BuildContext context, Jalali date) {
    final String day = date.day.toString().padLeft(2, '0');
    final String year = date.year.toString();

    return '${_toAfghanDigits(day)} '
        '${_monthName(context, date.month)} '
        '${_toAfghanDigits(year)}';
  }

  String _formatJalaliStorage(Jalali date) {
    final String year = date.year.toString().padLeft(4, '0');
    final String month = date.month.toString().padLeft(2, '0');
    final String day = date.day.toString().padLeft(2, '0');

    return '$year/$month/$day';
  }

  Jalali _currentJalaliDate() {
    return Jalali.now();
  }

  Jalali _getInitialJalaliDate(String savedDate) {
    final Jalali today = _currentJalaliDate();

    try {
      final List<String> parts = savedDate.trim().split('/');

      if (parts.length != 3) {
        return today;
      }

      final int year = int.parse(parts[0]);
      final int month = int.parse(parts[1]);
      final int day = int.parse(parts[2]);

      if (year < 1 ||
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

    final Jalali? result = await showDialog<Jalali>(
      context: context,
      builder: (BuildContext dialogContext) {
        return StatefulBuilder(
          builder: (
            BuildContext context,
            StateSetter setDialogState,
          ) {
            final Jalali today = _currentJalaliDate();
            final int currentJalaliYear = today.year;

            return AlertDialog(
              titlePadding: const EdgeInsets.fromLTRB(20, 20, 20, 4),
              contentPadding: const EdgeInsets.fromLTRB(20, 12, 20, 8),
              actionsPadding: const EdgeInsets.fromLTRB(12, 0, 12, 12),
              title: Text(
                'dob_picker_title'.tr(),
                style: const TextStyle(
                  fontWeight: FontWeight.bold,
                  color: AppColors.textPrimary,
                ),
              ),
              content: SizedBox(
                width: 330,
                child: Column(
                  mainAxisSize: MainAxisSize.min,
                  children: <Widget>[
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
                        _formatJalaliDate(context, selectedDate),
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
                      children: <Widget>[
                        Expanded(
                          flex: 4,
                          child: DropdownButtonFormField<int>(
                            value: selectedDate.year,
                            isExpanded: true,
                            decoration: InputDecoration(
                              labelText: 'dob_year_label'.tr(),
                              border: OutlineInputBorder(
                                borderRadius: BorderRadius.circular(12),
                              ),
                              contentPadding: const EdgeInsets.symmetric(
                                horizontal: 10,
                                vertical: 10,
                              ),
                            ),
                            items: List<DropdownMenuItem<int>>.generate(
                              currentJalaliYear,
                              (int index) {
                                final int year = index + 1;

                                return DropdownMenuItem<int>(
                                  value: year,
                                  child: Text(
                                    _toAfghanDigits(year.toString()),
                                  ),
                                );
                              },
                            ),
                            onChanged: (int? year) {
                              if (year == null) {
                                return;
                              }

                              final int maxDay = Jalali(
                                year,
                                selectedDate.month,
                                1,
                              ).monthLength;

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
                              labelText: 'dob_month_label'.tr(),
                              border: OutlineInputBorder(
                                borderRadius: BorderRadius.circular(12),
                              ),
                              contentPadding: const EdgeInsets.symmetric(
                                horizontal: 10,
                                vertical: 10,
                              ),
                            ),
                            items: List<DropdownMenuItem<int>>.generate(
                              12,
                              (int index) {
                                final int month = index + 1;

                                return DropdownMenuItem<int>(
                                  value: month,
                                  child: Text(
                                    _monthName(context, month),
                                  ),
                                );
                              },
                            ),
                            onChanged: (int? month) {
                              if (month == null) {
                                return;
                              }

                              final int maxDay = Jalali(
                                selectedDate.year,
                                month,
                                1,
                              ).monthLength;

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
                        labelText: 'dob_day_label'.tr(),
                        border: OutlineInputBorder(
                          borderRadius: BorderRadius.circular(12),
                        ),
                        contentPadding: const EdgeInsets.symmetric(
                          horizontal: 10,
                          vertical: 10,
                        ),
                      ),
                      items: List<DropdownMenuItem<int>>.generate(
                        selectedDate.monthLength,
                        (int index) {
                          final int day = index + 1;

                          return DropdownMenuItem<int>(
                            value: day,
                            child: Text(
                              _toAfghanDigits(day.toString()),
                            ),
                          );
                        },
                      ),
                      onChanged: (int? day) {
                        if (day == null) {
                          return;
                        }

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
              actions: <Widget>[
                TextButton(
                  onPressed: () {
                    Navigator.pop(dialogContext);
                  },
                  child: Text('cancel'.tr()),
                ),
                ElevatedButton(
                  onPressed: () {
                    Navigator.pop(dialogContext, selectedDate);
                  },
                  style: ElevatedButton.styleFrom(
                    backgroundColor: AppColors.primaryBrand,
                    foregroundColor: Colors.white,
                  ),
                  child: Text('confirm'.tr()),
                ),
              ],
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

  @override
  Widget build(BuildContext context) {
    final CommonMethods commonMethods = CommonMethods();

    return Consumer<RegistrationProvider>(
      builder: (
        BuildContext context,
        RegistrationProvider registrationProvider,
        Widget? child,
      ) {
        return Scaffold(
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
          body: Padding(
            padding: const EdgeInsets.all(16),
            child: SingleChildScrollView(
              child: Form(
                key: _formKey,
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
                                    : const AssetImage(
                                        'assets/auth/user.jpg',
                                      ) as ImageProvider,
                          ),
                          const SizedBox(height: 12),
                          Container(
                            height: 40,
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
                              controller:
                                  registrationProvider.firstNameController,
                              decoration: InputDecoration(
                                labelText: 'first_name'.tr(),
                                labelStyle: const TextStyle(fontSize: 13),
                                border: const OutlineInputBorder(
                                  borderRadius: BorderRadius.all(
                                    Radius.circular(12),
                                  ),
                                ),
                                contentPadding:
                                    const EdgeInsets.symmetric(
                                  horizontal: 12,
                                  vertical: 10,
                                ),
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
                              controller:
                                  registrationProvider.lastNameController,
                              decoration: InputDecoration(
                                labelText: 'last_name'.tr(),
                                labelStyle: const TextStyle(fontSize: 13),
                                border: const OutlineInputBorder(
                                  borderRadius: BorderRadius.all(
                                    Radius.circular(12),
                                  ),
                                ),
                                contentPadding:
                                    const EdgeInsets.symmetric(
                                  horizontal: 12,
                                  vertical: 10,
                                ),
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
                              controller:
                                  registrationProvider.emailController,
                              keyboardType: TextInputType.emailAddress,
                              decoration: InputDecoration(
                                labelText: 'email'.tr(),
                                labelStyle: const TextStyle(fontSize: 13),
                                border: const OutlineInputBorder(
                                  borderRadius: BorderRadius.all(
                                    Radius.circular(12),
                                  ),
                                ),
                                contentPadding:
                                    const EdgeInsets.symmetric(
                                  horizontal: 12,
                                  vertical: 10,
                                ),
                              ),
                              validator: (String? value) {
                                final String email = value?.trim() ?? '';

                                if (email.isEmpty || !email.contains('@')) {
                                  return 'invalid_email_error'.tr();
                                }

                                return null;
                              },
                              onChanged: (_) {
                                registrationProvider.checkBasicFormValidity();
                              },
                            ),
                            const SizedBox(height: 16),
                            TextFormField(
                              controller:
                                  registrationProvider.addressController,
                              decoration: InputDecoration(
                                labelText: 'home_address'.tr(),
                                labelStyle: const TextStyle(fontSize: 13),
                                border: const OutlineInputBorder(
                                  borderRadius: BorderRadius.all(
                                    Radius.circular(12),
                                  ),
                                ),
                                contentPadding:
                                    const EdgeInsets.symmetric(
                                  horizontal: 12,
                                  vertical: 10,
                                ),
                              ),
                              validator: (String? value) {
                                if (value == null ||
                                    value.trim().length < 5) {
                                  return 'err_address'.tr();
                                }

                                return null;
                              },
                              onChanged: (_) {
                                registrationProvider.checkBasicFormValidity();
                              },
                            ),
                            const SizedBox(height: 16),
                            TextFormField(
                              controller:
                                  registrationProvider.phoneController,
                              enabled: false,
                              decoration: InputDecoration(
                                labelText:
                                    '${'phone'.tr()} (${'not_registered'.tr()})',
                                labelStyle: const TextStyle(fontSize: 13),
                                border: const OutlineInputBorder(
                                  borderRadius: BorderRadius.all(
                                    Radius.circular(12),
                                  ),
                                ),
                                contentPadding:
                                    const EdgeInsets.symmetric(
                                  horizontal: 12,
                                  vertical: 10,
                                ),
                              ),
                            ),
                            const SizedBox(height: 16),
                            TextFormField(
                              controller: registrationProvider.dobController,
                              readOnly: true,
                              decoration: InputDecoration(
                                labelText: 'dob_jalali_label'.tr(),
                                hintText: 'dob_jalali_hint'.tr(),
                                labelStyle: const TextStyle(fontSize: 13),
                                border: const OutlineInputBorder(
                                  borderRadius: BorderRadius.all(
                                    Radius.circular(12),
                                  ),
                                ),
                                contentPadding:
                                    const EdgeInsets.symmetric(
                                  horizontal: 12,
                                  vertical: 10,
                                ),
                                suffixIcon: const Icon(
                                  Icons.calendar_month,
                                  size: 18,
                                  color: AppColors.primaryBrand,
                                ),
                              ),
                              validator: (String? value) {
                                if (value == null || value.trim().isEmpty) {
                                  return 'err_dob_required'.tr();
                                }

                                return null;
                              },
                              onTap: () {
                                _showAfghanDatePicker(registrationProvider);
                              },
                            ),
                          ],
                        ),
                      ),
                    ),
                    const SizedBox(height: 24),
                    SizedBox(
                      width: MediaQuery.of(context).size.width * 0.93,
                      height: 52,
                      child: ElevatedButton(
                        onPressed: !registrationProvider.isLoading &&
                                registrationProvider.isFormValidBasic
                            ? () async {
                                if (_formKey.currentState?.validate() !=
                                    true) {
                                  return;
                                }

                                try {
                                  await registrationProvider
                                      .updateBasicDriverInfo(context);

                                  if (context.mounted) {
                                    commonMethods.displaySnackBar(
                                      'driver_info_update_success'.tr(),
                                      context,
                                    );
                                  }
                                } catch (error, stackTrace) {
                                  debugPrint(
                                    'Error while saving driver data: $error',
                                  );
                                  debugPrintStack(stackTrace: stackTrace);
                                }
                              }
                            : null,
                        style: ElevatedButton.styleFrom(
                          backgroundColor: AppColors.primaryBrand,
                          disabledBackgroundColor: Colors.grey.shade400,
                          shape: RoundedRectangleBorder(
                            borderRadius: BorderRadius.circular(12),
                          ),
                        ),
                        child: registrationProvider.isLoading
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
