import 'package:flutter/material.dart';
import 'package:intl/intl.dart';

import '../../l10n/app_language.dart';
import '../../services/ekadashi_service.dart';
import '../../widgets/app_icons.dart';

/// The texts on a share card, all in the app language (ShareCardContent in
/// EkadashiShareCard.swift). No location is shown on the card.
class ShareCardContent {
  const ShareCardContent({
    required this.observance,
    required this.tradition,
    required this.name,
    required this.pakshaMonth,
    required this.date,
    required this.fastingTitle,
    required this.fastingTime,
    required this.paranaTitle,
    required this.paranaTime,
    required this.significanceTitle,
    required this.significance,
    required this.branding,
  });

  final String observance;
  final String tradition;
  final String name;
  final String pakshaMonth;
  final String date;
  final String fastingTitle;
  final String fastingTime;
  final String paranaTitle;
  final String paranaTime;
  final String significanceTitle;
  final String significance;
  final String branding;

  factory ShareCardContent.of(
    EkadashiDate event, {
    required String language,
    required String tradition,
  }) {
    String t(String key) => AppStrings.translate(key, language);
    final parana = event.fastBreakTime.replaceAll(
      RegExp(r'^[a-zA-Z]{3} \d{1,2}, '),
      '',
    );
    return ShareCardContent(
      observance: t('share_card_observance'),
      tradition: tradition,
      name: event.name,
      pakshaMonth: [
        event.paksha,
        event.month,
      ].where((s) => s.isNotEmpty).map((s) => s.toUpperCase()).join(' • '),
      date: longDate(event.date, language),
      fastingTitle: t('share_card_fasting_begins'),
      fastingTime: event.fastStartTime.isEmpty
          ? '--:--'
          : AppStrings.localizeClock(event.fastStartTime, language),
      paranaTitle: t('share_card_parana_window'),
      paranaTime: parana.isEmpty
          ? '--:--'
          : AppStrings.localizeClock(parana, language),
      significanceTitle: t('significance'),
      significance: event.description.isEmpty
          ? event.benefits
          : event.description,
      branding: t('app_title'),
    );
  }

  /// The full weekday, month and day of PR #20's card ("Friday, November
  /// 20, 2026") in the app language.
  static String longDate(DateTime date, String language) {
    try {
      return DateFormat.yMMMMEEEEd(language).format(date);
    } catch (_) {
      return DateFormat.yMMMMEEEEd('en').format(date);
    }
  }
}

/// The devotional share card of PR #20 (shareable_ekadashi_card.dart,
/// theme "divine teal"), as EkadashiShareCard.swift draws it: the header
/// with the tradition badge, the name in serif, paksha and month, the date
/// capsule, the timings and significance beside Lord Vishnu, and the
/// branding. Free for everyone.
class EkadashiShareCard extends StatelessWidget {
  const EkadashiShareCard({super.key, required this.content});

  final ShareCardContent content;
  static const width = 360.0;
  static const _accent = Color(0xFF80CBC4);

  @override
  Widget build(BuildContext context) {
    return Container(
      width: width,
      decoration: BoxDecoration(
        borderRadius: BorderRadius.circular(24),
        gradient: const LinearGradient(
          begin: Alignment.topCenter,
          end: Alignment.bottomCenter,
          colors: [Color(0xFF00332A), Color(0xFF002922), Color(0xFF00221C)],
        ),
        border: Border.all(
          color: const Color(0xFF00A19B).withValues(alpha: 0.75),
          width: 2.2,
        ),
      ),
      child: ClipRRect(
        borderRadius: BorderRadius.circular(22),
        child: Stack(
          children: [
            Positioned(
              top: -30,
              right: -30,
              child: _glow(160, const Color(0xFF00897B), 0.18),
            ),
            Positioned(
              bottom: -40,
              left: -30,
              child: _glow(170, const Color(0xFF004D40), 0.15),
            ),
            Padding(
              padding: const EdgeInsets.all(18),
              child: Column(
                mainAxisSize: MainAxisSize.min,
                crossAxisAlignment: CrossAxisAlignment.stretch,
                children: [
                  _header(),
                  const SizedBox(height: 14),
                  Text(
                    content.name,
                    textAlign: TextAlign.center,
                    style: const TextStyle(
                      fontFamily: 'serif',
                      color: Colors.white,
                      fontSize: 27,
                      fontWeight: FontWeight.bold,
                      letterSpacing: 0.6,
                      height: 1.2,
                      shadows: [
                        Shadow(
                          color: Colors.black54,
                          blurRadius: 4,
                          offset: Offset(0, 2),
                        ),
                      ],
                    ),
                  ),
                  if (content.pakshaMonth.isNotEmpty) ...[
                    const SizedBox(height: 5),
                    Text(
                      content.pakshaMonth,
                      textAlign: TextAlign.center,
                      style: const TextStyle(
                        color: _accent,
                        fontSize: 11.5,
                        fontWeight: FontWeight.w600,
                        letterSpacing: 1.8,
                      ),
                    ),
                  ],
                  const SizedBox(height: 12),
                  Container(
                    padding: const EdgeInsets.symmetric(
                      horizontal: 16,
                      vertical: 9,
                    ),
                    decoration: BoxDecoration(
                      color: const Color(0xFF004D40).withValues(alpha: 0.35),
                      borderRadius: BorderRadius.circular(14),
                      border: Border.all(
                        color: const Color(0xFF00796B).withValues(alpha: 0.4),
                      ),
                    ),
                    child: Text(
                      content.date,
                      textAlign: TextAlign.center,
                      style: const TextStyle(
                        color: Colors.white,
                        fontSize: 16,
                        fontWeight: FontWeight.bold,
                        letterSpacing: 0.3,
                      ),
                    ),
                  ),
                  const SizedBox(height: 12),
                  _timings(),
                  const SizedBox(height: 14),
                  Row(
                    mainAxisAlignment: MainAxisAlignment.center,
                    children: [
                      Icon(
                        AppIcons.shareCardBrand,
                        size: 14,
                        color: _accent.withValues(alpha: 0.85),
                      ),
                      const SizedBox(width: 6),
                      Flexible(
                        child: Text(
                          content.branding,
                          style: TextStyle(
                            color: Colors.white.withValues(alpha: 0.75),
                            fontSize: 11.5,
                            fontWeight: FontWeight.w600,
                            letterSpacing: 0.8,
                          ),
                        ),
                      ),
                    ],
                  ),
                ],
              ),
            ),
          ],
        ),
      ),
    );
  }

  static Widget _glow(double size, Color color, double alpha) => Container(
    width: size,
    height: size,
    decoration: BoxDecoration(
      shape: BoxShape.circle,
      color: color.withValues(alpha: alpha),
    ),
  );

  Widget _header() => Row(
    children: [
      const Icon(AppIcons.shareCardSun, color: _accent, size: 21),
      const SizedBox(width: 8),
      Expanded(
        child: Text(
          content.observance.toUpperCase(),
          maxLines: 1,
          overflow: TextOverflow.ellipsis,
          style: const TextStyle(
            color: _accent,
            fontSize: 11.5,
            fontWeight: FontWeight.bold,
            letterSpacing: 1.4,
          ),
        ),
      ),
      const SizedBox(width: 8),
      Container(
        padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 4.5),
        decoration: BoxDecoration(
          color: const Color(0xFF002922).withValues(alpha: 0.7),
          borderRadius: BorderRadius.circular(16),
          border: Border.all(
            color: const Color(0xFF00A19B).withValues(alpha: 0.6),
            width: 1.2,
          ),
        ),
        child: Text(
          content.tradition.toUpperCase(),
          style: const TextStyle(
            color: _accent,
            fontSize: 11,
            fontWeight: FontWeight.bold,
            letterSpacing: 1.2,
          ),
        ),
      ),
    ],
  );

  /// Fasting start, the Parana window and the significance, with the deity
  /// silhouette and its glow on the right.
  Widget _timings() {
    final divider = Padding(
      padding: const EdgeInsets.symmetric(vertical: 8),
      child: Divider(
        color: const Color(0xFF004D40).withValues(alpha: 0.6),
        height: 1,
        thickness: 1,
      ),
    );
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 14),
      decoration: BoxDecoration(
        color: const Color(0xFF001A15).withValues(alpha: 0.65),
        borderRadius: BorderRadius.circular(18),
        border: Border.all(
          color: const Color(0xFF00796B).withValues(alpha: 0.45),
          width: 1.2,
        ),
      ),
      child: Row(
        children: [
          Expanded(
            child: Column(
              mainAxisSize: MainAxisSize.min,
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                _row(
                  AppIcons.shareCardFasting,
                  _accent,
                  content.fastingTitle,
                  content.fastingTime,
                ),
                divider,
                _row(
                  AppIcons.shareCardParana,
                  const Color(0xFFFFD54F),
                  content.paranaTitle,
                  content.paranaTime,
                ),
                if (content.significance.isNotEmpty) ...[
                  divider,
                  _row(
                    AppIcons.shareCardSignificance,
                    _accent,
                    content.significanceTitle,
                    content.significance,
                    lines: 3,
                    size: 12.5,
                    weight: FontWeight.w600,
                  ),
                ],
              ],
            ),
          ),
          const SizedBox(width: 12),
          SizedBox(
            width: 95,
            height: 140,
            child: Stack(
              alignment: Alignment.center,
              children: [
                Container(
                  width: 90,
                  height: 90,
                  decoration: BoxDecoration(
                    shape: BoxShape.circle,
                    gradient: RadialGradient(
                      colors: [
                        const Color(0xFF00E5FF).withValues(alpha: 0.18),
                        const Color(0xFF00A19B).withValues(alpha: 0.06),
                        Colors.transparent,
                      ],
                    ),
                  ),
                ),
                Image.asset(
                  'assets/images/share_card_logo.png',
                  width: 95,
                  height: 140,
                  fit: BoxFit.contain,
                  errorBuilder: (_, _, _) => const SizedBox.shrink(),
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }

  Widget _row(
    IconData icon,
    Color tint,
    String title,
    String value, {
    int lines = 2,
    double size = 15.5,
    FontWeight weight = FontWeight.bold,
  }) => Row(
    children: [
      Icon(icon, color: tint, size: 21),
      const SizedBox(width: 10),
      Expanded(
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text(
              title.toUpperCase(),
              maxLines: 1,
              overflow: TextOverflow.ellipsis,
              style: const TextStyle(
                color: _accent,
                fontSize: 10.5,
                fontWeight: FontWeight.w600,
                letterSpacing: 0.8,
              ),
            ),
            const SizedBox(height: 2),
            Text(
              value,
              maxLines: lines,
              overflow: TextOverflow.ellipsis,
              style: TextStyle(
                color: Colors.white,
                fontSize: size,
                fontWeight: weight,
                letterSpacing: 0.2,
                height: 1.25,
              ),
            ),
          ],
        ),
      ),
    ],
  );
}
