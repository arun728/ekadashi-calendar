import '../widgets/devotion_theme.dart';
import '../services/native_settings_service.dart';
import 'dart:async';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:provider/provider.dart';
import 'package:uuid/uuid.dart';
import '../services/language_service.dart';
import '../services/practice_service.dart';
import '../services/premium_service.dart';
import 'premium_screen.dart';

class PracticeScreen extends StatefulWidget {
  const PracticeScreen({
    super.key,
    required this.openVrat,
    required this.openLibrary,
  });
  final VoidCallback openVrat;
  final void Function(bool learn) openLibrary;
  @override
  State<PracticeScreen> createState() => _PracticeScreenState();
}

class _PracticeScreenState extends State<PracticeScreen> {
  String t(String key) => context.read<LanguageService>().translate(key);
  Future<void> run(Future<void> Function() action) async {
    try {
      await action();
    } catch (_) {
      if (mounted) {
        ScaffoldMessenger.of(
          context,
        ).showSnackBar(SnackBar(content: Text(t('practice_error'))));
      }
    }
  }

  bool unlock() {
    if (context.read<PremiumService>().isPremium) return true;
    openPremium(context);
    return false;
  }

  Future<void> editRoutine([PracticeRoutine? prior]) async {
    final practice = context.read<PracticeService>();
    if (prior == null && practice.routines.isNotEmpty && !unlock()) return;
    final title = TextEditingController(text: prior?.title);
    final steps = [...?prior?.steps];
    final weekdays = {...?prior?.weekdays};
    int? minute = prior?.reminderMinute;
    String? error;
    final route = DialogRoute<void>(
      context: context,
      builder: (ctx) => StatefulBuilder(
        builder: (ctx, set) => AlertDialog(
          scrollable: true,
          title: Text(
            t(prior == null ? 'practice_add_routine' : 'practice_edit_routine'),
          ),
          content: SizedBox(
            width: 400,
            child: SingleChildScrollView(
              child: Column(
                mainAxisSize: MainAxisSize.min,
                children: [
                  TextField(
                    key: const Key('routine_name'),
                    controller: title,
                    maxLength: 120,
                    decoration: InputDecoration(labelText: t('practice_title')),
                  ),
                  Text(t('practice_steps')),
                  for (final step in ['chant', 'listen', 'read', 'reflect'])
                    CheckboxListTile(
                      contentPadding: EdgeInsets.zero,
                      title: Text(t('practice_$step')),
                      value: steps.contains(step),
                      onChanged: (v) => set(() {
                        if (v == true) {
                          steps.add(step);
                        } else {
                          steps.remove(step);
                        }
                      }),
                    ),
                  Text(t('practice_schedule')),
                  Wrap(
                    children: List.generate(
                      7,
                      (i) => FilterChip(
                        label: Text(
                          MaterialLocalizations.of(
                            context,
                          ).narrowWeekdays[(i + 1) % 7],
                        ),
                        selected: weekdays.contains(i + 1),
                        onSelected: (v) {
                          if (!unlock()) return;
                          set(() {
                            if (v) {
                              weekdays.add(i + 1);
                            } else {
                              weekdays.remove(i + 1);
                            }
                          });
                        },
                      ),
                    ),
                  ),
                  SwitchListTile(
                    contentPadding: EdgeInsets.zero,
                    title: Text(t('practice_reminder')),
                    value: minute != null,
                    onChanged: (v) async {
                      if (v && !unlock()) return;
                      if (v) {
                        final permission = await NativeSettingsService()
                            .checkAllPermissions();
                        if (!mounted || !ctx.mounted) return;
                        if (!permission.hasNotificationPermission) {
                          ScaffoldMessenger.of(context).showSnackBar(
                            SnackBar(
                              content: Text(t('practice_reminder_denied')),
                            ),
                          );
                        }
                      }
                      if (!v) {
                        set(() => minute = null);
                        return;
                      }
                      final time = await showTimePicker(
                        context: ctx,
                        initialTime: const TimeOfDay(hour: 9, minute: 0),
                      );
                      if (time != null && ctx.mounted) {
                        set(() => minute = time.hour * 60 + time.minute);
                      }
                    },
                  ),
                  if (minute != null)
                    Text(
                      TimeOfDay(
                        hour: minute! ~/ 60,
                        minute: minute! % 60,
                      ).format(context),
                    ),
                  if (error != null) Text(error!),
                ],
              ),
            ),
          ),
          actions: [
            TextButton(
              onPressed: () => Navigator.pop(ctx),
              child: Text(t('cancel')),
            ),
            FilledButton(
              key: const Key('routine_save'),
              onPressed: () async {
                if (title.text.trim().isEmpty || steps.isEmpty) {
                  set(() => error = t('practice_invalid'));
                  return;
                }
                try {
                  await practice.saveRoutine(
                    PracticeRoutine(
                      id: prior?.id ?? const Uuid().v4(),
                      title: title.text.trim(),
                      steps: List.of(steps),
                      weekdays: weekdays.toList()..sort(),
                      reminderMinute: minute,
                    ),
                  );
                  if (ctx.mounted) Navigator.pop(ctx);
                } catch (_) {
                  if (ctx.mounted) set(() => error = t('practice_error'));
                }
              },
              child: Text(t('practice_save')),
            ),
          ],
        ),
      ),
    );
    await Navigator.of(context).push(route);
    await route.completed;
    title.dispose();
  }

  Future<void> configureGoal() async {
    if (!unlock()) return;
    final practice = context.read<PracticeService>();
    final name = TextEditingController(),
        target = TextEditingController(text: '108'),
        size = TextEditingController(text: '108');
    bool haptics = false;
    String? error;
    final route = DialogRoute<void>(
      context: context,
      builder: (ctx) => StatefulBuilder(
        builder: (ctx, set) => AlertDialog(
          scrollable: true,
          title: Text(t('practice_save_goal')),
          content: SingleChildScrollView(
            child: Column(
              mainAxisSize: MainAxisSize.min,
              children: [
                TextField(
                  key: const Key('japa_goal_name'),
                  controller: name,
                  maxLength: 240,
                  decoration: InputDecoration(labelText: t('practice_mantra')),
                ),
                TextField(
                  controller: target,
                  keyboardType: TextInputType.number,
                  decoration: InputDecoration(labelText: t('practice_goal')),
                ),
                TextField(
                  controller: size,
                  keyboardType: TextInputType.number,
                  decoration: InputDecoration(labelText: t('practice_mala')),
                ),
                SwitchListTile(
                  title: Text(t('practice_haptics')),
                  value: haptics,
                  onChanged: (v) => set(() => haptics = v),
                ),
                if (error != null) Text(error!),
              ],
            ),
          ),
          actions: [
            TextButton(
              onPressed: () => Navigator.pop(ctx),
              child: Text(t('cancel')),
            ),
            FilledButton(
              onPressed: () async {
                try {
                  await practice.saveGoal(
                    mantra: name.text,
                    goal: int.tryParse(target.text) ?? 0,
                    malaSize: int.tryParse(size.text) ?? 0,
                    haptics: haptics,
                  );
                  if (ctx.mounted) Navigator.pop(ctx);
                } catch (_) {
                  if (ctx.mounted) set(() => error = t('practice_invalid'));
                }
              },
              child: Text(t('practice_save')),
            ),
          ],
        ),
      ),
    );
    await Navigator.of(context).push(route);
    await route.completed;
    name.dispose();
    target.dispose();
    size.dispose();
  }

  Future<void> quietHours() async {
    final p = context.read<PracticeService>();
    final start = await showTimePicker(
      context: context,
      helpText: t('practice_quiet_hours'),
      initialTime: TimeOfDay(
        hour: p.quietStart ~/ 60,
        minute: p.quietStart % 60,
      ),
    );
    if (start == null || !mounted) return;
    final end = await showTimePicker(
      context: context,
      helpText: t('practice_quiet_hours'),
      initialTime: TimeOfDay(hour: p.quietEnd ~/ 60, minute: p.quietEnd % 60),
    );
    if (end != null) {
      await run(
        () => p.setQuietHours(
          start.hour * 60 + start.minute,
          end.hour * 60 + end.minute,
        ),
      );
    }
  }

  @override
  Widget build(BuildContext context) {
    final p = context.watch<PracticeService>();
    final lang = context.watch<LanguageService>();
    String tr(String k) => lang.translate(k);
    final paid = context.watch<PremiumService>().isPremium;
    return ListView(
      key: const Key('practice_scroll'),
      padding: const EdgeInsets.fromLTRB(16, 12, 16, 150),
      children: [
        ListTile(
          contentPadding: EdgeInsets.zero,
          title: Text(
            tr('practice_routines'),
            style: Theme.of(context).textTheme.titleLarge,
          ),
          subtitle: Text('${tr('practice_streak')}: ${p.streak}'),
          trailing: IconButton(
            key: const Key('practice_vrat'),
            tooltip: tr('practice_vrat'),
            icon: const Icon(Icons.spa),
            onPressed: widget.openVrat,
          ),
        ),
        Text(tr('practice_free_hint')),
        if (p.routines.isEmpty)
          Padding(
            padding: const EdgeInsets.symmetric(vertical: 12),
            child: Text(tr('practice_empty')),
          ),
        for (final routine in p.routines)
          Card(
            child: Padding(
              padding: const EdgeInsets.all(12),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.stretch,
                children: [
                  Row(
                    children: [
                      Expanded(
                        child: Text(
                          routine.title,
                          style: Theme.of(context).textTheme.titleMedium,
                        ),
                      ),
                      IconButton(
                        tooltip: tr('practice_edit_routine'),
                        icon: const Icon(Icons.edit_outlined),
                        onPressed: () => editRoutine(routine),
                      ),
                      IconButton(
                        tooltip: tr('practice_delete'),
                        icon: const Icon(Icons.delete_outline),
                        onPressed: () => run(() => p.removeRoutine(routine.id)),
                      ),
                    ],
                  ),
                  for (var i = 0; i < routine.steps.length; i++)
                    CheckboxListTile(
                      contentPadding: EdgeInsets.zero,
                      value: p.checked(routine.id, i),
                      title: Text(tr('practice_${routine.steps[i]}')),
                      secondary: IconButton(
                        tooltip: tr('practice_${routine.steps[i]}'),
                        icon: const Icon(Icons.arrow_forward),
                        onPressed: () {
                          if (routine.steps[i] == 'chant') {
                            Navigator.push(
                              context,
                              MaterialPageRoute<void>(
                                builder: (_) =>
                                    const DevotionTheme(child: JapaScreen()),
                              ),
                            );
                          } else if (routine.steps[i] == 'listen' ||
                              routine.steps[i] == 'read') {
                            widget.openLibrary(routine.steps[i] == 'read');
                          } else {
                            run(() => p.toggleStep(routine.id, i));
                          }
                        },
                      ),
                      onChanged: (_) => run(() => p.toggleStep(routine.id, i)),
                    ),
                ],
              ),
            ),
          ),
        OutlinedButton.icon(
          key: const Key('practice_add_routine'),
          onPressed: () => editRoutine(),
          icon: const Icon(Icons.add),
          label: Text(tr('practice_add_routine')),
        ),
        const SizedBox(height: 16),
        Text(
          tr('practice_japa'),
          style: Theme.of(context).textTheme.titleLarge,
        ),
        FilledButton.icon(
          key: const Key('practice_start'),
          icon: const Icon(Icons.play_arrow),
          label: Text(tr(p.hasSession ? 'practice_resume' : 'practice_start')),
          onPressed: () => Navigator.push(
            context,
            MaterialPageRoute<void>(
              builder: (_) => const DevotionTheme(child: JapaScreen()),
            ),
          ),
        ),
        OutlinedButton(
          onPressed: configureGoal,
          child: Text(tr('practice_save_goal')),
        ),
        for (final goal in p.goals)
          ListTile(
            title: Text(goal['mantra'] as String),
            subtitle: Text('${tr('practice_goal')}: ${goal['goal']}'),
            trailing: IconButton(
              tooltip: tr('practice_delete'),
              icon: const Icon(Icons.delete_outline),
              onPressed: () => run(() => p.removeGoal(goal['id'] as String)),
            ),
            onTap: () async {
              if (!unlock()) return;
              await run(
                () => p.start(
                  mantra: goal['mantra'] as String,
                  goal: goal['goal'] as int,
                  malaSize: goal['malaSize'] as int,
                  haptics: goal['haptics'] == true,
                ),
              );
              if (context.mounted && p.hasSession) {
                Navigator.push(
                  context,
                  MaterialPageRoute<void>(
                    builder: (_) => const DevotionTheme(child: JapaScreen()),
                  ),
                );
              }
            },
          ),
        OutlinedButton(
          onPressed: () {
            if (paid || p.sessions.isNotEmpty) {
              Navigator.push(
                context,
                MaterialPageRoute<void>(
                  builder: (_) =>
                      const DevotionTheme(child: PracticeHistoryScreen()),
                ),
              );
            } else {
              unlock();
            }
          },
          child: Text(tr('practice_history')),
        ),
        ListTile(
          contentPadding: EdgeInsets.zero,
          title: Text(tr('practice_quiet_hours')),
          subtitle: Text(
            '${TimeOfDay(hour: p.quietStart ~/ 60, minute: p.quietStart % 60).format(context)} – ${TimeOfDay(hour: p.quietEnd ~/ 60, minute: p.quietEnd % 60).format(context)}',
          ),
          onTap: quietHours,
        ),
        Text(tr('practice_quiet_explanation')),
        const SizedBox(height: 12),
        OutlinedButton.icon(
          onPressed: widget.openVrat,
          icon: const Icon(Icons.spa_outlined),
          label: Text(tr('practice_vrat')),
        ),
      ],
    );
  }
}

class JapaScreen extends StatefulWidget {
  const JapaScreen({super.key});
  @override
  State<JapaScreen> createState() => _JapaScreenState();
}

class _JapaScreenState extends State<JapaScreen> {
  Timer? _ticker;
  bool _busy = false;
  String? _error;
  @override
  void initState() {
    super.initState();
    _ticker = Timer.periodic(const Duration(seconds: 1), (_) {
      if (mounted) setState(() {});
    });
  }

  @override
  void dispose() {
    _ticker?.cancel();
    super.dispose();
  }

  Future<void> act(Future<void> Function() action) async {
    if (_busy) return;
    setState(() {
      _busy = true;
      _error = null;
    });
    try {
      await action();
    } catch (_) {
      if (mounted) {
        _error = context.read<LanguageService>().translate('practice_error');
      }
    }
    if (mounted) setState(() => _busy = false);
  }

  @override
  Widget build(BuildContext context) {
    final p = context.watch<PracticeService>();
    final lang = context.watch<LanguageService>();
    String t(String k) => lang.translate(k);
    return Scaffold(
      appBar: AppBar(title: Text(t('practice_japa'))),
      body: ListView(
        padding: const EdgeInsets.all(24),
        children: [
          if (p.mantra.isNotEmpty)
            Text(p.mantra, style: Theme.of(context).textTheme.titleLarge),
          Text('${t('practice_streak')}: ${p.streak}'),
          const SizedBox(height: 16),
          Text(
            '${p.count}',
            key: const Key('japa_count'),
            textAlign: TextAlign.center,
            style: Theme.of(context).textTheme.displayLarge,
          ),
          Text(
            '${t('practice_goal')}: ${p.goal} · ${t('practice_rounds')}: ${p.rounds}',
            textAlign: TextAlign.center,
          ),
          Text('${t('practice_minutes')}: ${p.elapsedSeconds ~/ 60}'),
          const SizedBox(height: 24),
          SizedBox(
            height: 100,
            child: FilledButton(
              key: const Key('japa_increment'),
              onPressed: !p.running || _busy
                  ? null
                  : () => act(() async {
                      final rounds = p.rounds;
                      await p.increment(const Uuid().v4());
                      if (p.rounds > rounds &&
                          p.haptics &&
                          context.mounted &&
                          context.read<PremiumService>().isPremium) {
                        await HapticFeedback.mediumImpact();
                      }
                    }),
              child: Text(
                t('practice_count'),
                style: Theme.of(context).textTheme.headlineMedium,
              ),
            ),
          ),
          const SizedBox(height: 12),
          OutlinedButton(
            key: const Key('japa_toggle'),
            onPressed: _busy
                ? null
                : () => act(
                    () => !p.hasSession
                        ? p.start()
                        : p.running
                        ? p.pause()
                        : p.resume(),
                  ),
            child: Text(
              t(
                !p.hasSession
                    ? 'practice_start'
                    : p.running
                    ? 'practice_pause'
                    : 'practice_resume',
              ),
            ),
          ),
          if (p.hasSession)
            TextButton(
              key: const Key('japa_finish'),
              onPressed: _busy ? null : () => act(p.finish),
              child: Text(t('practice_finish')),
            ),
          Text(t('practice_timer_hint')),
          if (_error != null) Text(_error!),
        ],
      ),
    );
  }
}

class PracticeHistoryScreen extends StatelessWidget {
  const PracticeHistoryScreen({super.key});
  @override
  Widget build(BuildContext context) {
    final p = context.watch<PracticeService>();
    final lang = context.watch<LanguageService>();
    return Scaffold(
      appBar: AppBar(title: Text(lang.translate('practice_history'))),
      body: ListView(
        padding: const EdgeInsets.all(16),
        children: [
          if (context.watch<PremiumService>().isPremium) ...[
            Text(
              lang.translate('practice_insights'),
              style: Theme.of(context).textTheme.titleLarge,
            ),
            Text(
              '${lang.translate('practice_weekly_count')}: ${p.weeklyCount}',
            ),
          ],
          for (final s in p.sessions.reversed)
            ListTile(
              title: Text(
                (s['mantra'] as String).isEmpty
                    ? lang.translate('practice_japa')
                    : s['mantra'] as String,
              ),
              subtitle: Text(
                '${DateTime.parse(s['endedAt'] as String).toLocal().toString().substring(0, 16)} · ${lang.translate('practice_count')}: ${s['count']} · ${lang.translate('practice_minutes')}: ${(s['seconds'] as int) ~/ 60}',
              ),
            ),
          if (p.sessions.isEmpty) Text(lang.translate('practice_empty')),
        ],
      ),
    );
  }
}
