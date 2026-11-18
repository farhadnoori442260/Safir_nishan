import 'package:flutter/material.dart';
import 'package:provider/provider.dart';

import '../providers/registration_provider.dart';
import '../utils/afghan_locations.dart';
import '../utils/app_colors.dart';

/// دو انتخاب‌گر هماهنگ: اول ولایت، بعد شهر.
/// با عوض شدن ولایت، شهر قبلی پاک می‌شود. هم در ثبت‌نام و هم در ویرایش پروفایل
/// راننده استفاده می‌شود و مستقیم با [RegistrationProvider] کار می‌کند.
class ProvinceCityFields extends StatelessWidget {
  const ProvinceCityFields({super.key});

  @override
  Widget build(BuildContext context) {
    return Consumer<RegistrationProvider>(
      builder: (BuildContext context, RegistrationProvider p, Widget? _) {
        final bool hasProvince = p.province.isNotEmpty;
        return Column(
          children: <Widget>[
            _PickerField(
              label: 'ولایت',
              icon: Icons.map_outlined,
              value: p.province,
              onTap: () async {
                final String? picked = await _showPicker(
                  context,
                  title: 'انتخاب ولایت',
                  items: AfghanLocations.provinces,
                  current: p.province,
                );
                if (picked != null) p.setProvince(picked);
              },
            ),
            const SizedBox(height: 16),
            _PickerField(
              label: 'شهر / ولسوالی',
              icon: Icons.location_city_outlined,
              value: p.city,
              enabled: hasProvince,
              hint: hasProvince ? null : 'اول ولایت را انتخاب کنید',
              onTap: () async {
                final String? picked = await _showPicker(
                  context,
                  title: 'انتخاب شهر',
                  items: AfghanLocations.cities(p.province),
                  current: p.city,
                );
                if (picked != null) p.setCity(picked);
              },
            ),
          ],
        );
      },
    );
  }

  static Future<String?> _showPicker(
    BuildContext context, {
    required String title,
    required List<String> items,
    required String current,
  }) {
    return showModalBottomSheet<String>(
      context: context,
      isScrollControlled: true,
      backgroundColor: Colors.transparent,
      builder: (BuildContext sheetContext) => _PickerSheet(
        title: title,
        items: items,
        current: current,
      ),
    );
  }
}

/// محل فعالیت راننده (جایی که مسافر سوار می‌کند). به‌طور پیش‌فرض همان محل
/// سکونت است؛ اگر فرق دارد (مثلاً ساکن کابل ولی فعال در غزنی) خاموش می‌شود
/// و ولایت و شهر جدا انتخاب می‌شوند.
class WorkAreaFields extends StatelessWidget {
  const WorkAreaFields({super.key});

  @override
  Widget build(BuildContext context) {
    return Consumer<RegistrationProvider>(
      builder: (BuildContext context, RegistrationProvider p, Widget? _) {
        final bool hasProvince = p.workProvince.isNotEmpty;
        return Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: <Widget>[
            Row(
              children: <Widget>[
                Icon(Icons.work_outline_rounded,
                    size: 20, color: AppColors.textSecondary),
                const SizedBox(width: 10),
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: <Widget>[
                      Text(
                        'محل فعالیت',
                        style: TextStyle(
                          fontSize: 14,
                          fontWeight: FontWeight.w700,
                          color: AppColors.textPrimary,
                        ),
                      ),
                      const SizedBox(height: 2),
                      Text(
                        'همان ولایت و شهری که در آن مسافر سوار می‌کنید',
                        style: TextStyle(
                          fontSize: 11.5,
                          color: AppColors.textSecondary,
                        ),
                      ),
                    ],
                  ),
                ),
              ],
            ),
            const SizedBox(height: 4),
            SwitchListTile(
              contentPadding: EdgeInsets.zero,
              dense: true,
              activeColor: AppColors.primaryBrand,
              title: Text(
                'همان محل سکونتم است',
                style: TextStyle(
                  fontSize: 13.5,
                  color: AppColors.textPrimary,
                ),
              ),
              value: p.workSameAsHome,
              onChanged: p.setWorkSameAsHome,
            ),
            if (!p.workSameAsHome) ...<Widget>[
              const SizedBox(height: 8),
              _PickerField(
                label: 'ولایت فعالیت',
                icon: Icons.map_outlined,
                value: p.workProvince,
                onTap: () async {
                  final String? picked =
                      await ProvinceCityFields._showPicker(
                    context,
                    title: 'ولایت فعالیت',
                    items: AfghanLocations.provinces,
                    current: p.workProvince,
                  );
                  if (picked != null) p.setWorkProvince(picked);
                },
              ),
              const SizedBox(height: 16),
              _PickerField(
                label: 'شهر / ولسوالی فعالیت',
                icon: Icons.location_city_outlined,
                value: p.workCity,
                enabled: hasProvince,
                hint: hasProvince ? null : 'اول ولایت فعالیت را انتخاب کنید',
                onTap: () async {
                  final String? picked =
                      await ProvinceCityFields._showPicker(
                    context,
                    title: 'شهر فعالیت',
                    items: AfghanLocations.cities(p.workProvince),
                    current: p.workCity,
                  );
                  if (picked != null) p.setWorkCity(picked);
                },
              ),
            ],
          ],
        );
      },
    );
  }
}

class _PickerField extends StatelessWidget {
  const _PickerField({
    required this.label,
    required this.icon,
    required this.value,
    required this.onTap,
    this.enabled = true,
    this.hint,
  });

  final String label;
  final IconData icon;
  final String value;
  final VoidCallback onTap;
  final bool enabled;
  final String? hint;

  @override
  Widget build(BuildContext context) {
    final OutlineInputBorder border = OutlineInputBorder(
      borderRadius: BorderRadius.circular(12),
      borderSide: BorderSide(color: AppColors.fieldBorder),
    );
    final bool empty = value.isEmpty;

    return InkWell(
      borderRadius: BorderRadius.circular(12),
      onTap: enabled ? onTap : null,
      child: InputDecorator(
        isEmpty: empty,
        decoration: InputDecoration(
          labelText: label,
          hintText: hint,
          labelStyle: TextStyle(fontSize: 14, color: AppColors.textSecondary),
          floatingLabelStyle:
              TextStyle(fontSize: 14, color: AppColors.textSecondary),
          prefixIcon: Icon(
            icon,
            size: 20,
            color: AppColors.textSecondary,
          ),
          suffixIcon: Icon(
            Icons.keyboard_arrow_down_rounded,
            color: AppColors.textSecondary,
          ),
          border: border,
          enabledBorder: border,
          disabledBorder: border,
          contentPadding:
              const EdgeInsets.symmetric(horizontal: 14, vertical: 15),
        ),
        child: Text(
          value,
          style: TextStyle(
            fontSize: 15,
            color: enabled ? AppColors.textPrimary : AppColors.textSecondary,
          ),
        ),
      ),
    );
  }
}

class _PickerSheet extends StatefulWidget {
  const _PickerSheet({
    required this.title,
    required this.items,
    required this.current,
  });

  final String title;
  final List<String> items;
  final String current;

  @override
  State<_PickerSheet> createState() => _PickerSheetState();
}

class _PickerSheetState extends State<_PickerSheet> {
  String _q = '';

  @override
  Widget build(BuildContext context) {
    final List<String> shown = _q.isEmpty
        ? widget.items
        : widget.items.where((String e) => e.contains(_q)).toList();
    final double maxH = MediaQuery.sizeOf(context).height * 0.75;

    return Container(
      constraints: BoxConstraints(maxHeight: maxH),
      padding: EdgeInsets.only(
        bottom: MediaQuery.viewInsetsOf(context).bottom,
      ),
      decoration: BoxDecoration(
        color: AppColors.cardBackground,
        borderRadius: const BorderRadius.vertical(top: Radius.circular(28)),
      ),
      child: Column(
        mainAxisSize: MainAxisSize.min,
        children: <Widget>[
          const SizedBox(height: 12),
          Container(
            width: 40,
            height: 4,
            decoration: BoxDecoration(
              color: AppColors.handle,
              borderRadius: BorderRadius.circular(2),
            ),
          ),
          const SizedBox(height: 14),
          Text(
            widget.title,
            style: TextStyle(
              fontSize: 17,
              fontWeight: FontWeight.bold,
              color: AppColors.textPrimary,
            ),
          ),
          if (widget.items.length > 12)
            Padding(
              padding: const EdgeInsets.fromLTRB(16, 12, 16, 4),
              child: TextField(
                onChanged: (String v) => setState(() => _q = v.trim()),
                style: TextStyle(color: AppColors.textPrimary),
                decoration: InputDecoration(
                  hintText: 'جستجو',
                  hintStyle: TextStyle(color: AppColors.textSecondary),
                  prefixIcon:
                      Icon(Icons.search_rounded, color: AppColors.textSecondary),
                  isDense: true,
                  border: OutlineInputBorder(
                    borderRadius: BorderRadius.circular(12),
                    borderSide: BorderSide(color: AppColors.fieldBorder),
                  ),
                  enabledBorder: OutlineInputBorder(
                    borderRadius: BorderRadius.circular(12),
                    borderSide: BorderSide(color: AppColors.fieldBorder),
                  ),
                  focusedBorder: OutlineInputBorder(
                    borderRadius: BorderRadius.circular(12),
                    borderSide:
                        BorderSide(color: AppColors.primaryBrand, width: 1.5),
                  ),
                ),
              ),
            ),
          const SizedBox(height: 6),
          Flexible(
            child: shown.isEmpty
                ? Padding(
                    padding: const EdgeInsets.all(28),
                    child: Text(
                      'موردی پیدا نشد',
                      style: TextStyle(color: AppColors.textSecondary),
                    ),
                  )
                : ListView.builder(
                    shrinkWrap: true,
                    padding: const EdgeInsets.only(bottom: 16),
                    itemCount: shown.length,
                    itemBuilder: (BuildContext context, int i) {
                      final String item = shown[i];
                      final bool selected = item == widget.current;
                      return ListTile(
                        title: Text(
                          item,
                          style: TextStyle(
                            fontSize: 15,
                            fontWeight:
                                selected ? FontWeight.bold : FontWeight.normal,
                            color: selected
                                ? AppColors.primaryBrand
                                : AppColors.textPrimary,
                          ),
                        ),
                        trailing: selected
                            ? Icon(Icons.check_rounded,
                                color: AppColors.primaryBrand)
                            : null,
                        onTap: () => Navigator.pop(context, item),
                      );
                    },
                  ),
          ),
        ],
      ),
    );
  }
}
