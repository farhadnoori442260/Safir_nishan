import 'package:easy_localization/easy_localization.dart';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
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
      (TextEditingValue oldValue, TextEditingValue newValue) {
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
    String? hintText,
    double labelFontSize = 13,
  }) {
    return InputDecoration(
      labelText: labelText,
      hintText: hintText,
      labelStyle: TextStyle(
        fontSize: labelFontSize,
        color: AppColors.textSecondary,
      ),
      border: const OutlineInputBorder(
        borderRadius: BorderRadius.all(
          Radius.circular(12),
        ),
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
        vertical: 10,
      ),
    );
  }

  Future<void> _saveVehicleInfo() async {
    FocusScope.of(context).unfocus();

    if (_formKey.currentState?.validate() != true) {
      return;
    }

    final RegistrationProvider registrationProvider =
        context.read<RegistrationProvider>();

    registrationProvider.checkVehicleBasicFormValidity();

    final bool canSave =
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

    if (!canSave) {
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
    final RegistrationProvider registrationProvider =
        context.read<RegistrationProvider>();

    return Scaffold(
      // کیبورد فقط یک‌بار و به‌صورت نرم در _KeyboardAwareBody مدیریت می‌شود.
      resizeToAvoidBottomInset: false,
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
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: <Widget>[
                        _buildVehicleTypeSelector(),
                        const SizedBox(height: 10),
                        _buildVehicleDetailsCard(
                          registrationProvider,
                        ),
                      ],
                    ),
                  ),
                ),
                const SizedBox(height: 10),
                _buildSaveButton(),
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
            value: dropdownValue,
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
                final String errorText = 'vehicle_type_error'.tr();

                return errorText == 'vehicle_type_error'
                    ? 'نوع وسیله را انتخاب کنید'
                    : errorText;
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

  Widget _buildVehicleDetailsCard(
    RegistrationProvider registrationProvider,
  ) {
    return Container(
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
          const SizedBox(height: 14),
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
          const SizedBox(height: 14),
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
          _buildPlateFirstRow(),
          const SizedBox(height: 14),
          _buildPlateTypeSelector(),
        ],
      ),
    );
  }

  Widget _buildPlateFirstRow() {
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
          child: _buildPlateNumberField(),
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
            (String item) {
              return DropdownMenuItem<String>(
                value: item,
                child: Text(
                  item,
                  overflow: TextOverflow.ellipsis,
                  style: const TextStyle(fontSize: 12),
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
            (String item) {
              return DropdownMenuItem<String>(
                value: item,
                child: Text(
                  item,
                  overflow: TextOverflow.ellipsis,
                  style: const TextStyle(fontSize: 12),
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

  Widget _buildPlateNumberField() {
    final RegistrationProvider registrationProvider =
        context.read<RegistrationProvider>();

    return TextFormField(
      controller: registrationProvider.numberPlateController,
      keyboardType: TextInputType.number,
      scrollPadding: const EdgeInsets.only(bottom: 120),
      textInputAction: TextInputAction.done,
      inputFormatters: <TextInputFormatter>[
        _englishNumberFormatter(),
        FilteringTextInputFormatter.digitsOnly,
        LengthLimitingTextInputFormatter(8),
      ],
      decoration: _fieldDecoration(
        labelText: 'plate_number'.tr(),
        hintText: '44892',
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
          ),
          items: plateTypes.map(
            (String item) {
              return DropdownMenuItem<String>(
                value: item,
                child: Text(
                  item,
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
        );
      },
    );
  }

  Widget _buildSaveButton() {
    return Selector<RegistrationProvider, _SaveButtonState>(
      selector: (
        BuildContext context,
        RegistrationProvider provider,
      ) {
        return _SaveButtonState(
          isLoading: provider.isLoading,
          isFormValid: provider.isVehicleBasicFormValid,
        );
      },
      builder: (
        BuildContext context,
        _SaveButtonState state,
        Widget? child,
      ) {
        return SizedBox(
          width: double.infinity,
          height: 52,
          child: ElevatedButton(
            onPressed: state.isLoading ? null : _saveVehicleInfo,
            style: ElevatedButton.styleFrom(
              backgroundColor: AppColors.primaryBrand,
              disabledBackgroundColor: Colors.grey.shade400,
              shape: RoundedRectangleBorder(
                borderRadius: BorderRadius.circular(12),
              ),
            ),
            child: state.isLoading
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
    );
  }
}

class _SaveButtonState {
  const _SaveButtonState({
    required this.isLoading,
    required this.isFormValid,
  });

  final bool isLoading;
  final bool isFormValid;

  @override
  bool operator ==(Object other) {
    if (identical(this, other)) {
      return true;
    }

    return other is _SaveButtonState &&
        other.isLoading == isLoading &&
        other.isFormValid == isFormValid;
  }

  @override
  int get hashCode => Object.hash(
        isLoading,
        isFormValid,
      );
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
      duration: const Duration(milliseconds: 150),
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
