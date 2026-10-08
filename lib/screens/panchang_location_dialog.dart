import 'package:flutter/material.dart';
import 'package:flutter_timezone/flutter_timezone.dart';
import 'package:provider/provider.dart';
import '../l10n/app_language.dart';
import '../services/language_service.dart';
import '../services/native_location_service.dart';
import '../services/panchang/panchang_city.dart';
import '../services/panchang/panchang_location_store.dart';

class PanchangLocationDialog extends StatefulWidget {
  const PanchangLocationDialog({super.key, required this.city});
  final PanchangCity city;
  @override
  State<PanchangLocationDialog> createState() => _PanchangLocationDialogState();
}

class _PanchangLocationDialogState extends State<PanchangLocationDialog> {
  final _form = GlobalKey<FormState>();
  late final _name = TextEditingController(text: widget.city.label);
  late final _lat = TextEditingController(text: '${widget.city.latitude}');
  late final _lon = TextEditingController(text: '${widget.city.longitude}');
  late final _zone = TextEditingController(text: widget.city.timeZoneId);
  List<PanchangCity> _catalog = [];
  List<PanchangCity> _matches = [];
  bool _busy = false;
  String? _message;

  @override
  void initState() {
    super.initState();
    _loadCatalog();
  }

  Future<void> _loadCatalog() async {
    try {
      final cities = await PanchangLocationStore.cities();
      if (mounted) setState(() => _catalog = cities);
    } catch (_) {
      if (mounted) {
        setState(() => _message = _t('panchang_city_search_unavailable'));
      }
    }
  }

  @override
  void dispose() {
    for (final controller in [_name, _lat, _lon, _zone]) {
      controller.dispose();
    }
    super.dispose();
  }

  void _select(PanchangCity city) {
    setState(() {
      _name.text = city.label;
      _lat.text = '${city.latitude}';
      _lon.text = '${city.longitude}';
      _zone.text = city.timeZoneId;
      _matches = [];
    });
  }

  Future<void> _gps() async {
    setState(() {
      _busy = true;
      _message = null;
    });
    try {
      final service = NativeLocationService();
      final granted =
          await service.hasLocationPermission() ||
          await service.requestLocationPermission();
      if (!granted) {
        throw StateError(_t('panchang_location_denied'));
      }
      final data = await service.getCurrentLocation();
      if (data == null) {
        throw StateError(_t('panchang_location_unavailable'));
      }
      // The legacy service only returns coarse US/India timezone groups.
      // Use the device IANA zone as a suggestion, visibly requiring review.
      String? zone;
      try {
        zone = await FlutterTimezone.getLocalTimezone().timeout(
          const Duration(seconds: 3),
        );
      } catch (_) {}
      if (!mounted) return;
      _name.text = data.city;
      _lat.text = '${data.latitude}';
      _lon.text = '${data.longitude}';
      _zone.text = zone ?? '';
      setState(() => _message = _t('panchang_location_received'));
    } catch (e) {
      if (mounted) {
        setState(() => _message = e.toString().replaceFirst('Bad state: ', ''));
      }
    } finally {
      if (mounted) setState(() => _busy = false);
    }
  }

  @override
  Widget build(BuildContext context) => AlertDialog(
    title: Text(_t('panchang_location_title')),
    content: SizedBox(
      width: 420,
      child: SingleChildScrollView(
        child: Form(
          key: _form,
          child: Column(
            mainAxisSize: MainAxisSize.min,
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              TextField(
                key: const Key('location_search'),
                decoration: InputDecoration(
                  labelText: _t('panchang_search_cities'),
                  prefixIcon: const Icon(Icons.search),
                ),
                onChanged: (value) {
                  final q = value.trim().toLowerCase();
                  setState(
                    () => _matches = q.length < 2
                        ? []
                        : _catalog
                              .where(
                                (c) =>
                                    '${c.label.toLowerCase()} ${c.searchTerms}'
                                        .contains(q),
                              )
                              .take(12)
                              .toList(),
                  );
                },
              ),
              for (final city in _matches)
                ListTile(
                  dense: true,
                  title: Text(city.label),
                  subtitle: Text(city.timeZoneId),
                  onTap: () => _select(city),
                ),
              TextButton.icon(
                onPressed: _busy ? null : _gps,
                icon: const Icon(Icons.my_location),
                label: Text(
                  _t(
                    _busy
                        ? 'panchang_locating'
                        : 'panchang_use_current_location',
                  ),
                ),
              ),
              if (_message != null)
                Text(_message!, style: Theme.of(context).textTheme.bodySmall),
              TextFormField(
                key: const Key('location_name'),
                controller: _name,
                decoration: InputDecoration(
                  labelText: _t('panchang_location_name'),
                ),
                validator: (v) => v == null || v.trim().isEmpty
                    ? _t('panchang_enter_name')
                    : null,
              ),
              TextFormField(
                key: const Key('location_latitude'),
                controller: _lat,
                decoration: InputDecoration(labelText: _t('panchang_latitude')),
                keyboardType: const TextInputType.numberWithOptions(
                  decimal: true,
                  signed: true,
                ),
                validator: (v) => _coordinate(v, 90),
              ),
              TextFormField(
                key: const Key('location_longitude'),
                controller: _lon,
                decoration: InputDecoration(
                  labelText: _t('panchang_longitude'),
                ),
                keyboardType: const TextInputType.numberWithOptions(
                  decimal: true,
                  signed: true,
                ),
                validator: (v) => _coordinate(v, 180),
              ),
              TextFormField(
                key: const Key('location_timezone'),
                controller: _zone,
                decoration: InputDecoration(labelText: _t('panchang_timezone')),
                validator: (v) {
                  try {
                    PanchangCity(
                      id: '',
                      label: 'Zone',
                      latitude: 0,
                      longitude: 0,
                      timeZoneId: v?.trim() ?? '',
                    ).zone;
                    return null;
                  } catch (_) {
                    return _t('panchang_invalid_timezone');
                  }
                },
              ),
              const SizedBox(height: 12),
              Text(
                _t('panchang_location_footer'),
                style: const TextStyle(fontSize: 12),
              ),
            ],
          ),
        ),
      ),
    ),
    actions: [
      TextButton(
        onPressed: () => Navigator.pop(context),
        child: Text(_t('cancel')),
      ),
      FilledButton(
        onPressed: _busy
            ? null
            : () {
                if (!_form.currentState!.validate()) return;
                Navigator.pop(
                  context,
                  PanchangCity(
                    id: 'custom',
                    label: _name.text.trim(),
                    latitude: double.parse(_lat.text),
                    longitude: double.parse(_lon.text),
                    timeZoneId: _zone.text.trim(),
                  ),
                );
              },
        key: const Key('location_save'),
        child: Text(_t('panchang_save_location')),
      ),
    ],
  );

  String? _coordinate(String? value, int limit) {
    final number = double.tryParse(value ?? '');
    return number == null || !number.isFinite || number.abs() > limit
        ? AppStrings.translateWithArgs(
            'panchang_invalid_coordinate',
            _language,
            ['$limit'],
          )
        : null;
  }

  String get _language =>
      context.read<LanguageService>().currentLocale.languageCode;

  String _t(String key) => AppStrings.translate(key, _language);
}
