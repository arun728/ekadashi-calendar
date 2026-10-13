import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import 'package:intl/intl.dart';
import '../../services/tradition_service.dart';
import '../../services/language_service.dart';
import '../../services/parana_guidance_service.dart';
import '../../services/parana_guidance_models.dart';

class ParanaGuidanceSheet extends StatefulWidget {
  final AppTradition initialTradition;
  final String? breakTime;
  final String? timezone;

  const ParanaGuidanceSheet({
    super.key,
    required this.initialTradition,
    this.breakTime,
    this.timezone,
  });

  static const Color tealColor = Color(0xFF00A19B);

  static void show(
    BuildContext context, {
    required AppTradition initialTradition,
    String? breakTime,
    String? timezone,
  }) {
    showModalBottomSheet(
      context: context,
      isScrollControlled: true,
      backgroundColor: Colors.transparent,
      builder: (ctx) => ParanaGuidanceSheet(
        initialTradition: initialTradition,
        breakTime: breakTime,
        timezone: timezone,
      ),
    );
  }

  @override
  State<ParanaGuidanceSheet> createState() => _ParanaGuidanceSheetState();
}

class _ParanaGuidanceSheetState extends State<ParanaGuidanceSheet> {
  late AppTradition _viewingTradition;
  final ParanaGuidanceService _guidanceService = ParanaGuidanceService();
  bool _isLoading = true;

  @override
  void initState() {
    super.initState();
    _viewingTradition = widget.initialTradition;
    _initData();
  }

  Future<void> _initData() async {
    await _guidanceService.initializeData();
    if (mounted) {
      setState(() => _isLoading = false);
    }
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
    final langCode = lang.currentLocale.languageCode;
    final isDark = Theme.of(context).brightness == Brightness.dark;
    final doc = _guidanceService.document;

    return DraggableScrollableSheet(
      initialChildSize: 0.85,
      minChildSize: 0.5,
      maxChildSize: 0.95,
      builder: (context, scrollController) {
        return Container(
          decoration: BoxDecoration(
            color: Theme.of(context).cardColor,
            borderRadius: const BorderRadius.vertical(top: Radius.circular(20)),
            boxShadow: [
              BoxShadow(
                color: Colors.black.withOpacity(0.2),
                blurRadius: 10,
                offset: const Offset(0, -2),
              ),
            ],
          ),
          child: Column(
            children: [
              // Drag handle
              Center(
                child: Container(
                  margin: const EdgeInsets.only(top: 12, bottom: 8),
                  width: 40,
                  height: 4,
                  decoration: BoxDecoration(
                    color: Colors.grey.withOpacity(0.4),
                    borderRadius: BorderRadius.circular(2),
                  ),
                ),
              ),

              // Header
              Padding(
                padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 8),
                child: Row(
                  children: [
                    const Icon(Icons.wb_twilight, color: ParanaGuidanceSheet.tealColor, size: 26),
                    const SizedBox(width: 10),
                    Expanded(
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Text(
                            lang.translate('parana_guidance'),
                            style: const TextStyle(
                              fontSize: 20,
                              fontWeight: FontWeight.bold,
                              color: ParanaGuidanceSheet.tealColor,
                            ),
                          ),
                          Text(
                            lang.translate('parana_guidance_desc'),
                            style: TextStyle(
                              fontSize: 12,
                              color: isDark ? Colors.white60 : Colors.black54,
                            ),
                          ),
                        ],
                      ),
                    ),
                    IconButton(
                      icon: const Icon(Icons.close),
                      onPressed: () => Navigator.of(context).pop(),
                    ),
                  ],
                ),
              ),
              const Divider(height: 1),

              // Content
              Expanded(
                child: _isLoading || doc == null
                    ? const Center(
                        child: CircularProgressIndicator(color: ParanaGuidanceSheet.tealColor),
                      )
                    : ListView(
                        controller: scrollController,
                        padding: const EdgeInsets.all(20),
                        children: [
                          // Source-verified distinction banner
                          _buildVerificationBanner(context, lang, doc, isDark),
                          const SizedBox(height: 16),

                          // Tradition switcher chips
                          _buildTraditionSelector(lang),
                          const SizedBox(height: 16),

                          // Section 1: Meaning
                          _buildCard(
                            context: context,
                            isDark: isDark,
                            icon: Icons.info_outline,
                            iconColor: ParanaGuidanceSheet.tealColor,
                            title: lang.translate('parana_meaning_title'),
                            content: doc.general.localizedMeaning(langCode),
                          ),
                          const SizedBox(height: 12),

                          // Section 2: Timing & Window
                          _buildCard(
                            context: context,
                            isDark: isDark,
                            icon: Icons.schedule,
                            iconColor: Colors.blue.shade700,
                            title: lang.translate('parana_window_title'),
                            content: doc.general.localizedWindowGuidance(langCode),
                            extraWidget: widget.breakTime != null && widget.breakTime!.isNotEmpty
                                ? Column(
                                    crossAxisAlignment: CrossAxisAlignment.start,
                                    children: [
                                      Container(
                                        margin: const EdgeInsets.only(top: 10),
                                        padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
                                        decoration: BoxDecoration(
                                          color: ParanaGuidanceSheet.tealColor.withOpacity(0.08),
                                          borderRadius: BorderRadius.circular(8),
                                          border: Border.all(
                                            color: ParanaGuidanceSheet.tealColor.withOpacity(0.2),
                                          ),
                                        ),
                                        child: Row(
                                          children: [
                                            const Icon(Icons.wb_sunny_outlined,
                                                size: 16, color: ParanaGuidanceSheet.tealColor),
                                            const SizedBox(width: 8),
                                            Text(
                                              '${lang.translate('break_fasting')}: ${widget.breakTime}',
                                              style: const TextStyle(
                                                fontWeight: FontWeight.bold,
                                                fontSize: 13,
                                                color: ParanaGuidanceSheet.tealColor,
                                              ),
                                            ),
                                            if (widget.timezone != null) ...[
                                              const SizedBox(width: 4),
                                              Text(
                                                '(${widget.timezone})',
                                                style: TextStyle(
                                                  fontSize: 11,
                                                  color: Colors.grey.shade600,
                                                ),
                                              ),
                                            ],
                                          ],
                                        ),
                                      ),
                                      if (_isBreakTimeShort(widget.breakTime)) ...[
                                        const SizedBox(height: 8),
                                        Container(
                                          padding: const EdgeInsets.all(10),
                                          decoration: BoxDecoration(
                                            color: Colors.amber.withOpacity(0.1),
                                            borderRadius: BorderRadius.circular(8),
                                            border: Border.all(color: Colors.amber.withOpacity(0.4)),
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
                                                    color: isDark ? Colors.amber.shade200 : Colors.amber.shade900,
                                                  ),
                                                ),
                                              ),
                                            ],
                                          ),
                                        ),
                                      ],
                                    ],
                                  )
                                : null,
                          ),
                          const SizedBox(height: 12),

                          // Section 3: Tradition Specific Rule
                          _buildTraditionRuleCard(context, lang, langCode, doc, isDark),
                          const SizedBox(height: 12),

                          // Neutral difference note if not in general
                          if (doc.localizedTraditionDifferences(langCode).isNotEmpty) ...[
                            _buildCard(
                              context: context,
                              isDark: isDark,
                              icon: Icons.compare_arrows,
                              iconColor: Colors.purple.shade600,
                              title: lang.translate('tradition_difference'),
                              content: doc.localizedTraditionDifferences(langCode),
                            ),
                            const SizedBox(height: 12),
                          ],

                          // Section 4: Dwadashi Observance
                          _buildCard(
                            context: context,
                            isDark: isDark,
                            icon: Icons.self_improvement,
                            iconColor: Colors.teal.shade700,
                            title: lang.translate('dwadashi_rules_title'),
                            content: doc.general.localizedDwadashiObservance(langCode),
                          ),
                          const SizedBox(height: 12),

                          // Section 5: Missed Window Guidance (Atikrama)
                          _buildCard(
                            context: context,
                            isDark: isDark,
                            icon: Icons.warning_amber_rounded,
                            iconColor: Colors.amber.shade800,
                            title: lang.translate('parana_missed_title'),
                            content: doc.general.localizedMissedWindowGuidance(langCode),
                            backgroundColor: isDark
                                ? Colors.amber.shade900.withOpacity(0.12)
                                : Colors.amber.shade50,
                            borderColor: Colors.amber.shade300,
                          ),
                          const SizedBox(height: 16),

                          // Section 6: Sources
                          Container(
                            padding: const EdgeInsets.all(12),
                            decoration: BoxDecoration(
                              color: isDark ? Colors.white.withOpacity(0.04) : Colors.grey.shade100,
                              borderRadius: BorderRadius.circular(10),
                            ),
                            child: Column(
                              crossAxisAlignment: CrossAxisAlignment.start,
                              children: [
                                Row(
                                  children: [
                                    const Icon(Icons.menu_book, size: 14, color: Colors.grey),
                                    const SizedBox(width: 6),
                                    Text(
                                      lang.translate('parana_sources'),
                                      style: const TextStyle(
                                        fontSize: 11,
                                        fontWeight: FontWeight.bold,
                                        color: Colors.grey,
                                      ),
                                    ),
                                  ],
                                ),
                                const SizedBox(height: 4),
                                Text(
                                  doc.source,
                                  style: TextStyle(
                                    fontSize: 11,
                                    color: isDark ? Colors.white60 : Colors.black54,
                                    fontStyle: FontStyle.italic,
                                  ),
                                ),
                              ],
                            ),
                          ),
                          const SizedBox(height: 24),
                        ],
                      ),
              ),
            ],
          ),
        );
      },
    );
  }

  Widget _buildVerificationBanner(
    BuildContext context,
    LanguageService lang,
    ParanaGuidanceDocument doc,
    bool isDark,
  ) {
    return Container(
      padding: const EdgeInsets.all(12),
      decoration: BoxDecoration(
        color: isDark ? Colors.teal.shade900.withOpacity(0.2) : Colors.teal.shade50,
        borderRadius: BorderRadius.circular(12),
        border: Border.all(color: ParanaGuidanceSheet.tealColor.withOpacity(0.25)),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Wrap(
            spacing: 8,
            runSpacing: 6,
            children: [
              Container(
                padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 3),
                decoration: BoxDecoration(
                  color: ParanaGuidanceSheet.tealColor.withOpacity(0.15),
                  borderRadius: BorderRadius.circular(6),
                ),
                child: Row(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    const Icon(Icons.check_circle, size: 12, color: ParanaGuidanceSheet.tealColor),
                    const SizedBox(width: 4),
                    Text(
                      lang.translate('shastric_guidance_badge'),
                      style: const TextStyle(
                        fontSize: 11,
                        fontWeight: FontWeight.bold,
                        color: ParanaGuidanceSheet.tealColor,
                      ),
                    ),
                  ],
                ),
              ),
              Container(
                padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 3),
                decoration: BoxDecoration(
                  color: Colors.blue.withOpacity(0.12),
                  borderRadius: BorderRadius.circular(6),
                ),
                child: Row(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    Icon(Icons.access_time, size: 12, color: Colors.blue.shade700),
                    const SizedBox(width: 4),
                    Text(
                      lang.translate('calculated_timing_badge'),
                      style: TextStyle(
                        fontSize: 11,
                        fontWeight: FontWeight.bold,
                        color: Colors.blue.shade700,
                      ),
                    ),
                  ],
                ),
              ),
            ],
          ),
          const SizedBox(height: 8),
          Text(
            doc.verificationNote,
            style: TextStyle(
              fontSize: 12,
              color: isDark ? Colors.white70 : Colors.black87,
              height: 1.35,
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildTraditionSelector(LanguageService lang) {
    return SingleChildScrollView(
      scrollDirection: Axis.horizontal,
      child: Row(
        children: [
          Text(
            '${lang.translate('tradition')}:',
            style: const TextStyle(fontSize: 12, fontWeight: FontWeight.bold),
          ),
          const SizedBox(width: 8),
          for (final t in AppTradition.values) ...[
            Padding(
              padding: const EdgeInsets.only(right: 6),
              child: ChoiceChip(
                label: Text(
                  _getTraditionName(lang, t),
                  style: TextStyle(
                    fontSize: 12,
                    color: _viewingTradition == t ? Colors.white : ParanaGuidanceSheet.tealColor,
                    fontWeight: _viewingTradition == t ? FontWeight.bold : FontWeight.normal,
                  ),
                ),
                selected: _viewingTradition == t,
                selectedColor: ParanaGuidanceSheet.tealColor,
                backgroundColor: ParanaGuidanceSheet.tealColor.withOpacity(0.08),
                padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 2),
                materialTapTargetSize: MaterialTapTargetSize.shrinkWrap,
                visualDensity: VisualDensity.compact,
                onSelected: (_) => setState(() => _viewingTradition = t),
              ),
            ),
          ],
        ],
      ),
    );
  }

  Widget _buildTraditionRuleCard(
    BuildContext context,
    LanguageService lang,
    String langCode,
    ParanaGuidanceDocument doc,
    bool isDark,
  ) {
    final rule = doc.traditions[_viewingTradition];
    if (rule == null) {
      return const SizedBox.shrink();
    }

    final title = rule.localizedTitle(langCode);
    final rules = rule.localizedRules(langCode);

    return Container(
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: Theme.of(context).cardColor,
        borderRadius: BorderRadius.circular(14),
        border: Border.all(
          color: ParanaGuidanceSheet.tealColor.withOpacity(0.4),
          width: 1.2,
        ),
        boxShadow: [
          BoxShadow(
            color: Colors.black.withOpacity(0.03),
            blurRadius: 6,
            offset: const Offset(0, 2),
          ),
        ],
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              const Icon(Icons.bookmark_border, size: 20, color: ParanaGuidanceSheet.tealColor),
              const SizedBox(width: 8),
              Expanded(
                child: Text(
                  title,
                  style: const TextStyle(
                    fontSize: 15,
                    fontWeight: FontWeight.bold,
                    color: ParanaGuidanceSheet.tealColor,
                  ),
                ),
              ),
              Container(
                padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 2),
                decoration: BoxDecoration(
                  color: ParanaGuidanceSheet.tealColor.withOpacity(0.1),
                  borderRadius: BorderRadius.circular(6),
                ),
                child: Text(
                  _getTraditionName(lang, _viewingTradition),
                  style: const TextStyle(
                    fontSize: 11,
                    fontWeight: FontWeight.bold,
                    color: ParanaGuidanceSheet.tealColor,
                  ),
                ),
              ),
            ],
          ),
          const SizedBox(height: 8),
          Text(
            rules,
            style: TextStyle(
              fontSize: 13.5,
              height: 1.45,
              color: isDark ? Colors.white70 : Colors.black87,
            ),
          ),
          const SizedBox(height: 8),
          Text(
            '${lang.translate('parana_sources')}: ${rule.source}',
            style: TextStyle(
              fontSize: 11,
              fontStyle: FontStyle.italic,
              color: Colors.grey.shade600,
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildCard({
    required BuildContext context,
    required bool isDark,
    required IconData icon,
    required Color iconColor,
    required String title,
    required String content,
    Widget? extraWidget,
    Color? backgroundColor,
    Color? borderColor,
  }) {
    return Container(
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: backgroundColor ?? Theme.of(context).cardColor,
        borderRadius: BorderRadius.circular(14),
        border: Border.all(
          color: borderColor ?? (isDark ? Colors.white12 : Colors.grey.shade300),
        ),
        boxShadow: [
          BoxShadow(
            color: Colors.black.withOpacity(0.03),
            blurRadius: 6,
            offset: const Offset(0, 2),
          ),
        ],
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              Icon(icon, size: 20, color: iconColor),
              const SizedBox(width: 8),
              Expanded(
                child: Text(
                  title,
                  style: TextStyle(
                    fontSize: 15,
                    fontWeight: FontWeight.bold,
                    color: isDark ? Colors.white : Colors.black87,
                  ),
                ),
              ),
            ],
          ),
          const SizedBox(height: 8),
          Text(
            content,
            style: TextStyle(
              fontSize: 13.5,
              height: 1.45,
              color: isDark ? Colors.white70 : Colors.black87,
            ),
          ),
          if (extraWidget != null) extraWidget,
        ],
      ),
    );
  }

  bool _isBreakTimeShort(String? breakTime) {
    if (breakTime == null || !breakTime.contains('-')) return false;
    try {
      final parts = breakTime.split('-');
      if (parts.length != 2) return false;
      final startStr = parts[0].trim();
      final endStr = parts[1].trim();
      final format = DateFormat('hh:mm a');
      final dt1 = format.parse(startStr);
      final dt2 = format.parse(endStr);
      final diff = dt2.difference(dt1).inMinutes;
      return diff > 0 && diff < 15;
    } catch (_) {
      return false;
    }
  }
}
