import 'package:flutter/material.dart';
import 'package:intl/intl.dart';
import 'package:provider/provider.dart';
import '../services/ekadashi_service.dart';
import '../services/language_service.dart';
import '../services/vrat_tracker_service.dart';
import '../models/vrat_tracker_models.dart';
import 'vrat_tracker/record_vrat_dialog.dart';
import 'vrat_tracker/achievement_unlock_dialog.dart';

class DetailsScreen extends StatelessWidget {
  final EkadashiDate ekadashi;
  final String? timezone;

  const DetailsScreen({
    super.key,
    required this.ekadashi,
    this.timezone,
  });

  @override
  Widget build(BuildContext context) {
    const tealColor = Color(0xFF00A19B);
    final lang = Provider.of<LanguageService>(context);

    // Clean up break time string
    String breakTime = ekadashi.fastBreakTime;
    breakTime = breakTime.replaceAll(RegExp(r'^[a-zA-Z]{3} \d{1,2}, '), '');

    return Scaffold(
      appBar: AppBar(
        title: Text(lang.translate('app_title')),
        centerTitle: true,
      ),
      body: SingleChildScrollView(
        padding: const EdgeInsets.all(20.0),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            // Date Header
            Center(
              child: Column(
                children: [
                  Text(
                    DateFormat('MMM dd, yyyy').format(ekadashi.date),
                    style: const TextStyle(fontSize: 24, fontWeight: FontWeight.w300),
                  ),
                  Text(
                    ekadashi.name,
                    style: const TextStyle(
                        color: tealColor,
                        fontSize: 32,
                        fontWeight: FontWeight.bold
                    ),
                    textAlign: TextAlign.center,
                  ),
                  // Show timezone if available
                  if (timezone != null && timezone!.isNotEmpty) ...[
                    const SizedBox(height: 4),
                    Container(
                      padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 4),
                      decoration: BoxDecoration(
                        color: tealColor.withValues(alpha: 0.1),
                        borderRadius: BorderRadius.circular(12),
                      ),
                      child: Text(
                        timezone!,
                        style: TextStyle(
                          fontSize: 12,
                          color: tealColor.withValues(alpha: 0.8),
                          fontWeight: FontWeight.w500,
                        ),
                      ),
                    ),
                  ],
                ],
              ),
            ),
            const SizedBox(height: 30),

            // Significance Section
            Text(
              lang.translate('significance'),
              style: const TextStyle(color: tealColor, fontSize: 20, fontWeight: FontWeight.bold),
            ),
            const SizedBox(height: 8),
            Text(
              ekadashi.description,
              style: const TextStyle(fontSize: 16, height: 1.5),
            ),
            const SizedBox(height: 24),

            // Story Section
            Text(
              lang.translate('story_history'),
              style: const TextStyle(color: tealColor, fontSize: 20, fontWeight: FontWeight.bold),
            ),
            const SizedBox(height: 8),
            Text(
              ekadashi.story,
              style: const TextStyle(fontSize: 16, height: 1.5),
            ),
            const SizedBox(height: 24),

            // Rules Section
            Text(
              lang.translate('fasting_rules'),
              style: const TextStyle(color: tealColor, fontSize: 20, fontWeight: FontWeight.bold),
            ),
            const SizedBox(height: 8),
            Text(
              ekadashi.fastingRules,
              style: const TextStyle(fontSize: 16, height: 1.5),
            ),
            const SizedBox(height: 24),

            // Benefits Section
            Text(
              lang.translate('spiritual_benefits'),
              style: const TextStyle(color: tealColor, fontSize: 20, fontWeight: FontWeight.bold),
            ),
            const SizedBox(height: 8),
            Text(
              ekadashi.benefits,
              style: const TextStyle(fontSize: 16, height: 1.5),
            ),
            const SizedBox(height: 40), // Extra padding at the bottom

            // Timings Box
            Container(
              padding: const EdgeInsets.all(16),
              decoration: BoxDecoration(
                  color: Theme.of(context).cardColor,
                  borderRadius: BorderRadius.circular(12),
                  border: Border.all(color: tealColor.withValues(alpha: 0.3)),
                  boxShadow: [
                    BoxShadow(
                      color: Colors.black.withValues(alpha: 0.05),
                      blurRadius: 10,
                    )
                  ]
              ),
              child: Column(
                children: [
                  // Fasting Start
                  Row(
                    children: [
                      const Icon(Icons.restaurant_menu, color: tealColor),
                      const SizedBox(width: 12),
                      Expanded(
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            Text(
                                lang.translate('start_fasting'),
                                style: const TextStyle(color: tealColor, fontWeight: FontWeight.bold)
                            ),
                            Text(
                                DateFormat('MMM dd, yyyy').format(ekadashi.date),
                                style: const TextStyle(fontSize: 13, color: Colors.grey)
                            ),
                            Text(ekadashi.fastStartTime, style: const TextStyle(fontSize: 18)),
                          ],
                        ),
                      ),
                    ],
                  ),
                  const Divider(height: 24),
                  // Parana (Break Fast) Time
                  Row(
                    children: [
                      const Icon(Icons.wb_twilight, color: tealColor),
                      const SizedBox(width: 12),
                      Expanded(
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            Text(
                                lang.translate('break_fasting'),
                                style: const TextStyle(color: tealColor, fontWeight: FontWeight.bold)
                            ),
                            Text(
                                DateFormat('MMM dd, yyyy').format(ekadashi.date.add(const Duration(days: 1))),
                                style: const TextStyle(fontSize: 13, color: Colors.grey)
                            ),
                            Text(breakTime, style: const TextStyle(fontSize: 18)),
                          ],
                        ),
                      ),
                    ],
                  ),
                ],
              ),
            ),
            const SizedBox(height: 20),

            // Vrat Tracker Action Button (if enabled)
            Consumer<VratTrackerService>(
              builder: (ctx, trackerService, _) {
                if (!trackerService.trackerEnabled) return const SizedBox.shrink();
                final record = trackerService.getRecord(ekadashi.id);
                final status = record?.status ?? ObservanceStatus.unrecorded;

                String statusLabel;
                Color statusColor;
                IconData statusIcon;

                switch (status) {
                  case ObservanceStatus.observed:
                    statusLabel = lang.translate('observed');
                    statusColor = Colors.green;
                    statusIcon = Icons.check_circle;
                    break;
                  case ObservanceStatus.partial:
                    statusLabel = lang.translate('partial');
                    statusColor = Colors.amber.shade700;
                    statusIcon = Icons.adjust;
                    break;
                  case ObservanceStatus.missed:
                    statusLabel = lang.translate('missed');
                    statusColor = Colors.red.shade400;
                    statusIcon = Icons.highlight_off;
                    break;
                  case ObservanceStatus.unrecorded:
                    statusLabel = lang.translate('record_observance');
                    statusColor = tealColor;
                    statusIcon = Icons.edit_calendar_outlined;
                    break;
                }

                return SizedBox(
                  width: double.infinity,
                  child: OutlinedButton.icon(
                    icon: Icon(statusIcon, color: statusColor),
                    label: Text(
                      record != null
                          ? '${lang.translate('vrat')}: $statusLabel'
                          : lang.translate('record_vrat'),
                      style: TextStyle(color: statusColor, fontWeight: FontWeight.bold),
                    ),
                    style: OutlinedButton.styleFrom(
                      side: BorderSide(color: statusColor, width: 1.5),
                      padding: const EdgeInsets.symmetric(vertical: 14),
                      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
                    ),
                    onPressed: () async {
                      final occurrences = EkadashiService().getEkadashis(
                        timezone: timezone ?? 'IST',
                        languageCode: lang.currentLocale.languageCode,
                      );
                      final unlocks = await RecordVratDialog.show(
                        context,
                        ekadashi: ekadashi,
                        allOccurrences: occurrences,
                        currentTimezone: timezone ?? 'IST',
                      );
                      if (unlocks != null && unlocks.isNotEmpty && context.mounted) {
                        for (final u in unlocks) {
                          await AchievementUnlockDialog.show(context, u);
                        }
                      }
                    },
                  ),
                );
              },
            ),
            const SizedBox(height: 30),
          ],
        ),
      ),
    );
  }

}