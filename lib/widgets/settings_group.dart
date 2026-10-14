import 'package:flutter/material.dart';

import 'glass_tube.dart';
import 'app_icons.dart';

/// The iOS grouped-list look of Settings (SettingsView.swift): section
/// headers and footers outside rounded cards, icon rows with inset hairline
/// separators, grey details and teal icons.
abstract final class SettingsStyle {
  static const radius = 26.0;

  /// Row padding, the icon slot and the gap before the text.
  static const rowPadding = 20.0;
  static const iconSlot = 28.0;
  static const iconGap = 14.0;

  /// Separator insets below a row without and with a leading icon.
  static const textInset = rowPadding;
  static const iconInset = rowPadding + iconSlot + iconGap;

  static bool _dark(BuildContext context) =>
      Theme.of(context).brightness == Brightness.dark;

  /// iOS secondarySystemGroupedBackground.
  static Color card(BuildContext context) =>
      _dark(context) ? const Color(0xFF1C1C1E) : Colors.white;

  /// iOS secondaryLabel and tertiaryLabel.
  static Color secondary(BuildContext context) =>
      _dark(context) ? const Color(0x99EBEBF5) : const Color(0x993C3C43);
  static Color tertiary(BuildContext context) =>
      _dark(context) ? const Color(0x4DEBEBF5) : const Color(0x4D3C3C43);

  /// iOS separator.
  static Color separator(BuildContext context) =>
      _dark(context) ? const Color(0x99545458) : const Color(0x4A3C3C43);

  static Color primary(BuildContext context) =>
      _dark(context) ? Colors.white : Colors.black;
}

/// A section title above its card ("Appearance", "Notifications").
class SettingsHeader extends StatelessWidget {
  const SettingsHeader(this.text, {super.key, this.top = 24});
  final String text;
  final double top;

  @override
  Widget build(BuildContext context) => Padding(
    padding: EdgeInsets.fromLTRB(SettingsStyle.rowPadding, top, 16, 8),
    child: Semantics(
      header: true,
      child: Text(
        text,
        style: TextStyle(
          fontSize: 17,
          fontWeight: FontWeight.w600,
          color: SettingsStyle.secondary(context),
        ),
      ),
    ),
  );
}

/// The grey note below a card.
class SettingsFooter extends StatelessWidget {
  const SettingsFooter(this.text, {super.key});
  final String text;

  @override
  Widget build(BuildContext context) => Padding(
    padding: const EdgeInsets.fromLTRB(SettingsStyle.rowPadding, 8, 16, 0),
    child: Text(
      text,
      style: TextStyle(fontSize: 13, color: SettingsStyle.secondary(context)),
    ),
  );
}

/// A hairline between two rows, starting where the upper row's text starts.
class SettingsSeparator extends StatelessWidget {
  const SettingsSeparator({super.key, this.inset = SettingsStyle.textInset});
  final double inset;

  @override
  Widget build(BuildContext context) => Padding(
    padding: EdgeInsets.only(left: inset, right: 16),
    child: Container(height: .5, color: SettingsStyle.separator(context)),
  );
}

/// One rounded section card. Rows inside use iOS sizes: 17 for titles and
/// 12 for grey details, teal icons in a fixed slot.
class SettingsCard extends StatelessWidget {
  const SettingsCard({super.key, required this.children});
  final List<Widget> children;

  @override
  Widget build(BuildContext context) {
    final secondary = SettingsStyle.secondary(context);
    // From the theme's styles, so rows keep the app font.
    final text = Theme.of(context).textTheme;
    return Material(
      color: SettingsStyle.card(context),
      shape: RoundedRectangleBorder(
        borderRadius: BorderRadius.circular(SettingsStyle.radius),
      ),
      clipBehavior: Clip.antiAlias,
      child: ListTileTheme(
        data: ListTileThemeData(
          contentPadding: const EdgeInsets.symmetric(
            horizontal: SettingsStyle.rowPadding,
          ),
          minLeadingWidth: SettingsStyle.iconSlot,
          horizontalTitleGap: SettingsStyle.iconGap,
          minVerticalPadding: 10,
          minTileHeight: 50,
          iconColor: GlassTubeColors.teal,
          titleTextStyle: text.bodyLarge?.copyWith(
            fontSize: 17,
            color: SettingsStyle.primary(context),
          ),
          subtitleTextStyle: text.bodySmall?.copyWith(
            fontSize: 12,
            color: secondary,
          ),
          leadingAndTrailingTextStyle: text.bodyLarge?.copyWith(
            fontSize: 17,
            color: secondary,
          ),
        ),
        child: Column(mainAxisSize: MainAxisSize.min, children: children),
      ),
    );
  }
}

/// The teal leading icon of a row, centred in the icon slot.
class SettingsIcon extends StatelessWidget {
  const SettingsIcon(this.icon, {super.key, this.color});
  final IconData icon;
  final Color? color;

  @override
  Widget build(BuildContext context) => SizedBox(
    width: SettingsStyle.iconSlot,
    child: Icon(icon, size: 24, color: color ?? GlassTubeColors.teal),
  );
}

/// The small grey chevron of a row that opens a page.
class SettingsChevron extends StatelessWidget {
  const SettingsChevron({super.key});

  @override
  Widget build(BuildContext context) => Icon(
    AppIcons.rowDisclosure,
    size: 22,
    color: SettingsStyle.tertiary(context),
  );
}

/// An iOS switch row: keeps SwitchListTile (and its tests) but draws the
/// Cupertino switch with the teal track, like the iOS Toggle.
class SettingsSwitchTile extends StatelessWidget {
  const SettingsSwitchTile({
    super.key,
    required this.title,
    this.subtitle,
    this.icon,
    required this.value,
    required this.onChanged,
  });
  final Widget title;
  final Widget? subtitle;
  final IconData? icon;
  final bool value;
  final ValueChanged<bool>? onChanged;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    return Theme(
      data: theme.copyWith(platform: TargetPlatform.iOS),
      child: SwitchListTile.adaptive(
        title: title,
        subtitle: subtitle,
        secondary: icon == null ? null : SettingsIcon(icon!),
        value: value,
        activeTrackColor: GlassTubeColors.teal,
        onChanged: onChanged,
      ),
    );
  }
}
