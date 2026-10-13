import 'package:flutter/material.dart';
import 'package:intl/intl.dart';
import 'package:provider/provider.dart';
import '../services/ekadashi_service.dart';
import '../services/language_service.dart';
import '../services/tradition_service.dart';
import 'widgets/tradition_variant_sheet.dart';
import 'widgets/parana_guidance_sheet.dart';
import 'food_guide_screen.dart';
import 'share_card_preview_screen.dart';

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
    final traditionService = Provider.of<TraditionService>(context);
    final curTrad = traditionService.currentTradition;

    // Resolve observance for current tradition if variation exists
    final resolved = ekadashi.hasTraditionVariation
        ? EkadashiService().resolveEkadashiObservance(
            event: ekadashi,
            userTradition: curTrad,
          )
        : null;
    final currentEkadashi = resolved?.primary ?? ekadashi;

    // Clean up break time string
    String breakTime = currentEkadashi.fastBreakTime;
    breakTime = breakTime.replaceAll(RegExp(r'^[a-zA-Z]{3} \d{1,2}, '), '');

    // Identify alternate tradition if variation exists
    final otherTrad = (curTrad == AppTradition.smarta)
        ? AppTradition.vaishnava
        : (curTrad == AppTradition.vaishnava
            ? AppTradition.smarta
            : AppTradition.vaishnava);
    final alt = ekadashi.traditionVariants[otherTrad] ??
        ekadashi.traditionVariants.values.firstOrNull;

    // Determine tradition-aware fasting guidance and label
    String activeGuidance = '';
    String traditionBadgeText = '';

    if (curTrad == AppTradition.smarta &&
        ekadashi.traditionVariants.containsKey(AppTradition.smarta) &&
        ekadashi.traditionVariants[AppTradition.smarta]!.fastingRules.isNotEmpty) {
      activeGuidance = ekadashi.traditionVariants[AppTradition.smarta]!.fastingRules;
      traditionBadgeText = lang.translate('tradition_smarta');
    } else if (curTrad == AppTradition.vaishnava &&
        ekadashi.traditionVariants.containsKey(AppTradition.vaishnava) &&
        ekadashi.traditionVariants[AppTradition.vaishnava]!.fastingRules.isNotEmpty) {
      activeGuidance = ekadashi.traditionVariants[AppTradition.vaishnava]!.fastingRules;
      traditionBadgeText = lang.translate('tradition_vaishnava');
    } else {
      activeGuidance = currentEkadashi.fastingRules;
      traditionBadgeText = curTrad == AppTradition.smarta
          ? lang.translate('tradition_smarta')
          : (curTrad == AppTradition.vaishnava
              ? lang.translate('tradition_vaishnava')
              : lang.translate('tradition_general'));
    }

    if (activeGuidance.trim().isEmpty && currentEkadashi.fastingRules.trim().isNotEmpty) {
      activeGuidance = currentEkadashi.fastingRules;
    }

    return Scaffold(
      appBar: AppBar(
        title: Text(lang.translate('app_title')),
        centerTitle: true,
        actions: [
          IconButton(
            icon: const Icon(Icons.share_outlined),
            tooltip: lang.translate('share_card'),
            onPressed: () {
              Navigator.push(
                context,
                MaterialPageRoute(
                  builder: (_) => ShareCardPreviewScreen(
                    ekadashi: currentEkadashi,
                    timezone: timezone,
                  ),
                ),
              );
            },
          ),
        ],
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
                    DateFormat('MMM dd, yyyy').format(currentEkadashi.date),
                    style: const TextStyle(fontSize: 24, fontWeight: FontWeight.w300),
                  ),
                  Text(
                    currentEkadashi.name,
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
                        color: tealColor.withOpacity(0.1),
                        borderRadius: BorderRadius.circular(12),
                      ),
                      child: Text(
                        timezone!,
                        style: TextStyle(
                          fontSize: 12,
                          color: tealColor.withOpacity(0.8),
                          fontWeight: FontWeight.w500,
                        ),
                      ),
                    ),
                  ],
                  if (ekadashi.hasTraditionVariation) ...[
                    const SizedBox(height: 8),
                    Column(
                      children: [
                        Container(
                          padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 4),
                          decoration: BoxDecoration(
                            color: tealColor.withOpacity(0.1),
                            borderRadius: BorderRadius.circular(12),
                            border: Border.all(color: tealColor.withOpacity(0.3)),
                          ),
                          child: Text(
                            curTrad == AppTradition.smarta
                                ? '${lang.translate('tradition_smarta')} ${lang.translate('tradition')}'
                                : (curTrad == AppTradition.vaishnava
                                    ? '${lang.translate('tradition_vaishnava')} ${lang.translate('tradition')}'
                                    : lang.translate('tradition_variation_note')),
                            style: TextStyle(
                              fontSize: 12,
                              fontWeight: FontWeight.w500,
                              color: tealColor.withOpacity(0.9),
                            ),
                          ),
                        ),
                        if (alt != null) ...[
                          const SizedBox(height: 6),
                          TextButton.icon(
                            onPressed: () {
                              TraditionVariantSheet.show(
                                context,
                                ekadashi: ekadashi,
                                alternateVariant: alt,
                                timezone: timezone,
                              );
                            },
                            icon: const Icon(Icons.swap_horiz, size: 16, color: tealColor),
                            label: Text(
                              lang.translate('view_other_tradition'),
                              style: const TextStyle(
                                color: tealColor,
                                fontSize: 13,
                                fontWeight: FontWeight.w600,
                                decoration: TextDecoration.underline,
                              ),
                            ),
                          ),
                        ],
                      ],
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
              currentEkadashi.description,
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
              currentEkadashi.story,
              style: const TextStyle(fontSize: 16, height: 1.5),
            ),
            const SizedBox(height: 24),

            // Fasting Rules Section
            Row(
              children: [
                Text(
                  lang.translate('fasting_rules'),
                  style: const TextStyle(color: tealColor, fontSize: 20, fontWeight: FontWeight.bold),
                ),
                if (traditionBadgeText.isNotEmpty) ...[
                  const SizedBox(width: 8),
                  Container(
                    padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 2),
                    decoration: BoxDecoration(
                      color: tealColor.withOpacity(0.12),
                      borderRadius: BorderRadius.circular(8),
                      border: Border.all(color: tealColor.withOpacity(0.3)),
                    ),
                    child: Text(
                      traditionBadgeText,
                      style: const TextStyle(
                        color: tealColor,
                        fontSize: 12,
                        fontWeight: FontWeight.w600,
                      ),
                    ),
                  ),
                ],
              ],
            ),
            const SizedBox(height: 8),
            if (activeGuidance.trim().isNotEmpty) ...[
              Text(
                activeGuidance,
                style: const TextStyle(fontSize: 16, height: 1.5),
              ),
            ] else ...[
              Container(
                width: double.infinity,
                padding: const EdgeInsets.all(12),
                decoration: BoxDecoration(
                  color: Colors.amber.withOpacity(0.08),
                  borderRadius: BorderRadius.circular(8),
                  border: Border.all(color: Colors.amber.withOpacity(0.3)),
                ),
                child: Row(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Icon(Icons.info_outline, size: 20, color: Colors.amber.shade800),
                    const SizedBox(width: 8),
                    Expanded(
                      child: Text(
                        lang.translate('fasting_rules_pending'),
                        style: TextStyle(
                          fontSize: 14,
                          fontStyle: FontStyle.italic,
                          color: Theme.of(context).brightness == Brightness.dark
                              ? Colors.amber.shade200
                              : Colors.amber.shade900,
                        ),
                      ),
                    ),
                  ],
                ),
              ),
            ],
            const SizedBox(height: 6),
            Wrap(
              spacing: 8,
              runSpacing: 4,
              crossAxisAlignment: WrapCrossAlignment.center,
              children: [
                if (ekadashi.hasTraditionVariation && alt != null)
                  TextButton.icon(
                    onPressed: () {
                      TraditionVariantSheet.show(
                        context,
                        ekadashi: ekadashi,
                        alternateVariant: alt,
                        timezone: timezone,
                      );
                    },
                    icon: const Icon(Icons.swap_horiz, size: 16, color: tealColor),
                    label: Text(
                      lang.translate('view_other_tradition_rules'),
                      style: const TextStyle(
                        color: tealColor,
                        fontSize: 13,
                        fontWeight: FontWeight.w600,
                        decoration: TextDecoration.underline,
                      ),
                    ),
                  ),
                TextButton.icon(
                  onPressed: () {
                    Navigator.push(
                      context,
                      MaterialPageRoute(
                        builder: (_) => FoodGuideScreen(initialTradition: curTrad),
                      ),
                    );
                  },
                  icon: const Icon(Icons.restaurant_menu, size: 16, color: tealColor),
                  label: Text(
                    lang.translate('view_food_guide'),
                    style: const TextStyle(
                      color: tealColor,
                      fontSize: 13,
                      fontWeight: FontWeight.w600,
                      decoration: TextDecoration.underline,
                    ),
                  ),
                ),
                TextButton.icon(
                  onPressed: () {
                    Navigator.push(
                      context,
                      MaterialPageRoute(
                        builder: (_) => ShareCardPreviewScreen(ekadashi: ekadashi),
                      ),
                    );
                  },
                  icon: const Icon(Icons.share, size: 16, color: tealColor),
                  label: Text(
                    lang.translate('share_card'),
                    style: const TextStyle(
                      color: tealColor,
                      fontSize: 13,
                      fontWeight: FontWeight.w600,
                      decoration: TextDecoration.underline,
                    ),
                  ),
                ),
              ],
            ),
            const SizedBox(height: 24),

            // Benefits Section
            Text(
              lang.translate('spiritual_benefits'),
              style: const TextStyle(color: tealColor, fontSize: 20, fontWeight: FontWeight.bold),
            ),
            const SizedBox(height: 8),
            Text(
              currentEkadashi.benefits,
              style: const TextStyle(fontSize: 16, height: 1.5),
            ),
            const SizedBox(height: 40), // Extra padding at the bottom

            // Timings Box
            Container(
              padding: const EdgeInsets.all(16),
              decoration: BoxDecoration(
                  color: Theme.of(context).cardColor,
                  borderRadius: BorderRadius.circular(12),
                  border: Border.all(color: tealColor.withOpacity(0.3)),
                  boxShadow: [
                    BoxShadow(
                      color: Colors.black.withOpacity(0.05),
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
                                DateFormat('MMM dd, yyyy').format(currentEkadashi.date),
                                style: const TextStyle(fontSize: 13, color: Colors.grey)
                            ),
                            Text(currentEkadashi.fastStartTime, style: const TextStyle(fontSize: 18)),
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
                                DateFormat('MMM dd, yyyy').format(currentEkadashi.date.add(const Duration(days: 1))),
                                style: const TextStyle(fontSize: 13, color: Colors.grey)
                            ),
                            Text(breakTime, style: const TextStyle(fontSize: 18)),
                            if (currentEkadashi.isShortParanaWindow) ...[
                              const SizedBox(height: 8),
                              Container(
                                padding: const EdgeInsets.all(10),
                                decoration: BoxDecoration(
                                  color: Colors.amber.withOpacity(0.08),
                                  borderRadius: BorderRadius.circular(8),
                                  border: Border.all(color: Colors.amber.withOpacity(0.35)),
                                ),
                                child: Row(
                                  crossAxisAlignment: CrossAxisAlignment.start,
                                  children: [
                                    Icon(Icons.info_outline, size: 16, color: Colors.amber.shade800),
                                    const SizedBox(width: 8),
                                    Expanded(
                                      child: Text(
                                        lang.translate('short_parana_notice'),
                                        style: TextStyle(
                                          fontSize: 12,
                                          height: 1.4,
                                          color: Theme.of(context).brightness == Brightness.dark
                                              ? Colors.amber.shade200
                                              : Colors.amber.shade900,
                                        ),
                                      ),
                                    ),
                                  ],
                                ),
                              ),
                            ],
                          ],
                        ),
                      ),
                    ],
                  ),
                  const Divider(height: 24),
                  // Parana Guidance & Rules Link
                  InkWell(
                    onTap: () {
                      ParanaGuidanceSheet.show(
                        context,
                        initialTradition: curTrad,
                        breakTime: breakTime,
                        timezone: timezone,
                      );
                    },
                    borderRadius: BorderRadius.circular(8),
                    child: Padding(
                      padding: const EdgeInsets.symmetric(vertical: 4),
                      child: Row(
                        children: [
                          const Icon(Icons.menu_book_outlined, color: tealColor, size: 18),
                          const SizedBox(width: 8),
                          Expanded(
                            child: Text(
                              lang.translate('parana_guidance'),
                              style: const TextStyle(
                                color: tealColor,
                                fontSize: 14,
                                fontWeight: FontWeight.w600,
                                decoration: TextDecoration.underline,
                              ),
                            ),
                          ),
                          const Icon(Icons.chevron_right, color: tealColor, size: 18),
                        ],
                      ),
                    ),
                  ),
                ],
              ),
            ),
            const SizedBox(height: 30),
          ],
        ),
      ),
    );
  }

}