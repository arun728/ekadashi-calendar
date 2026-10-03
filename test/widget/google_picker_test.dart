import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:provider/provider.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:ekadashi_calendar/services/language_service.dart';
import 'package:ekadashi_calendar/services/google_calendar_service.dart';
import 'package:ekadashi_calendar/screens/widgets/google_calendar_picker_sheet.dart';

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();
  testWidgets('Legacy primary alias selects the actual primary calendar ID', (
    tester,
  ) async {
    SharedPreferences.setMockInitialValues({});
    await tester.pumpWidget(
      ChangeNotifierProvider(
        create: (_) => LanguageService(),
        child: MaterialApp(
          home: Builder(
            builder: (context) => Scaffold(
              body: TextButton(
                child: const Text('Open'),
                onPressed: () => showGoogleCalendarPickerSheet(
                  context: context,
                  calendars: [
                    const GoogleCalendarInfo(
                      id: 'owner@example.test',
                      summary: 'Personal',
                      primary: true,
                    ),
                  ],
                  initiallySelected: ['primary'],
                ),
              ),
            ),
          ),
        ),
      ),
    );
    await tester.tap(find.text('Open'));
    await tester.pumpAndSettle();
    expect(
      tester.widget<CheckboxListTile>(find.byType(CheckboxListTile)).value,
      isTrue,
    );
  });
}
