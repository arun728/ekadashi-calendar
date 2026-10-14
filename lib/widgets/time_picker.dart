import 'package:flutter/cupertino.dart';
import 'package:flutter/material.dart';
import 'package:provider/provider.dart';

import '../l10n/app_language.dart';
import '../services/language_service.dart';
import 'ios_style.dart';

/// The time picker as on the iPhone (DatePicker hourAndMinute): a wheel in
/// a sheet with Cancel and Done. English uses 12 hours; the other languages
/// use 24 hours, since AM and PM would be written in Latin letters
/// (AppModel.timePickerLocale on iOS). Null when cancelled.
Future<TimeOfDay?> pickTime(BuildContext context, TimeOfDay initial) {
  final language =
      context.read<LanguageService?>()?.currentLocale.languageCode ?? 'en';
  var value = initial;
  final start = DateTime(2000, 1, 1, initial.hour, initial.minute);
  return showAppSheet<TimeOfDay>(
    context,
    large: false,
    builder: (sheet) => Column(
      mainAxisSize: MainAxisSize.min,
      children: [
        SheetBar(
          title: AppStrings.translate('notifications_time', language),
          leading: BarTextButton(
            key: const Key('time_picker_cancel'),
            label: AppStrings.translate('cancel', language),
            onPressed: () => Navigator.of(sheet).pop(),
          ),
          trailing: BarTextButton(
            key: const Key('time_picker_done'),
            label: AppStrings.translate('panchang_done', language),
            bold: true,
            onPressed: () => Navigator.of(sheet).pop(value),
          ),
        ),
        SafeArea(
          top: false,
          child: SizedBox(
            height: 216,
            child: CupertinoTheme(
              data: CupertinoThemeData(
                brightness: Theme.of(sheet).brightness,
                primaryColor: IosColors.teal,
              ),
              child: CupertinoDatePicker(
                key: const Key('time_picker_wheel'),
                mode: CupertinoDatePickerMode.time,
                initialDateTime: start,
                use24hFormat: language != 'en',
                onDateTimeChanged: (time) =>
                    value = TimeOfDay(hour: time.hour, minute: time.minute),
              ),
            ),
          ),
        ),
      ],
    ),
  );
}
