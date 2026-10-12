import 'package:flutter/material.dart';
import '../../widgets/time_picker.dart';
import 'package:provider/provider.dart';

import '../../l10n/app_language.dart';
import '../../models/calendar_entry.dart';
import '../../services/language_service.dart';
import '../../services/notifications/event_reminder_service.dart';
import '../../services/notifications/event_reminders.dart';
import '../../services/search/search_text.dart';
import '../../widgets/glass_tube.dart';
import '../../widgets/settings_group.dart';
import '../premium_screen.dart';

typedef UpgradeAction = Future<void> Function(BuildContext context);

Future<void> _openPremium(BuildContext context) => openPremium(context);

String _language(BuildContext context) =>
    context.watch<LanguageService>().currentLocale.languageCode;

/// "On the day", "1 day before", "3 days before".
String _lead(int days, String language) => switch (days) {
  0 => AppStrings.translate('notifications_lead_0', language),
  1 => AppStrings.translate('notifications_lead_1', language),
  _ => AppStrings.translateWithArgs('notifications_lead_n', language, [
    '$days',
  ]),
};

/// "1 day before, 2 days before · 7:00 AM".
String _summary(BuildContext context, EventReminder reminder, String language) {
  final days = reminder.daysBefore.map((d) => _lead(d, language)).join(', ');
  final time = AppStrings.clock(reminder.hour, reminder.minute, language);
  return '$days · $time';
}

IconData _icon(EventReminderTarget target) => switch (target.source) {
  null => Icons.auto_awesome,
  CalendarEntrySource.google => Icons.event_available,
  CalendarEntrySource.custom => Icons.calendar_today,
};

/// The "Festivals and events" part of Notifications (docs/ROADMAP.md
/// Phase 7): the user's reminders and a button to add one. Festival and
/// Panchang reminders are Premium (like Key days); reminders for the user's
/// own and Google entries are free. Mirrors the iOS EventReminderRows.
class EventReminderRows extends StatelessWidget {
  const EventReminderRows({
    super.key,
    required this.service,
    required this.enabled,
    required this.premium,
    this.onUpgrade = _openPremium,
  });

  final EventReminderService service;

  /// The master Notifications switch (and permission).
  final bool enabled;
  final bool premium;
  final UpgradeAction onUpgrade;

  void _edit(BuildContext context, EventReminder? original) {
    Navigator.of(context).push(
      MaterialPageRoute<void>(
        fullscreenDialog: true,
        builder: (_) => EventReminderEditor(
          service: service,
          original: original,
          premium: premium,
          onUpgrade: onUpgrade,
        ),
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    final language = _language(context);
    return ListenableBuilder(
      listenable: service,
      builder: (context, _) {
        final reminders = service.reminders;
        final secondary = SettingsStyle.secondary(context);
        // Rows of the Settings card, separated like iOS list rows.
        return Column(
          children: [
            if (reminders.isEmpty) ...[
              ListTile(
                enabled: enabled,
                title: Text(
                  AppStrings.translate('notifications_no_events', language),
                  style: TextStyle(fontSize: 15, color: secondary),
                ),
              ),
              const SettingsSeparator(),
            ],
            for (final reminder in reminders) ...[
              ListTile(
                key: Key('event_reminder_row_${reminder.id}'),
                enabled: enabled,
                leading: SettingsIcon(_icon(reminder.target)),
                title: Text(
                  EventReminderChoice.titleFor(reminder.target, language),
                ),
                subtitle: Text(_summary(context, reminder, language)),
                trailing: Row(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    if (reminder.target.requiresPremium && !premium)
                      Padding(
                        padding: const EdgeInsetsDirectional.only(end: 6),
                        child: Icon(
                          Icons.lock,
                          size: 14,
                          color: secondary,
                          semanticLabel: AppStrings.translate(
                            'search_premium_locked',
                            language,
                          ),
                        ),
                      ),
                    const SettingsChevron(),
                  ],
                ),
                onTap: () => _edit(context, reminder),
              ),
              const SettingsSeparator(inset: SettingsStyle.iconInset),
            ],
            ListTile(
              key: const Key('notifications_add_event'),
              enabled: enabled,
              leading: SettingsIcon(
                Icons.add_circle,
                color: enabled ? GlassTubeColors.teal : secondary,
              ),
              title: Text(
                AppStrings.translate('notifications_add_event', language),
                style: TextStyle(
                  fontSize: 17,
                  color: enabled ? GlassTubeColors.teal : secondary,
                ),
              ),
              onTap: () => _edit(context, null),
            ),
          ],
        );
      },
    );
  }
}

/// Adds or edits one reminder: the event, the days before and the time.
class EventReminderEditor extends StatefulWidget {
  const EventReminderEditor({
    super.key,
    required this.service,
    required this.original,
    required this.premium,
    this.onUpgrade = _openPremium,
  });

  final EventReminderService service;
  final EventReminder? original;
  final bool premium;
  final UpgradeAction onUpgrade;

  @override
  State<EventReminderEditor> createState() => _EventReminderEditorState();
}

class _EventReminderEditorState extends State<EventReminderEditor> {
  EventReminderTarget? _target;
  late Set<int> _days;
  late TimeOfDay _time;

  @override
  void initState() {
    super.initState();
    final reminder =
        widget.original ??
        EventReminder(
          target: const EventReminderTarget.calendar(
            CalendarEntrySource.custom,
          ),
        );
    _target = widget.original?.target;
    _days = {...reminder.daysBefore};
    _time = TimeOfDay(hour: reminder.hour, minute: reminder.minute);
  }

  bool get _locked => _target?.requiresPremium == true && !widget.premium;

  Future<void> _choose() async {
    final picked = await Navigator.of(context).push<EventReminderTarget>(
      MaterialPageRoute(
        builder: (_) =>
            EventReminderPicker(selection: _target, premium: widget.premium),
      ),
    );
    if (picked != null && mounted) setState(() => _target = picked);
  }

  Future<void> _pickTime() async {
    final picked = await pickTime(context, _time);
    if (picked != null && mounted) setState(() => _time = picked);
  }

  /// Saves even while locked: the reminder starts with Premium.
  Future<void> _save() async {
    final target = _target;
    if (target == null || _days.isEmpty) return;
    final original = widget.original;
    if (original != null && original.target != target) {
      await widget.service.remove(original.target);
    }
    await widget.service.upsert(
      EventReminder(
        target: target,
        daysBefore: _days.toList(),
        hour: _time.hour,
        minute: _time.minute,
      ),
    );
    if (mounted) Navigator.of(context).pop();
  }

  Future<void> _delete() async {
    await widget.service.remove(widget.original!.target);
    if (mounted) Navigator.of(context).pop();
  }

  @override
  Widget build(BuildContext context) {
    final language = _language(context);
    String t(String key) => AppStrings.translate(key, language);
    final target = _target;
    final canSave = target != null && _days.isNotEmpty;
    final secondary = SettingsStyle.secondary(context);
    // Like the iOS Form: Cancel and Save in the bar, grouped cards below.
    return Scaffold(
      appBar: AppBar(
        leadingWidth: 96,
        leading: TextButton(
          style: TextButton.styleFrom(foregroundColor: GlassTubeColors.teal),
          onPressed: () => Navigator.of(context).pop(),
          child: Text(t('cancel'), overflow: TextOverflow.ellipsis),
        ),
        centerTitle: true,
        title: Text(
          t(
            widget.original == null
                ? 'notifications_add_event'
                : 'notifications_edit_event',
          ),
          style: TextStyle(
            fontSize: 17,
            fontWeight: FontWeight.w600,
            color: SettingsStyle.primary(context),
          ),
        ),
        actions: [
          TextButton(
            key: const Key('event_reminder_save'),
            style: TextButton.styleFrom(foregroundColor: GlassTubeColors.teal),
            onPressed: canSave ? _save : null,
            child: Text(
              t('save'),
              style: const TextStyle(fontWeight: FontWeight.w600),
            ),
          ),
        ],
      ),
      body: ListView(
        padding: const EdgeInsets.fromLTRB(16, 16, 16, 32),
        children: [
          SettingsCard(
            children: [
              ListTile(
                key: const Key('event_reminder_choose'),
                title: Text(t('notifications_choose_event')),
                trailing: Row(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    ConstrainedBox(
                      constraints: BoxConstraints(
                        maxWidth: MediaQuery.sizeOf(context).width * .4,
                      ),
                      child: Text(
                        target == null
                            ? '—'
                            : EventReminderChoice.titleFor(target, language),
                        textAlign: TextAlign.end,
                        style: TextStyle(fontSize: 17, color: secondary),
                      ),
                    ),
                    const SettingsChevron(),
                  ],
                ),
                onTap: _choose,
              ),
            ],
          ),
          SettingsHeader(t('notifications_lead_title')),
          SettingsCard(
            children: [
              for (final lead in EventReminder.leadDays) ...[
                if (lead != EventReminder.leadDays.first)
                  const SettingsSeparator(),
                ListTile(
                  key: Key('event_reminder_lead_$lead'),
                  selected: _days.contains(lead),
                  // The title stays in the primary colour; the check is teal.
                  selectedColor: SettingsStyle.primary(context),
                  title: Text(_lead(lead, language)),
                  trailing: _days.contains(lead)
                      ? const Icon(Icons.check, color: GlassTubeColors.teal)
                      : null,
                  onTap: () => setState(
                    () => _days.contains(lead)
                        ? _days.remove(lead)
                        : _days.add(lead),
                  ),
                ),
              ],
            ],
          ),
          if (_days.isEmpty)
            Padding(
              padding: const EdgeInsets.fromLTRB(
                SettingsStyle.rowPadding,
                8,
                16,
                0,
              ),
              child: Text(
                t('notifications_lead_required'),
                style: const TextStyle(fontSize: 13, color: Colors.orange),
              ),
            ),
          const SizedBox(height: 28),
          SettingsCard(
            children: [
              ListTile(
                key: const Key('event_reminder_time'),
                title: Text(t('notifications_time')),
                trailing: Container(
                  padding: const EdgeInsets.symmetric(
                    horizontal: 12,
                    vertical: 6,
                  ),
                  decoration: BoxDecoration(
                    color: SettingsStyle.tertiary(
                      context,
                    ).withValues(alpha: .24),
                    borderRadius: BorderRadius.circular(8),
                  ),
                  child: Text(
                    AppStrings.clock(
                      _time.hour,
                      _time.minute,
                      context
                          .read<LanguageService>()
                          .currentLocale
                          .languageCode,
                    ),
                    style: TextStyle(
                      fontSize: 17,
                      color: SettingsStyle.primary(context),
                    ),
                  ),
                ),
                onTap: _pickTime,
              ),
            ],
          ),
          if (_locked) ...[
            const SizedBox(height: 28),
            SettingsCard(
              children: [
                ListTile(
                  leading: SettingsIcon(Icons.lock, color: secondary),
                  title: Text(
                    t('notifications_premium_events'),
                    style: TextStyle(
                      fontSize: 15,
                      color: SettingsStyle.primary(context),
                    ),
                  ),
                ),
                const SettingsSeparator(inset: SettingsStyle.iconInset),
                ListTile(
                  key: const Key('event_reminder_upgrade'),
                  title: Text(
                    t('premium_upgrade'),
                    style: const TextStyle(
                      fontSize: 17,
                      color: GlassTubeColors.teal,
                    ),
                  ),
                  onTap: () => widget.onUpgrade(context),
                ),
              ],
            ),
          ],
          if (widget.original != null) ...[
            const SizedBox(height: 28),
            SettingsCard(
              children: [
                ListTile(
                  key: const Key('event_reminder_delete'),
                  title: Text(
                    t('notifications_delete_event'),
                    textAlign: TextAlign.center,
                    style: const TextStyle(fontSize: 17, color: Colors.red),
                  ),
                  onTap: _delete,
                ),
              ],
            ),
          ],
        ],
      ),
    );
  }
}

class _Header extends StatelessWidget {
  const _Header(this.text);
  final String text;

  @override
  Widget build(BuildContext context) => Padding(
    padding: const EdgeInsets.fromLTRB(16, 8, 16, 4),
    child: Text(
      text,
      style: Theme.of(
        context,
      ).textTheme.labelLarge?.copyWith(color: Colors.grey),
    ),
  );
}

/// Festivals (alphabetical), monthly days and the user's calendars, with a
/// search field. Premium choices carry a lock for free users.
class EventReminderPicker extends StatefulWidget {
  const EventReminderPicker({
    super.key,
    required this.selection,
    required this.premium,
  });

  final EventReminderTarget? selection;
  final bool premium;

  @override
  State<EventReminderPicker> createState() => _EventReminderPickerState();
}

class _EventReminderPickerState extends State<EventReminderPicker> {
  String _query = '';

  /// Matches the title in the app language or in English.
  List<EventReminderChoice> _filtered(List<EventReminderChoice> choices) {
    final needle = SearchText.normalize(_query);
    if (needle.isEmpty) return choices;
    return choices
        .where(
          (c) =>
              SearchText.normalize(c.title).contains(needle) ||
              SearchText.normalize(
                EventReminderChoice.titleFor(c.target, 'en'),
              ).contains(needle),
        )
        .toList();
  }

  @override
  Widget build(BuildContext context) {
    final language = _language(context);
    final choices = _filtered(EventReminderChoice.all(language));
    return Scaffold(
      appBar: AppBar(
        title: Text(
          AppStrings.translate('notifications_choose_event', language),
        ),
      ),
      body: Column(
        children: [
          Padding(
            padding: const EdgeInsets.fromLTRB(16, 8, 16, 8),
            child: TextField(
              key: const Key('event_reminder_search'),
              decoration: InputDecoration(
                prefixIcon: const Icon(Icons.search),
                hintText: AppStrings.translate(
                  'notifications_search_events',
                  language,
                ),
                border: const OutlineInputBorder(),
                isDense: true,
              ),
              onChanged: (value) => setState(() => _query = value),
            ),
          ),
          Expanded(
            child: ListView(
              children: [
                for (final group in EventReminderGroup.values)
                  if (choices.any((c) => c.group == group)) ...[
                    _Header(AppStrings.translate(group.titleKey, language)),
                    for (final choice in choices.where((c) => c.group == group))
                      ListTile(
                        key: Key('event_choice_${choice.id}'),
                        title: Text(choice.title),
                        trailing: widget.selection == choice.target
                            ? const Icon(
                                Icons.check,
                                color: GlassTubeColors.teal,
                              )
                            : choice.requiresPremium && !widget.premium
                            ? const Icon(
                                Icons.lock,
                                size: 16,
                                color: Colors.grey,
                              )
                            : null,
                        onTap: () => Navigator.of(context).pop(choice.target),
                      ),
                  ],
              ],
            ),
          ),
        ],
      ),
    );
  }
}
