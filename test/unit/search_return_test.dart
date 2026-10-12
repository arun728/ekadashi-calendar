import 'package:ekadashi_calendar/services/search/search_catalog.dart';
import 'package:ekadashi_calendar/services/search/search_return.dart';
import 'package:flutter_test/flutter_test.dart';

/// A search result that opens a tab or a calendar day leaves the search, so
/// that screen's top bar (and the system back) goes back to the same
/// results (SearchReturnTests.swift).
void main() {
  const session = SearchSession(
    query: 'settings',
    category: SearchCategory.myCalendar,
    year: 2027,
  );

  test('a screen opened from search goes back to the same search', () {
    final back = SearchReturn();
    back.opened(4, session);
    expect(back.showsBack(4), isTrue);
    expect(back.showsBack(1), isFalse, reason: 'only the screen it opened');
    expect(back.goBack(), session);
    expect(back.showsBack(4), isFalse, reason: 'going back uses it up');
    expect(back.goBack(), isNull);
  });

  test('a newer result replaces the older one', () {
    final back = SearchReturn();
    back.opened(1, session);
    back.opened(3, session);
    expect(back.showsBack(3), isTrue);
    expect(back.showsBack(1), isFalse);
  });

  test('choosing another tab or a new search forgets the return', () {
    final back = SearchReturn();
    back.opened(2, session);
    back.selected(2);
    expect(back.showsBack(2), isTrue, reason: 'the same tab keeps it');
    back.selected(0);
    expect(back.showsBack(2), isFalse);
    expect(back.goBack(), isNull);
    back.opened(2, session);
    back.clear();
    expect(back.goBack(), isNull);
  });

  test('search pages start with All, then each type', () {
    expect(SearchCategory.pages.first, isNull);
    expect(SearchCategory.pages.skip(1), SearchCategory.filters);
  });
}
