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

  print('Verifying Notification Logic (Android WorkManager Implementation)');
  print('Logic:');
  print('  - 2 Days Before: Fasting Start Time - 48 Hours');
  print('  - 1 Day Before:  Fasting Start Time - 24 Hours');
  print('  - Fasting Start: Fasting Start Time');
  print('  - Parana Start:  Parana Start Time');
  print('----------------------------------------------------------------');

  int totalChecks = 0;
  int missingData = 0;

  // We will store a few examples to print at the end
  List<Map<String, dynamic>> examples = [];

  for (final ekadashi in ekadashis) {
    final id = ekadashi['id'];
    final name = ekadashi['name']['en'];
    final timings = ekadashi['timing'];

    for (final timezone in ['IST', 'PST']) {
      totalChecks++;
      if (!timings.containsKey(timezone)) {
        print('WARNING: ID $id ($name) missing $timezone timing');
        missingData++;
        continue;
      }

      final tzData = timings[timezone];
      if (tzData['fasting_start'] == null || tzData['parana_start'] == null) {
         print('WARNING: ID $id ($name) [$timezone] missing fasting_start or parana_start');
         missingData++;
         continue;
      }

      final fastingStartIso = tzData['fasting_start'];
      final paranaStartIso = tzData['parana_start'];

      // Parse times
      // Input format ex: 2026-02-12T06:45:00+05:30
      final fastingStart = DateTime.parse(fastingStartIso);
      final paranaStart = DateTime.parse(paranaStartIso);

      // Calculate Triggers (Logic from NotificationScheduler.kt)
      final remind2Days = fastingStart.subtract(Duration(hours: 48));
      final remind1Day = fastingStart.subtract(Duration(hours: 24));
      final remindStart = fastingStart;
      final remindParana = paranaStart;

      final ekadashiDate = tzData['date'];

      // Extract offset from the original string to format output
      // Format: 2026-02-12T07:19:00-08:00
      final offsetStr = fastingStartIso.substring(19); // e.g., -08:00 or +05:30

      // Add to examples list
      examples.add({
        'name': '$name ($timezone)',
        'date': ekadashiDate,
        'remind2Days': formatWithOffset(remind2Days, offsetStr),
        'remind1Day': formatWithOffset(remind1Day, offsetStr),
        'remindStart': formatWithOffset(remindStart, offsetStr),
        'remindParana': formatWithOffset(remindParana, offsetStr),
      });

    }
  }

  if (missingData == 0) {
    print('\n✅ Data integrity check passed for all $totalChecks timezone entries.\n');
  } else {
    print('\n❌ Data integrity check failed with $missingData missing entries.\n');
  }

  print('=== VERIFICATION REPORT (All Ekadashis - Local Time) ===');
  for (final ex in examples) {
    print('Ekadashi: ${ex['name']}');
    print('  Official Date: ${ex['date']}');
    print('  2 Days Prior:  ${ex['remind2Days']}');
    print('  1 Day Prior:   ${ex['remind1Day']}');
    print('  Fasting Start: ${ex['remindStart']}');
    print('  Parana Start:  ${ex['remindParana']}');
    print('----------------------------------------------------------------');
  }
}

String formatWithOffset(DateTime utcDate, String offsetStr) {
  // Parse offset string (e.g. -08:00 or +05:30)
  // DateTime is in UTC. We need to apply the offset to get the local time components,
  // then append the offset string.
  
  // 1. Parse hours and minutes from offset string
  final sign = offsetStr.startsWith('-') ? -1 : 1;
  final parts = offsetStr.replaceAll('+', '').replaceAll('-', '').split(':');
  final offsetHours = int.parse(parts[0]);
  final offsetMinutes = int.parse(parts[1]);
  
  final totalOffsetMinutes = sign * (offsetHours * 60 + offsetMinutes);
  
  // 2. Add offset to UTC time to get "Local" time components
  final localDate = utcDate.add(Duration(minutes: totalOffsetMinutes));
  
  // 3. Format
  final y = localDate.year;
  final m = localDate.month.toString().padLeft(2, '0');
  final d = localDate.day.toString().padLeft(2, '0');
  final h = localDate.hour.toString().padLeft(2, '0');
  final min = localDate.minute.toString().padLeft(2, '0');
  
  // Get weekday name
  const weekdays = ['Mon', 'Tue', 'Wed', 'Thu', 'Fri', 'Sat', 'Sun'];
  final weekday = weekdays[localDate.weekday - 1]; // weekday is 1-7
  
  return "$weekday, $y-$m-$d ${h}:${min} $offsetStr";
}
