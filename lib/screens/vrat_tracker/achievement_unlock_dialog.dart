import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:provider/provider.dart';
import '../../models/vrat_tracker_models.dart';
import '../../services/journey_rewards.dart';
import '../../services/language_service.dart';
import '../../services/vrat_tracker_service.dart';
import '../../widgets/ios_style.dart';
import 'journey_artwork.dart';
import 'journey_rewards_views.dart';

/// Matches AchievementUnlockView: one sheet for simultaneous unlocks.
class AchievementUnlockDialog extends StatefulWidget {
  const AchievementUnlockDialog({
    super.key,
    required this.achievements,
    this.summary,
  });
  final List<Achievement> achievements;
  final JourneySummary? summary;
  static Future<void>? _presentation;
  static BuildContext? _owner;
  static int _generation = 0;
  static final _pending = <String, Achievement>{};
  static final _active = <String>{};
  static Future<void> show(BuildContext c, Achievement a) => showGroup(c, [a]);
  static Future<void> showGroup(
    BuildContext c,
    List<Achievement> achievements, {
    JourneySummary? summary,
  }) {
    if (_presentation != null && _owner?.mounted != true) {
      _generation++;
      _presentation = null;
      _active.clear();
      _pending.clear();
    }
    for (final a in achievements) {
      if (!_active.contains(a.id)) {
        _pending[a.id] = JourneyBadgeCatalog.definition(a.id)?.achievement ?? a;
      }
    }
    if (_presentation != null) return _presentation!;
    if (_pending.isEmpty) return Future.value();
    _owner = c;
    final generation = ++_generation;
    Future<void> drain() async {
      try {
        while (_pending.isNotEmpty && c.mounted && generation == _generation) {
          final group = _pending.values.toList();
          _pending.clear();
          _active.addAll(group.map((a) => a.id));
          await showAppSheet<void>(
            c,
            large: false,
            builder: (_) =>
                AchievementUnlockDialog(achievements: group, summary: summary),
          );
          _active.clear();
        }
      } finally {
        if (generation == _generation) {
          _pending.clear();
          _active.clear();
          _presentation = null;
          _owner = null;
        }
      }
    }

    return _presentation = drain();
  }

  @override
  State<AchievementUnlockDialog> createState() =>
      _AchievementUnlockDialogState();
}

class _AchievementUnlockDialogState extends State<AchievementUnlockDialog> {
  bool presented = false;
  @override
  void didChangeDependencies() {
    super.didChangeDependencies();
    if (presented) return;
    presented = true;
    final tracker = context.read<VratTrackerService?>();
    final reduce = MediaQuery.disableAnimationsOf(context);
    if ((tracker?.badgeHaptics ?? true) && !reduce) {
      HapticFeedback.mediumImpact();
    }
    WidgetsBinding.instance.addPostFrameCallback((_) {
      if (mounted) {
        tracker?.markAnnouncementsPresented(
          widget.achievements.map((a) => a.id),
        );
      }
    });
  }

  @override
  Widget build(BuildContext context) {
    final lang = context.watch<LanguageService>();
    final summary =
        widget.summary ??
        JourneyRewards.calculate(
          occurrences: [],
          history: [],
          completeYears: {},
        );
    final reduceMotion = MediaQuery.disableAnimationsOf(context);
    return TweenAnimationBuilder<double>(
      key: const Key('journey_celebration_animation'),
      tween: Tween(begin: reduceMotion ? 1 : 0, end: 1),
      duration: reduceMotion
          ? Duration.zero
          : const Duration(milliseconds: 250),
      curve: Curves.easeOut,
      builder: (context, value, child) => Opacity(
        opacity: value,
        child: Transform.scale(
          scale: reduceMotion ? 1 : .96 + .04 * value,
          child: child,
        ),
      ),
      child: DefaultTextStyle.merge(
        style: TextStyle(color: IosColors.primary(context)),
        child: SingleChildScrollView(
          key: const Key('journey_badge_celebration'),
          padding: const EdgeInsets.all(24),
          child: ConstrainedBox(
            constraints: BoxConstraints(
              minHeight: (MediaQuery.sizeOf(context).height * .5 - 61).clamp(
                0,
                double.infinity,
              ),
            ),
            child: Column(
              spacing: 18,
              mainAxisSize: MainAxisSize.min,
              children: [
                Text(
                  lang.translate('achievement_unlocked'),
                  style: const TextStyle(
                    fontSize: 12,
                    fontWeight: FontWeight.bold,
                    color: IosColors.teal,
                  ),
                ),
                for (final a in widget.achievements)
                  Builder(
                    builder: (c) {
                      final b = JourneyBadgeCatalog.definition(a.id);
                      return GestureDetector(
                        onTap: b == null
                            ? null
                            : () => JourneyBadgeDetail.show(c, b, summary),
                        child: Semantics(
                          button: true,
                          child: Row(
                            spacing: 14,
                            children: [
                              if (b != null)
                                JourneyBadgeArt(definition: b, size: 78),
                              Expanded(
                                child: Column(
                                  crossAxisAlignment: CrossAxisAlignment.start,
                                  spacing: 5,
                                  children: [
                                    Text(
                                      lang.translate(a.titleKey),
                                      style: const TextStyle(
                                        fontSize: 17,
                                        fontWeight: FontWeight.w600,
                                      ),
                                    ),
                                    Text(
                                      lang.translate(a.descriptionKey),
                                      style: TextStyle(
                                        fontSize: 12,
                                        color: IosColors.secondary(c),
                                      ),
                                    ),
                                    Text(
                                      lang.translate('ios_journey_view_badge'),
                                      style: const TextStyle(
                                        fontSize: 12,
                                        fontWeight: FontWeight.bold,
                                        color: IosColors.teal,
                                      ),
                                    ),
                                  ],
                                ),
                              ),
                            ],
                          ),
                        ),
                      );
                    },
                  ),
                KeyedSubtree(
                  key: const Key('achievement_unlock_ok'),
                  child: FilledButton(
                    key: const Key('journey_celebration_close'),
                    style: IosButtons.prominent(),
                    onPressed: () => Navigator.pop(context),
                    child: Text(
                      lang.translate('hari_om'),
                      style: IosButtons.label,
                    ),
                  ),
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }
}
