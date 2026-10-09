import 'dart:async';

import 'package:flutter/material.dart';
import 'package:intl/intl.dart';
import 'package:provider/provider.dart';

import '../data/calendar_entry_repository.dart';
import '../models/calendar_entry.dart';
import '../services/ekadashi_service.dart';
import '../services/language_service.dart';
import '../services/panchang/observance_calendar_service.dart';
import '../services/panchang/panchang_city.dart';
import '../services/panchang/panchang_location_store.dart';
import '../services/panchang/panchang_models.dart';
import '../services/premium_service.dart';
import '../services/recent_search_repository.dart';
import '../services/search/search_catalog.dart';
import '../services/search/search_corpus.dart';
import '../services/search/search_return.dart';
import '../services/search/unified_search.dart';
import '../widgets/glass_tube.dart';
import '../widgets/section_pager.dart';
import 'details_screen.dart';
import 'panchang_screen.dart';
import 'premium_screen.dart';
import 'widget_preview_screen.dart';

/// Icons for the search categories (the iOS SF Symbols).
IconData searchCategoryIcon(SearchCategory category) => switch (category) {
  SearchCategory.ekadashi => Icons.spa_outlined,
  SearchCategory.festival => Icons.auto_awesome,
  SearchCategory.amavasya => Icons.dark_mode_outlined,
  SearchCategory.purnima => Icons.brightness_1,
  SearchCategory.shivaratri => Icons.nights_stay_outlined,
  SearchCategory.chaturthi => Icons.verified_outlined,
  SearchCategory.pradosham => Icons.wb_twilight,
  SearchCategory.navaratri => Icons.local_fire_department_outlined,
  SearchCategory.sankranti => Icons.wb_sunny_outlined,
  SearchCategory.jayanti => Icons.star_outline,
  SearchCategory.myCalendar => Icons.event_outlined,
  SearchCategory.screen => Icons.open_in_new,
};

/// One search for the whole app (docs/ROADMAP.md Phase 1): Ekadashis,
/// Panchang festivals and observances (Premium), custom and Google
/// calendar entries, and app screens. The year filter comes first, then
/// the type chips. Only an explicit submission is saved to recent searches.
/// The type pages (All, then each type) also change with a horizontal swipe.
class GlobalSearchScreen extends StatefulWidget {
  const GlobalSearchScreen({
    super.key,
    required this.ekadashiList,
    required this.ekadashisFor,
    this.currentTimezone = 'IST',
    this.availableYears = const [],
    this.onOpenTab,
    this.onOpenCalendar,
    this.initialSession,
  });

  /// The schedule in the app language (Ekadashi details open from it).
  final List<EkadashiDate> ekadashiList;

  /// The published schedule in any language (every name is searchable).
  final List<EkadashiDate> Function(String language) ekadashisFor;
  final String currentTimezone;

  /// The data years, for the year filter and festival dates.
  final List<int> availableYears;

  /// Called after the search closes: switch to bottom tab [tab]. The
  /// session is what the search showed, so that tab can come back to it.
  final void Function(int tab, SearchSession session)? onOpenTab;

  /// Called after the search closes: show [day] in the Calendar tab.
  final void Function(DateTime day, SearchSession session)? onOpenCalendar;

  /// Reopens the search a result left (the text, type page and year).
  final SearchSession? initialSession;

  @override
  State<GlobalSearchScreen> createState() => _GlobalSearchScreenState();
}

class _GlobalSearchScreenState extends State<GlobalSearchScreen> {
  final _controller = TextEditingController();
  final _focus = FocusNode();
  final _recentRepo = RecentSearchRepository();
  SearchCatalog? _catalog;
  UnifiedSearch? _index;

  /// The text the results show (live typing settles after 200 ms).
  String _searched = '';

  /// Each page's results, worked out when the page is shown.
  final Map<SearchCategory?, List<SearchItem>> _pageResults = {};
  late final PageController _pages;
  List<String> _suggestions = const [];
  List<String> _recents = const [];
  SearchCategory? _category;
  int? _year;
  bool _loadingObservances = false;
  Timer? _debounce;
  String _language = '';
  int _build = 0;

  bool _hasInput(SearchCategory? page) =>
      _searched.trim().isNotEmpty || page != null || _year != null;

  SearchSession get _session =>
      SearchSession(query: _searched, category: _category, year: _year);

  @override
  void initState() {
    super.initState();
    final session = widget.initialSession;
    if (session != null) {
      _controller.text = session.query;
      _searched = session.query;
      _category = session.category;
      _year = session.year;
    }
    _pages = PageController(
      initialPage: SearchCategory.pages.indexOf(_category),
    );
    _recentRepo.getRecentSearches().then((list) {
      if (mounted) setState(() => _recents = list);
    });
  }

  @override
  void didChangeDependencies() {
    super.didChangeDependencies();
    final language = context
        .watch<LanguageService>()
        .currentLocale
        .languageCode;
    if (language != _language) {
      _language = language;
      _rebuild();
    }
  }

  @override
  void dispose() {
    _debounce?.cancel();
    _controller.dispose();
    _focus.dispose();
    _pages.dispose();
    super.dispose();
  }

  /// Ekadashis, entries and screens at once; festivals follow when the
  /// Panchang calculation for the data years is ready.
  Future<void> _rebuild() async {
    final generation = ++_build;
    final catalog = _catalog ??= await SearchCatalog.load();
    if (!mounted) return;
    final repository = context.read<CalendarEntryRepository?>();
    List<CalendarEntry> entries = const [];
    try {
      entries = await repository?.getAll() ?? const [];
    } catch (_) {}
    UnifiedSearch index(List<DatedObservance> observances) => UnifiedSearch(
      SearchCorpus.build(
        ekadashis: widget.ekadashisFor,
        observances: observances,
        entries: entries,
        language: _language,
        catalog: catalog,
      ),
      catalog,
    );
    if (!mounted || generation != _build) return;
    setState(() {
      _index = index(const []);
      _loadingObservances = true;
    });
    _run();
    final city = await PanchangLocationStore().load() ?? PanchangCity.newDelhi;
    final years = widget.availableYears.isNotEmpty
        ? widget.availableYears
        : [DateTime.now().year];
    final observances = await ObservanceCalendarService.instance.years(
      years,
      city,
    );
    if (!mounted || generation != _build) return;
    setState(() {
      _index = index(observances);
      _loadingObservances = false;
    });
    _run();
  }

  /// Shows the typed text; each page's results are worked out when shown.
  void _run() {
    setState(() {
      _searched = _controller.text;
      _pageResults.clear();
    });
  }

  List<SearchItem> _results(SearchCategory? page) {
    final index = _index;
    if (index == null) return const [];
    return _pageResults.putIfAbsent(page, () {
      final now = DateTime.now();
      return index.search(
        _searched,
        category: page,
        year: _year,
        today: DateTime.utc(now.year, now.month, now.day),
      );
    });
  }

  /// A chip or an explore suggestion chose the [page] of results.
  void _showCategory(SearchCategory? page) {
    setState(() => _category = page);
    showSectionPage(_pages, SearchCategory.pages.indexOf(page));
  }

  void _changed(String value) {
    _debounce?.cancel();
    final trimmed = value.trim();
    if (trimmed.isEmpty) {
      setState(() => _suggestions = const []);
      _run();
      return;
    }
    setState(() => _suggestions = _index?.suggestions(trimmed) ?? const []);
    // Live results after 200 ms; never saved to recent searches.
    _debounce = Timer(const Duration(milliseconds: 200), _run);
  }

  Future<void> _submit(String text) async {
    final clean = text.trim();
    if (clean.isEmpty) return;
    _debounce?.cancel();
    _controller.text = clean;
    setState(() => _suggestions = const []);
    _run();
    await _recentRepo.addSearch(clean);
    final list = await _recentRepo.getRecentSearches();
    if (mounted) setState(() => _recents = list);
  }

  bool _locked(SearchItem item) =>
      item.requiresPremium &&
      !(context.read<PremiumService?>()?.isPremium ?? false);

  Future<void> _open(SearchItem item) async {
    if (_locked(item)) {
      await openPremium(
        context,
        currentTimezone: widget.currentTimezone,
        reasonKey: 'search_premium_locked',
      );
      return;
    }
    final target = item.target;
    switch (target.kind) {
      case SearchTargetKind.ekadashi:
        final event = widget.ekadashiList
            .where((e) => e.occurrenceUid == target.id)
            .firstOrNull;
        if (event == null) return;
        await Navigator.of(context).push(
          MaterialPageRoute<void>(
            builder: (_) => DetailsScreen(
              ekadashi: event,
              timezone: widget.currentTimezone,
            ),
          ),
        );
      case SearchTargetKind.observance:
        final city =
            await PanchangLocationStore().load() ?? PanchangCity.newDelhi;
        if (!mounted) return;
        await Navigator.of(context).push(
          MaterialPageRoute<void>(
            builder: (_) => Scaffold(
              appBar: AppBar(title: Text(item.title)),
              body: PanchangScreen(initialDate: target.date, initialCity: city),
            ),
          ),
        );
      case SearchTargetKind.entry:
        final session = _session;
        Navigator.of(context).pop();
        widget.onOpenCalendar?.call(target.date!, session);
      case SearchTargetKind.tab:
        final session = _session;
        Navigator.of(context).pop();
        widget.onOpenTab?.call(target.tab!, session);
      case SearchTargetKind.paywall:
        await openPremium(context, currentTimezone: widget.currentTimezone);
      case SearchTargetKind.widgetPreview:
        await Navigator.of(context).push(
          MaterialPageRoute<void>(
            builder: (_) => WidgetPreviewScreen(
              ekadashiList: widget.ekadashiList,
              currentTimezone: widget.currentTimezone,
            ),
          ),
        );
    }
  }

  @override
  Widget build(BuildContext context) {
    final lang = context.watch<LanguageService>();
    context.watch<PremiumService?>();
    return Scaffold(
      appBar: AppBar(
        leading: IconButton(
          key: const Key('global_search_back'),
          icon: const Icon(Icons.arrow_back),
          tooltip: MaterialLocalizations.of(context).closeButtonTooltip,
          onPressed: () => Navigator.of(context).maybePop(),
        ),
        titleSpacing: 0,
        title: TextField(
          key: const Key('global_search_field'),
          controller: _controller,
          focusNode: _focus,
          autofocus: true,
          textInputAction: TextInputAction.search,
          decoration: InputDecoration(
            hintText: lang.translate('search_hint_all'),
            border: InputBorder.none,
            suffixIcon: _controller.text.isEmpty
                ? null
                : IconButton(
                    key: const Key('global_search_clear'),
                    icon: const Icon(Icons.close),
                    onPressed: () {
                      _controller.clear();
                      _changed('');
                    },
                  ),
          ),
          onChanged: _changed,
          onSubmitted: _submit,
        ),
        actions: [
          if (_loadingObservances)
            const Padding(
              padding: EdgeInsets.all(16),
              child: SizedBox.square(
                dimension: 18,
                child: CircularProgressIndicator(
                  strokeWidth: 2,
                  color: GlassTubeColors.teal,
                ),
              ),
            ),
        ],
      ),
      body: Column(
        children: [
          _filters(lang),
          if (_suggestions.isNotEmpty && _focus.hasFocus) _suggestionList(),
          Expanded(
            child: PageView.builder(
              controller: _pages,
              itemCount: SearchCategory.pages.length,
              onPageChanged: (index) =>
                  setState(() => _category = SearchCategory.pages[index]),
              itemBuilder: (_, index) => KeyedSubtree(
                key: ValueKey('search_page_$index'),
                child: _content(lang, SearchCategory.pages[index]),
              ),
            ),
          ),
        ],
      ),
    );
  }

  Widget _filters(LanguageService lang) {
    final years = widget.availableYears;
    return Padding(
      padding: const EdgeInsets.fromLTRB(12, 6, 12, 6),
      child: GlassTube(
        key: const Key('search_filters_tube'),
        optionCount: 2,
        padding: const EdgeInsets.symmetric(horizontal: 4, vertical: 2),
        child: SingleChildScrollView(
          key: const Key('search_categories_tube'),
          scrollDirection: Axis.horizontal,
          child: Row(
            children: [
              PopupMenuButton<int>(
                key: const Key('search_year_selector'),
                tooltip: lang.translate('year'),
                onSelected: (value) {
                  setState(() => _year = value == 0 ? null : value);
                  _run();
                },
                itemBuilder: (_) => [
                  PopupMenuItem(
                    value: 0,
                    child: Text(lang.translate('search_all_years')),
                  ),
                  for (final y in years)
                    PopupMenuItem(value: y, child: Text('$y')),
                ],
                child: Padding(
                  padding: const EdgeInsets.symmetric(
                    horizontal: 12,
                    vertical: 14,
                  ),
                  child: Row(
                    children: [
                      Icon(
                        Icons.calendar_today,
                        size: 16,
                        color: _year == null ? null : GlassTubeColors.teal,
                      ),
                      const SizedBox(width: 6),
                      Text(
                        _year?.toString() ?? lang.translate('year'),
                        style: TextStyle(
                          fontWeight: _year == null
                              ? FontWeight.w500
                              : FontWeight.w700,
                          color: _year == null ? null : GlassTubeColors.teal,
                        ),
                      ),
                      const Icon(Icons.arrow_drop_down, size: 18),
                    ],
                  ),
                ),
              ),
              _chip(lang.translate('filter_all'), Icons.grid_view, null),
              for (final type in SearchCategory.filters)
                _chip(
                  lang.translate(type.localizationKey),
                  searchCategoryIcon(type),
                  type,
                ),
            ],
          ),
        ),
      ),
    );
  }

  Widget _chip(String label, IconData icon, SearchCategory? type) {
    final selected = _category == type;
    final color = type == null ? GlassTubeColors.teal : Color(type.color);
    return Padding(
      padding: const EdgeInsets.only(right: 4),
      child: SelectedChipAnchor(
        selected: selected,
        child: GlassFilterChip(
          key: Key('search_filter_${type?.raw ?? 'all'}'),
          avatar: Icon(icon, size: 16, color: color),
          label: Text(label),
          selected: selected,
          showCheckmark: false,
          // The selected type's chip goes back to All.
          onSelected: (_) => _showCategory(selected ? null : type),
        ),
      ),
    );
  }

  Widget _suggestionList() => Material(
    elevation: 2,
    child: Column(
      children: [
        for (final s in _suggestions)
          ListTile(
            dense: true,
            leading: const Icon(Icons.search, size: 18),
            title: Text(s),
            onTap: () => _submit(s),
          ),
      ],
    ),
  );

  Widget _content(LanguageService lang, SearchCategory? page) {
    if (!_hasInput(page)) return _start(lang);
    final results = _results(page);
    if (results.isEmpty) {
      return Center(
        key: const Key('search_no_results'),
        child: Padding(
          padding: const EdgeInsets.all(32),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              Icon(Icons.search_off, size: 48, color: Colors.grey.shade500),
              const SizedBox(height: 12),
              Text(
                '${lang.translate('no_results_found')} "${_controller.text.trim()}"',
                textAlign: TextAlign.center,
                style: Theme.of(context).textTheme.titleMedium,
              ),
              const SizedBox(height: 6),
              Text(
                lang.translate('search_no_results_hint'),
                textAlign: TextAlign.center,
                style: TextStyle(color: Colors.grey.shade500),
              ),
            ],
          ),
        ),
      );
    }
    return ListView.separated(
      key: const Key('search_results'),
      padding: const EdgeInsets.fromLTRB(16, 8, 16, 32),
      itemCount: results.length,
      separatorBuilder: (_, _) => const SizedBox(height: 8),
      itemBuilder: (_, i) => _row(results[i], lang),
    );
  }

  Widget _start(LanguageService lang) => ListView(
    key: const Key('search_start'),
    padding: const EdgeInsets.all(16),
    children: [
      if (_recents.isNotEmpty) ...[
        Row(
          children: [
            Expanded(
              child: Text(
                lang.translate('recent_searches').toUpperCase(),
                style: Theme.of(context).textTheme.labelMedium?.copyWith(
                  color: Colors.grey.shade500,
                  fontWeight: FontWeight.w700,
                ),
              ),
            ),
            TextButton(
              onPressed: () async {
                await _recentRepo.clearAll();
                if (mounted) setState(() => _recents = const []);
              },
              child: Text(lang.translate('clear_all')),
            ),
          ],
        ),
        for (final term in _recents)
          ListTile(
            contentPadding: EdgeInsets.zero,
            leading: const Icon(Icons.history),
            title: Text(term),
            onTap: () => _submit(term),
            trailing: IconButton(
              icon: const Icon(Icons.close, size: 18),
              onPressed: () async {
                await _recentRepo.deleteSearch(term);
                final list = await _recentRepo.getRecentSearches();
                if (mounted) setState(() => _recents = list);
              },
            ),
          ),
        const SizedBox(height: 12),
      ],
      Text(
        lang.translate('search_start_all'),
        style: Theme.of(context).textTheme.titleMedium,
      ),
      const SizedBox(height: 12),
      Wrap(
        key: const Key('search_explore_tube'),
        spacing: 8,
        runSpacing: 8,
        children: [
          for (final type in SearchCategory.filters)
            ActionChip(
              avatar: Icon(
                searchCategoryIcon(type),
                size: 16,
                color: Color(type.color),
              ),
              label: Text(lang.translate(type.localizationKey)),
              shape: const StadiumBorder(),
              onPressed: () => _showCategory(type),
            ),
        ],
      ),
    ],
  );

  Widget _row(SearchItem item, LanguageService lang) {
    final locked = _locked(item);
    final category = item.categories.contains(SearchCategory.festival)
        ? SearchCategory.festival
        : item.categories.firstOrNull ?? SearchCategory.screen;
    final color = Color(category.color);
    final date = item.date;
    return Material(
      key: Key('search_result_${item.id}'),
      color: Theme.of(context).cardColor,
      borderRadius: BorderRadius.circular(16),
      child: InkWell(
        borderRadius: BorderRadius.circular(16),
        onTap: () => _open(item),
        child: Padding(
          padding: const EdgeInsets.all(12),
          child: Row(
            children: [
              Container(
                width: 40,
                height: 40,
                decoration: BoxDecoration(
                  color: color.withValues(alpha: .16),
                  borderRadius: BorderRadius.circular(12),
                ),
                child: Icon(
                  searchCategoryIcon(category),
                  color: color,
                  size: 22,
                ),
              ),
              const SizedBox(width: 12),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      item.title,
                      maxLines: 2,
                      overflow: TextOverflow.ellipsis,
                      style: Theme.of(context).textTheme.titleMedium?.copyWith(
                        fontWeight: FontWeight.w600,
                      ),
                    ),
                    if (locked)
                      Row(
                        children: [
                          const Icon(
                            Icons.lock,
                            size: 13,
                            color: Color(0xFFF59E0B),
                          ),
                          const SizedBox(width: 4),
                          Text(
                            lang.translate('search_premium_locked'),
                            style: const TextStyle(
                              fontSize: 12,
                              color: Color(0xFFF59E0B),
                            ),
                          ),
                        ],
                      )
                    else if (date != null)
                      Text(
                        DateFormat('EEE, d MMM yyyy', _language).format(date),
                        style: TextStyle(
                          color: Colors.grey.shade500,
                          fontSize: 13,
                        ),
                      ),
                    Text(
                      lang.translate(category.localizationKey),
                      style: TextStyle(
                        color: color,
                        fontSize: 11,
                        fontWeight: FontWeight.w600,
                      ),
                    ),
                  ],
                ),
              ),
              Icon(
                locked ? Icons.lock : Icons.chevron_right,
                size: 18,
                color: locked ? const Color(0xFFF59E0B) : Colors.grey.shade500,
              ),
            ],
          ),
        ),
      ),
    );
  }
}
