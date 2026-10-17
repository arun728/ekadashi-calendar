import 'dart:async';
import 'dart:math' as math;
import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import '../services/ekadashi_service.dart';
import '../services/language_service.dart';
import '../services/native_widget_service.dart';
import '../services/widget_sync_manager.dart';
import '../widgets/native_widget_preview.dart';

enum WidgetPreviewKind { ekadashi, upcoming }

enum WidgetPreviewSize { small, medium, large, lock }

/// The actual native Android cards, using Home's real schedule and current clock.
class WidgetPreviewScreen extends StatefulWidget {
  const WidgetPreviewScreen({
    super.key,
    required this.ekadashiList,
    this.currentTimezone,
    this.locationName = '',
    this.tradition = 'smarta',
    this.now,
    this.onOpenOccurrence,
  });
  final List<EkadashiDate> ekadashiList;
  final String? currentTimezone;
  final String locationName, tradition;
  final DateTime? now;
  final ValueChanged<String>? onOpenOccurrence;
  @override
  State<WidgetPreviewScreen> createState() => _WidgetPreviewScreenState();
}

class _WidgetPreviewScreenState extends State<WidgetPreviewScreen> {
  WidgetPreviewKind _kind = WidgetPreviewKind.ekadashi;
  WidgetPreviewSize _size = WidgetPreviewSize.medium;
  Timer? _timer;
  @override
  void initState() {
    super.initState();
    if (widget.now == null) {
      _timer = Timer.periodic(const Duration(minutes: 1), (_) {
        if (mounted) setState(() {});
      });
    }
  }

  @override
  void dispose() {
    _timer?.cancel();
    super.dispose();
  }

  List<WidgetPreviewSize> get _sizes => _kind == WidgetPreviewKind.ekadashi
      ? [
          WidgetPreviewSize.small,
          WidgetPreviewSize.medium,
          WidgetPreviewSize.lock,
        ]
      : [
          WidgetPreviewSize.medium,
          WidgetPreviewSize.large,
          WidgetPreviewSize.lock,
        ];

  @override
  Widget build(BuildContext context) {
    final lang = context.watch<LanguageService>();
    final now = widget.now ?? DateTime.now();
    final payload = WidgetSyncManager().buildPayload(
      ekadashiList: widget.ekadashiList,
      timezone: widget.currentTimezone ?? 'Asia/Kolkata',
      locationName: widget.locationName,
      languageService: lang,
      tradition: widget.tradition,
      now: now,
    );
    return Scaffold(
      appBar: AppBar(
        title: Text(lang.translate('widget_preview')),
        leading: BackButton(onPressed: () => Navigator.pop(context)),
      ),
      body: SingleChildScrollView(
        padding: const EdgeInsets.all(16),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            _choices<WidgetPreviewKind>(
              key: const Key('widget_preview_kind'),
              values: WidgetPreviewKind.values,
              selected: _kind,
              label: (kind) => lang.translate(
                kind == WidgetPreviewKind.ekadashi
                    ? 'widget_name_ekadashi'
                    : 'upcoming_ekadashis',
              ),
              onSelect: (kind) => setState(() {
                _kind = kind;
                if (!_sizes.contains(_size)) _size = WidgetPreviewSize.medium;
              }),
            ),
            const SizedBox(height: 16),
            Text(
              lang.translate(
                _kind == WidgetPreviewKind.ekadashi
                    ? 'widget_desc_ekadashi'
                    : 'widget_desc_upcoming',
              ),
            ),
            const SizedBox(height: 16),
            _choices<WidgetPreviewSize>(
              key: const Key('widget_preview_size'),
              values: _sizes,
              selected: _size,
              label: (size) => lang.translate('widget_size_${size.name}'),
              onSelect: (size) => setState(() => _size = size),
            ),
            if (_size == WidgetPreviewSize.lock) ...[
              const SizedBox(height: 16),
              Text(lang.translate('widget_lock_support')),
            ],
            const SizedBox(height: 20),
            LayoutBuilder(
              builder: (context, constraints) {
                final width = math.min(
                  constraints.maxWidth,
                  _size == WidgetPreviewSize.small ? 158.0 : 360.0,
                );
                final height = switch (_size) {
                  WidgetPreviewSize.small => 158.0,
                  WidgetPreviewSize.medium => 170.0,
                  WidgetPreviewSize.large => 340.0,
                  WidgetPreviewSize.lock => 240.0,
                };
                return Center(
                  child: NativeWidgetPreview(
                    key: ValueKey(
                      _kind == WidgetPreviewKind.ekadashi
                          ? 'card_ekadashi'
                          : 'card_upcoming_ekadashi',
                    ),
                    payload: payload,
                    upcoming: _kind == WidgetPreviewKind.upcoming,
                    width: width,
                    height: height,
                    now: now,
                    onOpenOccurrence:
                        widget.onOpenOccurrence ??
                        NativeWidgetService().openOccurrence,
                  ),
                );
              },
            ),
            const SizedBox(height: 20),
            Text(
              lang.translate('widget_preview_tap'),
              textAlign: TextAlign.center,
            ),
          ],
        ),
      ),
    );
  }

  Widget _choices<T>({
    required Key key,
    required List<T> values,
    required T selected,
    required String Function(T) label,
    required ValueChanged<T> onSelect,
  }) => Container(
    key: key,
    padding: const EdgeInsets.all(4),
    decoration: BoxDecoration(
      color: Theme.of(context).colorScheme.surfaceContainerHighest,
      borderRadius: BorderRadius.circular(24),
    ),
    child: Row(
      children: [
        for (final value in values)
          Expanded(
            child: Semantics(
              selected: value == selected,
              button: true,
              child: TextButton(
                onPressed: () => onSelect(value),
                style: TextButton.styleFrom(
                  backgroundColor: value == selected
                      ? Theme.of(context).colorScheme.secondaryContainer
                      : Colors.transparent,
                  padding: const EdgeInsets.symmetric(
                    horizontal: 6,
                    vertical: 12,
                  ),
                ),
                child: FittedBox(
                  fit: BoxFit.scaleDown,
                  child: Text(label(value), maxLines: 1),
                ),
              ),
            ),
          ),
      ],
    ),
  );
}
