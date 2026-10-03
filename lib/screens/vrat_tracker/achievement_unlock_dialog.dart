import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import '../../models/vrat_tracker_models.dart';
import '../../services/language_service.dart';

/// Gentle, devotional dialog shown when a milestone is achieved.
class AchievementUnlockDialog extends StatelessWidget {
  final Achievement achievement;

  const AchievementUnlockDialog({super.key, required this.achievement});

  static Future<void> show(BuildContext context, Achievement achievement) {
    return showDialog<void>(
      context: context,
      barrierDismissible: true,
      builder: (ctx) => AchievementUnlockDialog(achievement: achievement),
    );
  }

  @override
  Widget build(BuildContext context) {
    const tealColor = Color(0xFF00A19B);
    final lang = Provider.of<LanguageService>(context);
    final title = lang.translate(achievement.titleKey);
    final desc = lang.translate(achievement.descriptionKey);

    return Dialog(
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(20)),
      child: Padding(
        padding: const EdgeInsets.symmetric(horizontal: 24, vertical: 28),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            // Icon with soft glowing aura
            Container(
              width: 72,
              height: 72,
              decoration: BoxDecoration(
                shape: BoxShape.circle,
                color: tealColor.withValues(alpha: 0.12),
                border: Border.all(color: tealColor, width: 2),
              ),
              child: Icon(achievement.icon, size: 36, color: tealColor),
            ),
            const SizedBox(height: 20),

            // Achievement Unlocked Subtitle
            Text(
              lang.translate('achievement_unlocked'),
              style: const TextStyle(
                fontSize: 13,
                letterSpacing: 1.2,
                fontWeight: FontWeight.w600,
                color: tealColor,
              ),
            ),
            const SizedBox(height: 8),

            // Title
            Text(
              title,
              textAlign: TextAlign.center,
              style: const TextStyle(fontSize: 20, fontWeight: FontWeight.bold),
            ),
            const SizedBox(height: 10),

            // Description
            Text(
              desc,
              textAlign: TextAlign.center,
              style: TextStyle(
                fontSize: 14,
                color: Theme.of(
                  context,
                ).textTheme.bodyMedium?.color?.withValues(alpha: 0.75),
                height: 1.4,
              ),
            ),
            const SizedBox(height: 24),

            // Action
            ElevatedButton(
              onPressed: () => Navigator.of(context).pop(),
              style: ElevatedButton.styleFrom(
                backgroundColor: tealColor,
                foregroundColor: Colors.white,
                shape: RoundedRectangleBorder(
                  borderRadius: BorderRadius.circular(10),
                ),
                padding: const EdgeInsets.symmetric(
                  horizontal: 28,
                  vertical: 10,
                ),
              ),
              child: Text(
                lang.translate('hari_om'),
                style: const TextStyle(fontSize: 15),
              ),
            ),
          ],
        ),
      ),
    );
  }
}
