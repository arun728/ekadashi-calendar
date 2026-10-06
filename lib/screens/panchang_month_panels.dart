import 'package:flutter/foundation.dart';
import 'package:flutter/material.dart';
import '../services/panchang/calculated_ekadashi.dart';
import '../services/panchang/panchang_city.dart';
import '../services/panchang/panchang_models.dart';

typedef _MonthRequest = ({
  DateTime date,
  PanchangCity city,
  EkadashiTradition tradition,
});

List<CalculatedEkadashi> _calculateFasts(_MonthRequest request) =>
    const CalculatedEkadashiEngine().calculate(
      DateTime.utc(request.date.year, request.date.month),
      DateTime.utc(request.date.year, request.date.month + 1, 0).day,
      request.city,
      request.tradition,
    );

class PanchangEkadashiPanel extends StatefulWidget {
  const PanchangEkadashiPanel({
    super.key,
    required this.date,
    required this.city,
    required this.tradition,
    required this.onTraditionChanged,
  });
  final DateTime date;
  final PanchangCity city;
  final EkadashiTradition tradition;
  final ValueChanged<EkadashiTradition> onTraditionChanged;
  @override
  State<PanchangEkadashiPanel> createState() => _PanchangEkadashiPanelState();
}

class _PanchangEkadashiPanelState extends State<PanchangEkadashiPanel> {
  EkadashiTradition get _tradition => widget.tradition;
  late Future<List<CalculatedEkadashi>> _future;
  @override
  void initState() {
    super.initState();
    _load();
  }

  @override
  void didUpdateWidget(covariant PanchangEkadashiPanel oldWidget) {
    super.didUpdateWidget(oldWidget);
    if (oldWidget.tradition != widget.tradition ||
        oldWidget.city != widget.city ||
        oldWidget.date.month != widget.date.month ||
        oldWidget.date.year != widget.date.year) {
      _load();
    }
  }

  void _load() {
    _future = compute(_calculateFasts, (
      date: widget.date,
      city: widget.city,
      tradition: _tradition,
    ));
  }

  @override
  Widget build(BuildContext context) => Column(
    crossAxisAlignment: CrossAxisAlignment.start,
    children: [
      Text(
        'Calculated Ekadashi',
        style: Theme.of(context).textTheme.titleLarge,
      ),
      const SizedBox(height: 8),
      Wrap(
        spacing: 8,
        children: [
          for (final tradition in EkadashiTradition.values)
            ChoiceChip(
              label: Text(tradition.label),
              selected: _tradition == tradition,
              onSelected: (_) => widget.onTraditionChanged(tradition),
            ),
        ],
      ),
      const SizedBox(height: 8),
      Text(
        _tradition == EkadashiTradition.smarta
            ? 'Smarta householders: sunrise tithi, first day when Ekadashi repeats.'
            : 'Gaudiya/ISKCON: Arunodaya 96 minutes before local sunrise, with Mahadvadashi rules.',
      ),
      const SizedBox(height: 8),
      const Text(
        'Calculation preview. Existing calendar dates and reminders still use the published schedule while these results are validated.',
      ),
      const SizedBox(height: 16),
      FutureBuilder<List<CalculatedEkadashi>>(
        future: _future,
        builder: (context, snapshot) {
          if (snapshot.hasError) {
            return _retry(
              'Could not calculate this month.',
              () => setState(_load),
            );
          }
          if (snapshot.connectionState != ConnectionState.done) {
            return const Center(child: CircularProgressIndicator());
          }
          final fasts = snapshot.data!;
          if (fasts.isEmpty) {
            return const Text(
              'No calculated fast is available for this month/location. A valid local sunrise is required.',
            );
          }
          return Column(
            children: [
              for (final fast in fasts)
                Card(
                  child: Padding(
                    padding: const EdgeInsets.all(16),
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text(
                          fast.name,
                          style: Theme.of(context).textTheme.titleMedium,
                        ),
                        Text(
                          'Fast · ${_date(fast.date)}',
                          style: const TextStyle(fontWeight: FontWeight.bold),
                        ),
                        Text(
                          'Starts at ${formatPanchangTime(fast.fastStartsUtc, widget.city, fast.date)}',
                        ),
                        const SizedBox(height: 8),
                        Text(
                          'Parana · ${_date(fast.paranaDate)}',
                          style: const TextStyle(fontWeight: FontWeight.bold),
                        ),
                        Text(
                          fast.paranaStartUtc == null
                              ? 'Unavailable'
                              : '${fast.paranaEndUtc == null ? 'After ' : ''}${formatPanchangTime(fast.paranaStartUtc, widget.city, fast.paranaDate)}${fast.paranaEndUtc == null ? '' : ' – ${formatPanchangTime(fast.paranaEndUtc, widget.city, fast.paranaDate)}'}',
                        ),
                        const SizedBox(height: 8),
                        Text('Rule · ${fast.rule}'),
                        Text(fast.paranaReason),
                        if (fast.nearBoundary)
                          const Text(
                            'A limb transition is within five minutes of a decision boundary. Verify this date with your tradition’s calendar.',
                          ),
                        ExpansionTile(
                          tilePadding: EdgeInsets.zero,
                          title: const Text('Calculation details'),
                          children: [
                            Text(
                              'Ekadashi tithi: ${formatPanchangTime(fast.tithiStartUtc, widget.city, fast.date)} – ${formatPanchangTime(fast.tithiEndUtc, widget.city, fast.date)}',
                            ),
                            Text(
                              'Hari Vasara ends: ${formatPanchangTime(fast.hariVasaraEndUtc, widget.city, fast.paranaDate)}',
                            ),
                            const Text(
                              'Current-location apparent sunrise · Lahiri sidereal model · ${CalculatedEkadashi.ruleVersion}',
                            ),
                          ],
                        ),
                      ],
                    ),
                  ),
                ),
            ],
          );
        },
      ),
    ],
  );
}

Widget _retry(String message, VoidCallback action) => Column(
  children: [
    Text(message),
    TextButton(onPressed: action, child: const Text('Retry')),
  ],
);
String _date(DateTime date) =>
    '${date.year}-${date.month.toString().padLeft(2, '0')}-${date.day.toString().padLeft(2, '0')}';
