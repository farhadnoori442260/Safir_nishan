import 'package:easy_localization/easy_localization.dart';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:provider/provider.dart';

import '../../../providers/registration_provider.dart';
import '../../../utils/app_colors.dart';

class VehicleBasicInfoScreen extends StatefulWidget {
  const VehicleBasicInfoScreen({super.key});

  @override
  State<VehicleBasicInfoScreen> createState() =>
      _VehicleBasicInfoScreenState();
}

class _VehicleBasicInfoScreenState
    extends State<VehicleBasicInfoScreen> {
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

  String _toEnglishNumbers(String input) {
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

    const List<String> arabic = <String>[
      '٠',
      '١',
      '٢',
      '٣',
      '٤',
      '٥',
      '٦',
      '٧',
      '٨',
      '٩',
    ];

    for (int index = 0; index < 10; index++) {
      input = input.replaceAll(farsi[index], english[index]);
      input = input.replaceAll(arabic[index], english[index]);
    }

    return input;
  }

  TextInputFormatter _englishNumberFormatter() {
    return TextInputFormatter.withFunction(
      (
        TextEditingValue oldValue,
        TextEditingValue newValue,
      ) {
        if (!newValue.composing.isCollapsed) {
          return newValue;
        }

        final String converted = _toEnglishNumbers(newValue.text);

        return newValue.copyWith(
          text: converted,
          selection: TextSelection.collapsed(
            offset: converted.length,
          ),
          composing: TextRange.empty,
        );
      },
    );
  }

  Widget _vehicleOptionIcon(
    String assetPath,
    String value,
  ) {
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
      errorBuilder: (
        BuildContext context,
        Object error,
        StackTrace? stackTrace,
      ) {
        return Icon(
          fallbackIcon,
          size: 28,
          color: AppColors.primaryBrand,
        );
      },
    );
  }

  String _vehicleLabel(
    String translationKey,
    String fallback,
  ) {
    final String translated = translationKey.tr();

    return translated.isNotEmpty && translated != translationKey
        ? translated
        : fallback;
  }

  InputDecoration _fieldDecoration({
    required String labelText,
    double labelFontSize = 14,
  }) {
    return InputDecoration(
      labelText: labelText,
      labelStyle: TextStyle(
        fontSize: labelFontSize,
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
      border: const OutlineInputBorder(
        borderRadius: BorderRadius.all(
          Radius.circular(12),
        ),
      ),
      contentPadding: const EdgeInsets.symmetric(
        horizontal: 12,
        vertical: 14,
      ),
    );
  }

  void _confirmVehicleInfo() {
    FocusScope.of(context).unfocus();

    if (_formKey.currentState?.validate() != true) {
      return;
    }

    final RegistrationProvider registrationProvider =
        context.read<RegistrationProvider>();

    final bool isValid =
        registrationProvider.selectedVehicle != null &&
            registrationProvider.selectedVehicle!.trim().isNotEmpty &&
            registrationProvider.brandController.text.trim().isNotEmpty &&
            registrationProvider.colorController.text.trim().isNotEmpty &&
            registrationProvider
                .productionYearController.text
                .trim()
                .isNotEmpty &&
            registrationProvider
                .numberPlateController.text
                .trim()
                .isNotEmpty &&
            registrationProvider.plateProvince.trim().isNotEmpty &&
            registrationProvider.plateCategory.trim().isNotEmpty &&
            registrationProvider.plateType.trim().isNotEmpty;

    registrationProvider.checkVehicleBasicFormValidity();

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
      resizeToAvoidBottomInset: true,
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
                        ScrollViewKeyboardDismissBehavior.manual,
                    padding: EdgeInsets.only(
                      bottom: MediaQuery.viewInsetsOf(context).bottom + 16,
                    ),
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: <Widget>[
                        _buildVehicleTypeSelector(),
                        const SizedBox(height: 10),
                        _buildVehicleInformationCard(
                          registrationProvider,
                        ),
                      ],
                    ),
                  ),
                ),
                const SizedBox(height: 10),
                _buildConfirmButton(),
              ],
            ),
          ),
        ),
      ),
    );
  }

  Widget _buildVehicleTypeSelector() {
    return Selector<RegistrationProvider, String?>(
      selector: (
        BuildContext context,
        RegistrationProvider provider,
      ) {
        return provider.selectedVehicle;
      },
      builder: (
        BuildContext context,
        String? selectedVehicle,
        Widget? child,
      ) {
        final RegistrationProvider registrationProvider =
            context.read<RegistrationProvider>();

        final String? dropdownValue = _vehicleOptions.any(
          (Map<String, String> option) =>
              option['value'] == selectedVehicle,
        )
            ? selectedVehicle
            : null;

        return Container(
          margin: const EdgeInsets.symmetric(vertical: 4),
          padding: const EdgeInsets.symmetric(
            horizontal: 16,
            vertical: 8,
          ),
          decoration: BoxDecoration(
            border: Border.all(
              color: Colors.grey.shade200,
            ),
            borderRadius: BorderRadius.circular(16),
            color: AppColors.cardBackground,
            boxShadow: <BoxShadow>[
              BoxShadow(
                color: Colors.black.withOpacity(0.04),
                offset: const Offset(0, 4),
                blurRadius: 12,
              ),
            ],
          ),
          child: DropdownButtonFormField<String>(
            value: dropdownValue,
            decoration: InputDecoration(
              labelText: 'vehicle_type_label'.tr(),
              labelStyle: const TextStyle(
                fontSize: 13,
              ),
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
                        style: const TextStyle(
                          fontSize: 14,
                        ),
                      ),
                    ],
                  ),
                );
              },
            ).toList(),
            validator: (String? value) {
              if (value == null || value.isEmpty) {
                return 'نوع وسیله را انتخاب کنید';
              }

              return null;
            },
            onChanged: (String? value) {
              if (value != null) {
                registrationProvider.setSelectedVehicle(value);
              }
            },
          ),
        );
      },
    );
  }

  Widget _buildVehicleInformationCard(
    RegistrationProvider registrationProvider,
  ) {
    return Container(
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
      padding: const EdgeInsets.all(16),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: <Widget>[
          TextFormField(
            controller: registrationProvider.brandController,
            textInputAction: TextInputAction.next,
            decoration: _fieldDecoration(
              labelText: 'vehicle_brand_label'.tr(),
            ),
            validator: (String? value) {
              if (value == null || value.trim().isEmpty) {
                return 'vehicle_brand_error'.tr();
              }

              return null;
            },
            onChanged: (_) {
              registrationProvider.checkVehicleBasicFormValidity();
            },
          ),
          const SizedBox(height: 16),
          TextFormField(
            controller: registrationProvider.colorController,
            textInputAction: TextInputAction.next,
            decoration: _fieldDecoration(
              labelText: 'vehicle_color_label'.tr(),
            ),
            validator: (String? value) {
              if (value == null || value.trim().isEmpty) {
                return 'vehicle_color_error'.tr();
              }

              return null;
            },
            onChanged: (_) {
              registrationProvider.checkVehicleBasicFormValidity();
            },
          ),
          const SizedBox(height: 16),
          TextFormField(
            controller: registrationProvider.productionYearController,
            keyboardType: TextInputType.number,
            textInputAction: TextInputAction.next,
            inputFormatters: <TextInputFormatter>[
              _englishNumberFormatter(),
              FilteringTextInputFormatter.digitsOnly,
              LengthLimitingTextInputFormatter(4),
            ],
            decoration: _fieldDecoration(
              labelText: 'vehicle_year_label'.tr(),
            ),
            validator: (String? value) {
              if (value == null || value.trim().isEmpty) {
                return 'vehicle_year_error'.tr();
              }

              return null;
            },
            onChanged: (_) {
              registrationProvider.checkVehicleBasicFormValidity();
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
          _buildPlateRow(),
          const SizedBox(height: 14),
          _buildPlateTypeSelector(),
        ],
      ),
    );
  }

  Widget _buildPlateRow() {
    return Row(
      children: <Widget>[
        Expanded(
          flex: 3,
          child: _buildProvinceSelector(),
        ),
        const SizedBox(width: 6),
        Expanded(
          flex: 2,
          child: _buildCategorySelector(),
        ),
        const SizedBox(width: 6),
        Expanded(
          flex: 4,
          child: _buildNumberPlateField(),
        ),
      ],
    );
  }

  Widget _buildProvinceSelector() {
    return Selector<RegistrationProvider, String>(
      selector: (
        BuildContext context,
        RegistrationProvider provider,
      ) {
        return provider.plateProvince;
      },
      builder: (
        BuildContext context,
        String province,
        Widget? child,
      ) {
        final RegistrationProvider registrationProvider =
            context.read<RegistrationProvider>();

        final String value = afghanistanProvinces.contains(province)
            ? province
            : afghanistanProvinces.first;

        return DropdownButtonFormField<String>(
          value: value,
          isExpanded: true,
          decoration: _fieldDecoration(
            labelText: 'province'.tr(),
            labelFontSize: 11,
          ).copyWith(
            contentPadding: const EdgeInsets.symmetric(
              horizontal: 8,
              vertical: 10,
            ),
          ),
          items: afghanistanProvinces.map(
            (String provinceName) {
              return DropdownMenuItem<String>(
                value: provinceName,
                child: Text(
                  provinceName,
                  overflow: TextOverflow.ellipsis,
                  style: const TextStyle(
                    fontSize: 12,
                  ),
                ),
              );
            },
          ).toList(),
          onChanged: (String? value) {
            if (value != null) {
              registrationProvider.setPlateProvince(value);
            }
          },
        );
      },
    );
  }

  Widget _buildCategorySelector() {
    return Selector<RegistrationProvider, String>(
      selector: (
        BuildContext context,
        RegistrationProvider provider,
      ) {
        return provider.plateCategory;
      },
      builder: (
        BuildContext context,
        String category,
        Widget? child,
      ) {
        final RegistrationProvider registrationProvider =
            context.read<RegistrationProvider>();

        final String value = plateCategories.contains(category)
            ? category
            : plateCategories.first;

        return DropdownButtonFormField<String>(
          value: value,
          isExpanded: true,
          decoration: _fieldDecoration(
            labelText: 'plate_letter'.tr(),
            labelFontSize: 11,
          ).copyWith(
            contentPadding: const EdgeInsets.symmetric(
              horizontal: 6,
              vertical: 10,
            ),
          ),
          items: plateCategories.map(
            (String categoryName) {
              return DropdownMenuItem<String>(
                value: categoryName,
                child: Text(
                  categoryName,
                  overflow: TextOverflow.ellipsis,
                  style: const TextStyle(
                    fontSize: 12,
                  ),
                ),
              );
            },
          ).toList(),
          onChanged: (String? value) {
            if (value != null) {
              registrationProvider.setPlateCategory(value);
            }
          },
        );
      },
    );
  }

  Widget _buildNumberPlateField() {
    final RegistrationProvider registrationProvider =
        context.read<RegistrationProvider>();

    return TextFormField(
      controller: registrationProvider.numberPlateController,
      keyboardType: TextInputType.number,
      textInputAction: TextInputAction.done,
      inputFormatters: <TextInputFormatter>[
        _englishNumberFormatter(),
        FilteringTextInputFormatter.digitsOnly,
        LengthLimitingTextInputFormatter(8),
      ],
      decoration: _fieldDecoration(
        labelText: 'plate_number'.tr(),
        labelFontSize: 11,
      ).copyWith(
        contentPadding: const EdgeInsets.symmetric(
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
        registrationProvider.checkVehicleBasicFormValidity();
      },
      onFieldSubmitted: (_) {
        FocusScope.of(context).unfocus();
      },
    );
  }

  Widget _buildPlateTypeSelector() {
    return Selector<RegistrationProvider, String>(
      selector: (
        BuildContext context,
        RegistrationProvider provider,
      ) {
        return provider.plateType;
      },
      builder: (
        BuildContext context,
        String plateType,
        Widget? child,
      ) {
        final RegistrationProvider registrationProvider =
            context.read<RegistrationProvider>();

        final String value = plateTypes.contains(plateType)
            ? plateType
            : plateTypes.first;

        return DropdownButtonFormField<String>(
          value: value,
          isExpanded: true,
          decoration: _fieldDecoration(
            labelText: 'plate_type'.tr(),
            labelFontSize: 12,
          ).copyWith(
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
                  style: const TextStyle(
                    fontSize: 13,
                  ),
                ),
              );
            },
          ).toList(),
          onChanged: (String? value) {
            if (value != null) {
              registrationProvider.setPlateType(value);
            }
          },
        );
      },
    );
  }

  Widget _buildConfirmButton() {
    return Selector<RegistrationProvider, bool>(
      selector: (
        BuildContext context,
        RegistrationProvider provider,
      ) {
        return provider.isVehicleBasicFormValid;
      },
      builder: (
        BuildContext context,
        bool isFormValid,
        Widget? child,
      ) {
        return SizedBox(
          width: double.infinity,
          height: 52,
          child: ElevatedButton(
            onPressed: isFormValid ? _confirmVehicleInfo : null,
            style: ElevatedButton.styleFrom(
              backgroundColor: isFormValid
                  ? AppColors.primaryButton
                  : Colors.grey.shade400,
              foregroundColor: AppColors.buttonText,
              elevation: 0,
              shape: RoundedRectangleBorder(
                borderRadius: BorderRadius.circular(12),
              ),
            ),
            child: Text(
              'btn_confirm_register'.tr(),
              style: const TextStyle(
                fontSize: 16,
                fontWeight: FontWeight.bold,
              ),
            ),
          ),
        );
      },
    );
  }
}
