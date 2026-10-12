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
import '../widgets/app_background.dart';
import '../widgets/ios_style.dart';
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

  /// A page a result opens: inside the search sheet, on the app background
  /// (iOS keeps the gradient on every pushed page).
  Future<void> _push(WidgetBuilder builder) => Navigator.of(context).push(
    MaterialPageRoute<void>(
      builder: (context) => AppBackground(
        child: Theme(
          data: Theme.of(
            context,
          ).copyWith(scaffoldBackgroundColor: Colors.transparent),
          child: Builder(builder: builder),
        ),
      ),
    ),
  );

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
        await _push(
          (_) =>
              DetailsScreen(ekadashi: event, timezone: widget.currentTimezone),
        );
      case SearchTargetKind.observance:
        final city =
            await PanchangLocationStore().load() ?? PanchangCity.newDelhi;
        if (!mounted) return;
        await _push(
          (_) => Scaffold(
            backgroundColor: Colors.transparent,
            appBar: AppBar(title: Text(item.title)),
            body: PanchangScreen(initialDate: target.date, initialCity: city),
          ),
        );
      case SearchTargetKind.entry:
        final session = _session;
        // The search is a sheet with its own navigation: close the sheet.
        Navigator.of(context, rootNavigator: true).pop();
        widget.onOpenCalendar?.call(target.date!, session);
      case SearchTargetKind.tab:
        final session = _session;
        Navigator.of(context, rootNavigator: true).pop();
        widget.onOpenTab?.call(target.tab!, session);
      case SearchTargetKind.paywall:
        await openPremium(context, currentTimezone: widget.currentTimezone);
      case SearchTargetKind.widgetPreview:
        await _push(
          (_) => WidgetPreviewScreen(
            ekadashiList: widget.ekadashiList,
            currentTimezone: widget.currentTimezone,
          ),
        );
    }
  }

  @override
  Widget build(BuildContext context) {
    final lang = context.watch<LanguageService>();
    context.watch<PremiumService?>();
    // The iOS sheet: ⌄ to close, the inline title, the search field below.
    return AppBackground(
      child: Scaffold(
        backgroundColor: Colors.transparent,
        appBar: AppBar(
          backgroundColor: Colors.transparent,
          surfaceTintColor: Colors.transparent,
          centerTitle: true,
          leading: IconButton(
            key: const Key('global_search_back'),
            icon: const Icon(Icons.keyboard_arrow_down, size: 30),
            color: IosColors.teal,
            tooltip: MaterialLocalizations.of(context).closeButtonTooltip,
            onPressed: () =>
                Navigator.of(context, rootNavigator: true).maybePop(),
          ),
          title: Text(lang.translate('search'), style: iosNavTitle(context)),
          actions: [
            if (_loadingObservances)
              const Padding(
                padding: EdgeInsets.all(16),
                child: SizedBox.square(
                  dimension: 18,
                  child: CircularProgressIndicator(
                    strokeWidth: 2,
                    color: IosColors.teal,
                  ),
                ),
              ),
          ],
        ),
        body: Column(
          children: [
            _searchField(lang),
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
      ),
    );
  }

  /// The iOS search field (.searchable): a rounded fill, a magnifier, the
  /// prompt and a clear button; the keyboard opens only on a tap.
  Widget _searchField(LanguageService lang) {
    final dark = Theme.of(context).brightness == Brightness.dark;
    final secondary = IosColors.secondary(context);
    return Padding(
      padding: const EdgeInsets.fromLTRB(16, 2, 16, 4),
      child: Container(
        key: const Key('global_search_bar'),
        height: 38,
        decoration: BoxDecoration(
          // tertiarySystemFill.
          color: dark ? const Color(0x3D767680) : const Color(0x1F767680),
          borderRadius: BorderRadius.circular(10),
        ),
        padding: const EdgeInsets.symmetric(horizontal: 8),
        child: Row(
          children: [
            Icon(Icons.search, size: 20, color: secondary),
            const SizedBox(width: 6),
            Expanded(
              child: TextField(
                key: const Key('global_search_field'),
                controller: _controller,
                focusNode: _focus,
                textInputAction: TextInputAction.search,
                cursorColor: IosColors.teal,
                style: TextStyle(
                  fontSize: IosText.body,
                  color: IosColors.primary(context),
                ),
                decoration: InputDecoration(
                  isDense: true,
                  hintText: lang.translate('search_hint_all'),
                  hintStyle: TextStyle(
                    fontSize: IosText.body,
                    color: secondary,
                  ),
                  hintMaxLines: 1,
                  border: InputBorder.none,
                  contentPadding: const EdgeInsets.symmetric(vertical: 8),
                ),
                onChanged: _changed,
                onSubmitted: _submit,
              ),
            ),
            if (_controller.text.isNotEmpty)
              GestureDetector(
                key: const Key('global_search_clear'),
                behavior: HitTestBehavior.opaque,
                onTap: () {
                  _controller.clear();
                  _changed('');
                },
                child: Padding(
                  padding: const EdgeInsets.all(4),
                  child: Icon(
                    Icons.cancel,
                    size: 18,
                    color: secondary,
                    semanticLabel: MaterialLocalizations.of(
                      context,
                    ).deleteButtonTooltip,
                  ),
                ),
              ),
          ],
        ),
      ),
    );
  }

  /// The year menu (a glass capsule) and the type chips, each its own glass
  /// control, scrolling sideways.
  Widget _filters(LanguageService lang) {
    final years = widget.availableYears;
    final yearColor = _year == null
        ? IosColors.primary(context)
        : IosColors.teal;
    return Padding(
      key: const Key('search_filters_tube'),
      padding: const EdgeInsets.symmetric(vertical: 8),
      child: SingleChildScrollView(
        key: const Key('search_categories_tube'),
        scrollDirection: Axis.horizontal,
        padding: const EdgeInsets.symmetric(horizontal: 16),
        child: Row(
          children: [
            PopupMenuButton<int>(
              key: const Key('search_year_selector'),
              tooltip: lang.translate('year'),
              padding: EdgeInsets.zero,
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
              child: GlassPanel(
                radius: 18,
                padding: const EdgeInsets.symmetric(
                  horizontal: 14,
                  vertical: 8,
                ),
                child: Row(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    Icon(Icons.calendar_today, size: 15, color: yearColor),
                    const SizedBox(width: 6),
                    Text(
                      _year?.toString() ?? lang.translate('year'),
                      style: TextStyle(
                        fontSize: IosText.subheadline,
                        fontWeight: _year == null
                            ? FontWeight.w400
                            : FontWeight.w600,
                        color: yearColor,
                      ),
                    ),
                  ],
                ),
              ),
            ),
            for (final type in SearchCategory.pages) ...[
              const SizedBox(width: 8),
              _chip(lang, type),
            ],
          ],
        ),
      ),
    );
  }

  Widget _chip(LanguageService lang, SearchCategory? type) {
    final selected = _category == type;
    return SelectedChipAnchor(
      selected: selected,
      child: GlassChip(
        key: Key('search_filter_${type?.raw ?? 'all'}'),
        label: lang.translate(type?.localizationKey ?? 'filter_all'),
        icon: type == null ? Icons.grid_view : searchCategoryIcon(type),
        color: type == null ? IosColors.teal : Color(type.color),
        selected: selected,
        // The selected type's chip goes back to All.
        onTap: () => _showCategory(selected ? null : type),
      ),
    );
  }

  /// Completions under the field, like the iOS search suggestions list.
  Widget _suggestionList() => Padding(
    padding: const EdgeInsets.fromLTRB(16, 0, 16, 8),
    child: GlassPanel(
      key: const Key('search_suggestions'),
      radius: 12,
      child: Column(
        children: [
          for (final s in _suggestions) ...[
            if (s != _suggestions.first)
              Divider(
                height: .5,
                thickness: .5,
                indent: 16,
                color: IosColors.separator(context),
              ),
            InkWell(
              onTap: () => _submit(s),
              child: Padding(
                padding: const EdgeInsets.symmetric(
                  horizontal: 16,
                  vertical: 11,
                ),
                child: Row(
                  children: [
                    Expanded(
                      child: Text(
                        s,
                        maxLines: 1,
                        overflow: TextOverflow.ellipsis,
                        style: TextStyle(
                          fontSize: IosText.body,
                          color: IosColors.primary(context),
                        ),
                      ),
                    ),
                  ],
                ),
              ),
            ),
          ],
        ],
      ),
    ),
  );

  Widget _content(LanguageService lang, SearchCategory? page) {
    if (!_hasInput(page)) return _start(lang);
    final results = _results(page);
    if (results.isEmpty) {
      // The query follows the sentence: No results found for "xyz".
      return UnavailableView(
        key: const Key('search_no_results'),
        icon: Icons.search,
        title:
            '${lang.translate('no_results_found')} "${_controller.text.trim()}"',
        description: lang.translate('search_no_results_hint'),
      );
    }
    return ListView.separated(
      key: const Key('search_results'),
      padding: const EdgeInsets.fromLTRB(16, 8, 16, 32),
      itemCount: results.length,
      separatorBuilder: (_, _) => const SizedBox(height: 10),
      itemBuilder: (_, i) => _row(results[i], lang),
    );
  }

  Future<void> _removeRecent(String term) async {
    await _recentRepo.deleteSearch(term);
    final list = await _recentRepo.getRecentSearches();
    if (mounted) setState(() => _recents = list);
  }

  Widget _start(LanguageService lang) {
    final primary = IosColors.primary(context);
    final secondary = IosColors.secondary(context);
    return ListView(
      key: const Key('search_start'),
      padding: const EdgeInsets.all(16),
      children: [
        if (_recents.isNotEmpty) ...[
          Row(
            children: [
              Expanded(
                child: Text(
                  lang.translate('recent_searches').toUpperCase(),
                  style: TextStyle(
                    fontSize: IosText.caption,
                    fontWeight: FontWeight.w700,
                    color: secondary,
                  ),
                ),
              ),
              GestureDetector(
                key: const Key('search_clear_recents'),
                behavior: HitTestBehavior.opaque,
                onTap: () async {
                  await _recentRepo.clearAll();
                  if (mounted) setState(() => _recents = const []);
                },
                child: Padding(
                  padding: const EdgeInsets.symmetric(vertical: 4),
                  child: Text(
                    lang.translate('clear_all'),
                    style: const TextStyle(
                      fontSize: IosText.caption,
                      color: IosColors.teal,
                    ),
                  ),
                ),
              ),
            ],
          ),
          for (final term in _recents) ...[
            const SizedBox(height: 16),
            Row(
              key: Key('search_recent_$term'),
              children: [
                Expanded(
                  child: GestureDetector(
                    behavior: HitTestBehavior.opaque,
                    onTap: () => _submit(term),
                    child: Row(
                      children: [
                        Icon(Icons.history, size: 18, color: primary),
                        const SizedBox(width: 8),
                        Expanded(
                          child: Text(
                            term,
                            maxLines: 1,
                            overflow: TextOverflow.ellipsis,
                            style: TextStyle(
                              fontSize: IosText.body,
                              color: primary,
                            ),
                          ),
                        ),
                      ],
                    ),
                  ),
                ),
                GestureDetector(
                  behavior: HitTestBehavior.opaque,
                  onTap: () => _removeRecent(term),
                  child: Padding(
                    padding: const EdgeInsets.fromLTRB(12, 4, 0, 4),
                    child: Icon(
                      Icons.close,
                      size: IosText.caption,
                      color: secondary,
                      semanticLabel: MaterialLocalizations.of(
                        context,
                      ).deleteButtonTooltip,
                    ),
                  ),
                ),
              ],
            ),
          ],
          const SizedBox(height: 16),
        ],
        Text(
          lang.translate('search_start_all'),
          style: TextStyle(
            fontSize: IosText.headline,
            fontWeight: FontWeight.w600,
            color: primary,
          ),
        ),
        const SizedBox(height: 16),
        Wrap(
          key: const Key('search_explore_tube'),
          spacing: 8,
          runSpacing: 8,
          children: [
            for (final type in SearchCategory.filters)
              GlassChip(
                label: lang.translate(type.localizationKey),
                icon: searchCategoryIcon(type),
                color: Color(type.color),
                selected: false,
                onTap: () => _showCategory(type),
              ),
          ],
        ),
      ],
    );
  }

  Widget _row(SearchItem item, LanguageService lang) {
    final locked = _locked(item);
    final category = item.categories.contains(SearchCategory.festival)
        ? SearchCategory.festival
        : item.categories.firstOrNull ?? SearchCategory.screen;
    final color = Color(category.color);
    final date = item.date;
    final secondary = IosColors.secondary(context);
    // iOS SearchResultRow: a glass card, headline title, the date (or the
    // amber lock), the category in its colour and a chevron or lock.
    return GlassPanel(
      key: Key('search_result_${item.id}'),
      radius: 16,
      padding: const EdgeInsets.all(12),
      onTap: () => _open(item),
      child: Row(
        children: [
          Container(
            width: 40,
            height: 40,
            decoration: BoxDecoration(
              color: color.withValues(alpha: .16),
              borderRadius: BorderRadius.circular(12),
            ),
            child: Icon(searchCategoryIcon(category), color: color, size: 20),
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
                  style: TextStyle(
                    fontSize: IosText.headline,
                    fontWeight: FontWeight.w600,
                    color: IosColors.primary(context),
                  ),
                ),
                const SizedBox(height: 3),
                if (locked)
                  Row(
                    children: [
                      const Icon(
                        Icons.lock,
                        size: IosText.caption,
                        color: IosColors.amber,
                      ),
                      const SizedBox(width: 4),
                      Flexible(
                        child: Text(
                          lang.translate('search_premium_locked'),
                          style: const TextStyle(
                            fontSize: IosText.caption,
                            color: IosColors.amber,
                          ),
                        ),
                      ),
                    ],
                  )
                else if (date != null)
                  Text(
                    DateFormat('EEE, d MMM yyyy', _language).format(date),
                    style: TextStyle(
                      fontSize: IosText.subheadline,
                      color: secondary,
                    ),
                  ),
                const SizedBox(height: 3),
                Text(
                  lang.translate(category.localizationKey),
                  style: TextStyle(
                    color: color,
                    fontSize: IosText.caption2,
                    fontWeight: FontWeight.w600,
                  ),
                ),
              ],
            ),
          ),
          const SizedBox(width: 8),
          Icon(
            locked ? Icons.lock : Icons.chevron_right,
            size: 16,
            color: locked ? IosColors.amber : secondary,
          ),
        ],
      ),
    );
  }
}
