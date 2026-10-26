import 'package:easy_localization/easy_localization.dart';
import 'package:flutter/material.dart';
import 'package:provider/provider.dart';

import '../../../providers/registration_provider.dart';
import '../../../utils/app_colors.dart';

class VehicleBasicInfoScreen extends StatefulWidget {
  const VehicleBasicInfoScreen({super.key});

  @override
  State<VehicleBasicInfoScreen> createState() => _VehicleBasicInfoScreenState();
}

class _VehicleBasicInfoScreenState extends State<VehicleBasicInfoScreen> {
  final _formKey = GlobalKey<FormState>();

  final List<String> afghanistanProvinces = [
    'کابل',
    'هرات',
    'بلخ',
    'قندهار',
    'ننگرهار',
    'غزنی',
    'پکتیا',
    'پروان',
    'کندز',
    'دایکندی',
    'بامیان',
  ];

  final List<String> plateCategories = [
    'ش',
    'الف',
    'ب',
    'ت',
    'ج',
    'د',
    'ر',
    'ز',
    'س',
    'ص',
    'ط',
    'ع',
    'ف',
    'ق',
    'ک',
    'م',
    'ن',
    'و',
    'هـ',
    'ی',
  ];

  final List<String> plateTypes = [
    'شخصی',
    'موقتی',
    'تاکسی',
    'دولتی',
  ];

  static const List<Map<String, String>> _vehicleOptions = [
    {
      'value': 'Car',
      'label': 'vehicle_car',
      'icon': 'assets/vehicles/home_car.png',
    },
    {
      'value': 'Bike',
      'label': 'vehicle_bike',
      'icon': 'assets/vehicles/bike.png',
    },
    {
      'value': 'cargo',
      'label': 'vehicle_cargo',
      'icon': 'assets/vehicles/cargo.png',
    },
  ];

  String _toEnglishNumbers(String input) {
    const english = ['0', '1', '2', '3', '4', '5', '6', '7', '8', '9'];
    const farsi = ['۰', '۱', '۲', '۳', '۴', '۵', '۶', '۷', '۸', '۹'];
    const arabic = ['٠', '١', '٢', '٣', '٤', '٥', '٦', '٧', '٨', '٩'];

    for (int i = 0; i < 10; i++) {
      input = input.replaceAll(farsi[i], english[i]);
      input = input.replaceAll(arabic[i], english[i]);
    }

    return input;
  }

  Widget _vehicleOptionIcon(String assetPath, String value) {
    IconData fallbackIcon;

    switch (value) {
      case 'Bike':
        fallbackIcon = Icons.two_wheeler_rounded;
        break;
      case 'cargo':
        fallbackIcon = Icons.local_shipping_rounded;
        break;
      case 'Car':
      default:
        fallbackIcon = Icons.directions_car_rounded;
    }

    return Image.asset(
      assetPath,
      height: 32,
      width: 56,
      fit: BoxFit.contain,
      errorBuilder: (context, error, stackTrace) {
        return Icon(
          fallbackIcon,
          size: 28,
          color: AppColors.primaryBrand,
        );
      },
    );
  }

  String _vehicleLabel(String translationKey, String fallback) {
    final String translated = translationKey.tr();

    return translated.isNotEmpty && translated != translationKey
        ? translated
        : fallback;
  }

  @override
  Widget build(BuildContext context) {
    return Consumer<RegistrationProvider>(
      builder: (
        context,
        RegistrationProvider registrationProvider,
        child,
      ) {
        return Scaffold(
          backgroundColor: AppColors.background,
          appBar: AppBar(
            title: Text(
              'vehicle_info_title'.tr(),
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
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Container(
                      margin: const EdgeInsets.symmetric(vertical: 10),
                      padding: const EdgeInsets.symmetric(
                        horizontal: 16,
                        vertical: 8,
                      ),
                      decoration: BoxDecoration(
                        border: Border.all(color: Colors.grey.shade200),
                        borderRadius: BorderRadius.circular(16),
                        color: AppColors.cardBackground,
                        boxShadow: [
                          BoxShadow(
                            color: Colors.black.withOpacity(0.04),
                            offset: const Offset(0, 4),
                            blurRadius: 12,
                          ),
                        ],
                      ),
                      child: DropdownButtonFormField<String>(
                        value: _vehicleOptions.any(
                          (option) =>
                              option['value'] ==
                              registrationProvider.selectedVehicle,
                        )
                            ? registrationProvider.selectedVehicle
                            : null,
                        decoration: InputDecoration(
                          labelText: 'vehicle_type_label'.tr().isNotEmpty &&
                                  'vehicle_type_label'.tr() !=
                                      'vehicle_type_label'
                              ? 'vehicle_type_label'.tr()
                              : 'نوع وسیله',
                          labelStyle: const TextStyle(fontSize: 13),
                          border: InputBorder.none,
                        ),
                        icon: const Icon(
                          Icons.keyboard_arrow_down_rounded,
                        ),
                        isExpanded: true,
                        items: _vehicleOptions.map((option) {
                          final String value = option['value']!;

                          final String fallbackLabel = value == 'Car'
                              ? 'تاکسی (سواری)'
                              : value == 'Bike'
                                  ? 'موترسایکل'
                                  : 'باربری';

                          return DropdownMenuItem<String>(
                            value: value,
                            child: Row(
                              children: [
                                _vehicleOptionIcon(
                                  option['icon']!,
                                  value,
                                ),
                                const SizedBox(width: 12),
                                Text(
                                  _vehicleLabel(
                                    option['label']!,
                                    fallbackLabel,
                                  ),
                                  style: const TextStyle(fontSize: 14),
                                ),
                              ],
                            ),
                          );
                        }).toList(),
                        validator: (value) {
                          if (value == null || value.isEmpty) {
                            final String errorText = 'vehicle_type_error'.tr();

                            return errorText == 'vehicle_type_error'
                                ? 'نوع وسیله را انتخاب کنید'
                                : errorText;
                          }

                          return null;
                        },
                        onChanged: (value) {
                          if (value != null) {
                            registrationProvider.setSelectedVehicle(value);
                            registrationProvider
                                .checkVehicleBasicFormValidity();
                          }
                        },
                      ),
                    ),
                    const SizedBox(height: 10),
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
                      padding: const EdgeInsets.all(16),
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          TextFormField(
                            controller: registrationProvider.brandController,
                            decoration: InputDecoration(
                              labelText: 'vehicle_brand_label'.tr(),
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
                              if (value == null || value.isEmpty) {
                                return 'vehicle_brand_error'.tr();
                              }

                              return null;
                            },
                            onChanged: (_) {
                              registrationProvider
                                  .checkVehicleBasicFormValidity();
                            },
                          ),
                          const SizedBox(height: 16),
                          TextFormField(
                            controller: registrationProvider.colorController,
                            decoration: InputDecoration(
                              labelText: 'vehicle_color_label'.tr(),
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
                              if (value == null || value.isEmpty) {
                                return 'vehicle_color_error'.tr();
                              }

                              return null;
                            },
                            onChanged: (_) {
                              registrationProvider
                                  .checkVehicleBasicFormValidity();
                            },
                          ),
                          const SizedBox(height: 16),
                          TextFormField(
                            controller:
                                registrationProvider.productionYearController,
                            keyboardType: TextInputType.number,
                            decoration: InputDecoration(
                              labelText: 'vehicle_year_label'.tr(),
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
                              if (value == null || value.isEmpty) {
                                return 'vehicle_year_error'.tr();
                              }

                              return null;
                            },
                            onChanged: (value) {
                              final String converted =
                                  _toEnglishNumbers(value);

                              if (converted != value) {
                                registrationProvider
                                    .productionYearController
                                    .value = TextEditingValue(
                                  text: converted,
                                  selection: TextSelection.collapsed(
                                    offset: converted.length,
                                  ),
                                );
                              }

                              registrationProvider
                                  .checkVehicleBasicFormValidity();
                            },
                          ),
                          const SizedBox(height: 20),
                          Text(
                            'plate_info_header'.tr(),
                            style: const TextStyle(
                              fontWeight: FontWeight.bold,
                              fontSize: 13,
                              color: AppColors.primaryBrand,
                            ),
                          ),
                          const SizedBox(height: 12),
                          Row(
                            children: [
                              Expanded(
                                flex: 3,
                                child: DropdownButtonFormField<String>(
                                  value: afghanistanProvinces.contains(
                                    registrationProvider.plateProvince,
                                  )
                                      ? registrationProvider.plateProvince
                                      : null,
                                  decoration: InputDecoration(
                                    labelText: 'province'.tr(),
                                    labelStyle: const TextStyle(
                                      fontSize: 11,
                                    ),
                                    border: OutlineInputBorder(
                                      borderRadius: BorderRadius.circular(12),
                                    ),
                                    contentPadding:
                                        const EdgeInsets.symmetric(
                                      horizontal: 8,
                                      vertical: 10,
                                    ),
                                  ),
                                  items: afghanistanProvinces.map((province) {
                                    return DropdownMenuItem<String>(
                                      value: province,
                                      child: Text(
                                        province,
                                        style: const TextStyle(fontSize: 12),
                                      ),
                                    );
                                  }).toList(),
                                  onChanged: (value) {
                                    if (value != null) {
                                      registrationProvider
                                          .setPlateProvince(value);
                                      registrationProvider
                                          .checkVehicleBasicFormValidity();
                                    }
                                  },
                                ),
                              ),
                              const SizedBox(width: 6),
                              Expanded(
                                flex: 2,
                                child: DropdownButtonFormField<String>(
                                  value: plateCategories.contains(
                                    registrationProvider.plateCategory,
                                  )
                                      ? registrationProvider.plateCategory
                                      : null,
                                  decoration: InputDecoration(
                                    labelText: 'plate_letter'.tr(),
                                    labelStyle: const TextStyle(
                                      fontSize: 11,
                                    ),
                                    border: OutlineInputBorder(
                                      borderRadius: BorderRadius.circular(12),
                                    ),
                                    contentPadding:
                                        const EdgeInsets.symmetric(
                                      horizontal: 6,
                                      vertical: 10,
                                    ),
                                  ),
                                  items: plateCategories.map((category) {
                                    return DropdownMenuItem<String>(
                                      value: category,
                                      child: Text(
                                        category,
                                        style: const TextStyle(fontSize: 12),
                                      ),
                                    );
                                  }).toList(),
                                  onChanged: (value) {
                                    if (value != null) {
                                      registrationProvider
                                          .setPlateCategory(value);
                                      registrationProvider
                                          .checkVehicleBasicFormValidity();
                                    }
                                  },
                                ),
                              ),
                              const SizedBox(width: 6),
                              Expanded(
                                flex: 4,
                                child: TextFormField(
                                  controller: registrationProvider
                                      .numberPlateController,
                                  keyboardType: TextInputType.number,
                                  decoration: InputDecoration(
                                    labelText: 'plate_number'.tr(),
                                    labelStyle: const TextStyle(
                                      fontSize: 11,
                                    ),
                                    border: const OutlineInputBorder(
                                      borderRadius: BorderRadius.all(
                                        Radius.circular(12),
                                      ),
                                    ),
                                    contentPadding:
                                        const EdgeInsets.symmetric(
                                      horizontal: 10,
                                      vertical: 10,
                                    ),
                                  ),
                                  validator: (value) {
                                    if (value == null || value.isEmpty) {
                                      return 'plate_number_error'.tr();
                                    }

                                    return null;
                                  },
                                  onChanged: (value) {
                                    final String converted =
                                        _toEnglishNumbers(value);

                                    if (converted != value) {
                                      registrationProvider
                                          .numberPlateController
                                          .value = TextEditingValue(
                                        text: converted,
                                        selection: TextSelection.collapsed(
                                          offset: converted.length,
                                        ),
                                      );
                                    }

                                    registrationProvider
                                        .checkVehicleBasicFormValidity();
                                  },
                                ),
                              ),
                            ],
                          ),
                          const SizedBox(height: 14),
                          DropdownButtonFormField<String>(
                            value: plateTypes.contains(
                              registrationProvider.plateType,
                            )
                                ? registrationProvider.plateType
                                : null,
                            decoration: InputDecoration(
                              labelText: 'plate_type'.tr(),
                              labelStyle: const TextStyle(fontSize: 12),
                              border: OutlineInputBorder(
                                borderRadius: BorderRadius.circular(12),
                              ),
                              contentPadding: const EdgeInsets.symmetric(
                                horizontal: 10,
                                vertical: 10,
                              ),
                            ),
                            items: plateTypes.map((type) {
                              return DropdownMenuItem<String>(
                                value: type,
                                child: Text(
                                  type,
                                  style: const TextStyle(fontSize: 13),
                                ),
                              );
                            }).toList(),
                            onChanged: (value) {
                              if (value != null) {
                                registrationProvider.setPlateType(value);
                                registrationProvider
                                    .checkVehicleBasicFormValidity();
                              }
                            },
                          ),
                        ],
                      ),
                    ),
                    const SizedBox(height: 25),
                    SizedBox(
                      width: double.infinity,
                      height: 50,
                      child: ElevatedButton(
                        onPressed: registrationProvider
                                .isVehicleBasicFormValid
                            ? () async {
                                if (_formKey.currentState?.validate() ==
                                    true) {
                                  Navigator.pop(context, true);
                                }
                              }
                            : null,
                        style: ElevatedButton.styleFrom(
                          backgroundColor: registrationProvider
                                  .isVehicleBasicFormValid
                              ? AppColors.primaryButton
                              : Colors.grey.shade400,
                          foregroundColor: AppColors.buttonText,
                          shape: RoundedRectangleBorder(
                            borderRadius: BorderRadius.circular(12),
                          ),
                          elevation: 0,
                        ),
                        child: Text(
                          'btn_confirm_register'.tr(),
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
