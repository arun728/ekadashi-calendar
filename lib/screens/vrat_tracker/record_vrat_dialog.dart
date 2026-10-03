import 'package:flutter/material.dart';
import 'package:intl/intl.dart';
import 'package:provider/provider.dart';
import '../../models/vrat_tracker_models.dart';
import '../../services/ekadashi_service.dart';
import '../../services/language_service.dart';
import '../../services/vrat_tracker_service.dart';

/// Modal bottom sheet for recording, editing, or deleting an Ekadashi observance.
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
    return showModalBottomSheet<List<Achievement>>(
      context: context,
      isScrollControlled: true,
      backgroundColor: Colors.transparent,
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
  static const Color tealColor = Color(0xFF00A19B);

  late ObservanceStatus _status;
  FastingMethod? _fastingMethod;
  late TextEditingController _otherMethodController;
  late TextEditingController _noteController;
  bool _isFutureEvent = false;
  VratHistory? _existingRecord;

  @override
  void initState() {
    super.initState();
    final tracker = Provider.of<VratTrackerService>(context, listen: false);
    _existingRecord = tracker.getRecord(widget.ekadashi.id);

    final today = DateTime(
      DateTime.now().year,
      DateTime.now().month,
      DateTime.now().day,
    );
    final eventDate = DateTime(
      widget.ekadashi.date.year,
      widget.ekadashi.date.month,
      widget.ekadashi.date.day,
    );
    _isFutureEvent = eventDate.isAfter(today);

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
      final lang = Provider.of<LanguageService>(context, listen: false);
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text(lang.translate('cannot_record_future')),
          backgroundColor: Colors.orange.shade800,
          duration: const Duration(seconds: 2),
        ),
      );
      return;
    }
    setState(() {
      _status = newStatus;
    });
  }

  Future<void> _save() async {
    if (_isFutureEvent) {
      final lang = Provider.of<LanguageService>(context, listen: false);
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text(lang.translate('cannot_record_future')),
          backgroundColor: Colors.orange.shade800,
        ),
      );
      return;
    }

    final tracker = Provider.of<VratTrackerService>(context, listen: false);
    final dateStr = DateFormat('yyyy-MM-dd').format(widget.ekadashi.date);

    final newlyUnlocked = await tracker.recordVrat(
      ekadashiOccurrenceId: widget.ekadashi.id,
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
            style: TextButton.styleFrom(foregroundColor: Colors.red),
            child: Text(lang.translate('delete_record')),
          ),
        ],
      ),
    );

    if (confirmed == true && mounted) {
      final tracker = Provider.of<VratTrackerService>(context, listen: false);
      await tracker.deleteVrat(
        ekadashiOccurrenceId: widget.ekadashi.id,
        occurrences: widget.allOccurrences,
      );
      if (mounted) {
        Navigator.of(context).pop(<Achievement>[]);
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    final lang = Provider.of<LanguageService>(context);
    final isDark = Theme.of(context).brightness == Brightness.dark;
    final formattedDate = DateFormat(
      'EEEE, d MMMM yyyy',
    ).format(widget.ekadashi.date);

    return Container(
      decoration: BoxDecoration(
        color: Theme.of(context).cardColor,
        borderRadius: const BorderRadius.vertical(top: Radius.circular(24)),
      ),
      padding: EdgeInsets.only(
        top: 20,
        left: 20,
        right: 20,
        bottom: MediaQuery.of(context).viewInsets.bottom + 24,
      ),
      child: SingleChildScrollView(
        child: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            // Handle bar
            Center(
              child: Container(
                width: 40,
                height: 4,
                margin: const EdgeInsets.only(bottom: 16),
                decoration: BoxDecoration(
                  color: Colors.grey.withValues(alpha: 0.3),
                  borderRadius: BorderRadius.circular(2),
                ),
              ),
            ),

            // Header: Name & Date
            Row(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        widget.ekadashi.name,
                        style: const TextStyle(
                          fontSize: 20,
                          fontWeight: FontWeight.bold,
                        ),
                      ),
                      const SizedBox(height: 4),
                      Text(
                        formattedDate,
                        style: TextStyle(
                          fontSize: 13,
                          color: isDark
                              ? Colors.grey.shade400
                              : Colors.grey.shade700,
                        ),
                      ),
                    ],
                  ),
                ),
                if (_existingRecord != null)
                  IconButton(
                    icon: const Icon(
                      Icons.delete_outline,
                      color: Colors.redAccent,
                    ),
                    tooltip: lang.translate('delete_record'),
                    onPressed: _delete,
                  ),
              ],
            ),
            const SizedBox(height: 20),

            // Future warning if applicable
            if (_isFutureEvent) ...[
              Container(
                padding: const EdgeInsets.all(10),
                decoration: BoxDecoration(
                  color: Colors.orange.withValues(alpha: 0.1),
                  borderRadius: BorderRadius.circular(8),
                  border: Border.all(
                    color: Colors.orange.withValues(alpha: 0.3),
                  ),
                ),
                child: Row(
                  children: [
                    const Icon(
                      Icons.info_outline,
                      size: 16,
                      color: Colors.orange,
                    ),
                    const SizedBox(width: 8),
                    Expanded(
                      child: Text(
                        lang.translate('cannot_record_future'),
                        style: const TextStyle(
                          fontSize: 12,
                          color: Colors.orange,
                        ),
                      ),
                    ),
                  ],
                ),
              ),
              const SizedBox(height: 16),
            ],

            // Status Selector Chips
            Text(
              lang.translate('status_active'),
              style: const TextStyle(
                fontSize: 13,
                fontWeight: FontWeight.w600,
                color: tealColor,
              ),
            ),
            const SizedBox(height: 8),
            Row(
              children: [
                _buildStatusChip(
                  ObservanceStatus.observed,
                  lang.translate('observed'),
                  Icons.check_circle_outline,
                  Colors.green,
                ),
                const SizedBox(width: 8),
                _buildStatusChip(
                  ObservanceStatus.partial,
                  lang.translate('partial'),
                  Icons.adjust,
                  Colors.amber.shade700,
                ),
                const SizedBox(width: 8),
                _buildStatusChip(
                  ObservanceStatus.missed,
                  lang.translate('missed'),
                  Icons.highlight_off,
                  Colors.red.shade400,
                ),
              ],
            ),
            const SizedBox(height: 20),

            // Fasting Method (if Observed or Partial)
            if (_status == ObservanceStatus.observed ||
                _status == ObservanceStatus.partial) ...[
              Text(
                lang.translate('fasting_method'),
                style: const TextStyle(
                  fontSize: 13,
                  fontWeight: FontWeight.w600,
                  color: tealColor,
                ),
              ),
              const SizedBox(height: 8),
              Wrap(
                spacing: 8,
                runSpacing: 8,
                children: [
                  _buildMethodChip(
                    FastingMethod.fullFast,
                    lang.translate('method_full_fast'),
                  ),
                  _buildMethodChip(
                    FastingMethod.waterOnly,
                    lang.translate('method_water_only'),
                  ),
                  _buildMethodChip(
                    FastingMethod.fruitsMilk,
                    lang.translate('method_fruits_milk'),
                  ),
                  _buildMethodChip(
                    FastingMethod.oneMeal,
                    lang.translate('method_one_meal'),
                  ),
                  _buildMethodChip(
                    FastingMethod.other,
                    lang.translate('method_other'),
                  ),
                ],
              ),
              if (_fastingMethod == FastingMethod.other) ...[
                const SizedBox(height: 10),
                TextField(
                  controller: _otherMethodController,
                  decoration: InputDecoration(
                    hintText: lang.translate('method_other_hint'),
                    contentPadding: const EdgeInsets.symmetric(
                      horizontal: 12,
                      vertical: 10,
                    ),
                    border: OutlineInputBorder(
                      borderRadius: BorderRadius.circular(8),
                    ),
                  ),
                ),
              ],
              const SizedBox(height: 20),
            ],

            // Personal Notes Field
            Text(
              lang.translate('notes'),
              style: const TextStyle(
                fontSize: 13,
                fontWeight: FontWeight.w600,
                color: tealColor,
              ),
            ),
            const SizedBox(height: 8),
            TextField(
              controller: _noteController,
              maxLines: 3,
              decoration: InputDecoration(
                hintText: lang.translate('notes_hint'),
                contentPadding: const EdgeInsets.all(12),
                border: OutlineInputBorder(
                  borderRadius: BorderRadius.circular(8),
                ),
              ),
            ),
            const SizedBox(height: 24),

            // Save / Record button
            ElevatedButton(
              onPressed: _save,
              style: ElevatedButton.styleFrom(
                backgroundColor: tealColor,
                foregroundColor: Colors.white,
                padding: const EdgeInsets.symmetric(vertical: 14),
                shape: RoundedRectangleBorder(
                  borderRadius: BorderRadius.circular(12),
                ),
              ),
              child: Text(
                _existingRecord != null
                    ? lang.translate('edit_record')
                    : lang.translate('record_observance'),
                style: const TextStyle(
                  fontSize: 16,
                  fontWeight: FontWeight.bold,
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildStatusChip(
    ObservanceStatus status,
    String label,
    IconData icon,
    Color activeColor,
  ) {
    final isSelected = _status == status;
    return Expanded(
      child: InkWell(
        onTap: () => _onStatusChanged(status),
        borderRadius: BorderRadius.circular(10),
        child: Container(
          padding: const EdgeInsets.symmetric(vertical: 10),
          decoration: BoxDecoration(
            color: isSelected
                ? activeColor.withValues(alpha: 0.15)
                : Colors.grey.withValues(alpha: 0.08),
            borderRadius: BorderRadius.circular(10),
            border: Border.all(
              color: isSelected
                  ? activeColor
                  : Colors.grey.withValues(alpha: 0.2),
              width: isSelected ? 1.8 : 1,
            ),
          ),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              Icon(
                icon,
                size: 20,
                color: isSelected ? activeColor : Colors.grey,
              ),
              const SizedBox(height: 4),
              Text(
                label,
                style: TextStyle(
                  fontSize: 12,
                  fontWeight: isSelected ? FontWeight.bold : FontWeight.normal,
                  color: isSelected ? activeColor : Colors.grey.shade600,
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }

  Widget _buildMethodChip(FastingMethod method, String label) {
    final isSelected = _fastingMethod == method;
    return ChoiceChip(
      label: Text(label),
      selected: isSelected,
      selectedColor: tealColor.withValues(alpha: 0.2),
      labelStyle: TextStyle(
        fontSize: 12,
        fontWeight: isSelected ? FontWeight.bold : FontWeight.normal,
        color: isSelected ? tealColor : null,
      ),
      onSelected: (_) {
        setState(() {
          _fastingMethod = method;
        });
      },
    );
  }
}
