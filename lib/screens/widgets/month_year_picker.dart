import 'package:flutter/cupertino.dart';
import 'package:flutter/material.dart';

import '../../l10n/app_language.dart';
import '../../services/panchang/panchang_terms.dart';
import '../../widgets/ios_style.dart';

/// The month and year picker shared by the Calendar and the Panchang
/// (PanchangMonthPicker in PanchangView.swift): a sheet with a month wheel
/// and a year wheel, Cancel and Done. Returns the first day of the chosen
/// month (UTC), or null when cancelled.
Future<DateTime?> showMonthYearPicker(
  BuildContext context, {
  required DateTime month,
  required String language,
  List<int>? years,
}) => showAppSheet<DateTime>(
  context,
  large: false,
  builder: (_) =>
      PanchangMonthPickerDialog(month: month, language: language, years: years),
);

/// The picker sheet's content (its old Panchang name is kept); shown by
/// [showMonthYearPicker].
class PanchangMonthPickerDialog extends StatefulWidget {
  const PanchangMonthPickerDialog({
    super.key,
    required this.month,
    required this.language,
    this.years,
  });

  final DateTime month;
  final String language;

  /// The years offered (the Calendar's data years); 1900 to 2100 when null.
  final List<int>? years;

  @override
  State<PanchangMonthPickerDialog> createState() =>
      _PanchangMonthPickerDialogState();
}

class _PanchangMonthPickerDialogState extends State<PanchangMonthPickerDialog> {
  late final List<int> _years =
      widget.years ?? [for (var y = 1900; y <= 2100; y++) y];
  late int _month = widget.month.month;
  late int _year = _years.contains(widget.month.year)
      ? widget.month.year
      : _years.first;
  late final _monthWheel = FixedExtentScrollController(initialItem: _month - 1);
  late final _yearWheel = FixedExtentScrollController(
    initialItem: _years.indexOf(_year),
  );

  @override
  void dispose() {
    _monthWheel.dispose();
    _yearWheel.dispose();
    super.dispose();
  }

  void _scroll(FixedExtentScrollController wheel, int index) =>
      wheel.animateToItem(
        index,
        duration: const Duration(milliseconds: 250),
        curve: Curves.easeOut,
      );

  Widget _wheel({
    Key? key,
    required FixedExtentScrollController controller,
    required int count,
    required ValueChanged<int> onChanged,
    required Widget Function(int index) item,
  }) => CupertinoPicker.builder(
    key: key,
    scrollController: controller,
    itemExtent: 34,
    childCount: count,
    onSelectedItemChanged: onChanged,
    // A tap on a row scrolls the wheel to it, as on iOS.
    itemBuilder: (context, index) => GestureDetector(
      behavior: HitTestBehavior.opaque,
      onTap: () => _scroll(controller, index),
      child: Center(child: item(index)),
    ),
  );

  @override
  Widget build(BuildContext context) {
    final language = widget.language;
    final style = TextStyle(
      fontSize: IosText.body + 3,
      color: IosColors.primary(context),
    );
    final content = Material(
      type: MaterialType.transparency,
      child: Column(
        key: const Key('panchang_month_picker'),
        mainAxisSize: MainAxisSize.min,
        children: [
          SheetBar(
            title: '',
            leading: BarTextButton(
              key: const Key('month_picker_cancel'),
              label: AppStrings.translate('cancel', language),
              onPressed: () => Navigator.of(context).pop(),
            ),
            trailing: BarTextButton(
              key: const Key('month_picker_done'),
              label: AppStrings.translate('panchang_done', language),
              bold: true,
              onPressed: () =>
                  Navigator.of(context).pop(DateTime.utc(_year, _month)),
            ),
          ),
          SizedBox(
            height: 216,
            child: Padding(
              padding: const EdgeInsets.symmetric(horizontal: 16),
              child: Row(
                children: [
                  Expanded(
                    child: _wheel(
                      key: const Key('month_picker_month_wheel'),
                      controller: _monthWheel,
                      count: 12,
                      onChanged: (i) => setState(() => _month = i + 1),
                      item: (i) => Text(
                        PanchangFormat.format(
                          DateTime.utc(2026, i + 1),
                          'LLLL',
                          language,
                        ),
                        key: Key('panchang_month_${i + 1}'),
                        style: style,
                      ),
                    ),
                  ),
                  Expanded(
                    child: _wheel(
                      controller: _yearWheel,
                      count: _years.length,
                      onChanged: (i) => setState(() => _year = _years[i]),
                      item: (i) => Text(
                        '${_years[i]}',
                        key: Key('month_picker_year_${_years[i]}'),
                        style: style,
                      ),
                    ),
                  ),
                ],
              ),
            ),
          ),
          const SizedBox(height: 24),
        ],
      ),
    );
    return content;
  }
}
