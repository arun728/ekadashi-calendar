import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:provider/provider.dart';
import '../../models/vrat_tracker_models.dart';
import '../../services/language_service.dart';
import '../../widgets/ios_style.dart';

/// "Achievement unlocked" (iOS AchievementUnlockView): a medium sheet with
/// a success haptic, the badge in a glass circle, an upper-case caption and
/// a full-width "Hari Om" button.
class AchievementUnlockDialog extends StatefulWidget {
  final Achievement achievement;

  const AchievementUnlockDialog({super.key, required this.achievement});

  static Future<void> show(BuildContext context, Achievement achievement) =>
      showAppSheet<void>(
        context,
        large: false,
        builder: (_) => AchievementUnlockDialog(achievement: achievement),
      );

  @override
  State<AchievementUnlockDialog> createState() =>
      _AchievementUnlockDialogState();
}

class _AchievementUnlockDialogState extends State<AchievementUnlockDialog> {
  @override
  void initState() {
    super.initState();
    // iOS .sensoryFeedback(.success).
    HapticFeedback.mediumImpact();
  }

  @override
  Widget build(BuildContext context) {
    final lang = Provider.of<LanguageService>(context);
    final achievement = widget.achievement;
    return SingleChildScrollView(
      padding: const EdgeInsets.all(28),
      child: Column(
        mainAxisSize: MainAxisSize.min,
        spacing: 16,
        children: [
          SizedBox(
            width: 88,
            height: 88,
            child: GlassPanel(
              radius: 44,
              tint: IosColors.teal,
              child: Center(
                child: Icon(achievement.icon, size: 40, color: IosColors.teal),
              ),
            ),
          ),
          Text(
            lang.translate('achievement_unlocked').toUpperCase(),
            textAlign: TextAlign.center,
            style: const TextStyle(
              fontSize: IosText.caption,
              fontWeight: FontWeight.w700,
              color: IosColors.teal,
            ),
          ),
          Text(
            lang.translate(achievement.titleKey),
            textAlign: TextAlign.center,
            style: TextStyle(
              fontSize: IosText.title2,
              fontWeight: FontWeight.w700,
              color: IosColors.primary(context),
            ),
          ),
          Text(
            lang.translate(achievement.descriptionKey),
            textAlign: TextAlign.center,
            style: TextStyle(
              fontSize: IosText.callout,
              color: IosColors.secondary(context),
            ),
          ),
          SizedBox(
            width: double.infinity,
            child: FilledButton(
              key: const Key('achievement_unlock_ok'),
              onPressed: () => Navigator.of(context).pop(),
              style: IosButtons.prominent(vertical: 13),
              child: Text(lang.translate('hari_om'), style: IosButtons.label),
            ),
          ),
        ],
      ),
    );
  }
}
