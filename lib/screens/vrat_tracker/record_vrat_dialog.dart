import '../../l10n/app_language.dart';
import '../../widgets/ios_style.dart';
import 'package:flutter/material.dart';
import 'package:intl/intl.dart';
import 'package:provider/provider.dart';
import '../../models/vrat_tracker_models.dart';
import '../../services/ekadashi_service.dart';
import '../../services/vrat_recording.dart';
import '../../services/language_service.dart';
import '../../services/vrat_tracker_service.dart';
import '../../services/premium_service.dart';
import '../premium_screen.dart';

/// Records, edits or deletes one observance (iOS RecordVratSheet): a sheet
/// with Cancel and a trash button in its bar.
class RecordVratDialog extends StatefulWidget {
  final EkadashiDate ekadashi;
  final List<EkadashiDate> allOccurrences;
  final String currentTimezone;

  const RecordVratDialog({
    super.key,
    required this.ekadashi,
    required this.allOccurrences,
    required this.currentTimezone,
  });

  static Future<List<Achievement>?> show(
    BuildContext context, {
    required EkadashiDate ekadashi,
    required List<EkadashiDate> allOccurrences,
    required String currentTimezone,
  }) {
    // An iOS sheet (.large) over the tab bar.
    return showAppSheet<List<Achievement>>(
      context,
      builder: (ctx) => RecordVratDialog(
        ekadashi: ekadashi,
        allOccurrences: allOccurrences,
        currentTimezone: currentTimezone,
      ),
    );
  }

  @override
  State<RecordVratDialog> createState() => _RecordVratDialogState();
}

class _RecordVratDialogState extends State<RecordVratDialog> {
  late ObservanceStatus _status;
  FastingMethod? _fastingMethod;
  late TextEditingController _otherMethodController;
  late TextEditingController _noteController;
  bool _isFutureEvent = false;
  bool _saving = false;
  VratHistory? _existingRecord;

  @override
  void initState() {
    super.initState();
    final tracker = Provider.of<VratTrackerService>(context, listen: false);
    _existingRecord = tracker.getRecordByUid(widget.ekadashi.occurrenceUid);

    // A fast can be recorded once it is over: past Ekadashis, and today's
    // once Parana begins (docs/ROADMAP.md Phase 4).
    _isFutureEvent = !VratRecording.isOpen(
      widget.ekadashi,
      now: DateTime.now(),
      timezone: widget.currentTimezone,
    );

    _status =
        _existingRecord?.status ??
        (_isFutureEvent
            ? ObservanceStatus.unrecorded
            : ObservanceStatus.observed);
    _fastingMethod = _existingRecord?.fastingMethod ?? FastingMethod.fullFast;
    _otherMethodController = TextEditingController(
      text: _existingRecord?.fastingMethodOther ?? '',
    );
    _noteController = TextEditingController(text: _existingRecord?.note ?? '');
  }

  @override
  void dispose() {
    _otherMethodController.dispose();
    _noteController.dispose();
    super.dispose();
  }

  void _onStatusChanged(ObservanceStatus newStatus) {
    if (_isFutureEvent && newStatus != ObservanceStatus.unrecorded) {
      _toast('journey_record_after_parana');
      return;
    }
    setState(() {
      _status = newStatus;
    });
  }

  void _toast(String key) =>
      showToast(context, context.read<LanguageService>().translate(key));

  Future<void> _save() async {
    if (_isFutureEvent) {
      _toast('journey_record_after_parana');
      return;
    }

    final tracker = Provider.of<VratTrackerService>(context, listen: false);
    final premium = context.read<PremiumService?>();
    if (_status != ObservanceStatus.unrecorded &&
        tracker.needsPremiumToRecord(
          widget.ekadashi.occurrenceUid,
          premium: premium?.isPremium == true,
        )) {
      await openPremium(
        context,
        currentTimezone: widget.currentTimezone,
        reasonKey: 'vrat_free_limit_reached',
      );
      if (!mounted) return;
      if (premium?.isPremium != true) {
        _toast('vrat_free_limit_reached');
        return;
      }
    }
    setState(() => _saving = true);
    final dateStr = DateFormat('yyyy-MM-dd').format(widget.ekadashi.date);

    try {
      final newlyUnlocked = await tracker.recordVrat(
        ekadashiOccurrenceId: widget.ekadashi.id,
        occurrenceUid: widget.ekadashi.occurrenceUid,
        ekadashiDate: dateStr,
        ekadashiName: widget.ekadashi.name,
        status: _status,
        fastingMethod:
            _status == ObservanceStatus.observed ||
                _status == ObservanceStatus.partial
            ? _fastingMethod
            : null,
        fastingMethodOther: _fastingMethod == FastingMethod.other
            ? _otherMethodController.text.trim()
            : null,
        note: _noteController.text.trim().isNotEmpty
            ? _noteController.text.trim()
            : null,
        timezone: widget.currentTimezone,
        occurrences: widget.allOccurrences,
      );

      if (mounted) {
        Navigator.of(context).pop(newlyUnlocked);
      }
    } catch (_) {
      if (mounted) {
        setState(() => _saving = false);
        _toast('tracker_storage_failed');
      }
    }
  }

  Future<void> _delete() async {
    final lang = Provider.of<LanguageService>(context, listen: false);
    final confirmed = await showDialog<bool>(
      context: context,
      builder: (ctx) => AlertDialog(
        title: Text(lang.translate('delete_confirm')),
        content: Text(lang.translate('delete_confirm_desc')),
        actions: [
          TextButton(
            onPressed: () => Navigator.of(ctx).pop(false),
            child: Text(lang.translate('cancel')),
          ),
          TextButton(
            onPressed: () => Navigator.of(ctx).pop(true),
            style: TextButton.styleFrom(foregroundColor: IosColors.red(ctx)),
            child: Text(lang.translate('delete_record')),
          ),
        ],
      ),
    );

    if (confirmed == true && mounted) {
      final tracker = Provider.of<VratTrackerService>(context, listen: false);
      try {
        await tracker.deleteVrat(
          ekadashiOccurrenceId: widget.ekadashi.id,
          occurrenceUid: widget.ekadashi.occurrenceUid,
          occurrences: widget.allOccurrences,
        );
        if (mounted) {
          Navigator.of(context).pop(<Achievement>[]);
        }
      } catch (_) {
        if (mounted) _toast('tracker_storage_failed');
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    final lang = Provider.of<LanguageService>(context);
    final formattedDate = AppStrings.fullDate(
      widget.ekadashi.date,
      lang.currentLocale.languageCode,
    );
    final orange = IosColors.orange(context);
    final fasting =
        _status == ObservanceStatus.observed ||
        _status == ObservanceStatus.partial;
    final fieldBorder = OutlineInputBorder(
      borderRadius: BorderRadius.circular(8),
      borderSide: BorderSide(color: IosColors.separator(context)),
    );
    InputDecoration field(String hintKey) => InputDecoration(
      hintText: lang.translate(hintKey),
      isDense: true,
      filled: true,
      fillColor: IosColors.groupedCard(context),
      contentPadding: const EdgeInsets.symmetric(horizontal: 10, vertical: 10),
      border: fieldBorder,
      enabledBorder: fieldBorder,
      focusedBorder: fieldBorder.copyWith(
        borderSide: const BorderSide(color: IosColors.teal),
      ),
    );

    return Material(
      type: MaterialType.transparency,
      child: Column(
        children: [
          SheetBar(
            title: '',
            leading: BarTextButton(
              key: const Key('vrat_record_cancel'),
              label: lang.translate('cancel'),
              onPressed: () => Navigator.of(context).pop(),
            ),
            trailing: _existingRecord == null
                ? null
                : IconButton(
                    key: const Key('vrat_record_delete'),
                    tooltip: lang.translate('delete_record'),
                    onPressed: _delete,
                    icon: Icon(
                      Icons.delete_outline,
                      color: IosColors.red(context),
                    ),
                  ),
          ),
          Expanded(
            child: SingleChildScrollView(
              padding: EdgeInsets.fromLTRB(
                20,
                20,
                20,
                MediaQuery.of(context).viewInsets.bottom + 20,
              ),
              child: Column(
                key: const Key('vrat_record_form'),
                crossAxisAlignment: CrossAxisAlignment.stretch,
                spacing: 20,
                children: [
                  Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    spacing: 4,
                    children: [
                      Text(
                        widget.ekadashi.name,
                        style: TextStyle(
                          fontSize: IosText.title3,
                          fontWeight: FontWeight.w700,
                          color: IosColors.primary(context),
                        ),
                      ),
                      Text(
                        formattedDate,
                        style: TextStyle(
                          fontSize: IosText.footnote,
                          color: IosColors.secondary(context),
                        ),
                      ),
                    ],
                  ),
                  if (_isFutureEvent)
                    Container(
                      padding: const EdgeInsets.all(10),
                      decoration: BoxDecoration(
                        color: orange.withValues(alpha: .1),
                        borderRadius: BorderRadius.circular(8),
                      ),
                      child: Row(
                        children: [
                          Icon(
                            Icons.info_outline,
                            size: IosText.caption + 2,
                            color: orange,
                          ),
                          const SizedBox(width: 6),
                          Expanded(
                            child: Text(
                              lang.translate('journey_record_after_parana'),
                              style: TextStyle(
                                fontSize: IosText.caption,
                                color: orange,
                              ),
                            ),
                          ),
                        ],
                      ),
                    ),
                  _label(lang.translate('status_active')),
                  // Natural-width chips spread across the row, wrapping
                  // only when they do not fit (large text).
                  Wrap(
                    key: const Key('vrat_record_status_tube'),
                    alignment: WrapAlignment.spaceBetween,
                    spacing: 8,
                    runSpacing: 8,
                    children: [
                      _buildStatusChip(
                        ObservanceStatus.observed,
                        lang.translate('observed'),
                        Icons.check_circle_outline,
                      ),
                      _buildStatusChip(
                        ObservanceStatus.partial,
                        lang.translate('partial'),
                        Icons.adjust,
                      ),
                      _buildStatusChip(
                        ObservanceStatus.missed,
                        lang.translate('missed'),
                        Icons.highlight_off,
                      ),
                    ],
                  ),
                  if (fasting) ...[
                    _label(lang.translate('fasting_method')),
                    Wrap(
                      key: const Key('vrat_fasting_method_tube'),
                      spacing: 8,
                      runSpacing: 8,
                      children: [
                        for (final (method, key) in const [
                          (FastingMethod.fullFast, 'method_full_fast'),
                          (FastingMethod.waterOnly, 'method_water_only'),
                          (FastingMethod.fruitsMilk, 'method_fruits_milk'),
                          (FastingMethod.oneMeal, 'method_one_meal'),
                          (FastingMethod.other, 'method_other'),
                        ])
                          GlassChip(
                            key: Key('vrat_method_${method.name}'),
                            label: lang.translate(key),
                            selected: _fastingMethod == method,
                            onTap: () =>
                                setState(() => _fastingMethod = method),
                          ),
                      ],
                    ),
                    if (_fastingMethod == FastingMethod.other)
                      TextField(
                        controller: _otherMethodController,
                        decoration: field('method_other_hint'),
                      ),
                  ],
                  _label(lang.translate('notes')),
                  TextField(
                    key: const Key('vrat_record_notes'),
                    controller: _noteController,
                    minLines: 3,
                    maxLines: 5,
                    decoration: field('notes_hint'),
                  ),
                  FilledButton(
                    key: const Key('vrat_record_save'),
                    onPressed: _saving ? null : _save,
                    style: IosButtons.prominent(),
                    child: Text(
                      _existingRecord != null
                          ? lang.translate('edit_record')
                          : lang.translate('record_observance'),
                      textAlign: TextAlign.center,
                      style: IosButtons.label,
                    ),
                  ),
                ],
              ),
            ),
          ),
        ],
      ),
    );
  }

  /// A section label: footnote, semibold, teal.
  Widget _label(String text) => Text(
    text,
    style: const TextStyle(
      fontSize: IosText.footnote,
      fontWeight: FontWeight.w600,
      color: IosColors.teal,
    ),
  );

  /// A status chip in the status's colour, with its symbol inline.
  Widget _buildStatusChip(
    ObservanceStatus status,
    String label,
    IconData icon,
  ) => GlassChip(
    key: Key('vrat_status_${status.name}'),
    label: label,
    icon: icon,
    color: vratStatusColor(context, status),
    selected: _status == status,
    onTap: () => _onStatusChanged(status),
  );
}

/// The colour of an observance status (iOS VratStatusStyle.color).
Color vratStatusColor(BuildContext context, ObservanceStatus? status) =>
    switch (status ?? ObservanceStatus.unrecorded) {
      ObservanceStatus.observed => IosColors.green(context),
      ObservanceStatus.partial => IosColors.partial,
      ObservanceStatus.missed => IosColors.missed,
      ObservanceStatus.unrecorded => IosColors.gray(context),
    };
