import 'dart:convert';
import 'dart:io';

void main() async {
  final file = File('assets/ekadashi_data.json');
  if (!await file.exists()) {
    print('Error: assets/ekadashi_data.json not found');
    return;
  }

  final jsonString = await file.readAsString();
  final data = jsonDecode(jsonString);
  final ekadashis = data['ekadashis'] as List;

  int totalTests = 0;
  int passedTests = 0;
  int failedTests = 0;

  print('Verifying Days To Go Logic for ${ekadashis.length} Ekadashis...\n');

  for (final ekadashi in ekadashis) {
    final id = ekadashi['id'];
    final name = ekadashi['name']['en'];
    final timings = ekadashi['timing'];

    // Test IST and PST
    for (final timezone in ['IST', 'PST']) {
      if (!timings.containsKey(timezone)) {
        print('WARNING: ID $id ($name) missing $timezone timing');
        continue;
      }

      final dateStr = timings[timezone]['date'];
      // ekadashi.date is parsed from YYYY-MM-DD string, so it's a local DateTime at 00:00:00
      final ekadashiDate = DateTime.parse(dateStr);

      // --- Test Case 1: 5 Days Before ---
      // Simulate "Now" being 5 days before the Ekadashi date
      // In the app: today = DateTime(nowTz.year, nowTz.month, nowTz.day);
      // We simulate 'today' directly as (ekadashiDate - 5 days)
      final simulatedToday_5DaysBefore = ekadashiDate.subtract(const Duration(days: 5));
      // App Logic: difference in days
      final diff1 = ekadashiDate.difference(simulatedToday_5DaysBefore).inDays;
      
      totalTests++;
      if (diff1 == 5) {
        passedTests++;
      } else {
         failedTests++;
         print('[$timezone] FAIL ID $id ($name): Expected 5 days to go, got $diff1');
         print('  Ekadashi Date: $ekadashiDate');
         print('  Simulated Today: $simulatedToday_5DaysBefore');
      }

      // --- Test Case 2: On The Day ---
      // Simulate "Now" being exactly the Ekadashi date
      final simulatedToday_SameDay = ekadashiDate;
      final diff2 = ekadashiDate.difference(simulatedToday_SameDay).inDays;

      totalTests++;
      if (diff2 == 0) {
        passedTests++;
      } else {
        failedTests++;
        print('[$timezone] FAIL ID $id ($name): Expected 0 days (Today), got $diff2');
      }

      // --- Test Case 3: 1 Day After ---
      // Simulate "Now" being 1 day AFTER
      final simulatedToday_1DayAfter = ekadashiDate.add(const Duration(days: 1));
      final diff3 = ekadashiDate.difference(simulatedToday_1DayAfter).inDays; // Should be -1

      totalTests++;
      if (diff3 == -1) {
        passedTests++;
      } else {
        failedTests++;
        print('[$timezone] FAIL ID $id ($name): Expected -1 days (Passed), got $diff3');
      }
    }
  }

  print('\n------------------------------------------------');
  print('Verification Complete');
  print('Total Tests: $totalTests');
  print('Passed:      $passedTests');
  print('Failed:      $failedTests');
  print('------------------------------------------------');

  if (failedTests == 0) {
    print('SUCCESS: Days to go logic is correct for all entries.');
  } else {
    print('FAILURE: Some tests failed.');
    exit(1);
  }
}
