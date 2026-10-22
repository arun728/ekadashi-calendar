import 'package:flutter/material.dart';
import 'package:timezone/timezone.dart' as tz;
import '../l10n/app_language.dart';
import '../services/ekadashi_service.dart';
import 'ios_style.dart';

/// Today's remaining fast, in the Home city's civil day. It never appears on
/// a future/past card, including after midnight while Parana is still ahead.
class HomeFastingProgress extends StatelessWidget {
  const HomeFastingProgress({
    super.key,
    required this.fraction,
    required this.language,
  });
  final double fraction;
  final String language;

  static double? remaining(EkadashiDate event, DateTime now, String timezone) {
    final local = tz.TZDateTime.from(now, tz.getLocation(timezone));
    if (local.year != event.date.year ||
        local.month != event.date.month ||
        local.day != event.date.day) {
      return null;
    }
    final start = DateTime.tryParse(event.fastingStartIso);
    final end = DateTime.tryParse(event.paranaStartIso);
    if (start == null || end == null || !end.isAfter(start)) return null;
    return (end.difference(now).inMilliseconds /
            end.difference(start).inMilliseconds)
        .clamp(0.0, 1.0);
  }

  @override
  Widget build(BuildContext context) {
    // Match iOS: round remaining time upwards, with exact boundaries stable.
    final percent = (fraction.clamp(0.0, 1.0) * 100 - 0.000000001).ceil();
    return Semantics(
      label: '$percent% ${AppStrings.translate('widget_remaining', language)}',
      child: ExcludeSemantics(
        child: SizedBox.square(
          dimension: 48,
          child: Stack(
            alignment: Alignment.center,
            children: [
              Positioned.fill(
                child: CircularProgressIndicator(
                  value: fraction,
                  strokeWidth: 3.5,
                  strokeCap: StrokeCap.round,
                  color: IosColors.teal,
                  backgroundColor: IosColors.primary(
                    context,
                  ).withValues(alpha: .16),
                ),
              ),
              Padding(
                padding: const EdgeInsets.all(9),
                child: FittedBox(
                  fit: BoxFit.scaleDown,
                  child: Text(
                    '$percent%',
                    style: TextStyle(
                      fontSize: 13,
                      fontWeight: FontWeight.bold,
                      color: IosColors.primary(context),
                    ),
                  ),
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}
