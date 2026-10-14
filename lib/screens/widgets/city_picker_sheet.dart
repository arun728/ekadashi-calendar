import 'package:flutter/material.dart';
import 'package:provider/provider.dart';

import '../../l10n/app_language.dart';
import '../../services/language_service.dart';
import '../../services/panchang/panchang_city.dart';
import '../../services/panchang/city_search_index.dart';
import '../../services/panchang/panchang_location_store.dart';
import '../../services/place_name_resolver.dart';
import '../../widgets/ios_style.dart';
import '../../widgets/app_icons.dart';

/// The one city picker of the app (Home and every Panchang sub-tab, as
/// CityPickerSheet on iOS): the current place, a worldwide search, "Use
/// current location", then recent picks and popular cities, every city with
/// its time zone ("IST", "EDT", "GMT"…). [extra] adds screen-specific
/// sections at the end.
Future<void> showCityPicker(
  BuildContext context, {
  required String title,
  required String footer,
  required PanchangCity current,
  required IconData icon,
  required Future<void> Function(PanchangCity city) onPick,

  /// Uses the device location; null when done, else the message key to show.
  required Future<String?> Function() onLocate,
  Widget? extra,
}) => showAppSheet<void>(
  context,
  // An iOS sheet over the whole app, not a page in the tab's stack.
  builder: (_) => CityPickerSheet(
    title: title,
    footer: footer,
    current: current,
    icon: icon,
    onPick: onPick,
    onLocate: onLocate,
    extra: extra,
  ),
);

class CityPickerSheet extends StatefulWidget {
  const CityPickerSheet({
    super.key,
    required this.title,
    required this.footer,
    required this.current,
    required this.icon,
    required this.onPick,
    required this.onLocate,
    this.extra,
  });

  final String title;
  final String footer;
  final PanchangCity current;
  final IconData icon;
  final Future<void> Function(PanchangCity city) onPick;
  final Future<String?> Function() onLocate;
  final Widget? extra;

  @override
  State<CityPickerSheet> createState() => _CityPickerSheetState();
}

class _CityPickerSheetState extends State<CityPickerSheet> {
  final _search = TextEditingController();
  List<PanchangCity> _matches = [];
  List<PanchangCity> _recent = [];
  List<PanchangCity> _popular = [];
  bool _busy = false;
  String? _message;

  String get _language =>
      context.read<LanguageService>().currentLocale.languageCode;
  String _t(String key) => AppStrings.translate(key, _language);

  @override
  void initState() {
    super.initState();
    PlaceNameResolver.instance.addListener(_namesChanged);
    // Prepares the names in the app language while the sheet opens.
    WidgetsBinding.instance.addPostFrameCallback((_) {
      if (mounted) PanchangLocationStore.searchIndex(_language).ignore();
    });
    RecentCities.shortlist().then((list) {
      if (mounted) {
        setState(() {
          _recent = list.recent;
          _popular = list.popular;
        });
      }
    });
  }

  void _namesChanged() {
    if (mounted) setState(() {});
  }

  @override
  void dispose() {
    PlaceNameResolver.instance.removeListener(_namesChanged);
    _search.dispose();
    super.dispose();
  }

  /// Searches the language's prepared index (built in the background when
  /// the sheet opens), keeping only the answer for the text still typed.
  Future<void> _query(String value) async {
    if (CitySearchIndex.query(value) == null) {
      if (_matches.isNotEmpty) setState(() => _matches = []);
      return;
    }
    final index = await PanchangLocationStore.searchIndex(_language);
    if (!mounted || value != _search.text) return;
    setState(() => _matches = index.search(value));
  }

  Future<void> _pick(PanchangCity city) async {
    await RecentCities.add(city);
    await widget.onPick(city);
    if (mounted) Navigator.of(context).pop();
  }

  Future<void> _locate() async {
    setState(() {
      _busy = true;
      _message = null;
    });
    final failure = await widget.onLocate();
    if (!mounted) return;
    if (failure == null) {
      Navigator.of(context).pop();
    } else {
      setState(() {
        _busy = false;
        _message = _t(failure);
      });
    }
  }

  Widget _row(PanchangCity city) => ListTile(
    key: Key('ekadashi_city_${city.id}'),
    title: Text(PlaceNameResolver.instance.city(city, _language)),
    trailing: Text(
      city.timeZoneLabel(_language),
      style: TextStyle(color: Colors.grey.shade500, fontSize: 12),
    ),
    onTap: () => _pick(city),
  );

  Widget _header(String text) => Padding(
    padding: const EdgeInsets.fromLTRB(16, 16, 16, 4),
    child: Text(
      text,
      style: TextStyle(
        color: Theme.of(context).colorScheme.primary,
        fontWeight: FontWeight.w600,
      ),
    ),
  );

  @override
  Widget build(BuildContext context) {
    final typed = CitySearchIndex.query(_search.text) != null;
    return Column(
      children: [
        // iOS: the title in the middle, Cancel on the left.
        SheetBar(
          title: widget.title,
          leading: BarTextButton(
            key: const Key('city_picker_cancel'),
            label: _t('cancel'),
            onPressed: () => Navigator.of(context).pop(),
          ),
        ),
        Expanded(
          child: ListView(
            key: const Key('city_picker_list'),
            children: [
              ListTile(
                key: const Key('ekadashi_location_current'),
                leading: Icon(
                  widget.icon,
                  color: Theme.of(context).colorScheme.primary,
                ),
                title: Text(
                  PlaceNameResolver.instance.city(widget.current, _language),
                ),
                subtitle: Text(widget.current.timeZoneLabel(_language)),
              ),
              if (widget.footer.isNotEmpty)
                Padding(
                  padding: const EdgeInsets.symmetric(horizontal: 16),
                  child: Text(
                    widget.footer,
                    style: TextStyle(fontSize: 12, color: Colors.grey.shade500),
                  ),
                ),
              Padding(
                padding: const EdgeInsets.fromLTRB(16, 12, 16, 0),
                child: TextField(
                  key: const Key('ekadashi_location_search'),
                  controller: _search,
                  textCapitalization: TextCapitalization.words,
                  decoration: InputDecoration(
                    labelText: _t('panchang_search_cities'),
                  ),
                  onChanged: (value) {
                    setState(() {});
                    _query(value);
                  },
                ),
              ),
              for (final city in _matches.where((_) => typed)) _row(city),
              ListTile(
                key: const Key('ekadashi_location_current_button'),
                leading: const Icon(AppIcons.useCurrentLocation),
                title: Text(
                  _t(
                    _busy
                        ? 'panchang_locating'
                        : 'panchang_use_current_location',
                  ),
                ),
                enabled: !_busy,
                onTap: _locate,
              ),
              if (_message != null)
                Padding(
                  padding: const EdgeInsets.symmetric(horizontal: 16),
                  child: Text(_message!, style: const TextStyle(fontSize: 12)),
                ),
              if (!typed) ...[
                if (_recent.isNotEmpty) ...[
                  _header(_t('recent_searches')),
                  for (final city in _recent) _row(city),
                ],
                _header(_t('home_popular_cities')),
                for (final city in _popular) _row(city),
              ],
              if (widget.extra != null) widget.extra!,
              const SizedBox(height: 24),
            ],
          ),
        ),
      ],
    );
  }
}

/// Coordinates and an IANA timezone typed by hand (the Panchang location
/// dialog's form), as an extra section of the Panchang city picker.
class ManualCoordinatesSection extends StatefulWidget {
  const ManualCoordinatesSection({
    super.key,
    required this.city,
    required this.onSave,
  });
  final PanchangCity city;
  final Future<void> Function(PanchangCity city) onSave;

  @override
  State<ManualCoordinatesSection> createState() =>
      _ManualCoordinatesSectionState();
}

class _ManualCoordinatesSectionState extends State<ManualCoordinatesSection> {
  final _form = GlobalKey<FormState>();
  late final _name = TextEditingController(text: widget.city.label);
  late final _lat = TextEditingController(text: '${widget.city.latitude}');
  late final _lon = TextEditingController(text: '${widget.city.longitude}');
  late final _zone = TextEditingController(text: widget.city.timeZoneId);

  String get _language =>
      context.read<LanguageService>().currentLocale.languageCode;
  String _t(String key) => AppStrings.translate(key, _language);

  @override
  void dispose() {
    for (final c in [_name, _lat, _lon, _zone]) {
      c.dispose();
    }
    super.dispose();
  }

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

  @override
  Widget build(BuildContext context) => Padding(
    padding: const EdgeInsets.fromLTRB(16, 16, 16, 0),
    child: Form(
      key: _form,
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
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
            decoration: InputDecoration(labelText: _t('panchang_longitude')),
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
          const SizedBox(height: 8),
          Text(
            _t('panchang_location_footer'),
            style: const TextStyle(fontSize: 12),
          ),
          Align(
            alignment: Alignment.centerRight,
            child: FilledButton(
              key: const Key('location_save'),
              onPressed: () async {
                if (!_form.currentState!.validate()) return;
                final navigator = Navigator.of(context);
                await widget.onSave(
                  PanchangCity(
                    id: 'custom',
                    label: _name.text.trim(),
                    latitude: double.parse(_lat.text),
                    longitude: double.parse(_lon.text),
                    timeZoneId: _zone.text.trim(),
                  ),
                );
                navigator.pop();
              },
              child: Text(_t('panchang_save_location')),
            ),
          ),
        ],
      ),
    ),
  );
}
