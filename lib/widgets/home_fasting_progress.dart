import 'package:flutter/material.dart';
import '../services/ekadashi_lifecycle.dart';
import '../l10n/app_language.dart';
import '../services/ekadashi_service.dart';
import 'ios_style.dart';

/// Completed fasting progress, retained overnight and through Parana.
/// The legacy helper name remains compatible with existing callers.
class HomeFastingProgress extends StatelessWidget {
  const HomeFastingProgress({
    super.key,
    required this.fraction,
    required this.language,
  });
  final double fraction;
  final String language;

  static double? remaining(EkadashiDate event, DateTime now, String timezone) {
    return EkadashiLifecycle.of(event, now, timezone).progress;
  }

  @override
  Widget build(BuildContext context) {
    // Match iOS: round completed time downwards, with exact boundaries stable.
    final percent = (fraction.clamp(0.0, 1.0) * 100 + 0.000000001).floor();
    return Semantics(
      label: AppStrings.translate(
        'widget_fast_done',
        language,
      ).replaceAll('{value0}', '$percent'),
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
                  strokeAlign: CircularProgressIndicator.strokeAlignInside,
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
