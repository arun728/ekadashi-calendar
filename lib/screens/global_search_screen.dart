import 'dart:async';
import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import '../models/search_content_type.dart';
import '../models/search_result.dart';
import '../services/ekadashi_service.dart';
import '../services/language_service.dart';
import '../services/recent_search_repository.dart';
import '../services/search_index_manager.dart';
import 'details_screen.dart';
import 'search_detail_screen.dart';

/// Module 19 — Global Search Screen
/// Single unified search interface across all 8 indexed content types:
/// Ekadashi, Katha, Mantra, Food, Vrat Info, Festival, Temple, Event.
class GlobalSearchScreen extends StatefulWidget {
  final List<EkadashiDate> ekadashiList;
  final String? currentTimezone;
  final bool showBackButton;
  final VoidCallback? onBackToHome;

  const GlobalSearchScreen({
    super.key,
    required this.ekadashiList,
    this.currentTimezone,
    this.showBackButton = true,
    this.onBackToHome,
  });

  @override
  State<GlobalSearchScreen> createState() => _GlobalSearchScreenState();
}

class _GlobalSearchScreenState extends State<GlobalSearchScreen> {
  final TextEditingController _searchController = TextEditingController();
  final FocusNode _focusNode = FocusNode();
  final SearchIndexManager _indexManager = SearchIndexManager();
  final RecentSearchRepository _recentRepo = RecentSearchRepository();

  SearchContentType _selectedCategory = SearchContentType.all;
  List<SearchResult> _results = [];
  List<String> _recentSearches = [];
  List<String> _liveSuggestions = [];

  bool _isLoading = false;
  bool _isOffline = false;
  String _activeQuery = '';
  String _submittedQuery = '';
  Timer? _debounceTimer;

  static const Color _tealColor = Color(0xFF00A19B);
  static const Color _accentGold = Color(0xFFFFB300);

  @override
  void initState() {
    super.initState();
    _isOffline = _indexManager.isOffline;
    _loadRecentSearches();
    _ensureIndexReady();
  }

  @override
  void dispose() {
    _debounceTimer?.cancel();
    _searchController.dispose();
    _focusNode.dispose();
    super.dispose();
  }

  Future<void> _ensureIndexReady() async {
    final lang = Provider.of<LanguageService>(context, listen: false);
    final langCode = lang.currentLocale.languageCode;
    await _indexManager.buildIndexFromEkadashis(
      widget.ekadashiList,
      languageCode: langCode,
    );
  }

  Future<void> _loadRecentSearches() async {
    final recents = await _recentRepo.getRecentSearches();
    if (mounted) {
      setState(() {
        _recentSearches = recents;
      });
    }
  }

  void _onSearchChanged(String query) {
    _debounceTimer?.cancel();

    if (query.trim().isEmpty) {
      setState(() {
        _activeQuery = '';
        _submittedQuery = '';
        _results = [];
        _liveSuggestions = [];
        _isLoading = false;
      });
      _loadRecentSearches();
      return;
    }

    // Live suggestions update immediately (does NOT write to Recent Search History)
    final suggestions = _indexManager.getLiveSuggestions(query, limit: 5);
    setState(() {
      _liveSuggestions = suggestions;
    });

    // Debounce the heavier live search ranking (250ms)
    // CRITICAL: Live typing search MUST NOT save to Recent Search History
    _debounceTimer = Timer(const Duration(milliseconds: 250), () {
      _executeSearch(query, isExplicitSubmission: false);
    });
  }

  /// Centralized search submission handler (EC2-FR-082).
  /// A search query is ONLY recorded into Recent Search History when the user
  /// explicitly submits the search (e.g. keyboard Search action, Search button,
  /// tapping an explicit suggestion, or selecting a recent search).
  void submitSearch(String query) {
    final cleanQuery = query.trim();
    if (cleanQuery.isEmpty) return;

    _focusNode.unfocus();
    _searchController.text = cleanQuery;
    _searchController.selection = TextSelection.fromPosition(
      TextPosition(offset: cleanQuery.length),
    );

    _debounceTimer?.cancel();
    _executeSearch(cleanQuery, isExplicitSubmission: true);
  }

  void _executeSearch(String query, {bool isExplicitSubmission = false}) {
    final cleanQuery = query.trim();
    if (cleanQuery.isEmpty) return;

    setState(() {
      _isLoading = true;
      _activeQuery = cleanQuery;
      _liveSuggestions = [];
    });

    final lang = Provider.of<LanguageService>(context, listen: false);
    final langCode = lang.currentLocale.languageCode;

    final results = _indexManager.search(
      cleanQuery,
      contentType: _selectedCategory,
      languageCode: langCode,
    );

    // CRITICAL BUG FIX: Recent search is ONLY saved on explicit submission.
    // Typing keystrokes, debounced live results, live suggestions, and filter toggles
    // NEVER save intermediate entries to Recent Search History.
    if (isExplicitSubmission) {
      _submittedQuery = cleanQuery;
      _recentRepo.addSearch(cleanQuery).then((_) => _loadRecentSearches());
    }

    if (mounted) {
      setState(() {
        _results = results;
        _isLoading = false;
      });
    }
  }

  void _onFilterSelected(SearchContentType type) {
    if (_selectedCategory == type) return;

    setState(() {
      _selectedCategory = type;
    });

    if (_activeQuery.isNotEmpty) {
      _executeSearch(_activeQuery, isExplicitSubmission: false);
    }
  }

  void _onRecentSearchTapped(String term) {
    submitSearch(term);
  }

  Future<void> _deleteRecentSearch(String term) async {
    await _recentRepo.deleteSearch(term);
    await _loadRecentSearches();
  }

  Future<void> _clearAllRecentSearches() async {
    await _recentRepo.clearAll();
    await _loadRecentSearches();
  }

  void _handleDownload(SearchResult item) async {
    final success = await _indexManager.downloadContent(item.id);
    if (!mounted) return;

    if (success) {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text('Downloaded "${item.title}" for offline reading'),
          backgroundColor: _tealColor,
          behavior: SnackBarBehavior.floating,
          duration: const Duration(seconds: 2),
        ),
      );

      // Re-run search so the result card shows as downloaded
      if (_activeQuery.isNotEmpty) {
        _executeSearch(_activeQuery, isExplicitSubmission: false);
      }
    }
  }

  void _navigateToDetail(SearchResult result) {
    if (result.contentType == SearchContentType.ekadashi) {
      // Find matching EkadashiDate from list
      EkadashiDate? match;
      try {
        match = widget.ekadashiList.firstWhere(
          (e) =>
              e.id.toString() == result.id ||
              'ekadashi_${e.id}' == result.id ||
              e.name.toLowerCase() == result.title.toLowerCase(),
        );
      } catch (_) {
        if (widget.ekadashiList.isNotEmpty) {
          match = widget.ekadashiList.first;
        }
      }

      if (match != null) {
        Navigator.push(
          context,
          MaterialPageRoute(
            builder: (context) => DetailsScreen(
              ekadashi: match!,
              timezone: widget.currentTimezone,
            ),
          ),
        );
        return;
      }
    }

    // For Katha, Mantra, Food, Vrat Info, Festival, Temple, Event:
    Navigator.push(
      context,
      MaterialPageRoute(
        builder: (context) => SearchDetailScreen(
          result: result,
          onDownload: () => _handleDownload(result),
        ),
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    final isDark = Theme.of(context).brightness == Brightness.dark;
    final lang = Provider.of<LanguageService>(context);

    return Scaffold(
      backgroundColor: isDark ? const Color(0xFF121212) : Colors.grey.shade100,
      appBar: AppBar(
        elevation: 0,
        backgroundColor: isDark ? const Color(0xFF1E1E1E) : Colors.white,
        automaticallyImplyLeading: false,
        leading: (widget.showBackButton && Navigator.canPop(context))
            ? IconButton(
                icon: const Icon(Icons.arrow_back),
                onPressed: () => Navigator.pop(context),
              )
            : (widget.onBackToHome != null
                ? IconButton(
                    icon: const Icon(Icons.arrow_back),
                    onPressed: widget.onBackToHome,
                  )
                : null),
        title: _buildSearchBar(isDark, lang),
        actions: [
          // Offline indicator toggle / status
          IconButton(
            tooltip: _isOffline ? 'Offline mode active' : 'Online search mode',
            icon: Icon(
              _isOffline ? Icons.wifi_off : Icons.wifi,
              size: 20,
              color: _isOffline ? Colors.amber : Colors.grey.shade400,
            ),
            onPressed: () {
              setState(() {
                _isOffline = !_isOffline;
                _indexManager.setForcedOffline(_isOffline);
              });
              if (_activeQuery.isNotEmpty) {
                _executeSearch(_activeQuery, isExplicitSubmission: false);
              }
            },
          ),
        ],
      ),
      body: Column(
        children: [
          // Offline indicator banner (EC2-FR-081)
          if (_isOffline) _buildOfflineBanner(lang),

          // Horizontal Filter Chips (EC2-FR-080)
          _buildFilterChipRow(lang, isDark),

          // Main Search Content
          Expanded(
            child: _buildSearchBody(isDark, lang),
          ),
        ],
      ),
    );
  }

  Widget _buildSearchBar(bool isDark, LanguageService lang) {
    return Container(
      height: 44,
      decoration: BoxDecoration(
        color: isDark ? const Color(0xFF2A2A2A) : Colors.grey.shade100,
        borderRadius: BorderRadius.circular(12),
      ),
      child: TextField(
        controller: _searchController,
        focusNode: _focusNode,
        autofocus: true,
        textInputAction: TextInputAction.search,
        onChanged: _onSearchChanged,
        onSubmitted: (query) => submitSearch(query),
        style: TextStyle(
          fontSize: 15,
          color: isDark ? Colors.white : Colors.black87,
        ),
        decoration: InputDecoration(
          hintText: lang.translate('search_hint'),
          hintStyle: TextStyle(
            fontSize: 14,
            color: isDark ? Colors.grey.shade500 : Colors.grey.shade500,
          ),
          prefixIcon: IconButton(
            icon: const Icon(Icons.search, size: 20, color: _tealColor),
            tooltip: lang.translate('search'),
            onPressed: () => submitSearch(_searchController.text),
          ),
          suffixIcon: _searchController.text.isNotEmpty
              ? Row(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    IconButton(
                      icon: const Icon(Icons.clear, size: 18),
                      color: Colors.grey.shade500,
                      onPressed: () {
                        _searchController.clear();
                        _onSearchChanged('');
                      },
                    ),
                    IconButton(
                      icon: const Icon(Icons.arrow_forward, size: 18, color: _tealColor),
                      tooltip: lang.translate('search'),
                      onPressed: () => submitSearch(_searchController.text),
                    ),
                  ],
                )
              : null,
          border: InputBorder.none,
          contentPadding: const EdgeInsets.symmetric(horizontal: 12, vertical: 12),
        ),
      ),
    );
  }

  Widget _buildOfflineBanner(LanguageService lang) {
    return Container(
      width: double.infinity,
      padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
      color: Colors.amber.shade900.withValues(alpha: 0.2),
      child: Row(
        children: [
          const Icon(Icons.offline_bolt_outlined, size: 16, color: _accentGold),
          const SizedBox(width: 8),
          Expanded(
            child: Text(
              lang.translate('offline_indicator'),
              style: const TextStyle(
                fontSize: 12,
                fontWeight: FontWeight.w600,
                color: _accentGold,
              ),
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildFilterChipRow(LanguageService lang, bool isDark) {
    const categories = SearchContentType.values;

    return Container(
      height: 50,
      padding: const EdgeInsets.symmetric(vertical: 6),
      color: isDark ? const Color(0xFF1E1E1E) : Colors.white,
      child: ListView.separated(
        scrollDirection: Axis.horizontal,
        padding: const EdgeInsets.symmetric(horizontal: 12),
        itemCount: categories.length,
        separatorBuilder: (_, __) => const SizedBox(width: 8),
        itemBuilder: (context, index) {
          final cat = categories[index];
          final isSelected = _selectedCategory == cat;

          return FilterChip(
            selected: isSelected,
            showCheckmark: false,
            avatar: Icon(
              cat.icon,
              size: 16,
              color: isSelected ? Colors.white : (isDark ? Colors.grey.shade400 : Colors.grey.shade700),
            ),
            label: Text(
              cat.displayName,
              style: TextStyle(
                fontSize: 13,
                fontWeight: isSelected ? FontWeight.bold : FontWeight.normal,
                color: isSelected ? Colors.white : (isDark ? Colors.grey.shade300 : Colors.black87),
              ),
            ),
            backgroundColor: isDark ? const Color(0xFF2C2C2C) : Colors.grey.shade200,
            selectedColor: _tealColor,
            shape: RoundedRectangleBorder(
              borderRadius: BorderRadius.circular(20),
              side: BorderSide(
                color: isSelected ? _tealColor : Colors.transparent,
              ),
            ),
            onSelected: (_) => _onFilterSelected(cat),
          );
        },
      ),
    );
  }

  Widget _buildSearchBody(bool isDark, LanguageService lang) {
    if (_isLoading) {
      return const Center(
        child: CircularProgressIndicator(color: _tealColor),
      );
    }

    // 1. Live suggestions state (while typing before search enter or debounced result)
    if (_liveSuggestions.isNotEmpty && _activeQuery.isEmpty) {
      return _buildSuggestionsList(isDark);
    }

    // 2. Active Query Results
    if (_activeQuery.isNotEmpty) {
      if (_results.isEmpty) {
        return _buildNoResultsState(isDark, lang);
      }
      return _buildResultsList(isDark, lang);
    }

    // 3. Empty Query: Show Recent Searches and Quick Exploration
    return _buildRecentSearchesAndSuggestions(isDark, lang);
  }

  Widget _buildSuggestionsList(bool isDark) {
    return ListView.builder(
      itemCount: _liveSuggestions.length,
      itemBuilder: (context, index) {
        final suggestion = _liveSuggestions[index];
        return ListTile(
          leading: const Icon(Icons.search, size: 20, color: _tealColor),
          title: Text(suggestion),
          onTap: () {
            submitSearch(suggestion);
          },
        );
      },
    );
  }

  Widget _buildRecentSearchesAndSuggestions(bool isDark, LanguageService lang) {
    return SingleChildScrollView(
      padding: const EdgeInsets.all(16),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          if (_recentSearches.isNotEmpty) ...[
            Row(
              mainAxisAlignment: MainAxisAlignment.spaceBetween,
              children: [
                Text(
                  lang.translate('recent_searches').toUpperCase(),
                  style: TextStyle(
                    fontSize: 12,
                    fontWeight: FontWeight.bold,
                    letterSpacing: 1.1,
                    color: isDark ? Colors.grey.shade400 : Colors.grey.shade600,
                  ),
                ),
                TextButton(
                  onPressed: _clearAllRecentSearches,
                  style: TextButton.styleFrom(
                    visualDensity: VisualDensity.compact,
                    foregroundColor: Colors.grey.shade500,
                  ),
                  child: Text(
                    lang.translate('clear_all'),
                    style: const TextStyle(fontSize: 12),
                  ),
                ),
              ],
            ),
            const SizedBox(height: 6),
            ..._recentSearches.map(
              (term) => Container(
                margin: const EdgeInsets.only(bottom: 6),
                child: Material(
                  color: isDark ? const Color(0xFF1E1E1E) : Colors.white,
                  shape: RoundedRectangleBorder(
                    borderRadius: BorderRadius.circular(10),
                    side: BorderSide(
                      color: isDark ? Colors.white10 : Colors.grey.shade200,
                    ),
                  ),
                  child: ListTile(
                    dense: true,
                    leading: Icon(
                      Icons.history,
                      size: 20,
                      color: isDark ? Colors.grey.shade400 : Colors.grey.shade600,
                    ),
                    title: Text(
                      term,
                      style: TextStyle(
                        fontSize: 14,
                        color: isDark ? Colors.white : Colors.black87,
                      ),
                    ),
                    trailing: IconButton(
                      icon: const Icon(Icons.close, size: 16),
                      color: Colors.grey.shade500,
                      onPressed: () => _deleteRecentSearch(term),
                    ),
                    onTap: () => _onRecentSearchTapped(term),
                  ),
                ),
              ),
            ),
            const SizedBox(height: 24),
          ],

          // Quick Category Exploration
          Text(
            'EXPLORE CONTENT',
            style: TextStyle(
              fontSize: 12,
              fontWeight: FontWeight.bold,
              letterSpacing: 1.1,
              color: isDark ? Colors.grey.shade400 : Colors.grey.shade600,
            ),
          ),
          const SizedBox(height: 12),
          Wrap(
            spacing: 8,
            runSpacing: 8,
            children: [
              _buildExploreChip('Nirjala Ekadashi', Icons.brightness_7),
              _buildExploreChip('Vishnu Sahasranama', Icons.menu_book),
              _buildExploreChip('Vrat Food Guide', Icons.restaurant),
              _buildExploreChip('Parana Rules', Icons.rule),
              _buildExploreChip('Gita Jayanti', Icons.celebration),
              _buildExploreChip('Tirupati Balaji', Icons.account_balance),
              _buildExploreChip('Kartik Damodara', Icons.event),
            ],
          ),
        ],
      ),
    );
  }

  Widget _buildExploreChip(String label, IconData icon) {
    return ActionChip(
      avatar: Icon(icon, size: 16, color: _tealColor),
      label: Text(label),
      backgroundColor: Theme.of(context).brightness == Brightness.dark
          ? const Color(0xFF1E1E1E)
          : Colors.white,
      shape: RoundedRectangleBorder(
        borderRadius: BorderRadius.circular(16),
        side: BorderSide(color: Colors.grey.withValues(alpha: 0.2)),
      ),
      onPressed: () {
        submitSearch(label);
      },
    );
  }

  Widget _buildResultsList(bool isDark, LanguageService lang) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Padding(
          padding: const EdgeInsets.fromLTRB(16, 12, 16, 8),
          child: Text(
            '${_results.length} results found',
            style: TextStyle(
              fontSize: 13,
              fontWeight: FontWeight.w600,
              color: isDark ? Colors.grey.shade400 : Colors.grey.shade600,
            ),
          ),
        ),
        Expanded(
          child: ListView.separated(
            padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
            itemCount: _results.length,
            separatorBuilder: (_, __) => const SizedBox(height: 10),
            itemBuilder: (context, index) {
              final item = _results[index];
              return _buildResultCard(item, isDark, lang);
            },
          ),
        ),
      ],
    );
  }

  Widget _buildResultCard(SearchResult item, bool isDark, LanguageService lang) {
    return InkWell(
      onTap: () => _navigateToDetail(item),
      borderRadius: BorderRadius.circular(12),
      child: Container(
        padding: const EdgeInsets.all(14),
        decoration: BoxDecoration(
          color: isDark ? const Color(0xFF1E1E1E) : Colors.white,
          borderRadius: BorderRadius.circular(12),
          border: Border.all(
            color: isDark ? Colors.white10 : Colors.grey.shade200,
          ),
          boxShadow: [
            BoxShadow(
              color: Colors.black.withValues(alpha: isDark ? 0.2 : 0.04),
              blurRadius: 6,
              offset: const Offset(0, 2),
            ),
          ],
        ),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            // Header Row: Category Badge + Online/Offline status
            Row(
              mainAxisAlignment: MainAxisAlignment.spaceBetween,
              children: [
                Container(
                  padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
                  decoration: BoxDecoration(
                    color: item.contentType.badgeColor.withValues(alpha: 0.15),
                    borderRadius: BorderRadius.circular(6),
                  ),
                  child: Row(
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      Icon(
                        item.contentType.icon,
                        size: 14,
                        color: item.contentType.badgeColor,
                      ),
                      const SizedBox(width: 4),
                      Text(
                        item.contentType.displayName.toUpperCase(),
                        style: TextStyle(
                          fontSize: 11,
                          fontWeight: FontWeight.bold,
                          color: item.contentType.badgeColor,
                          letterSpacing: 0.5,
                        ),
                      ),
                    ],
                  ),
                ),
                if (item.isOnlineOnly && !item.isDownloaded)
                  Container(
                    padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 2),
                    decoration: BoxDecoration(
                      color: Colors.orange.withValues(alpha: 0.15),
                      borderRadius: BorderRadius.circular(4),
                    ),
                    child: Text(
                      lang.translate('online_only'),
                      style: const TextStyle(
                        fontSize: 10,
                        fontWeight: FontWeight.w600,
                        color: Colors.orange,
                      ),
                    ),
                  )
                else if (item.date != null && item.date!.isNotEmpty)
                  Text(
                    item.date!,
                    style: TextStyle(
                      fontSize: 12,
                      color: isDark ? Colors.grey.shade400 : Colors.grey.shade600,
                    ),
                  ),
              ],
            ),
            const SizedBox(height: 8),

            // Title with query highlighting
            _buildHighlightedText(
              item.title,
              _activeQuery,
              TextStyle(
                fontSize: 16,
                fontWeight: FontWeight.bold,
                color: isDark ? Colors.white : Colors.black87,
              ),
              highlightColor: _accentGold,
            ),
            const SizedBox(height: 4),

            // Subtitle / snippet with query highlighting
            _buildHighlightedText(
              item.subtitle,
              _activeQuery,
              TextStyle(
                fontSize: 13,
                color: isDark ? Colors.grey.shade400 : Colors.grey.shade600,
                height: 1.3,
              ),
              highlightColor: _accentGold,
              maxLines: 2,
            ),

            // Download action row if online only
            if (item.isOnlineOnly && !item.isDownloaded) ...[
              const SizedBox(height: 10),
              Row(
                mainAxisAlignment: MainAxisAlignment.end,
                children: [
                  OutlinedButton.icon(
                    icon: const Icon(Icons.download_rounded, size: 16),
                    label: Text(lang.translate('download')),
                    style: OutlinedButton.styleFrom(
                      foregroundColor: _tealColor,
                      side: const BorderSide(color: _tealColor),
                      visualDensity: VisualDensity.compact,
                      shape: RoundedRectangleBorder(
                        borderRadius: BorderRadius.circular(8),
                      ),
                    ),
                    onPressed: () => _handleDownload(item),
                  ),
                ],
              ),
            ],
          ],
        ),
      ),
    );
  }

  Widget _buildNoResultsState(bool isDark, LanguageService lang) {
    return Center(
      child: SingleChildScrollView(
        padding: const EdgeInsets.all(32),
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            Icon(
              Icons.search_off_rounded,
              size: 64,
              color: Colors.grey.shade400,
            ),
            const SizedBox(height: 16),
            Text(
              '${lang.translate('no_results_found')} "${_submittedQuery.isNotEmpty ? _submittedQuery : _activeQuery}"',
              textAlign: TextAlign.center,
              style: TextStyle(
                fontSize: 16,
                fontWeight: FontWeight.bold,
                color: isDark ? Colors.white70 : Colors.black87,
              ),
            ),
            const SizedBox(height: 8),
            if (_isOffline)
              Padding(
                padding: const EdgeInsets.symmetric(horizontal: 16),
                child: Text(
                  'No offline results found. Online-only content may be available when connected.',
                  textAlign: TextAlign.center,
                  style: TextStyle(
                    fontSize: 13,
                    color: Colors.amber.shade700,
                  ),
                ),
              ),
            const SizedBox(height: 24),
            Text(
              lang.translate('try_searching'),
              style: TextStyle(
                fontSize: 13,
                fontWeight: FontWeight.w600,
                color: isDark ? Colors.grey.shade400 : Colors.grey.shade600,
              ),
            ),
            const SizedBox(height: 12),
            Wrap(
              spacing: 8,
              runSpacing: 8,
              alignment: WrapAlignment.center,
              children: [
                _buildExploreChip('Ekadashi', Icons.brightness_7),
                _buildExploreChip('Katha', Icons.menu_book),
                _buildExploreChip('Mantra', Icons.record_voice_over),
                _buildExploreChip('Food', Icons.restaurant),
                _buildExploreChip('Vrat', Icons.rule),
                _buildExploreChip('Festival', Icons.celebration),
              ],
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildHighlightedText(
    String text,
    String query,
    TextStyle baseStyle, {
    required Color highlightColor,
    int? maxLines,
  }) {
    if (query.trim().isEmpty || !text.toLowerCase().contains(query.toLowerCase())) {
      return Text(
        text,
        style: baseStyle,
        maxLines: maxLines,
        overflow: maxLines != null ? TextOverflow.ellipsis : null,
      );
    }

    final spans = <TextSpan>[];
    final lowerText = text.toLowerCase();
    final lowerQuery = query.toLowerCase().trim();

    int start = 0;
    while (start < text.length) {
      final matchIndex = lowerText.indexOf(lowerQuery, start);
      if (matchIndex == -1) {
        spans.add(TextSpan(text: text.substring(start), style: baseStyle));
        break;
      }

      if (matchIndex > start) {
        spans.add(TextSpan(
          text: text.substring(start, matchIndex),
          style: baseStyle,
        ));
      }

      spans.add(TextSpan(
        text: text.substring(matchIndex, matchIndex + lowerQuery.length),
        style: baseStyle.copyWith(
          color: highlightColor,
          fontWeight: FontWeight.bold,
        ),
      ));

      start = matchIndex + lowerQuery.length;
    }

    return RichText(
      text: TextSpan(children: spans),
      maxLines: maxLines,
      overflow: maxLines != null ? TextOverflow.ellipsis : TextOverflow.clip,
    );
  }
}
