import 'package:flutter/foundation.dart';
import 'package:home_widget/home_widget.dart';

import '../models/next_ekadashi_widget_data.dart';
import 'ekadashi_service.dart';

/// Writes next-Ekadashi payload for the Android home-screen widget.
class EkadashiWidgetService {
  EkadashiWidgetService({
    Future<bool?> Function(String key, String value)? save,
    Future<bool?> Function()? updateWidget,
  })  : _save = save,
        _updateWidget = updateWidget;

  final Future<bool?> Function(String key, String value)? _save;
  final Future<bool?> Function()? _updateWidget;

  static const androidProvider =
      'com.applausestudios.ekadashi_calendar.EkadashiHomeWidgetProvider';

  /// Call after data load, language change, or timezone change.
  Future<NextEkadashiWidgetData> refresh({
    required List<EkadashiDate> ekadashis,
    required String languageCode,
    DateTime? now,
  }) async {
    final data = NextEkadashiWidgetBuilder.build(
      entries: ekadashis
          .map((e) => (
                id: e.id,
                name: e.name,
                date: e.date,
                fastStartTime: e.fastStartTime,
                description: e.description,
              ))
          .toList(),
      now: now ?? DateTime.now(),
      languageCode: languageCode,
    );

    try {
      final save = _save ?? HomeWidget.saveWidgetData<String>;
      for (final e in data.toWidgetKeys().entries) {
        await save(e.key, e.value);
      }
      final update = _updateWidget ??
          () => HomeWidget.updateWidget(
                qualifiedAndroidName: androidProvider,
                androidName: 'EkadashiHomeWidgetProvider',
              );
      await update();
    } catch (e, st) {
      debugPrint('EkadashiWidgetService.refresh failed: $e\n$st');
    }
    return data;
  }
}
