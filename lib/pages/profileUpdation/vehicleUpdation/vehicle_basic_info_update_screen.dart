import 'package:easy_localization/easy_localization.dart';
import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import 'package:safir_drivers/methods/common_method.dart';
import 'package:safir_drivers/providers/registration_provider.dart';
import 'package:safir_drivers/utils/app_colors.dart';

class VehicleBasicInfoUpdateScreen extends StatefulWidget {
  const VehicleBasicInfoUpdateScreen({super.key});

  @override
  State<VehicleBasicInfoUpdateScreen> createState() =>
      _VehicleBasicInfoUpdateScreenState();
}

class _VehicleBasicInfoUpdateScreenState
    extends State<VehicleBasicInfoUpdateScreen> {
  final GlobalKey<FormState> _formKey = GlobalKey<FormState>();

  final List<String> afghanistanProvinces = <String>[
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

  final List<String> plateCategories = <String>[
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

  final List<String> plateTypes = <String>[
    'شخصی',
    'موقتی',
    'تاکسی',
    'دولتی',
  ];

  static const List<Map<String, String>> _vehicleOptions =
      <Map<String, String>>[
    <String, String>{
      'value': 'Car',
      'label': 'vehicle_car',
      'icon': 'assets/vehicles/home_car.png',
    },
    <String, String>{
      'value': 'Bike',
      'label': 'vehicle_bike',
      'icon': 'assets/vehicles/bike.png',
    },
    <String, String>{
      'value': 'cargo',
      'label': 'vehicle_cargo',
      'icon': 'assets/vehicles/cargo.png',
    },
  ];

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

  void _saveVehicleInfo(
    BuildContext context,
    RegistrationProvider registrationProvider,
  ) async {
    if (_formKey.currentState?.validate() != true) {
      return;
    }

    try {
      await registrationProvider.updateVehicleBasicInfo(context);

      if (!mounted) {
        return;
      }

      CommonMethods().displaySnackBar(
        'save_success'.tr(),
        context,
      );

      Navigator.pop(context);
    } catch (error, stackTrace) {
      debugPrint('Error while saving vehicle info: $error');
      debugPrintStack(stackTrace: stackTrace);
    }
  }

  @override
  Widget build(BuildContext context) {
    // این Provider فقط یک بار گرفته می‌شود؛ به notifyListeners گوش نمی‌دهد.
    final RegistrationProvider registrationProvider =
        context.read<RegistrationProvider>();

    return Scaffold(
      backgroundColor: AppColors.background,
      appBar: AppBar(
        backgroundColor: AppColors.cardBackground,
        elevation: 0,
        title: Text(
          'vehicle_info_title'.tr(),
          style: const TextStyle(
            fontWeight: FontWeight.bold,
            fontSize: 16,
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
          keyboardDismissBehavior:
              ScrollViewKeyboardDismissBehavior.manual,
          child: Form(
            key: _formKey,
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: <Widget>[
                Container(
                  margin: const EdgeInsets.symmetric(vertical: 10),
                  padding: const EdgeInsets.symmetric(
                    horizontal: 16,
                    vertical: 8,
                  ),
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
                  child: DropdownButtonFormField<String>(
                    value: _vehicleOptions.any(
                      (Map<String, String> option) =>
                          option['value'] ==
                          registrationProvider.selectedVehicle,
                    )
                        ? registrationProvider.selectedVehicle
                        : null,
                    decoration: InputDecoration(
                      labelText: 'vehicle_type_label'.tr(),
                      labelStyle: const TextStyle(fontSize: 13),
                      border: InputBorder.none,
                    ),
                    icon: const Icon(
                      Icons.keyboard_arrow_down_rounded,
                    ),
                    isExpanded: true,
                    items: _vehicleOptions.map(
                      (Map<String, String> option) {
                        final String value = option['value']!;

                        final String fallbackLabel = value == 'Car'
                            ? 'تاکسی (سواری)'
                            : value == 'Bike'
                                ? 'موترسایکل'
                                : 'باربری';

                        return DropdownMenuItem<String>(
                          value: value,
                          child: Row(
                            children: <Widget>[
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
                      },
                    ).toList(),
                    validator: (String? value) {
                      if (value == null || value.isEmpty) {
                        return 'vehicle_type_error'.tr();
                      }

                      return null;
                    },
                    onChanged: (String? value) {
                      if (value != null) {
                        registrationProvider.setSelectedVehicle(value);
                      }
                    },
                  ),
                ),
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
                  padding: const EdgeInsets.all(16),
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: <Widget>[
                      TextFormField(
                        controller: registrationProvider.brandController,
                        decoration: InputDecoration(
                          labelText: 'vehicle_brand_label'.tr(),
                          labelStyle: const TextStyle(fontSize: 13),
                          border: const OutlineInputBorder(
                            borderRadius: BorderRadius.all(
                              Radius.circular(12),
                            ),
                          ),
                          contentPadding: const EdgeInsets.symmetric(
                            horizontal: 12,
                            vertical: 10,
                          ),
                        ),
                        validator: (String? value) {
                          if (value == null || value.trim().isEmpty) {
                            return 'vehicle_brand_error'.tr();
                          }

                          return null;
                        },
                        onChanged: (_) {
                          registrationProvider
                              .checkVehicleBasicFormValidity();
                        },
                      ),
                      const SizedBox(height: 14),
                      TextFormField(
                        controller: registrationProvider.colorController,
                        decoration: InputDecoration(
                          labelText: 'vehicle_color_label'.tr(),
                          labelStyle: const TextStyle(fontSize: 13),
                          border: const OutlineInputBorder(
                            borderRadius: BorderRadius.all(
                              Radius.circular(12),
                            ),
                          ),
                          contentPadding: const EdgeInsets.symmetric(
                            horizontal: 12,
                            vertical: 10,
                          ),
                        ),
                        validator: (String? value) {
                          if (value == null || value.trim().isEmpty) {
                            return 'vehicle_color_error'.tr();
                          }

                          return null;
                        },
                        onChanged: (_) {
                          registrationProvider
                              .checkVehicleBasicFormValidity();
                        },
                      ),
                      const SizedBox(height: 14),
                      TextFormField(
                        controller:
                            registrationProvider.productionYearController,
                        keyboardType: TextInputType.number,
                        decoration: InputDecoration(
                          labelText: 'vehicle_year_label'.tr(),
                          labelStyle: const TextStyle(fontSize: 13),
                          border: const OutlineInputBorder(
                            borderRadius: BorderRadius.all(
                              Radius.circular(12),
                            ),
                          ),
                          contentPadding: const EdgeInsets.symmetric(
                            horizontal: 12,
                            vertical: 10,
                          ),
                        ),
                        validator: (String? value) {
                          if (value == null || value.trim().isEmpty) {
                            return 'vehicle_year_error'.tr();
                          }

                          return null;
                        },
                        onChanged: (_) {
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
                        children: <Widget>[
                          Expanded(
                            flex: 3,
                            child: DropdownButtonFormField<String>(
                              value: afghanistanProvinces.contains(
                                registrationProvider.plateProvince,
                              )
                                  ? registrationProvider.plateProvince
                                  : afghanistanProvinces.first,
                              decoration: InputDecoration(
                                labelText: 'province'.tr(),
                                labelStyle: const TextStyle(fontSize: 11),
                                border: OutlineInputBorder(
                                  borderRadius: BorderRadius.circular(12),
                                ),
                                contentPadding:
                                    const EdgeInsets.symmetric(
                                  horizontal: 8,
                                  vertical: 10,
                                ),
                              ),
                              items: afghanistanProvinces.map(
                                (String province) {
                                  return DropdownMenuItem<String>(
                                    value: province,
                                    child: Text(
                                      province,
                                      style: const TextStyle(fontSize: 12),
                                    ),
                                  );
                                },
                              ).toList(),
                              onChanged: (String? value) {
                                if (value != null) {
                                  registrationProvider
                                      .setPlateProvince(value);
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
                                  : plateCategories.first,
                              decoration: InputDecoration(
                                labelText: 'plate_letter'.tr(),
                                labelStyle: const TextStyle(fontSize: 11),
                                border: OutlineInputBorder(
                                  borderRadius: BorderRadius.circular(12),
                                ),
                                contentPadding:
                                    const EdgeInsets.symmetric(
                                  horizontal: 6,
                                  vertical: 10,
                                ),
                              ),
                              items: plateCategories.map(
                                (String category) {
                                  return DropdownMenuItem<String>(
                                    value: category,
                                    child: Text(
                                      category,
                                      style: const TextStyle(fontSize: 12),
                                    ),
                                  );
                                },
                              ).toList(),
                              onChanged: (String? value) {
                                if (value != null) {
                                  registrationProvider
                                      .setPlateCategory(value);
                                }
                              },
                            ),
                          ),
                          const SizedBox(width: 6),
                          Expanded(
                            flex: 4,
                            child: TextFormField(
                              controller:
                                  registrationProvider.numberPlateController,
                              keyboardType: TextInputType.number,
                              decoration: InputDecoration(
                                labelText: 'plate_number'.tr(),
                                labelStyle: const TextStyle(fontSize: 11),
                                hintText: '44892',
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
                              validator: (String? value) {
                                if (value == null || value.trim().isEmpty) {
                                  return 'plate_number_error'.tr();
                                }

                                return null;
                              },
                              onChanged: (_) {
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
                            : plateTypes.first,
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
                        items: plateTypes.map(
                          (String type) {
                            return DropdownMenuItem<String>(
                              value: type,
                              child: Text(
                                type,
                                style: const TextStyle(fontSize: 13),
                              ),
                            );
                          },
                        ).toList(),
                        onChanged: (String? value) {
                          if (value != null) {
                            registrationProvider.setPlateType(value);
                          }
                        },
                      ),
                    ],
                  ),
                ),
                const SizedBox(height: 24),
                Selector<RegistrationProvider, bool>(
                  selector: (
                    BuildContext context,
                    RegistrationProvider provider,
                  ) {
                    return provider.isLoading;
                  },
                  builder: (
                    BuildContext context,
                    bool isLoading,
                    Widget? child,
                  ) {
                    return SizedBox(
                      width: double.infinity,
                      height: 52,
                      child: ElevatedButton(
                        onPressed: isLoading
                            ? null
                            : () {
                                _saveVehicleInfo(
                                  context,
                                  registrationProvider,
                                );
                              },
                        style: ElevatedButton.styleFrom(
                          backgroundColor: AppColors.primaryBrand,
                          disabledBackgroundColor: Colors.grey.shade400,
                          shape: RoundedRectangleBorder(
                            borderRadius: BorderRadius.circular(12),
                          ),
                        ),
                        child: isLoading
                            ? const SizedBox(
                                width: 24,
                                height: 24,
                                child: CircularProgressIndicator(
                                  color: Colors.white,
                                  strokeWidth: 2.5,
                                ),
                              )
                            : Text(
                                'confirm_and_submit'.tr(),
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
    );
  }
}
