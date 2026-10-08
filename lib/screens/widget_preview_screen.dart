import 'package:flutter/material.dart';
import 'package:intl/intl.dart';
import 'package:provider/provider.dart';
import '../services/ekadashi_service.dart';
import '../services/language_service.dart';
import 'details_screen.dart';
import 'calendar_screen.dart';

/// The in-app preview of the two home screen widgets (docs/ROADMAP.md Phase 6):
///   1. Ekadashi: on an Ekadashi, "Today is Ekadashi", its name and the
///      progress of the fast; otherwise the next Ekadashi and the days to go.
///   2. Upcoming Ekadashis: a list.
class WidgetPreviewScreen extends StatelessWidget {
  final List<EkadashiDate> ekadashiList;
  final String? currentTimezone;

  /// The preview's clock; tests pass a fixed time.
  final DateTime? now;

  const WidgetPreviewScreen({
    super.key,
    required this.ekadashiList,
    this.currentTimezone,
    this.now,
  });

  static const Color _cyan = Color(0xFF00E5FF);

  @override
  Widget build(BuildContext context) {
    final lang = Provider.of<LanguageService>(context);
    final clock = now ?? DateTime.now();
    final today = DateTime(clock.year, clock.month, clock.day);

    final sorted = [...ekadashiList]..sort((a, b) => a.date.compareTo(b.date));
    final ahead = sorted
        .where(
          (e) =>
              !DateTime(e.date.year, e.date.month, e.date.day).isBefore(today),
        )
        .toList();
    final first = ahead.firstOrNull;
    final isToday =
        first != null &&
        DateTime(first.date.year, first.date.month, first.date.day) == today;
    // The list starts after today's Ekadashi, like the widget.
    final list = (isToday ? ahead.skip(1) : ahead).take(3).toList();

    void openDetails(EkadashiDate e) => Navigator.push(
      context,
      MaterialPageRoute(
        builder: (_) => DetailsScreen(ekadashi: e, timezone: currentTimezone),
      ),
    );

    return Scaffold(
      backgroundColor: Colors.black,
      appBar: AppBar(
        backgroundColor: Colors.transparent,
        elevation: 0,
        leading: IconButton(
          icon: const Icon(
            Icons.arrow_back_ios_new_rounded,
            color: _cyan,
            size: 20,
          ),
          onPressed: () => Navigator.pop(context),
        ),
        centerTitle: true,
        title: Text(
          lang.translate('widget_preview'),
          style: const TextStyle(
            color: _cyan,
            fontWeight: FontWeight.bold,
            fontSize: 19,
            letterSpacing: 0.5,
          ),
        ),
      ),
      body: Container(
        width: double.infinity,
        height: double.infinity,
        decoration: const BoxDecoration(
          gradient: LinearGradient(
            begin: Alignment.topCenter,
            end: Alignment.bottomCenter,
            colors: [Color(0xFF021820), Color(0xFF010D12), Color(0xFF000000)],
            stops: [0.0, 0.40, 1.0],
          ),
        ),
        child: SafeArea(
          child: ListView(
            padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 14),
            children: [
              _SectionLabel(lang.translate('widget_name_ekadashi')),
              _CompactPreviewCard(
                key: const Key('card_ekadashi'),
                onTap: () {
                  if (first != null) openDetails(first);
                },
                child: _EkadashiContent(
                  item: first,
                  isToday: isToday,
                  now: clock,
                  today: today,
                ),
              ),
              const SizedBox(height: 18),
              _SectionLabel(lang.translate('upcoming_ekadashis')),
              _CompactPreviewCard(
                key: const Key('card_upcoming_ekadashi'),
                onTap: () => Navigator.push(
                  context,
                  MaterialPageRoute(
                    builder: (_) => CalendarScreen(
                      ekadashiList: ekadashiList,
                      currentTimezone: currentTimezone,
                    ),
                  ),
                ),
                child: _UpcomingContent(upcoming: list),
              ),
              const SizedBox(height: 24),
            ],
          ),
        ),
      ),
    );
  }
}

class _SectionLabel extends StatelessWidget {
  final String text;
  const _SectionLabel(this.text);

  @override
  Widget build(BuildContext context) => Padding(
    padding: const EdgeInsets.only(left: 4, bottom: 8),
    child: Text(
      text,
      style: const TextStyle(color: Colors.white70, fontSize: 13),
    ),
  );
}

// ════════════════════════════════════════════════════════════════════════════
// SHARED COMPACT CARD SHELL (NO BORDER / COMPACT RECTANGLE)
// ════════════════════════════════════════════════════════════════════════════

class _CompactPreviewCard extends StatelessWidget {
  final VoidCallback onTap;
  final Widget child;

  const _CompactPreviewCard({
    super.key,
    required this.onTap,
    required this.child,
  });

  @override
  Widget build(BuildContext context) {
    return GestureDetector(
      onTap: onTap,
      child: Container(
        width: double.infinity,
        decoration: BoxDecoration(
          borderRadius: BorderRadius.circular(16),
          // STRICT SPECIFICATION: NO CARD OUTLINE / NO BORDER / NO STROKE
          gradient: const LinearGradient(
            begin: Alignment.topLeft,
            end: Alignment.bottomRight,
            colors: [
              Color(0xFF042530), // Dark black / deep teal top-left
              Color(0xFF011820), // Deeper mid
              Color(0xFF000E14), // Near-black bottom-right
            ],
            stops: [0.0, 0.5, 1.0],
          ),
          boxShadow: [
            BoxShadow(
              color: const Color(0xFF00E5FF).withValues(alpha: 0.12),
              blurRadius: 18,
              spreadRadius: -2,
              offset: const Offset(0, 4),
            ),
            BoxShadow(
              color: Colors.black.withValues(alpha: 0.65),
              blurRadius: 14,
              offset: const Offset(0, 6),
            ),
          ],
        ),
        clipBehavior: Clip.antiAlias,
        child: Stack(
          alignment: Alignment.center,
          children: [
            // Attached decorative background banner (responsive to card size, BoxFit.cover, slight opacity)
            Positioned.fill(
              child: Opacity(
                opacity: 0.28,
                child: Image.asset(
                  'assets/images/widget_card_banner.png',
                  fit: BoxFit.cover,
                  errorBuilder: (context, error, stackTrace) =>
                      const SizedBox.shrink(),
                ),
              ),
            ),

            // Subtle dark translucent overlay to ensure crystal-clear text readability
            Positioned.fill(
              child: Container(
                color: const Color(0xFF000E14).withValues(alpha: 0.35),
              ),
            ),

            // Subtle wave lines in the background
            Positioned.fill(child: CustomPaint(painter: _WaveLinePainter())),

            // Tiny glowing particles
            Positioned.fill(child: CustomPaint(painter: _ParticlePainter())),

            // Foreground content with balanced padding (fits content closely)
            Padding(
              padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 16),
              child: child,
            ),
          ],
        ),
      ),
    );
  }
}

// ════════════════════════════════════════════════════════════════════════════
// DEVOTIONAL LOTUS LOGO COMPONENT (PROPORTIONAL CONTAIN / NO ZOOM / NO CROP)
// ════════════════════════════════════════════════════════════════════════════

class _LotusLogo extends StatelessWidget {
  final double size;
  static const double borderRadius = 10;

  const _LotusLogo({this.size = 54});

  @override
  Widget build(BuildContext context) {
    return ClipRRect(
      borderRadius: BorderRadius.circular(borderRadius),
      child: SizedBox(
        width: size,
        height: size,
        child: Image.asset(
          'assets/images/widget_lotus_deity.png',
          fit: BoxFit
              .contain, // Strict requirement: contain scaling, no zoom, no crop
          filterQuality: FilterQuality.medium,
          errorBuilder: (context, error, stackTrace) => const SizedBox.shrink(),
        ),
      ),
    );
  }
}

// ════════════════════════════════════════════════════════════════════════════
// EKADASHI WIDGET — today with progress, or the next one and the days to go
// ════════════════════════════════════════════════════════════════════════════

class _EkadashiContent extends StatelessWidget {
  final EkadashiDate? item;
  final bool isToday;
  final DateTime now;
  final DateTime today;

  const _EkadashiContent({
    required this.item,
    required this.isToday,
    required this.now,
    required this.today,
  });

  /// How much of the fast (fasting start to Parana start) has passed.
  static double progress(EkadashiDate e, DateTime now) {
    final start = DateTime.tryParse(e.fastingStartIso);
    final parana = DateTime.tryParse(e.paranaStartIso);
    if (start == null || parana == null) return 0;
    final total = parana.difference(start).inSeconds;
    if (total <= 0) return now.isBefore(parana) ? 0 : 1;
    return (now.difference(start).inSeconds / total).clamp(0.0, 1.0);
  }

  @override
  Widget build(BuildContext context) {
    final lang = context.watch<LanguageService>();
    final e = item;
    const titleStyle = TextStyle(
      color: Colors.white,
      fontSize: 13,
      fontWeight: FontWeight.w800,
      letterSpacing: 1.1,
    );
    const detailStyle = TextStyle(
      color: Color(0xFFE0F7FA),
      fontSize: 14,
      fontWeight: FontWeight.w500,
    );
    if (e == null) {
      return Row(
        children: [
          const _LotusLogo(size: 54),
          const SizedBox(width: 14),
          Expanded(
            child: Text(
              lang.translate('open_app_to_refresh'),
              style: detailStyle,
            ),
          ),
        ],
      );
    }
    final String detail;
    double? value;
    if (isToday) {
      value = progress(e, now);
      detail = lang.translateWithArgs('widget_fast_done', [
        '${(value * 100).floor()}',
      ]);
    } else {
      final days = DateTime(
        e.date.year,
        e.date.month,
        e.date.day,
      ).difference(today).inDays;
      detail = days <= 1
          ? lang.translate(days <= 0 ? 'today' : 'tomorrow')
          : lang.translateWithArgs('widget_days_to_go', ['$days']);
    }
    return Row(
      crossAxisAlignment: CrossAxisAlignment.center,
      children: [
        const _LotusLogo(size: 54),
        const SizedBox(width: 14),
        Expanded(
          child: Column(
            mainAxisSize: MainAxisSize.min,
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text(
                lang
                    .translate(
                      isToday ? 'widget_today_is_ekadashi' : 'next_ekadashi',
                    )
                    .toUpperCase(),
                style: titleStyle,
              ),
              const SizedBox(height: 4),
              Text(
                e.name,
                maxLines: 2,
                overflow: TextOverflow.ellipsis,
                style: const TextStyle(
                  color: Colors.white,
                  fontSize: 19,
                  fontWeight: FontWeight.bold,
                ),
              ),
              if (value != null) ...[
                const SizedBox(height: 8),
                ClipRRect(
                  borderRadius: BorderRadius.circular(3),
                  child: LinearProgressIndicator(
                    value: value,
                    minHeight: 6,
                    color: const Color(0xFFFFC857),
                    backgroundColor: Colors.white24,
                  ),
                ),
              ],
              const SizedBox(height: 6),
              Text(detail, style: detailStyle),
            ],
          ),
        ),
      ],
    );
  }
}

// ════════════════════════════════════════════════════════════════════════════
// UPCOMING EKADASHIS WIDGET — a list
// ════════════════════════════════════════════════════════════════════════════

class _UpcomingContent extends StatelessWidget {
  final List<EkadashiDate> upcoming;

  const _UpcomingContent({required this.upcoming});

  @override
  Widget build(BuildContext context) {
    final lang = context.watch<LanguageService>();
    final code = lang.currentLocale.languageCode;
    return Column(
      mainAxisSize: MainAxisSize.min,
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(
          lang.translate('upcoming_ekadashis').toUpperCase(),
          style: const TextStyle(
            color: Colors.white,
            fontSize: 13,
            fontWeight: FontWeight.w800,
            letterSpacing: 1.1,
          ),
        ),
        const SizedBox(height: 10),
        if (upcoming.isEmpty)
          Text(
            lang.translate('open_app_to_refresh'),
            style: const TextStyle(color: Color(0xFFE0F7FA)),
          ),
        for (final item in upcoming)
          Padding(
            padding: const EdgeInsets.only(bottom: 8),
            child: Row(
              children: [
                _DateTile(
                  month: DateFormat(
                    'MMM',
                    code,
                  ).format(item.date).toUpperCase(),
                  day: DateFormat('d').format(item.date),
                ),
                const SizedBox(width: 12),
                Expanded(
                  child: Text(
                    item.name,
                    maxLines: 2,
                    overflow: TextOverflow.ellipsis,
                    style: const TextStyle(
                      color: Colors.white,
                      fontSize: 15,
                      fontWeight: FontWeight.w600,
                    ),
                  ),
                ),
              ],
            ),
          ),
      ],
    );
  }
}

// ════════════════════════════════════════════════════════════════════════════
// COMPACT DATE TILE (MONTH IN CYAN, DAY IN WHITE)
// ════════════════════════════════════════════════════════════════════════════

class _DateTile extends StatelessWidget {
  final String month;
  final String day;

  const _DateTile({required this.month, required this.day});

  @override
  Widget build(BuildContext context) {
    return Container(
      width: 50,
      padding: const EdgeInsets.symmetric(vertical: 6, horizontal: 2),
      decoration: BoxDecoration(
        color: const Color(0xFF021B24).withValues(alpha: 0.85),
        borderRadius: BorderRadius.circular(10),
        border: Border.all(color: const Color(0xFF008FA0), width: 1.2),
        boxShadow: [
          BoxShadow(
            color: const Color(0xFF00E5FF).withValues(alpha: 0.12),
            blurRadius: 8,
            spreadRadius: -1,
          ),
        ],
      ),
      child: Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          Text(
            month,
            style: const TextStyle(
              color: Color(0xFF00E5FF),
              fontSize: 10,
              fontWeight: FontWeight.bold,
              letterSpacing: 0.6,
            ),
          ),
          const SizedBox(height: 2),
          Text(
            day,
            style: const TextStyle(
              color: Colors.white,
              fontSize: 17,
              fontWeight: FontWeight.bold,
            ),
          ),
        ],
      ),
    );
  }
}

// ════════════════════════════════════════════════════════════════════════════
// CUSTOM PAINTERS (SUBTLE DEVOTIONAL AMBIENCE)
// ════════════════════════════════════════════════════════════════════════════

/// Subtle wave lines painted across the card background
class _WaveLinePainter extends CustomPainter {
  @override
  void paint(Canvas canvas, Size size) {
    final p = Paint()
      ..color = const Color(0xFF00E5FF).withValues(alpha: 0.05)
      ..style = PaintingStyle.stroke
      ..strokeWidth = 1.0;

    final a1 = Path()
      ..moveTo(0, size.height * 0.75)
      ..quadraticBezierTo(
        size.width * 0.30,
        size.height * 0.60,
        size.width * 0.60,
        size.height * 0.80,
      )
      ..quadraticBezierTo(
        size.width * 0.85,
        size.height * 0.95,
        size.width,
        size.height * 0.78,
      );
    canvas.drawPath(a1, p);
  }

  @override
  bool shouldRepaint(covariant CustomPainter old) => false;
}

/// Tiny cyan glowing particle specks across the card
class _ParticlePainter extends CustomPainter {
  @override
  void paint(Canvas canvas, Size size) {
    final p = Paint()..style = PaintingStyle.fill;

    const spots = [
      [0.10, 0.25],
      [0.25, 0.75],
      [0.45, 0.30],
      [0.70, 0.80],
      [0.88, 0.25],
    ];

    for (int i = 0; i < spots.length; i++) {
      final x = size.width * spots[i][0];
      final y = size.height * spots[i][1];
      p.color = const Color(0xFF00E5FF).withValues(alpha: 0.35);
      canvas.drawCircle(Offset(x, y), 1.2, p);
    }
  }

  @override
  bool shouldRepaint(covariant CustomPainter old) => false;
}
