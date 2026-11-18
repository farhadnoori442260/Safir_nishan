import 'package:easy_localization/easy_localization.dart';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:provider/provider.dart';

import '../../../providers/registration_provider.dart';
import '../../../utils/afghan_locations.dart';
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

  // همهٔ ۳۴ ولایت (قبلاً فقط ۱۱ ولایت بود و راننده‌های بقیه ولایت‌ها نمی‌توانستند
  // پلاک درست ثبت کنند). همان فهرست ولایت‌های ثبت‌نام است.
  final List<String> afghanistanProvinces = AfghanLocations.provinces;

  // املای قدیمی ذخیره‌شده → املای فهرست فعلی
  static const Map<String, String> _provinceAlias = <String, String>{
    'کندهار': 'قندهار',
  };

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

  // پیشنهاد سریع برند/مدل و رنگ؛ تایپ را کم می‌کند و املای یکسان می‌دهد
  static const Map<String, List<String>> _brandSuggestions =
      <String, List<String>>{
    'Car': <String>[
      'تویوتا کرولا',
      'تویوتا پروبکس',
      'تویوتا کمری',
      'تویوتا ویتز',
      'هیوندای',
      'نیسان',
    ],
    'Bike': <String>['هوندا', 'یاماها', 'سوزوکی'],
  };

  static const List<String> _colorSuggestions = <String>[
    'سفید',
    'نقره‌ای',
    'خاکستری',
    'مشکی',
    'آبی',
    'قرمز',
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
    bool selected,
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
      height: 36,
      width: 60,
      fit: BoxFit.contain,
      // آیکن‌ها سفیدند؛ برای دیده شدن در هر دو تم، رنگ‌آمیزی می‌شوند
      color: selected ? AppColors.primaryBrand : AppColors.iconSecondary,
      colorBlendMode: BlendMode.srcIn,
      errorBuilder: (
        BuildContext context,
        Object error,
        StackTrace? stackTrace,
      ) {
        return Icon(
          fallbackIcon,
          size: 30,
          color: selected ? AppColors.primaryBrand : AppColors.iconSecondary,
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
        color: AppColors.fieldBorder,
      ),
    );

    final Color errorColor = AppColors.danger;

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
        borderSide: BorderSide(
          color: AppColors.primaryBrand,
          width: 2,
        ),
      ),
      errorBorder: baseBorder.copyWith(
        borderSide: BorderSide(color: errorColor),
      ),
      focusedErrorBorder: baseBorder.copyWith(
        borderSide: BorderSide(color: errorColor, width: 2),
      ),
      contentPadding: const EdgeInsets.symmetric(
        horizontal: 14,
        vertical: 14,
      ),
    );
  }

  /// ظاهر مشترک کارت‌ها؛ بدون سایه (سبک‌تر است و در حالت تاریک تمیز می‌ماند).
  BoxDecoration _cardDecoration() {
    return BoxDecoration(
      color: AppColors.cardBackground,
      borderRadius: BorderRadius.circular(24),
      border: Border.all(color: AppColors.borderLight),
    );
  }

  // سال ساخت: چهار رقم، میلادی (مثلاً ۲۰۱۵)، از ۱۹۷۰ تا سال آینده
  bool _yearOk(String raw) {
    final int? y = int.tryParse(_toEnglishNumbers(raw.trim()));
    return y != null && y >= 1970 && y <= DateTime.now().year + 1;
  }

  void _confirmVehicleInfo() {
    FocusScope.of(context).unfocus();

    if (_formKey.currentState?.validate() != true) {
      return;
    }

    final RegistrationProvider registrationProvider =
        context.read<RegistrationProvider>();

    final bool isValid = _yearOk(
            registrationProvider.productionYearController.text) &&
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
          style: TextStyle(
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
          bottom: BorderSide(color: AppColors.borderLight),
        ),
        actions: <Widget>[
          TextButton(
            onPressed: () => Navigator.pop(context),
            child: Text(
              'close'.tr(),
              style: TextStyle(
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

  String _typeFallbackLabel(String value) => value == 'Car'
      ? 'تاکسی (سواری)'
      : value == 'Bike'
          ? 'موترسایکل'
          : 'باربری';

  /// انتخاب نوع وسیله: سه کارت کنار هم، همیشه دیده می‌شود (به‌جای منوی بازشو)
  Widget _buildVehicleTypeSelector() {
    final RegistrationProvider registrationProvider =
        context.read<RegistrationProvider>();

    return FormField<String>(
      validator: (String? _) {
        final String? v = registrationProvider.selectedVehicle;
        final bool ok = v != null &&
            _vehicleOptions.any((Map<String, String> o) => o['value'] == v);
        return ok ? null : 'نوع وسیله را انتخاب کنید';
      },
      builder: (FormFieldState<String> field) {
        return Selector<RegistrationProvider, String?>(
          selector: (BuildContext context, RegistrationProvider provider) =>
              provider.selectedVehicle,
          builder: (BuildContext context, String? selectedVehicle, Widget? _) {
            return Container(
              margin: const EdgeInsets.symmetric(vertical: 4),
              padding: const EdgeInsets.all(16),
              decoration: _cardDecoration(),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: <Widget>[
                  Text(
                    'vehicle_type_label'.tr(),
                    style: TextStyle(
                      fontSize: 13,
                      fontWeight: FontWeight.w600,
                      color: AppColors.textSecondary,
                    ),
                  ),
                  const SizedBox(height: 12),
                  Row(
                    children: <Widget>[
                      for (int i = 0; i < _vehicleOptions.length; i++) ...<Widget>[
                        if (i > 0) const SizedBox(width: 10),
                        Expanded(
                          child: _typeCard(
                            option: _vehicleOptions[i],
                            selected:
                                selectedVehicle == _vehicleOptions[i]['value'],
                            onTap: () {
                              registrationProvider.setSelectedVehicle(
                                _vehicleOptions[i]['value']!,
                              );
                              field.didChange(_vehicleOptions[i]['value']);
                            },
                          ),
                        ),
                      ],
                    ],
                  ),
                  if (field.hasError)
                    Padding(
                      padding: const EdgeInsets.only(top: 8),
                      child: Text(
                        field.errorText!,
                        style: TextStyle(
                          fontSize: 12,
                          color: AppColors.danger,
                        ),
                      ),
                    ),
                ],
              ),
            );
          },
        );
      },
    );
  }

  Widget _typeCard({
    required Map<String, String> option,
    required bool selected,
    required VoidCallback onTap,
  }) {
    final String value = option['value']!;

    return InkWell(
      borderRadius: BorderRadius.circular(16),
      onTap: onTap,
      child: AnimatedContainer(
        duration: const Duration(milliseconds: 150),
        padding: const EdgeInsets.symmetric(vertical: 14, horizontal: 6),
        decoration: BoxDecoration(
          color: selected
              ? AppColors.primaryBrand.withOpacity(0.10)
              : AppColors.backgroundLight,
          borderRadius: BorderRadius.circular(16),
          border: Border.all(
            color: selected ? AppColors.primaryBrand : AppColors.fieldBorder,
            width: selected ? 1.6 : 1,
          ),
        ),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: <Widget>[
            _vehicleOptionIcon(option['icon']!, value, selected),
            const SizedBox(height: 8),
            Text(
              _vehicleLabel(option['label']!, _typeFallbackLabel(value)),
              textAlign: TextAlign.center,
              maxLines: 2,
              overflow: TextOverflow.ellipsis,
              style: TextStyle(
                fontSize: 12.5,
                fontWeight: selected ? FontWeight.bold : FontWeight.w500,
                color: selected ? AppColors.primaryBrand : AppColors.textPrimary,
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _chips(
    List<String> items,
    TextEditingController controller,
    RegistrationProvider provider,
  ) {
    return Padding(
      padding: const EdgeInsets.only(top: 8),
      child: ValueListenableBuilder<TextEditingValue>(
        valueListenable: controller,
        builder: (BuildContext context, TextEditingValue v, Widget? _) {
          return Wrap(
            spacing: 6,
            runSpacing: 6,
            children: items.map((String item) {
              final bool on = v.text.trim() == item;
              return GestureDetector(
                onTap: () {
                  controller.text = item;
                  provider.checkVehicleBasicFormValidity();
                },
                child: Container(
                  padding:
                      const EdgeInsets.symmetric(horizontal: 12, vertical: 6),
                  decoration: BoxDecoration(
                    color: on
                        ? AppColors.primaryBrand.withOpacity(0.10)
                        : Colors.transparent,
                    borderRadius: BorderRadius.circular(20),
                    border: Border.all(
                      color: on ? AppColors.primaryBrand : AppColors.fieldBorder,
                    ),
                  ),
                  child: Text(
                    item,
                    style: TextStyle(
                      fontSize: 12,
                      color:
                          on ? AppColors.primaryBrand : AppColors.textSecondary,
                    ),
                  ),
                ),
              );
            }).toList(),
          );
        },
      ),
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
          Selector<RegistrationProvider, String?>(
            selector: (BuildContext c, RegistrationProvider p) =>
                p.selectedVehicle,
            builder: (BuildContext c, String? type, Widget? _) {
              final List<String>? list = _brandSuggestions[type];
              if (list == null) return const SizedBox.shrink();
              return _chips(
                list,
                registrationProvider.brandController,
                registrationProvider,
              );
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
          _chips(
            _colorSuggestions,
            registrationProvider.colorController,
            registrationProvider,
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
              hintText: '2015',
              icon: Icons.calendar_today_outlined,
            ),
            validator: (String? value) {
              if (value == null || value.trim().isEmpty) {
                return 'vehicle_year_error'.tr();
              }

              if (!_yearOk(value)) {
                return _vehicleLabel(
                  'vehicle_year_invalid',
                  'سال ساخت را میلادی و درست بنویسید (مثلاً 2015)',
                );
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
            style: TextStyle(
              fontWeight: FontWeight.w700,
              fontSize: 13.5,
              color: AppColors.textPrimary,
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

        final String normalized = _provinceAlias[province] ?? province;
        final String value = afghanistanProvinces.contains(normalized)
            ? normalized
            : afghanistanProvinces.first;

        return DropdownButtonFormField<String>(
          value: value,
          isExpanded: true,
          menuMaxHeight: 320,
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
                  style: TextStyle(
                    fontSize: 12,
                    color: AppColors.textPrimary,
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
                  style: TextStyle(
                    fontSize: 12,
                    color: AppColors.textPrimary,
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
        if (value == null || value.trim().length < 3) {
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
                  style: TextStyle(
                    fontSize: 13,
                    color: AppColors.textPrimary,
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
              disabledBackgroundColor: AppColors.borderLight,
              disabledForegroundColor: AppColors.textSecondary,
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
