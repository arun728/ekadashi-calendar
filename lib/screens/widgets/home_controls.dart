import 'package:flutter/material.dart';
import 'package:provider/provider.dart';

import '../../l10n/app_language.dart';
import '../../services/ekadashi_settings.dart';
import '../../services/language_service.dart';
import '../../services/panchang/calculated_ekadashi.dart';
import '../../services/place_name_resolver.dart';
import '../../widgets/glass_tube.dart';
import '../../widgets/ios_style.dart';
import '../../widgets/app_icons.dart';

/// The four Home menus in a 2×2 grid that lines up from top to bottom
/// (HomeControls in TodayView.swift): location over tradition on the left
/// (same width, filling the row) and language over year on the right (same
/// width: each reserves the other's label). Every pill has the same height
/// and style, each in its own glass capsule.
class HomeControls extends StatelessWidget {
  const HomeControls({
    super.key,
    required this.locating,
    required this.onLocation,
  });

  /// Detecting the place (a spinner beside the city).
  final bool locating;

  /// Opens the city search.
  final VoidCallback onLocation;

  static const spacing = 10.0;
  static const pillHeight = 44.0;
  static const _teal = GlassTubeColors.teal;

  @override
  Widget build(BuildContext context) {
    final settings = context.watch<EkadashiSettings>();
    final lang = context.watch<LanguageService>();
    final language = lang.currentLocale.languageCode;
    final current = AppLanguage.named(language);
    final languageName = current.nativeName;
    final yearText = '${settings.year}';
    return LayoutBuilder(
      builder: (context, constraints) {
        // The right column never takes more than half the row.
        final right = (constraints.maxWidth - spacing) / 2;
        Widget row(Widget left, Widget rightPill) => IntrinsicHeight(
          child: Row(
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: [
              Expanded(child: left),
              const SizedBox(width: spacing),
              ConstrainedBox(
                constraints: BoxConstraints(maxWidth: right),
                child: rightPill,
              ),
            ],
          ),
        );
        return Column(
          key: const Key('home_options_tube'),
          mainAxisSize: MainAxisSize.min,
          children: [
            row(
              _location(context, settings, language),
              _languageMenu(context, lang, current, yearText),
            ),
            const SizedBox(height: spacing),
            row(
              _traditionMenu(context, settings, lang),
              _yearMenu(context, settings, lang, languageName),
            ),
          ],
        );
      },
    );
  }

  // Left column: fills the row.

  /// The Ekadashi city; tapping it opens the city search.
  Widget _location(
    BuildContext context,
    EkadashiSettings settings,
    String language,
  ) => Semantics(
    button: true,
    hint: AppStrings.translate('home_location_hint', language),
    child: _Pill(
      key: const Key('home_location'),
      onTap: onLocation,
      leading: locating && !settings.isManual
          ? const SizedBox(
              width: 18,
              height: 18,
              child: CircularProgressIndicator(strokeWidth: 2, color: _teal),
            )
          : Icon(
              settings.isManual
                  ? AppIcons.locationPicked
                  : AppIcons.locationDetected,
              size: 18,
              color: _teal,
            ),
      label: ListenableBuilder(
        listenable: PlaceNameResolver.instance,
        builder: (_, _) => Text(
          PlaceNameResolver.instance.city(settings.city, language),
          key: const Key('home_location_name'),
          maxLines: 1,
          overflow: TextOverflow.ellipsis,
        ),
      ),
    ),
  );

  Widget _traditionMenu(
    BuildContext context,
    EkadashiSettings settings,
    LanguageService lang,
  ) => PopupMenuButton<EkadashiTradition>(
    key: const Key('home_tradition_menu'),
    tooltip: lang.translate('home_tradition'),
    onSelected: settings.setTradition,
    // The menu overlays the app; it is not a page in Home's tab stack.
    useRootNavigator: true,
    color: IosColors.sheet(context),
    shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(14)),
    offset: const Offset(0, pillHeight),
    itemBuilder: (_) => [
      for (final tradition in [
        EkadashiTradition.gaudiya,
        EkadashiTradition.smarta,
      ])
        _item(
          tradition,
          lang.translate(EkadashiSettings.traditionKeyFor(tradition)),
          tradition == settings.tradition,
        ),
    ],
    child: _Pill(
      leading: const Icon(AppIcons.homeTradition, size: 18, color: _teal),
      label: Text(
        lang.translate(settings.traditionNameKey),
        maxLines: 1,
        overflow: TextOverflow.ellipsis,
      ),
    ),
  );

  // Right column: as wide as the wider of language and year.

  /// The app's only language menu (docs/ROADMAP.md Phase 2), in the
  /// registry's order: English, Hindi, Tamil, Telugu, Gujarati, Bengali.
  Widget _languageMenu(
    BuildContext context,
    LanguageService lang,
    AppLanguage current,
    String yearText,
  ) => PopupMenuButton<String>(
    key: const Key('language_menu'),
    onSelected: lang.changeLanguage,
    // The menu overlays the app; it is not a page in Home's tab stack.
    useRootNavigator: true,
    color: IosColors.sheet(context),
    shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(14)),
    offset: const Offset(0, pillHeight),
    itemBuilder: (_) => [
      for (final language in AppLanguage.all)
        _item(
          language.code,
          language.nativeName,
          language.code == current.code,
        ),
    ],
    child: _Pill(
      centered: true,
      label: _reserving(
        shown: (current.nativeName, AppIcons.homeLanguage),
        reserved: (yearText, AppIcons.homeYear),
      ),
    ),
  );

  Widget _yearMenu(
    BuildContext context,
    EkadashiSettings settings,
    LanguageService lang,
    String languageName,
  ) => PopupMenuButton<int>(
    key: const Key('home_year_menu'),
    tooltip: lang.translate('year'),
    onSelected: settings.setYear,
    // The menu overlays the app; it is not a page in Home's tab stack.
    useRootNavigator: true,
    color: IosColors.sheet(context),
    shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(14)),
    offset: const Offset(0, pillHeight),
    itemBuilder: (_) => [
      for (final year in settings.years)
        _item(year, '$year', year == settings.year),
    ],
    child: _Pill(
      centered: true,
      label: _reserving(
        shown: ('${settings.year}', AppIcons.homeYear),
        reserved: (languageName, AppIcons.homeLanguage),
      ),
    ),
  );

  /// A right-column label sized for both labels, so language and year match.
  static Widget _reserving({
    required (String, IconData) shown,
    required (String, IconData) reserved,
  }) => Stack(
    alignment: Alignment.center,
    children: [
      Visibility(
        visible: false,
        maintainSize: true,
        maintainAnimation: true,
        maintainState: true,
        child: _content(reserved),
      ),
      _content(shown),
    ],
  );

  static Widget _content((String, IconData) item) => Row(
    mainAxisSize: MainAxisSize.min,
    children: [
      Icon(item.$2, size: 18, color: _teal),
      const SizedBox(width: 6),
      Flexible(
        child: Text(item.$1, maxLines: 1, overflow: TextOverflow.ellipsis),
      ),
    ],
  );

  /// A menu item as on iOS: the check mark first, then the name.
  static PopupMenuItem<T> _item<T>(T value, String text, bool selected) =>
      PopupMenuItem<T>(
        value: value,
        child: Builder(
          builder: (context) => Row(
            children: [
              SizedBox(
                width: 28,
                child: selected
                    ? Icon(
                        AppIcons.checkmark,
                        size: 18,
                        color: IosColors.primary(context),
                      )
                    : null,
              ),
              Expanded(
                child: Text(
                  text,
                  style: const TextStyle(fontSize: IosText.body),
                ),
              ),
            ],
          ),
        ),
      );
}

/// One Home menu: a glass capsule with the icon and label, then a chevron.
class _Pill extends StatelessWidget {
  const _Pill({
    super.key,
    this.leading,
    required this.label,
    this.centered = false,
    this.onTap,
  });

  final Widget? leading;
  final Widget label;
  final bool centered;
  final VoidCallback? onTap;

  @override
  Widget build(BuildContext context) {
    final content = Row(
      mainAxisSize: centered ? MainAxisSize.min : MainAxisSize.max,
      children: [
        if (leading != null) ...[leading!, const SizedBox(width: 6)],
        if (centered) Flexible(child: label) else Expanded(child: label),
        const SizedBox(width: 4),
        Icon(AppIcons.menuDisclosure, size: 16, color: Colors.grey.shade500),
      ],
    );
    final pill = ConstrainedBox(
      constraints: const BoxConstraints(minHeight: HomeControls.pillHeight),
      child: GlassTube.single(
        child: DefaultTextStyle.merge(
          style: TextStyle(
            fontSize: IosText.subheadline,
            fontWeight: FontWeight.w500,
            color: GlassTubeColors.foreground(context),
          ),
          child: Center(widthFactor: 1, child: content),
        ),
      ),
    );
    if (onTap == null) return pill;
    return Material(
      type: MaterialType.transparency,
      child: InkWell(
        onTap: onTap,
        customBorder: const StadiumBorder(),
        child: pill,
      ),
    );
  }
}
