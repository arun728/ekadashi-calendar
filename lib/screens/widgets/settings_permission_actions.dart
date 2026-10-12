import 'package:flutter/material.dart';
import '../../widgets/settings_group.dart';

/// The Permissions card, like iOS: App Settings (opens the system settings)
/// and the Permissions Guide, as two separate rows.
class SettingsPermissionActions extends StatelessWidget {
  const SettingsPermissionActions({
    super.key,
    required this.settingsTitle,
    required this.settingsSubtitle,
    required this.guideTitle,
    required this.onGuide,
    required this.onSettings,
  });
  final String settingsTitle, settingsSubtitle, guideTitle;
  final VoidCallback onGuide, onSettings;

  @override
  Widget build(BuildContext context) => SettingsCard(
    key: const Key('settings_permission_actions_tube'),
    children: [
      ListTile(
        key: const Key('permission_settings_action'),
        leading: const SettingsIcon(Icons.settings_outlined),
        title: Text(settingsTitle),
        subtitle: Text(settingsSubtitle),
        onTap: onSettings,
      ),
      const SettingsSeparator(inset: SettingsStyle.iconInset),
      ListTile(
        key: const Key('permission_guide_action'),
        leading: const SettingsIcon(Icons.info_outline),
        title: Text(guideTitle),
        onTap: onGuide,
      ),
    ],
  );
}
