import 'package:ekadashi_calendar/l10n/place_names.dart';
import 'package:flutter_test/flutter_test.dart';

/// Cities and countries show in the app language (assets/panchang/
/// place_names.json, shared with iOS).
void main() {
  TestWidgetsFlutterBinding.ensureInitialized();
  setUpAll(PlaceNames.load);

  test('places and countries are named in each language', () {
    expect(PlaceNames.place('Chennai', 'hi'), 'चेन्नई');
    expect(PlaceNames.place('New Delhi', 'bn'), 'নয়াদিল্লি');
    expect(PlaceNames.place('Chennai', 'en'), 'Chennai');
    expect(PlaceNames.place('Nowhere', 'ta'), 'Nowhere');
    expect(PlaceNames.label('London (GB)', 'gu'), 'લંડન (યુનાઇટેડ કિંગડમ)');
    expect(PlaceNames.label('London (GB)', 'en'), 'London (GB)');
    expect(PlaceNames.country('IN', 'te'), 'భారతదేశం');
  });
}
