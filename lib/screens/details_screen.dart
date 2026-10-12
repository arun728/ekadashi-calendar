import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import '../services/ekadashi_service.dart';
import '../services/vrat_recording.dart';
import '../l10n/app_language.dart';
import '../services/language_service.dart';
import '../services/vrat_tracker_service.dart';
import '../models/vrat_tracker_models.dart';
import '../widgets/app_background.dart';
import '../widgets/ios_style.dart';
import 'vrat_tracker/record_vrat_dialog.dart';
import 'vrat_tracker/achievement_unlock_dialog.dart';

/// Significance, story, rules, benefits, timings and the Vrat button, as
/// the iOS EkadashiDetailsView. It is pushed inside the Home or Calendar
/// tab, so it paints the app background itself, keeps its own inline bar
/// (back chevron, no search) and scrolls clear of the floating tab bar.
class DetailsScreen extends StatelessWidget {
  final EkadashiDate ekadashi;
  final String? timezone;

  const DetailsScreen({super.key, required this.ekadashi, this.timezone});

  @override
  Widget build(BuildContext context) {
    const tealColor = IosColors.teal;
    final lang = Provider.of<LanguageService>(context);
    final language = lang.currentLocale.languageCode;
    final zone = timezone ?? 'IST';

    final breakTime = AppStrings.localizeClock(
      ekadashi.fastBreakTime.replaceAll(RegExp(r'^[a-zA-Z]{3} \d{1,2}, '), ''),
      language,
    );

    Widget section(String key, String text) => Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(
          lang.translate(key),
          style: const TextStyle(
            color: tealColor,
            fontSize: IosText.title3,
            fontWeight: FontWeight.bold,
          ),
        ),
        const SizedBox(height: 8),
        Text(text, style: const TextStyle(fontSize: IosText.body, height: 1.5)),
      ],
    );

    Widget timing(IconData icon, String title, DateTime date, String time) =>
        Row(
          children: [
            SizedBox(width: 28, child: Icon(icon, color: tealColor)),
            const SizedBox(width: 12),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    title,
                    style: const TextStyle(
                      color: tealColor,
                      fontSize: IosText.body,
                      fontWeight: FontWeight.bold,
                    ),
                  ),
                  const SizedBox(height: 2),
                  Text(
                    AppStrings.fullDate(date, language),
                    style: TextStyle(
                      fontSize: IosText.footnote,
                      color: IosColors.secondary(context),
                    ),
                  ),
                  const SizedBox(height: 2),
                  Text(time, style: const TextStyle(fontSize: IosText.title3)),
                ],
              ),
            ),
          ],
        );

    const gap = SizedBox(height: 24);
    return AppBackground(
      child: Scaffold(
        backgroundColor: Colors.transparent,
        appBar: AppBar(title: Text(lang.translate('app_title'))),
        body: SingleChildScrollView(
          padding: EdgeInsets.fromLTRB(
            20,
            20,
            20,
            100 + MediaQuery.paddingOf(context).bottom,
          ),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              // Date, name and the time zone of the timings.
              Center(
                child: Column(
                  children: [
                    Text(
                      AppStrings.fullDate(ekadashi.date, language),
                      textAlign: TextAlign.center,
                      style: const TextStyle(
                        fontSize: IosText.title2,
                        fontWeight: FontWeight.w300,
                      ),
                    ),
                    const SizedBox(height: 4),
                    Text(
                      ekadashi.name,
                      style: const TextStyle(
                        color: tealColor,
                        fontSize: IosText.largeTitle,
                        fontWeight: FontWeight.bold,
                      ),
                      textAlign: TextAlign.center,
                    ),
                    const SizedBox(height: 4),
                    StatusPill(
                      text: AppStrings.timeZoneName(zone, language),
                      color: tealColor,
                    ),
                  ],
                ),
              ),
              gap,
              if (ekadashi.usesContentFallback) ...[
                Text(
                  lang.translate('content_fallback'),
                  style: const TextStyle(
                    fontSize: IosText.body,
                    fontStyle: FontStyle.italic,
                  ),
                ),
                gap,
              ],
              section('significance', ekadashi.description),
              gap,
              section('story_history', ekadashi.story),
              gap,
              section('fasting_rules', ekadashi.fastingRules),
              gap,
              section('spiritual_benefits', ekadashi.benefits),
              gap,
              GlassPanel(
                key: const Key('details_timings'),
                radius: 16,
                tint: tealColor,
                padding: const EdgeInsets.all(16),
                child: Column(
                  children: [
                    timing(
                      Icons.restaurant,
                      lang.translate('start_fasting'),
                      ekadashi.date,
                      AppStrings.localizeClock(
                        ekadashi.fastStartTime,
                        language,
                      ),
                    ),
                    Divider(height: 25, color: IosColors.separator(context)),
                    timing(
                      Icons.wb_twilight,
                      lang.translate('break_fasting'),
                      ekadashi.date.add(const Duration(days: 1)),
                      breakTime,
                    ),
                  ],
                ),
              ),
              Consumer<VratTrackerService>(
                builder: (ctx, tracker, _) => tracker.trackerEnabled
                    ? Padding(
                        padding: const EdgeInsets.only(top: 24),
                        child: _vratButton(context, tracker, lang, zone),
                      )
                    : const SizedBox.shrink(),
              ),
            ],
          ),
        ),
      ),
    );
  }

  /// The Vrat button (iOS vratButton): the record's status, or Record Vrat,
  /// or, until Parana begins, a dimmed "You can record this fast once
  /// Parana begins".
  Widget _vratButton(
    BuildContext context,
    VratTrackerService tracker,
    LanguageService lang,
    String zone,
  ) {
    final record = tracker.getRecord(ekadashi.id);
    final style = _StatusStyle(record?.status, context);
    final open = VratRecording.isOpen(
      ekadashi,
      now: DateTime.now(),
      timezone: zone,
    );
    final label = record != null
        ? '${lang.translate('vrat')}: ${lang.translate(style.detailKey)}'
        : lang.translate(open ? 'record_vrat' : 'journey_record_after_parana');
    final button = SizedBox(
      width: double.infinity,
      child: OutlinedButton.icon(
        key: const Key('details_record_vrat'),
        icon: Icon(style.icon, color: style.color, size: 20),
        label: Text(
          label,
          textAlign: TextAlign.center,
          style: TextStyle(
            color: style.color,
            fontSize: IosText.callout,
            fontWeight: FontWeight.bold,
          ),
        ),
        style: IosButtons.glass(
          context,
          vertical: 14,
        ).copyWith(side: const WidgetStatePropertyAll(BorderSide.none)),
        onPressed: !open
            ? null
            : () async {
                final occurrences = EkadashiService().getEkadashis(
                  timezone: zone,
                  languageCode: lang.currentLocale.languageCode,
                );
                final unlocks = await RecordVratDialog.show(
                  context,
                  ekadashi: ekadashi,
                  allOccurrences: occurrences,
                  currentTimezone: zone,
                );
                if (unlocks != null && unlocks.isNotEmpty && context.mounted) {
                  for (final u in unlocks) {
                    await AchievementUnlockDialog.show(context, u);
                  }
                }
              },
      ),
    );
    // A disabled iOS button is drawn faded.
    return open ? button : Opacity(opacity: .45, child: button);
  }
}

/// Colour, symbol and label of a status (iOS VratStatusStyle).
class _StatusStyle {
  _StatusStyle(ObservanceStatus? status, BuildContext context)
    : status = status ?? ObservanceStatus.unrecorded,
      _context = context;

  final ObservanceStatus status;
  final BuildContext _context;

  Color get color => switch (status) {
    ObservanceStatus.observed => IosColors.green(_context),
    ObservanceStatus.partial => IosColors.partial,
    ObservanceStatus.missed => IosColors.missed,
    ObservanceStatus.unrecorded => IosColors.gray(_context),
  };

  IconData get icon => switch (status) {
    ObservanceStatus.observed => Icons.check_circle_outline,
    ObservanceStatus.partial => Icons.adjust,
    ObservanceStatus.missed => Icons.highlight_off,
    ObservanceStatus.unrecorded => Icons.help_outline,
  };

  String get detailKey =>
      status == ObservanceStatus.unrecorded ? 'record_observance' : status.name;
}
