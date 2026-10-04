import 'package:flutter/material.dart';
import '../../widgets/glass_tube.dart';

/// Android permission guide and system settings remain two distinct actions.
class SettingsPermissionActions extends StatelessWidget {
  const SettingsPermissionActions({
    super.key,
    required this.title,
    required this.guideTooltip,
    required this.settingsTooltip,
    required this.onGuide,
    required this.onSettings,
  });
  final String title, guideTooltip, settingsTooltip;
  final VoidCallback onGuide, onSettings;

  @override
  Widget build(BuildContext context) => Padding(
    padding: const EdgeInsets.symmetric(vertical: 8, horizontal: 4),
    child: Row(
      children: [
        const Icon(
          Icons.settings_applications,
          color: GlassTubeColors.teal,
          size: 20,
        ),
        const SizedBox(width: 12),
        Expanded(child: Text(title, style: const TextStyle(fontSize: 14))),
        GlassTube(
          key: const Key('settings_permission_actions_tube'),
          optionCount: 2,
          child: Row(
            mainAxisSize: MainAxisSize.min,
            children: [
              IconButton(
                key: const Key('permission_guide_action'),
                tooltip: guideTooltip,
                onPressed: onGuide,
                icon: const Icon(
                  Icons.info_outline,
                  color: GlassTubeColors.teal,
                ),
              ),
              IconButton(
                key: const Key('permission_settings_action'),
                tooltip: settingsTooltip,
                onPressed: onSettings,
                icon: const Icon(
                  Icons.settings_outlined,
                  color: GlassTubeColors.teal,
                ),
              ),
            ],
          ),
        ),
      ],
    ),
  );
}
