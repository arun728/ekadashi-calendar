import 'package:flutter/foundation.dart';
import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import '../services/panchang/panchang_city.dart';
import '../services/panchang/panchang_engine.dart';
import '../services/panchang/panchang_location_store.dart';
import '../services/panchang/panchang_models.dart';
import '../services/premium_service.dart';
import 'panchang_screen.dart';
import 'premium_screen.dart';

/// Free calculation notes shown in Panchang's Guide subtab.
class PanchangGuide extends StatelessWidget {
  const PanchangGuide({super.key});
  @override
  Widget build(BuildContext context) => const Column(
    crossAxisAlignment: CrossAxisAlignment.stretch,
    children: [
      Card(
        child: ExpansionTile(
          leading: Icon(Icons.menu_book_outlined),
          title: Text('Panchang guide'),
          childrenPadding: EdgeInsets.all(16),
          children: [
            Text(
              'Tithi measures the angular separation of Moon and Sun in 12° steps. Nakshatra divides the sidereal Moon’s path into 27 parts; each has four padas. Yoga divides the sum of sidereal Sun and Moon longitudes into 27 parts. Karana is half a tithi. Vara is the weekday.\n\nLimb labels are sampled at the selected location’s sunrise, with every subsequent change shown through the next sunrise. Times after local midnight carry a day marker.',
            ),
          ],
        ),
      ),
      Card(
        child: ExpansionTile(
          leading: Icon(Icons.spa_outlined),
          title: Text('Smarta and Vaishnava'),
          childrenPadding: EdgeInsets.all(16),
          children: [
            Text(
              'Smarta householders fast on the Ekadashi at sunrise. When Ekadashi touches two sunrises and Dwadashi also reaches the next one, the second day is kept; when Ekadashi or the following Dwadashi touches no sunrise, the fast moves to the Dashami day so that Parana falls in Dwadashi. The Gaudiya/ISKCON profile also tests Arunodaya, 96 minutes before sunrise, and Mahadvadashi conditions.\n\nSmarta Parana begins after sunrise and Hari Vasara (the first quarter of Dwadashi), preferably within Pratahkala, the first fifth of the day; if Hari Vasara lasts longer, it moves after Madhyahna. Gaudiya Parana follows the GCAL rules for its special days. A difference between profiles can be intentional. The calculated schedule is a preview while comparisons with independent calendars are completed; existing reminders and fasting history remain on the published schedule.',
            ),
          ],
        ),
      ),
      Card(
        child: ExpansionTile(
          leading: Icon(Icons.public),
          title: Text('Location and calculation methods'),
          childrenPadding: EdgeInsets.all(16),
          children: [
            Text(
              'City search and Panchang calculations work offline. City selection supplies coordinates and an IANA timezone, including daylight-saving transitions. GPS is optional and its suggested timezone should be checked.\n\nThe Sun uses the VSOP87 planetary theory and the Moon the ELP 2000-82B lunar theory, with IAU nutation and the Lahiri ayanamsa; positions agree with JPL ephemerides to better than an arcsecond. Rise/set use the apparent upper limb, standard refraction and a sea-level horizon. Mountains, elevation and unusual refraction can change observed times. When there is no complete solar day, sunrise-based periods and fasting recommendations are unavailable.\n\nRitu uses lunar months; Ayana is labelled with the tropical solstice convention. Muhurta labels are traditional timing categories, not guarantees of outcomes.',
            ),
          ],
        ),
      ),
      Card(
        child: ExpansionTile(
          leading: Icon(Icons.info_outline),
          title: Text('Sources and coverage'),
          childrenPadding: EdgeInsets.all(16),
          children: [
            Text(
              'Astronomy: VSOP87 (Bretagnon & Francou), ELP 2000-82B (Chapront-Touzé & Chapront), IAU 1980 nutation, Meeus, Astronomical Algorithms; checked against Swiss Ephemeris (JPL DE431). Fasting rules: Smarta dates and Parana checked against published Drik Panchang dates; Gaudiya cross-reviewed against the GCAL decision table. Festivals follow the traditional time-window (kala) rules and were checked against public Indian festival lists.\n\nCities: GeoNames (geonames.org), CC BY 4.0. Timezones: IANA database distributed by the timezone package.\n\nRegional festival profiles, personal birth charts, horoscope matching and eclipse calculations are not yet included. This is not a claim of full Drik Panchang equivalence.',
            ),
          ],
        ),
      ),
    ],
  );
}

/// Entry to the premium festival finder in Panchang's Festivals subtab.
class PanchangFestivalFinderCard extends StatelessWidget {
  const PanchangFestivalFinderCard({super.key});
  @override
  Widget build(BuildContext context) => Card(
    child: ListTile(
      key: const Key('panchang_festival_finder'),
      leading: const Icon(Icons.celebration_outlined),
      title: const Text('Festival finder'),
      subtitle: const Text(
        'Browse calculated observances for your saved location',
      ),
      trailing: const Icon(Icons.chevron_right),
      onTap: () => Navigator.push(
        context,
        MaterialPageRoute<void>(
          builder: (_) => const PanchangFestivalExplorer(),
        ),
      ),
    ),
  );
}

List<PanchangDay> _festivalDays(({DateTime month, PanchangCity city}) input) =>
    [
      for (
        var day = 1;
        day <= DateTime.utc(input.month.year, input.month.month + 1, 0).day;
        day++
      )
        const PanchangEngine().calculate(
          DateTime.utc(input.month.year, input.month.month, day),
          city: input.city,
        ),
    ];

class PanchangFestivalExplorer extends StatefulWidget {
  const PanchangFestivalExplorer({super.key});
  @override
  State<PanchangFestivalExplorer> createState() =>
      _PanchangFestivalExplorerState();
}

class _PanchangFestivalExplorerState extends State<PanchangFestivalExplorer> {
  PanchangCity _city = PanchangCity.newDelhi;
  late DateTime _month;
  Future<List<PanchangDay>>? _future;
  String _query = '';
  @override
  void initState() {
    super.initState();
    _initialize();
  }

  Future<void> _initialize() async {
    final saved = await PanchangLocationStore().load();
    if (!mounted) return;
    _city = saved ?? _city;
    final today = _city.wallClock(DateTime.now());
    _month = DateTime.utc(today.year, today.month);
    setState(_load);
  }

  void _load() {
    _future = compute(_festivalDays, (month: _month, city: _city));
  }

  void _move(int months) => setState(() {
    _month = DateTime.utc(_month.year, _month.month + months);
    _load();
  });
  @override
  Widget build(BuildContext context) =>
      !(context.select<PremiumService?, bool>(
        (service) => service?.isPremium ?? false,
      ))
      ? Scaffold(
          appBar: AppBar(title: const Text('Festival finder')),
          body: Center(
            child: FilledButton(
              onPressed: () => openPremium(context, currentTimezone: 'IST'),
              child: const Text('Unlock full Panchang'),
            ),
          ),
        )
      : Scaffold(
          appBar: AppBar(title: const Text('Festival finder')),
          body: _future == null
              ? const Center(child: CircularProgressIndicator())
              : ListView(
                  padding: const EdgeInsets.all(20),
                  children: [
                    Text('${_city.label} · ${_city.timezoneLabel}'),
                    Row(
                      children: [
                        IconButton(
                          tooltip: 'Previous month',
                          onPressed: () => _move(-1),
                          icon: const Icon(Icons.chevron_left),
                        ),
                        Expanded(
                          child: Text(
                            '${_month.year}-${_month.month.toString().padLeft(2, '0')}',
                            textAlign: TextAlign.center,
                          ),
                        ),
                        IconButton(
                          tooltip: 'Next month',
                          onPressed: () => _move(1),
                          icon: const Icon(Icons.chevron_right),
                        ),
                      ],
                    ),
                    TextField(
                      decoration: const InputDecoration(
                        labelText: 'Filter observances',
                        prefixIcon: Icon(Icons.search),
                      ),
                      onChanged: (value) =>
                          setState(() => _query = value.trim().toLowerCase()),
                    ),
                    const SizedBox(height: 16),
                    FutureBuilder<List<PanchangDay>>(
                      future: _future,
                      builder: (context, snapshot) {
                        if (snapshot.hasError) {
                          return Column(
                            children: [
                              const Text('Calculation unavailable'),
                              TextButton(
                                onPressed: () => setState(_load),
                                child: const Text('Retry'),
                              ),
                            ],
                          );
                        }
                        if (snapshot.connectionState != ConnectionState.done) {
                          return const Center(
                            child: CircularProgressIndicator(),
                          );
                        }
                        final days = snapshot.data!
                            .where(
                              (day) => day.observances.any(
                                (event) =>
                                    event.name.toLowerCase().contains(_query),
                              ),
                            )
                            .toList();
                        if (days.isEmpty) {
                          return const Text(
                            'No matching calculated observances this month.',
                          );
                        }
                        return Column(
                          children: [
                            for (final day in days)
                              Card(
                                child: ListTile(
                                  title: Text(
                                    '${day.date.day} · ${day.observances.where((event) => event.name.toLowerCase().contains(_query)).map((event) => event.name).join(' · ')}',
                                  ),
                                  subtitle: Text(
                                    '${day.tithi.paksha} ${day.tithi.name} · ${day.amantaMonth}',
                                  ),
                                  trailing: const Icon(Icons.chevron_right),
                                  onTap: () => Navigator.push(
                                    context,
                                    MaterialPageRoute<void>(
                                      builder: (_) => Scaffold(
                                        appBar: AppBar(
                                          title: const Text('Panchang'),
                                        ),
                                        body: PanchangScreen(
                                          initialDate: day.date,
                                          initialCity: _city,
                                        ),
                                      ),
                                    ),
                                  ),
                                ),
                              ),
                          ],
                        );
                      },
                    ),
                  ],
                ),
        );
}
