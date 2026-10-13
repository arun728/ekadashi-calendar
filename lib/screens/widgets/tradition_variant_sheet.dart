import 'package:flutter/material.dart';
import 'package:intl/intl.dart';
import 'package:provider/provider.dart';
import '../../services/ekadashi_service.dart';
import '../../services/tradition_service.dart';
import '../../services/language_service.dart';

class TraditionVariantSheet extends StatelessWidget {
  final EkadashiDate ekadashi;
  final TraditionVariant alternateVariant;
  final String? timezone;

  const TraditionVariantSheet({
    super.key,
    required this.ekadashi,
    required this.alternateVariant,
    this.timezone,
  });

  static const Color tealColor = Color(0xFF00A19B);

  static void show(
    BuildContext context, {
    required EkadashiDate ekadashi,
    required TraditionVariant alternateVariant,
    String? timezone,
  }) {
    showModalBottomSheet(
      context: context,
      isScrollControlled: true,
      backgroundColor: Colors.transparent,
      builder: (ctx) => TraditionVariantSheet(
        ekadashi: ekadashi,
        alternateVariant: alternateVariant,
        timezone: timezone,
      ),
    );
  }

  String _getTraditionName(LanguageService lang, AppTradition tradition) {
    switch (tradition) {
      case AppTradition.smarta:
        return lang.translate('tradition_smarta');
      case AppTradition.vaishnava:
        return lang.translate('tradition_vaishnava');
      case AppTradition.general:
        return lang.translate('tradition_general');
    }
  }

  @override
  Widget build(BuildContext context) {
    final lang = Provider.of<LanguageService>(context);
    final traditionService = Provider.of<TraditionService>(context);
    final isDark = Theme.of(context).brightness == Brightness.dark;

    final userTradition = traditionService.currentTradition;
    final otherTradition = alternateVariant.tradition;

    // Determine primary tradition fasting guidance
    final primaryGuidance = (userTradition == AppTradition.smarta &&
            ekadashi.traditionVariants.containsKey(AppTradition.smarta) &&
            ekadashi.traditionVariants[AppTradition.smarta]!.fastingRules.isNotEmpty)
        ? ekadashi.traditionVariants[AppTradition.smarta]!.fastingRules
        : ((userTradition == AppTradition.vaishnava &&
                ekadashi.traditionVariants.containsKey(AppTradition.vaishnava) &&
                ekadashi.traditionVariants[AppTradition.vaishnava]!.fastingRules.isNotEmpty)
            ? ekadashi.traditionVariants[AppTradition.vaishnava]!.fastingRules
            : ekadashi.fastingRules);

    return Container(
      decoration: BoxDecoration(
        color: Theme.of(context).scaffoldBackgroundColor,
        borderRadius: const BorderRadius.vertical(top: Radius.circular(24)),
      ),
      padding: const EdgeInsets.fromLTRB(24, 16, 24, 32),
      child: SafeArea(
        top: false,
        child: SingleChildScrollView(
          child: Column(
            mainAxisSize: MainAxisSize.min,
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              // Drag handle
              Center(
                child: Container(
                  width: 40,
                  height: 4,
                  margin: const EdgeInsets.only(bottom: 16),
                  decoration: BoxDecoration(
                    color: Colors.grey.withOpacity(0.4),
                    borderRadius: BorderRadius.circular(2),
                  ),
                ),
              ),

              // Title Header
              Row(
                mainAxisAlignment: MainAxisAlignment.spaceBetween,
                children: [
                  Expanded(
                    child: Text(
                      lang.translate('other_tradition_date'),
                      style: const TextStyle(
                        fontSize: 20,
                        fontWeight: FontWeight.bold,
                      ),
                    ),
                  ),
                  IconButton(
                    icon: const Icon(Icons.close),
                    onPressed: () => Navigator.of(context).pop(),
                  ),
                ],
              ),
              const SizedBox(height: 8),

              // Informational note
              Text(
                lang.translate('other_tradition_desc'),
                style: TextStyle(
                  fontSize: 13,
                  color: isDark ? Colors.white60 : Colors.black54,
                  height: 1.4,
                ),
              ),
              const SizedBox(height: 20),

              // Primary Section (Your Tradition)
              _buildTraditionCard(
                context,
                title: '${lang.translate('your_tradition')} — ${_getTraditionName(lang, userTradition)}',
                date: ekadashi.date,
                fastStart: ekadashi.fastStartTime,
                fastBreak: ekadashi.fastBreakTime,
                guidance: primaryGuidance,
                isPrimary: true,
                isDark: isDark,
              ),

              const SizedBox(height: 16),

              // Alternate Section (Other Tradition)
              _buildTraditionCard(
                context,
                title: '${lang.translate('alternate_tradition')} — ${_getTraditionName(lang, otherTradition)}',
                date: alternateVariant.date,
                fastStart: alternateVariant.fastStartTime,
                fastBreak: alternateVariant.fastBreakTime,
                guidance: alternateVariant.fastingRules,
                isPrimary: false,
                isDark: isDark,
              ),

              const SizedBox(height: 20),

              // Subtle variation disclaimer
              Container(
                padding: const EdgeInsets.all(12),
                decoration: BoxDecoration(
                  color: tealColor.withOpacity(0.08),
                  borderRadius: BorderRadius.circular(10),
                  border: Border.all(color: tealColor.withOpacity(0.2)),
                ),
                child: Row(
                  children: [
                    const Icon(Icons.info_outline, size: 18, color: tealColor),
                    const SizedBox(width: 8),
                    Expanded(
                      child: Text(
                        lang.translate('tradition_variation_note'),
                        style: const TextStyle(fontSize: 12, color: tealColor),
                      ),
                    ),
                  ],
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }

  Widget _buildTraditionCard(
    BuildContext context, {
    required String title,
    required DateTime date,
    required String fastStart,
    required String fastBreak,
    String? guidance,
    required bool isPrimary,
    required bool isDark,
  }) {
    final lang = Provider.of<LanguageService>(context, listen: false);

    return Container(
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: Theme.of(context).cardColor,
        borderRadius: BorderRadius.circular(14),
        border: Border.all(
          color: isPrimary ? tealColor : (isDark ? Colors.white12 : Colors.grey.shade300),
          width: isPrimary ? 1.5 : 1,
        ),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              Icon(
                isPrimary ? Icons.check_circle : Icons.swap_horiz,
                color: isPrimary ? tealColor : Colors.grey,
                size: 18,
              ),
              const SizedBox(width: 8),
              Expanded(
                child: Text(
                  title,
                  style: TextStyle(
                    fontWeight: FontWeight.bold,
                    fontSize: 15,
                    color: isPrimary ? tealColor : (isDark ? Colors.white : Colors.black87),
                  ),
                ),
              ),
            ],
          ),
          const SizedBox(height: 12),
          Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: [
              Text(
                DateFormat('EEEE, MMM dd, yyyy').format(date),
                style: const TextStyle(fontSize: 16, fontWeight: FontWeight.w600),
              ),
            ],
          ),
          const SizedBox(height: 10),
          if (fastStart.isNotEmpty) ...[
            Text(
              'Fasting: $fastStart',
              style: TextStyle(fontSize: 13, color: isDark ? Colors.white70 : Colors.black87),
            ),
          ],
          if (fastBreak.isNotEmpty) ...[
            const SizedBox(height: 2),
            Text(
              'Parana: $fastBreak',
              style: TextStyle(fontSize: 13, color: isDark ? Colors.white70 : Colors.black87),
            ),
          ],
          if (guidance != null && guidance.trim().isNotEmpty) ...[
            const SizedBox(height: 10),
            Divider(color: isDark ? Colors.white12 : Colors.grey.shade200, height: 1),
            const SizedBox(height: 8),
            Row(
              children: [
                const Icon(Icons.rule_outlined, size: 14, color: tealColor),
                const SizedBox(width: 4),
                Text(
                  lang.translate('fasting_rules'),
                  style: TextStyle(
                    fontSize: 12,
                    fontWeight: FontWeight.w600,
                    color: isDark ? Colors.white70 : Colors.black87,
                  ),
                ),
              ],
            ),
            const SizedBox(height: 4),
            Text(
              guidance,
              style: TextStyle(
                fontSize: 12,
                color: isDark ? Colors.white70 : Colors.black87,
                height: 1.4,
              ),
            ),
          ] else if (guidance != null) ...[
            const SizedBox(height: 10),
            Divider(color: isDark ? Colors.white12 : Colors.grey.shade200, height: 1),
            const SizedBox(height: 8),
            Text(
              lang.translate('fasting_rules_pending'),
              style: TextStyle(
                fontSize: 12,
                color: isDark ? Colors.white60 : Colors.black54,
                fontStyle: FontStyle.italic,
              ),
            ),
          ],
        ],
      ),
    );
  }
}
