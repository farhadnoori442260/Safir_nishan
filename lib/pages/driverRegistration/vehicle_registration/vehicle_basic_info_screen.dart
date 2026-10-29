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
    String? hintText,
    IconData? icon,
    double labelFontSize = 14,
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
      fontSize: labelFontSize,
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
        vertical: 14,
      ),
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
      // کیبورد فقط یک‌بار و به‌صورت نرم در _KeyboardAwareBody مدیریت می‌شود.
      resizeToAvoidBottomInset: false,
      backgroundColor: AppColors.background,
      appBar: AppBar(
        title: Text(
          'vehicle_info_title'.tr(),
          style: const TextStyle(
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
            color: AppColors.textSecondary.withOpacity(0.10),
          ),
        ),
        actions: <Widget>[
          TextButton(
            onPressed: () => Navigator.pop(context),
            child: Text(
              'close'.tr(),
              style: const TextStyle(
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
                    padding: const EdgeInsets.only(bottom: 16),
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
          decoration: _cardDecoration(),
          child: DropdownButtonFormField<String>(
            value: dropdownValue,
            decoration: InputDecoration(
              labelText: 'vehicle_type_label'.tr(),
              labelStyle: const TextStyle(
                fontSize: 13,
                color: AppColors.textSecondary,
              ),
              border: InputBorder.none,
            ),
            icon: const Icon(
              Icons.keyboard_arrow_down_rounded,
            ),
            isExpanded: true,
            dropdownColor: AppColors.cardBackground,
            borderRadius: BorderRadius.circular(14),
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
      decoration: _cardDecoration(),
      padding: const EdgeInsets.all(16),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: <Widget>[
          TextFormField(
            controller: registrationProvider.brandController,
            textInputAction: TextInputAction.next,
            decoration: _fieldDecoration(
              labelText: 'vehicle_brand_label'.tr(),
              icon: Icons.directions_car_outlined,
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
              icon: Icons.palette_outlined,
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
              icon: Icons.calendar_today_outlined,
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
              fontWeight: FontWeight.w700,
              fontSize: 13.5,
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
          dropdownColor: AppColors.cardBackground,
          borderRadius: BorderRadius.circular(14),
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
          dropdownColor: AppColors.cardBackground,
          borderRadius: BorderRadius.circular(14),
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
      scrollPadding: const EdgeInsets.only(bottom: 120),
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
          dropdownColor: AppColors.cardBackground,
          borderRadius: BorderRadius.circular(14),
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
          height: 54,
          child: ElevatedButton(
            onPressed: isFormValid ? _confirmVehicleInfo : null,
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
            child: Text(
              'btn_confirm_register'.tr(),
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
