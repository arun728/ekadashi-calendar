import 'dart:math' as math;
import 'dart:ui' as ui;
import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import '../../services/journey_rewards.dart';
import '../../l10n/app_language.dart';
import '../../services/language_service.dart';
import '../../models/vrat_tracker_models.dart';
import '../../widgets/ios_style.dart';

/// The same paths, 100-unit coordinate system and colours as JourneyArtwork.swift.
class JourneyBadgeArt extends StatelessWidget {
  const JourneyBadgeArt({
    super.key,
    required this.definition,
    this.earned = true,
    this.size = 82,
  });
  final JourneyBadgeDefinition definition;
  final bool earned;
  final double size;
  @override
  Widget build(BuildContext context) => ExcludeSemantics(
    child: SizedBox.square(
      dimension: size,
      child: CustomPaint(
        painter: JourneyBadgePainter(
          definition,
          earned,
          IosColors.secondary(context),
        ),
      ),
    ),
  );
}

void _stroke(
  Canvas c,
  Path p,
  Color color,
  double width, [
  List<double>? dash,
]) {
  final paint = Paint()
    ..color = color
    ..style = PaintingStyle.stroke
    ..strokeWidth = width
    ..strokeCap = StrokeCap.round
    ..strokeJoin = StrokeJoin.round;
  if (dash == null) {
    c.drawPath(p, paint);
    return;
  }
  for (final metric in p.computeMetrics()) {
    var position = 0.0, index = 0;
    while (position < metric.length) {
      final length = dash[index % dash.length];
      if (index.isEven) {
        c.drawPath(
          metric.extractPath(
            position,
            math.min(position + length, metric.length),
          ),
          paint,
        );
      }
      position += length;
      index++;
    }
  }
}

class JourneyBadgePainter extends CustomPainter {
  JourneyBadgePainter(this.definition, this.earned, this.secondary);
  final JourneyBadgeDefinition definition;
  final bool earned;
  final Color secondary;
  @override
  void paint(Canvas c, Size size) {
    final unit = math.min(size.width, size.height);
    c.save();
    c.translate((size.width - unit) / 2, (size.height - unit) / 2);
    c.scale(unit / 100);
    final ink = earned
        ? (definition.year == 2027 ? IosColors.amber : IosColors.teal)
        : secondary.withValues(alpha: secondary.a * .55);
    final circle = Path()..addOval(const Rect.fromLTWH(5, 5, 90, 90));
    c.drawPath(
      circle,
      Paint()
        ..shader = LinearGradient(
          colors: [
            ink.withValues(alpha: ink.a * .23),
            ink.withValues(alpha: ink.a * .04),
          ],
          begin: const Alignment(-.6, -1),
          end: const Alignment(.6, 1),
        ).createShader(const Rect.fromLTWH(0, 0, 100, 100)),
    );
    _stroke(c, circle, ink.withValues(alpha: ink.a * .7), 1);
    _stroke(
      c,
      Path()..addOval(const Rect.fromLTWH(10, 10, 80, 80)),
      ink.withValues(alpha: ink.a * .5),
      .8,
      [1, 4],
    );
    void line(List<Offset> points, {double width = 1.8}) =>
        _stroke(c, Path()..addPolygon(points, false), ink, width);
    void petal(double x, double y, double angle, {double length = 29}) {
      final p = Path()
        ..moveTo(0, 0)
        ..quadraticBezierTo(-12, -length * .55, 0, -length)
        ..quadraticBezierTo(12, -length * .55, 0, 0);
      c.save();
      c.translate(x, y);
      c.rotate(angle);
      c.drawPath(p, Paint()..color = ink.withValues(alpha: ink.a * .22));
      _stroke(c, p, ink, 1.4);
      c.restore();
    }

    void flame(double x, double y, {double scale = 1}) {
      final p = Path()
        ..moveTo(0, 5)
        ..cubicTo(-15, 0, -3, -12, 0, -20)
        ..cubicTo(2, -11, 14, -2, 0, 5);
      c.save();
      c.translate(x, y);
      c.scale(scale);
      c.drawPath(p, Paint()..color = ink.withValues(alpha: ink.a * .4));
      _stroke(c, p, ink, 1.5 / scale);
      c.restore();
    }

    switch (definition.art) {
      case JourneyArt.lamp:
        flame(50, 45);
        final p = Path()
          ..moveTo(27, 53)
          ..quadraticBezierTo(50, 88, 73, 53)
          ..close();
        c.drawPath(p, Paint()..color = ink.withValues(alpha: ink.a * .2));
        _stroke(c, p, ink, 1.8);
        line([const Offset(38, 76), const Offset(62, 76)]);
      case JourneyArt.leaves:
        line([const Offset(50, 77), const Offset(50, 32)]);
        petal(50, 62, -.8, length: 25);
        petal(50, 50, .8, length: 26);
        petal(50, 38, 0, length: 17);
      case JourneyArt.lotus:
      case JourneyArt.petals:
      case JourneyArt.annual:
        final count = definition.art == JourneyArt.petals ? 3 : 7;
        for (var i = 0; i < count; i++) {
          petal(
            50,
            65,
            (i - count ~/ 2) * .33,
            length: i == count ~/ 2 ? 39 : 33,
          );
        }
        line([const Offset(30, 72), const Offset(70, 72)]);
        if (definition.art == JourneyArt.annual) {
          for (var i = 0; i < 12; i++) {
            final a = i * math.pi / 6;
            c.drawCircle(
              Offset(50 + math.cos(a) * 34, 49 + math.sin(a) * 34),
              1,
              Paint()..color = ink,
            );
          }
        }
      case JourneyArt.lights:
        for (var i = 0; i < 12; i++) {
          final a = i * math.pi / 6;
          flame(50 + math.cos(a) * 24, 51 + math.sin(a) * 24, scale: .36);
        }
        _stroke(
          c,
          Path()..addOval(const Rect.fromLTWH(38, 38, 24, 24)),
          ink,
          1,
        );
      case JourneyArt.flame:
        flame(50, 64, scale: 1.8);
      case JourneyArt.arcs:
        for (var i = 0; i < 3; i++) {
          _stroke(
            c,
            Path()..addArc(
              Rect.fromCircle(center: const Offset(50, 56), radius: 15 + i * 9),
              205 * math.pi / 180,
              130 * math.pi / 180,
            ),
            ink,
            3,
          );
        }
        c.drawCircle(const Offset(50, 67), 4, Paint()..color = ink);
      case JourneyArt.thread:
        for (var i = 0; i < 3; i++) {
          _stroke(
            c,
            Path()..addOval(Rect.fromLTWH(29 + i * 3, 23 + i * 4, 38, 48)),
            ink.withValues(alpha: ink.a * .85),
            2,
            [7, 3],
          );
        }
      case JourneyArt.wreath:
        for (final side in [-1.0, 1.0]) {
          for (var i = 0; i < 6; i++) {
            final a = i * .28;
            petal(
              50 + side * math.sin(a + .3) * 26,
              77 - i * 8,
              side * (.5 + a),
              length: 14,
            );
          }
        }
        flame(50, 54);
      case JourneyArt.sunrise:
        _stroke(
          c,
          Path()..addArc(
            Rect.fromCircle(center: const Offset(50, 58), radius: 19),
            math.pi,
            math.pi,
          ),
          ink,
          2,
        );
        line([const Offset(24, 59), const Offset(76, 59)]);
        line([const Offset(34, 68), const Offset(66, 68)]);
        for (var i = 0; i < 5; i++) {
          final a = i * math.pi / 4;
          line([
            Offset(50 + math.cos(a) * 24, 58 - math.sin(a) * 24),
            Offset(50 + math.cos(a) * 30, 58 - math.sin(a) * 30),
          ]);
        }
      case JourneyArt.quarter:
        for (var i = 0; i < 4; i++) {
          petal(50, 50, i * math.pi / 2, length: 30);
        }
        final a = ((definition.quarter ?? 1) - 1) * math.pi / 2 - math.pi / 2;
        c.drawCircle(
          Offset(50 + math.cos(a) * 20, 50 + math.sin(a) * 20),
          4,
          Paint()..color = ink,
        );
    }
    c.restore();
  }

  @override
  bool shouldRepaint(JourneyBadgePainter old) =>
      old.definition.id != definition.id ||
      old.earned != earned ||
      old.secondary != secondary;
}

class JourneyMandala extends StatelessWidget {
  const JourneyMandala({super.key, required this.progress});
  final JourneyYear progress;
  @override
  Widget build(BuildContext context) {
    final lang = context.watch<LanguageService>();
    return Semantics(
      key: const Key('journey_mandala'),
      label: lang.translate('ios_journey_mandala'),
      value: AppStrings.translateWithArgs(
        'ios_journey_mandala_summary',
        lang.currentLocale.languageCode,
        [
          '${progress.segments.length}',
          '${progress.observed}',
          '${progress.partial}',
        ],
      ),
      excludeSemantics: true,
      child: AspectRatio(
        aspectRatio: 1,
        child: Stack(
          alignment: Alignment.center,
          children: [
            Positioned.fill(
              child: CustomPaint(
                painter: JourneyMandalaPainter(
                  progress,
                  IosColors.secondary(context),
                ),
              ),
            ),
            Column(
              mainAxisSize: MainAxisSize.min,
              spacing: 2,
              children: [
                if (progress.annualBonus > 0)
                  JourneyBadgeArt(
                    definition: JourneyBadgeCatalog.definition(
                      'journey_${progress.year}_full',
                    )!,
                    size: 64,
                  ),
                Text(
                  '${progress.year}',
                  style: const TextStyle(
                    fontSize: 22,
                    fontWeight: FontWeight.w600,
                    color: IosColors.teal,
                  ),
                ),
                Text(
                  '${progress.observed} / ${progress.segments.length}',
                  style: TextStyle(
                    fontSize: 12,
                    color: IosColors.secondary(context),
                  ),
                ),
              ],
            ),
          ],
        ),
      ),
    );
  }
}

class JourneyMandalaPainter extends CustomPainter {
  JourneyMandalaPainter(this.progress, this.secondary);
  final JourneyYear progress;
  final Color secondary;
  @override
  void paint(Canvas c, Size size) {
    final side = math.min(size.width, size.height),
        center = Offset(size.width / 2, size.height / 2),
        inner = side * .29,
        outer = side * .45,
        count = math.max(1, progress.segments.length);
    _stroke(
      c,
      Path()..addOval(Rect.fromCircle(center: center, radius: inner - 5)),
      IosColors.teal.withValues(alpha: .2),
      1,
    );
    for (var i = 0; i < progress.segments.length; i++) {
      final e = progress.segments[i],
          a = i / count * math.pi * 2 - math.pi / 2,
          half = math.pi / count * .78;
      Offset point(double r, double angle) =>
          center + Offset(math.cos(angle) * r, math.sin(angle) * r);
      final start = point(inner, a - half),
          tip = point(outer, a),
          end = point(inner, a + half),
          c1 = point(outer * .95, a - half),
          c2 = point(outer * .95, a + half),
          c3 = point(inner * .83, a);
      final p = Path()
        ..moveTo(start.dx, start.dy)
        ..quadraticBezierTo(c1.dx, c1.dy, tip.dx, tip.dy)
        ..quadraticBezierTo(c2.dx, c2.dy, end.dx, end.dy)
        ..quadraticBezierTo(c3.dx, c3.dy, start.dx, start.dy);
      final observed = !e.isFuture && e.status == ObservanceStatus.observed,
          partial = !e.isFuture && e.status == ObservanceStatus.partial,
          color = observed
              ? IosColors.teal
              : partial
              ? IosColors.partial
              : secondary;
      if (observed || partial) {
        c.drawPath(
          p,
          Paint()
            ..shader = ui.Gradient.linear(point(inner, a), point(outer, a), [
              color.withValues(alpha: color.a * .2),
              color.withValues(alpha: color.a * .85),
            ]),
        );
      }
      _stroke(
        c,
        p,
        color.withValues(alpha: color.a * (e.isFuture ? .2 : .7)),
        1.3,
        e.status == ObservanceStatus.unrecorded && !e.isFuture ? [2, 3] : null,
      );
      if (partial) {
        c.save();
        c.clipPath(p);
        for (var offset = -side; offset <= side; offset += 6) {
          _stroke(
            c,
            Path()
              ..moveTo(center.dx + offset, 0)
              ..lineTo(center.dx + offset + side, side),
            Colors.white.withValues(alpha: .65),
            1,
          );
        }
        c.restore();
      }
      if (!e.isFuture && e.status == ObservanceStatus.missed) {
        final d = point((inner + outer) / 2, a);
        _stroke(
          c,
          Path()
            ..moveTo(d.dx - 2, d.dy - 2)
            ..lineTo(d.dx + 2, d.dy + 2)
            ..moveTo(d.dx - 2, d.dy + 2)
            ..lineTo(d.dx + 2, d.dy - 2),
          color,
          1.2,
        );
      }
    }
    for (final q in progress.quarters) {
      final a = (q.id - 1) * math.pi / 2 - math.pi / 2,
          p =
              center +
              Offset(math.cos(a) * side * .485, math.sin(a) * side * .485);
      if (q.completed) {
        c.drawCircle(p, 3, Paint()..color = IosColors.amber);
      } else {
        _stroke(
          c,
          Path()..addOval(Rect.fromCircle(center: p, radius: 3)),
          IosColors.teal.withValues(alpha: .25),
          1,
        );
      }
    }
  }

  @override
  bool shouldRepaint(JourneyMandalaPainter old) =>
      old.progress != progress || old.secondary != secondary;
}
