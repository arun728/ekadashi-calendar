import 'package:flutter/material.dart';
import 'package:intl/intl.dart';
import '../../services/ekadashi_service.dart';
import '../../services/tradition_service.dart';
import '../../services/language_service.dart';
import '../../services/native_location_service.dart';
import '../../services/share_card_service.dart';

/// A beautifully styled, devotional Ekadashi card matching the official green/emerald branding.
class ShareableEkadashiCard extends StatelessWidget {
  final EkadashiDate ekadashi;
  final CardDesignTheme theme;
  final AppTradition tradition;
  final LocationData? location;
  final LanguageService lang;

  const ShareableEkadashiCard({
    super.key,
    required this.ekadashi,
    this.theme = CardDesignTheme.divineTeal,
    required this.tradition,
    required this.lang,
    this.location,
  });

  @override
  Widget build(BuildContext context) {
    const accent = Color(0xFF80CBC4);
    final borderColor = theme.cardBorderColor;

    // Tradition display label: only show for smarta or vaishnava, never for general
    String? traditionLabel;
    switch (tradition) {
      case AppTradition.smarta:
        traditionLabel = lang.translate('tradition_smarta');
        break;
      case AppTradition.vaishnava:
        traditionLabel = lang.translate('tradition_vaishnava');
        break;
      case AppTradition.general:
        traditionLabel = null;
        break;
    }

    // Resolve tradition observance if variation exists
    final resolved = ekadashi.hasTraditionVariation
        ? EkadashiService().resolveEkadashiObservance(
            event: ekadashi,
            userTradition: tradition,
          )
        : null;
    final currentEkadashi = resolved?.primary ?? ekadashi;

    // Format date in current language
    final langCode = lang.currentLocale.languageCode;
    String formattedDate;
    try {
      formattedDate = DateFormat.yMMMMEEEEd(langCode).format(currentEkadashi.date);
    } catch (_) {
      try {
        formattedDate = DateFormat.yMMMMEEEEd('en').format(currentEkadashi.date);
      } catch (_) {
        formattedDate =
            '${currentEkadashi.date.year}-${currentEkadashi.date.month.toString().padLeft(2, '0')}-${currentEkadashi.date.day.toString().padLeft(2, '0')}';
      }
    }

    // Significance text (reusing existing description / significance content)
    final significanceText = currentEkadashi.description.isNotEmpty
        ? currentEkadashi.description
        : (currentEkadashi.benefits.isNotEmpty ? currentEkadashi.benefits : '');

    return Container(
      width: 360,
      decoration: BoxDecoration(
        borderRadius: BorderRadius.circular(24),
        gradient: LinearGradient(
          begin: Alignment.topCenter,
          end: Alignment.bottomCenter,
          colors: theme.gradientColors,
        ),
        border: Border.all(color: borderColor, width: 2.2),
        boxShadow: [
          BoxShadow(
            color: Colors.black.withOpacity(0.45),
            blurRadius: 18,
            offset: const Offset(0, 8),
          ),
        ],
      ),
      child: Stack(
        children: [
          // Background subtle glowing shapes
          Positioned(
            top: -30,
            right: -30,
            child: Container(
              width: 160,
              height: 160,
              decoration: BoxDecoration(
                shape: BoxShape.circle,
                color: const Color(0xFF00897B).withOpacity(0.18),
              ),
            ),
          ),
          Positioned(
            bottom: -40,
            left: -30,
            child: Container(
              width: 170,
              height: 170,
              decoration: BoxDecoration(
                shape: BoxShape.circle,
                color: const Color(0xFF004D40).withOpacity(0.15),
              ),
            ),
          ),

          // Main Card Content
          Padding(
            padding: const EdgeInsets.symmetric(horizontal: 18, vertical: 18),
            child: Column(
              mainAxisSize: MainAxisSize.min,
              crossAxisAlignment: CrossAxisAlignment.stretch,
              children: [
                // Top Header: Devotional icon & Tradition badge
                Row(
                  mainAxisAlignment: MainAxisAlignment.spaceBetween,
                  children: [
                    Expanded(
                      child: Row(
                        mainAxisSize: MainAxisSize.min,
                        children: [
                          const Icon(
                            Icons.brightness_7_rounded,
                            color: accent,
                            size: 21,
                          ),
                          const SizedBox(width: 8),
                          Flexible(
                            child: Text(
                              lang.translate('ekadashi_observance').toUpperCase(),
                              maxLines: 1,
                              overflow: TextOverflow.ellipsis,
                              style: const TextStyle(
                                color: accent,
                                fontSize: 11.5,
                                fontWeight: FontWeight.bold,
                                letterSpacing: 1.4,
                              ),
                            ),
                          ),
                        ],
                      ),
                    ),
                    if (traditionLabel != null && traditionLabel.isNotEmpty) ...[
                      const SizedBox(width: 8),
                      Container(
                        padding: const EdgeInsets.symmetric(
                          horizontal: 14,
                          vertical: 4.5,
                        ),
                        decoration: BoxDecoration(
                          color: const Color(0xFF002922).withOpacity(0.7),
                          borderRadius: BorderRadius.circular(16),
                          border: Border.all(
                            color: const Color(0xFF00A19B).withOpacity(0.6),
                            width: 1.2,
                          ),
                        ),
                        child: Text(
                          traditionLabel.toUpperCase(),
                          style: const TextStyle(
                            color: accent,
                            fontSize: 11,
                            fontWeight: FontWeight.bold,
                            letterSpacing: 1.2,
                          ),
                        ),
                      ),
                    ],
                  ],
                ),
                const SizedBox(height: 14),

                // Ekadashi Name in Serif Typography
                Text(
                  currentEkadashi.name,
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
                  textAlign: TextAlign.center,
                ),

                // Paksha & Month details if present
                if (currentEkadashi.paksha.isNotEmpty || currentEkadashi.month.isNotEmpty) ...[
                  const SizedBox(height: 5),
                  Text(
                    [
                      if (currentEkadashi.paksha.isNotEmpty) currentEkadashi.paksha.toUpperCase(),
                      if (currentEkadashi.month.isNotEmpty) currentEkadashi.month.toUpperCase(),
                    ].join(' • '),
                    style: const TextStyle(
                      color: accent,
                      fontSize: 11.5,
                      fontWeight: FontWeight.w600,
                      letterSpacing: 1.8,
                    ),
                    textAlign: TextAlign.center,
                  ),
                ],

                // Full Formatted Observance Date Capsule Panel
                const SizedBox(height: 12),
                Container(
                  padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 9),
                  decoration: BoxDecoration(
                    color: const Color(0xFF004D40).withOpacity(0.35),
                    borderRadius: BorderRadius.circular(14),
                    border: Border.all(
                      color: const Color(0xFF00796B).withOpacity(0.4),
                      width: 1,
                    ),
                  ),
                  child: Text(
                    formattedDate,
                    style: const TextStyle(
                      color: Colors.white,
                      fontSize: 16,
                      fontWeight: FontWeight.bold,
                      letterSpacing: 0.3,
                    ),
                    textAlign: TextAlign.center,
                  ),
                ),
                const SizedBox(height: 12),

                // Timings Container with Lord Vishnu silhouette on the right
                Container(
                  padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 14),
                  decoration: BoxDecoration(
                    color: const Color(0xFF001A15).withOpacity(0.65),
                    borderRadius: BorderRadius.circular(18),
                    border: Border.all(
                      color: const Color(0xFF00796B).withOpacity(0.45),
                      width: 1.2,
                    ),
                  ),
                  child: Row(
                    crossAxisAlignment: CrossAxisAlignment.center,
                    children: [
                      // Left: Timings & Significance Column
                      Expanded(
                        child: Column(
                          mainAxisSize: MainAxisSize.min,
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            // Fasting Start
                            _buildTimingRow(
                              icon: Icons.wb_twilight_rounded,
                              iconColor: accent,
                              title: lang.translate('fasting_begins').toUpperCase(),
                              value: currentEkadashi.fastStartTime.isNotEmpty
                                  ? currentEkadashi.fastStartTime
                                  : '--:--',
                            ),
                            Padding(
                              padding: const EdgeInsets.symmetric(vertical: 8),
                              child: Divider(
                                color: const Color(0xFF004D40).withOpacity(0.6),
                                height: 1,
                                thickness: 1,
                              ),
                            ),

                            // Parana Break Window (Golden Sun accent)
                            _buildTimingRow(
                              icon: Icons.wb_sunny_rounded,
                              iconColor: const Color(0xFFFFD54F),
                              title: lang.translate('parana_window_label').toUpperCase(),
                              value: currentEkadashi.fastBreakTime.isNotEmpty
                                  ? currentEkadashi.fastBreakTime
                                  : '--:--',
                            ),

                            // Significance (replacing CURRENT LOCATION)
                            if (significanceText.isNotEmpty) ...[
                              Padding(
                                padding: const EdgeInsets.symmetric(vertical: 8),
                                child: Divider(
                                  color: const Color(0xFF004D40).withOpacity(0.6),
                                  height: 1,
                                  thickness: 1,
                                ),
                              ),
                              _buildTimingRow(
                                icon: Icons.auto_awesome_rounded,
                                iconColor: accent,
                                title: lang.translate('significance').toUpperCase(),
                                value: significanceText,
                                maxLines: 3,
                                valueFontSize: 12.5,
                                valueFontWeight: FontWeight.w600,
                              ),
                            ],
                          ],
                        ),
                      ),
                      const SizedBox(width: 12),
                      // Right: Official Transparent Deity Silhouette with radiant aura
                      SizedBox(
                        width: 95,
                        height: 140,
                        child: Stack(
                          alignment: Alignment.center,
                          children: [
                            // Radiating divine glow
                            Container(
                              width: 90,
                              height: 90,
                              decoration: BoxDecoration(
                                shape: BoxShape.circle,
                                gradient: RadialGradient(
                                  colors: [
                                    const Color(0xFF00E5FF).withOpacity(0.18),
                                    const Color(0xFF00A19B).withOpacity(0.06),
                                    Colors.transparent,
                                  ],
                                ),
                              ),
                            ),
                            // Golden silhouette image
                            Image.asset(
                              'assets/ekadashi_logo_transparent.png',
                              width: 95,
                              height: 140,
                              fit: BoxFit.contain,
                              alignment: Alignment.center,
                              errorBuilder: (context, error, stackTrace) {
                                return Image.asset(
                                  'assets/app_icon.png',
                                  fit: BoxFit.contain,
                                );
                              },
                            ),
                          ],
                        ),
                      ),
                    ],
                  ),
                ),
                const SizedBox(height: 14),

                // Footer branding (Leaf + App name, strictly NO URLs or download links)
                Row(
                  mainAxisAlignment: MainAxisAlignment.center,
                  children: [
                    Icon(
                      Icons.eco_rounded,
                      size: 14,
                      color: accent.withOpacity(0.85),
                    ),
                    const SizedBox(width: 6),
                    Text(
                      lang.translate('card_branding'),
                      style: TextStyle(
                        color: Colors.white.withOpacity(0.75),
                        fontSize: 11.5,
                        fontWeight: FontWeight.w600,
                        letterSpacing: 0.8,
                      ),
                    ),
                  ],
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildTimingRow({
    required IconData icon,
    required Color iconColor,
    required String title,
    required String value,
    int maxLines = 2,
    double valueFontSize = 15.5,
    FontWeight valueFontWeight = FontWeight.bold,
  }) {
    return Row(
      crossAxisAlignment: CrossAxisAlignment.center,
      children: [
        Icon(icon, color: iconColor, size: 21),
        const SizedBox(width: 10),
        Expanded(
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text(
                title,
                maxLines: 1,
                overflow: TextOverflow.ellipsis,
                style: const TextStyle(
                  color: Color(0xFF80CBC4),
                  fontSize: 10.5,
                  fontWeight: FontWeight.w600,
                  letterSpacing: 0.8,
                ),
              ),
              const SizedBox(height: 2),
              Text(
                value,
                maxLines: maxLines,
                overflow: TextOverflow.ellipsis,
                style: TextStyle(
                  color: Colors.white,
                  fontSize: valueFontSize,
                  fontWeight: valueFontWeight,
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
}
