import 'package:flutter/material.dart';
import 'package:intl/intl.dart';
import 'package:provider/provider.dart';
import '../services/ekadashi_service.dart';
import '../services/language_service.dart';
import 'details_screen.dart';
import 'calendar_screen.dart';

/// Module 13 — Widget Preview Card Simplification with Lotus Logo
/// Final Compact Rectangle Design (Android + iOS)
/// Exactly 3 preview cards:
///   1. [LOTUS LOGO] EKADASHI TODAY (Only this text, compact rectangular frame)
///   2. [LOTUS LOGO] NEXT EKADASHI / Starts in 2 days (Only these two lines)
///   3. [LOTUS LOGO] UPCOMING EKADASHI / 2–3 compact date boxes
/// Design Standards:
///   • Devotional lotus logo positioned on the LEFT side of each card
///   • Logo scaled proportionally with BoxFit.contain (NO zoom, NO crop, NO distortion)
///   • No outer card outline/border/stroke
///   • Dark black/deep teal background gradient + glassmorphism + soft glow
///   • Responsive wide-rectangle proportions with compact height (no excess empty space)
///   • Large readable white typography
class WidgetPreviewScreen extends StatelessWidget {
  final List<EkadashiDate> ekadashiList;
  final String? currentTimezone;

  const WidgetPreviewScreen({
    super.key,
    required this.ekadashiList,
    this.currentTimezone,
  });

  static const Color _cyan = Color(0xFF00E5FF);

  @override
  Widget build(BuildContext context) {
    final lang = Provider.of<LanguageService>(context);

    // Resolve real dynamic data
    final today = DateTime(
      DateTime.now().year,
      DateTime.now().month,
      DateTime.now().day,
    );

    EkadashiDate? todayEkadashi;
    EkadashiDate? nextEkadashi;
    final List<EkadashiDate> upcomingRest = [];

    for (final e in ekadashiList) {
      final eDate = DateTime(e.date.year, e.date.month, e.date.day);
      if (eDate == today) {
        todayEkadashi = e;
      } else if (eDate.isAfter(today)) {
        if (nextEkadashi == null) {
          nextEkadashi = e;
        } else {
          upcomingRest.add(e);
        }
      }
    }

    final activeToday = todayEkadashi;
    final activeNext = nextEkadashi;

    // Build 2–3 item upcoming list for Card 3 (distinct upcoming dates)
    final List<EkadashiDate> threeUpcoming = [];
    for (final e in upcomingRest) {
      if (threeUpcoming.length >= 3) break;
      threeUpcoming.add(e);
    }
    if (threeUpcoming.length < 3 &&
        nextEkadashi != null &&
        !threeUpcoming.contains(nextEkadashi)) {
      threeUpcoming.insert(0, nextEkadashi);
    }
    if (threeUpcoming.length < 3) {
      for (final e in ekadashiList) {
        if (threeUpcoming.length >= 3) break;
        if (!threeUpcoming.contains(e)) threeUpcoming.add(e);
      }
    }

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
          lang.translate('app_title'),
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
              // ── CARD 1: EKADASHI TODAY ──────────────────────────────────
              _CompactPreviewCard(
                key: const Key('card_today_ekadashi'),
                onTap: () {
                  if (activeToday != null) {
                    Navigator.push(
                      context,
                      MaterialPageRoute(
                        builder: (_) => DetailsScreen(
                          ekadashi: activeToday,
                          timezone: currentTimezone,
                        ),
                      ),
                    );
                  }
                },
                child: const _Card1TodayContent(),
              ),

              const SizedBox(height: 14),

              // ── CARD 2: NEXT EKADASHI ───────────────────────────────────
              _CompactPreviewCard(
                key: const Key('card_next_ekadashi'),
                onTap: () {
                  if (activeNext != null) {
                    Navigator.push(
                      context,
                      MaterialPageRoute(
                        builder: (_) => DetailsScreen(
                          ekadashi: activeNext,
                          timezone: currentTimezone,
                        ),
                      ),
                    );
                  }
                },
                child: _Card2NextContent(next: activeNext),
              ),

              const SizedBox(height: 14),

              // ── CARD 3: UPCOMING EKADASHI ───────────────────────────────
              _CompactPreviewCard(
                key: const Key('card_upcoming_ekadashi'),
                onTap: () {
                  Navigator.push(
                    context,
                    MaterialPageRoute(
                      builder: (_) => CalendarScreen(
                        ekadashiList: ekadashiList,
                        currentTimezone: currentTimezone,
                      ),
                    ),
                  );
                },
                child: _Card3UpcomingContent(upcoming: threeUpcoming),
              ),

              const SizedBox(height: 24),
            ],
          ),
        ),
      ),
    );
  }
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
// CARD 1 CONTENT — [LOTUS LOGO] EKADASHI TODAY ONLY
// ════════════════════════════════════════════════════════════════════════════

class _Card1TodayContent extends StatelessWidget {
  const _Card1TodayContent();

  @override
  Widget build(BuildContext context) {
    final lang = context.watch<LanguageService>();
    return Row(
      crossAxisAlignment: CrossAxisAlignment.center,
      children: [
        const _LotusLogo(size: 52),
        const SizedBox(width: 14),
        Expanded(
          child: Text(
            lang.translate('widget_today_title').toUpperCase(),
            style: const TextStyle(
              color: Colors.white,
              fontSize: 19,
              fontWeight: FontWeight.w800,
              letterSpacing: 1.1,
            ),
          ),
        ),
      ],
    );
  }
}

// ════════════════════════════════════════════════════════════════════════════
// CARD 2 CONTENT — [LOTUS LOGO] NEXT EKADASHI + Starts in 2 days
// ════════════════════════════════════════════════════════════════════════════

class _Card2NextContent extends StatelessWidget {
  final EkadashiDate? next;
  const _Card2NextContent({this.next});

  @override
  Widget build(BuildContext context) {
    final lang = context.watch<LanguageService>();
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
                lang.translate('next_ekadashi').toUpperCase(),
                style: const TextStyle(
                  color: Colors.white,
                  fontSize: 19,
                  fontWeight: FontWeight.w800,
                  letterSpacing: 1.1,
                ),
              ),
              const SizedBox(height: 5),
              Text(
                next == null
                    ? lang.translate('open_app_to_refresh')
                    : lang.translateWithArgs('in_days', [
                        '${DateTime(next!.date.year, next!.date.month, next!.date.day).difference(DateTime(DateTime.now().year, DateTime.now().month, DateTime.now().day)).inDays}',
                      ]),
                style: const TextStyle(
                  color: Color(0xFFE0F7FA),
                  fontSize: 14,
                  fontWeight: FontWeight.w500,
                  letterSpacing: 0.3,
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
// CARD 3 CONTENT — [LOTUS LOGO] UPCOMING EKADASHI + 2–3 COMPACT DATE BOXES
// ════════════════════════════════════════════════════════════════════════════

class _Card3UpcomingContent extends StatelessWidget {
  final List<EkadashiDate> upcoming;

  const _Card3UpcomingContent({required this.upcoming});

  @override
  Widget build(BuildContext context) {
    final count = upcoming.length > 3 ? 3 : upcoming.length;
    final List<EkadashiDate> displayItems = upcoming.take(count).toList();

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
                context
                    .watch<LanguageService>()
                    .translate('upcoming_ekadashis')
                    .toUpperCase(),
                style: const TextStyle(
                  color: Colors.white,
                  fontSize: 19,
                  fontWeight: FontWeight.w800,
                  letterSpacing: 1.1,
                ),
              ),
              const SizedBox(height: 10),
              Row(
                mainAxisAlignment: MainAxisAlignment.start,
                children: List.generate(displayItems.length, (i) {
                  final item = displayItems[i];
                  final mon = DateFormat(
                    'MMM',
                    context.read<LanguageService>().currentLocale.languageCode,
                  ).format(item.date).toUpperCase();
                  final day = DateFormat('d').format(item.date);
                  return Padding(
                    padding: EdgeInsets.only(
                      right: i < displayItems.length - 1 ? 8 : 0,
                    ),
                    child: _DateTile(month: mon, day: day),
                  );
                }),
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
