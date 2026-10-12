import 'package:flutter/material.dart';
import 'package:flutter_timezone/flutter_timezone.dart';
import 'package:provider/provider.dart';
import '../l10n/app_language.dart';
import '../l10n/place_names.dart';
import '../services/language_service.dart';
import '../services/native_location_service.dart';
import '../services/panchang/panchang_city.dart';
import '../services/panchang/panchang_location_store.dart';
import '../widgets/ios_style.dart';
import '../widgets/settings_group.dart';

/// Search the offline worldwide city list, use the current location, or
/// enter coordinates and an IANA time zone. The iOS PanchangLocationSheet:
/// a sheet with Cancel and Save in its bar and a grouped form with
/// placeholders; Save stays disabled until the location is valid.
class PanchangLocationSheet extends StatefulWidget {
  const PanchangLocationSheet({super.key, required this.city});
  final PanchangCity city;
  @override
  State<PanchangLocationSheet> createState() => _PanchangLocationSheetState();
}

class _PanchangLocationSheetState extends State<PanchangLocationSheet> {
  late final _search = TextEditingController();
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
    for (final controller in [_search, _name, _lat, _lon, _zone]) {
      controller.dispose();
    }
    super.dispose();
  }

  /// The location the fields describe, or null while they are invalid.
  PanchangCity? get _candidate {
    final lat = double.tryParse(_lat.text.trim());
    final lon = double.tryParse(_lon.text.trim());
    if (lat == null || lon == null) return null;
    final city = PanchangCity(
      id: 'custom',
      label: _name.text.trim(),
      latitude: lat,
      longitude: lon,
      timeZoneId: _zone.text.trim(),
    );
    try {
      city.validate();
      return city;
    } catch (_) {
      return null;
    }
  }

  void _searchChanged(String value) {
    final q = value.trim().toLowerCase();
    setState(
      () => _matches = q.length < 2
          ? []
          : _catalog
                .where(
                  (c) =>
                      // Names typed in the app language match too.
                      '${c.label.toLowerCase()} ${c.searchTerms} ${PlaceNames.label(c.label, _language)}'
                          .contains(q),
                )
                .take(12)
                .toList(),
    );
  }

  void _select(PanchangCity city) {
    setState(() {
      _name.text = city.label;
      _lat.text = '${city.latitude}';
      _lon.text = '${city.longitude}';
      _zone.text = city.timeZoneId;
      _search.clear();
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
  Widget build(BuildContext context) {
    final candidate = _candidate;
    final secondary = IosColors.secondary(context);
    Widget field(
      String key,
      TextEditingController controller,
      String placeholder, {
      TextInputType? keyboard,
      ValueChanged<String>? onChanged,
      bool words = false,
    }) => Padding(
      padding: const EdgeInsets.symmetric(horizontal: SettingsStyle.rowPadding),
      child: TextField(
        key: Key(key),
        controller: controller,
        keyboardType: keyboard,
        autocorrect: false,
        textCapitalization: words
            ? TextCapitalization.words
            : TextCapitalization.none,
        onChanged: onChanged ?? (_) => setState(() {}),
        style: TextStyle(
          fontSize: IosText.body,
          color: IosColors.primary(context),
        ),
        decoration: InputDecoration(
          hintText: placeholder,
          hintStyle: TextStyle(
            fontSize: IosText.body,
            color: IosColors.tertiary(context),
          ),
          border: InputBorder.none,
          enabledBorder: InputBorder.none,
          focusedBorder: InputBorder.none,
          filled: false,
          isDense: true,
          contentPadding: const EdgeInsets.symmetric(vertical: 14),
        ),
      ),
    );
    const numbers = TextInputType.numberWithOptions(
      decimal: true,
      signed: true,
    );
    return Column(
      key: const Key('panchang_location_sheet'),
      children: [
        SheetBar(
          title: _t('panchang_location_title'),
          leading: BarTextButton(
            key: const Key('location_cancel'),
            label: _t('cancel'),
            onPressed: () => Navigator.pop(context),
          ),
          trailing: BarTextButton(
            key: const Key('location_save'),
            label: _t('panchang_save_location'),
            bold: true,
            onPressed: candidate == null || _busy
                ? null
                : () => Navigator.pop(context, candidate),
          ),
        ),
        Expanded(
          child: ListView(
            padding: EdgeInsets.fromLTRB(
              16,
              8,
              16,
              24 + MediaQuery.viewInsetsOf(context).bottom,
            ),
            children: [
              SettingsCard(
                children: [
                  field(
                    'location_search',
                    _search,
                    _t('panchang_search_cities'),
                    onChanged: _searchChanged,
                    words: true,
                  ),
                  for (final city in _matches) ...[
                    const SettingsSeparator(),
                    InkWell(
                      onTap: () => _select(city),
                      child: Padding(
                        padding: const EdgeInsets.symmetric(
                          horizontal: SettingsStyle.rowPadding,
                          vertical: 10,
                        ),
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            Text(
                              PlaceNames.label(city.label, _language),
                              style: TextStyle(
                                fontSize: IosText.body,
                                color: IosColors.primary(context),
                              ),
                            ),
                            Text(
                              city.timeZoneLabel(_language),
                              style: TextStyle(
                                fontSize: IosText.caption,
                                color: secondary,
                              ),
                            ),
                          ],
                        ),
                      ),
                    ),
                  ],
                  const SettingsSeparator(),
                  InkWell(
                    key: const Key('location_use_current'),
                    onTap: _busy ? null : _gps,
                    child: Padding(
                      padding: const EdgeInsets.symmetric(
                        horizontal: SettingsStyle.rowPadding,
                        vertical: 14,
                      ),
                      child: Row(
                        children: [
                          Icon(
                            Icons.near_me,
                            size: 20,
                            color: _busy
                                ? IosColors.tertiary(context)
                                : IosColors.teal,
                          ),
                          const SizedBox(width: 10),
                          Expanded(
                            child: Text(
                              _t(
                                _busy
                                    ? 'panchang_locating'
                                    : 'panchang_use_current_location',
                              ),
                              style: TextStyle(
                                fontSize: IosText.body,
                                color: _busy
                                    ? IosColors.tertiary(context)
                                    : IosColors.teal,
                              ),
                            ),
                          ),
                        ],
                      ),
                    ),
                  ),
                  if (_message != null) ...[
                    const SettingsSeparator(),
                    Padding(
                      padding: const EdgeInsets.symmetric(
                        horizontal: SettingsStyle.rowPadding,
                        vertical: 12,
                      ),
                      child: Align(
                        alignment: AlignmentDirectional.centerStart,
                        child: Text(
                          _message!,
                          style: TextStyle(
                            fontSize: IosText.caption,
                            color: secondary,
                          ),
                        ),
                      ),
                    ),
                  ],
                ],
              ),
              const SizedBox(height: 24),
              SettingsCard(
                children: [
                  field(
                    'location_name',
                    _name,
                    _t('panchang_location_name'),
                    words: true,
                  ),
                  const SettingsSeparator(),
                  field(
                    'location_latitude',
                    _lat,
                    _t('panchang_latitude'),
                    keyboard: numbers,
                  ),
                  const SettingsSeparator(),
                  field(
                    'location_longitude',
                    _lon,
                    _t('panchang_longitude'),
                    keyboard: numbers,
                  ),
                  const SettingsSeparator(),
                  field('location_timezone', _zone, _t('panchang_timezone')),
                ],
              ),
              SettingsFooter(_t('panchang_location_footer')),
            ],
          ),
        ),
      ],
    );
  }

  String get _language =>
      context.read<LanguageService>().currentLocale.languageCode;

  String _t(String key) => AppStrings.translate(key, _language);
}
