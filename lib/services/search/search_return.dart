import 'search_catalog.dart';

/// What a search showed: the text, the type page and the year.
class SearchSession {
  const SearchSession({required this.query, this.category, this.year});

  final String query;
  final SearchCategory? category;
  final int? year;

  @override
  bool operator ==(Object other) =>
      other is SearchSession &&
      other.query == query &&
      other.category == category &&
      other.year == year;

  @override
  int get hashCode => Object.hash(query, category, year);
}

/// A search result that opens a tab or a calendar day leaves the search;
/// that screen's top bar (and the system back) then goes back to the same
/// results. Another tab, a deep link or a new search forgets it
/// (SearchReturn.swift).
class SearchReturn {
  SearchSession? _session;
  int? _tab;

  /// A result opened bottom tab [tab] from [session].
  void opened(int tab, SearchSession session) {
    _session = session;
    _tab = tab;
  }

  /// Whether [tab]'s top bar offers the way back.
  bool showsBack(int tab) => _session != null && _tab == tab;

  /// The search to reopen; the way back is used up.
  SearchSession? goBack() {
    final session = _session;
    clear();
    return session;
  }

  /// The user chose [tab] in the tab bar.
  void selected(int tab) {
    if (tab != _tab) clear();
  }

  void clear() {
    _session = null;
    _tab = null;
  }
}
