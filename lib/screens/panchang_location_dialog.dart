import 'package:flutter/material.dart';
import 'package:flutter_timezone/flutter_timezone.dart';
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
        setState(
          () => _message = 'City search unavailable. Enter coordinates below.',
        );
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
        throw StateError(
          'Location permission denied. Search or enter a location instead.',
        );
      }
      final data = await service.getCurrentLocation();
      if (data == null) {
        throw StateError(
          'Location unavailable. Search or enter a location instead.',
        );
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
      setState(
        () => _message =
            'Coordinates received. Check the timezone before saving; the device timezone may differ from this location.',
      );
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
    title: const Text('Panchang location'),
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
                decoration: const InputDecoration(
                  labelText: 'Search cities worldwide',
                  prefixIcon: Icon(Icons.search),
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
                label: Text(_busy ? 'Locating…' : 'Use current location'),
              ),
              if (_message != null)
                Text(_message!, style: Theme.of(context).textTheme.bodySmall),
              TextFormField(
                key: const Key('location_name'),
                controller: _name,
                decoration: const InputDecoration(labelText: 'Location name'),
                validator: (v) =>
                    v == null || v.trim().isEmpty ? 'Enter a name' : null,
              ),
              TextFormField(
                key: const Key('location_latitude'),
                controller: _lat,
                decoration: const InputDecoration(labelText: 'Latitude'),
                keyboardType: const TextInputType.numberWithOptions(
                  decimal: true,
                  signed: true,
                ),
                validator: (v) => _coordinate(v, 90, 'latitude'),
              ),
              TextFormField(
                key: const Key('location_longitude'),
                controller: _lon,
                decoration: const InputDecoration(labelText: 'Longitude'),
                keyboardType: const TextInputType.numberWithOptions(
                  decimal: true,
                  signed: true,
                ),
                validator: (v) => _coordinate(v, 180, 'longitude'),
              ),
              TextFormField(
                key: const Key('location_timezone'),
                controller: _zone,
                decoration: const InputDecoration(
                  labelText: 'IANA timezone',
                  helperText: 'Example: Asia/Kolkata or America/New_York',
                ),
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
                    return 'Enter a valid IANA timezone';
                  }
                },
              ),
              const SizedBox(height: 12),
              const Text(
                'City data: GeoNames · CC BY 4.0. Calculations and city search work offline.',
                style: TextStyle(fontSize: 12),
              ),
            ],
          ),
        ),
      ),
    ),
    actions: [
      TextButton(
        onPressed: () => Navigator.pop(context),
        child: const Text('Cancel'),
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
        child: const Text('Save location'),
      ),
    ],
  );

  String? _coordinate(String? value, int limit, String name) {
    final number = double.tryParse(value ?? '');
    return number == null || !number.isFinite || number.abs() > limit
        ? 'Enter a $name from -$limit to $limit'
        : null;
  }
}
