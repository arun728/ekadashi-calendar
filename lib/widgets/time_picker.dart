import 'package:flutter/material.dart';
import 'package:provider/provider.dart';

import '../services/language_service.dart';

/// The time picker in the app language. Other languages use the 24-hour
/// dial, since Material writes AM and PM in Latin letters for most of them.
Future<TimeOfDay?> pickTime(BuildContext context, TimeOfDay initial) {
  final english =
      context.read<LanguageService?>()?.currentLocale.languageCode == 'en';
  return showTimePicker(
    context: context,
    initialTime: initial,
    builder: (context, child) => english
        ? child!
        : MediaQuery(
            data: MediaQuery.of(context).copyWith(alwaysUse24HourFormat: true),
            child: child!,
          ),
  );
}
