import 'dart:convert';
import 'dart:io';
import 'package:flutter_test/flutter_test.dart';
import '../../tool/panchang_accuracy/export_engine.dart' as exporter;

void main() {
  test('accuracy export includes independently auditable Anandadi labels', () {
    final temp = Directory.systemTemp.createTempSync('panchang-export-');
    addTearDown(() => temp.deleteSync(recursive: true));
    final cities = File('${temp.path}/cities.json')..writeAsStringSync(jsonEncode([
      {'id':'chennai','label':'Chennai','lat':13.0827,'lon':80.2707,'tz':'Asia/Kolkata'}
    ]));
    final out = File('${temp.path}/engine.json');
    exporter.main([cities.path,'2026-01-06','1',out.path]);
    final row = jsonDecode(out.readAsStringSync())['chennai']['days'][0];
    expect(row['anandadi'], 'Ananda');
  });

  test('export configured independent accuracy audit', () {
    exporter.main([
      Platform.environment['AUDIT_CITIES'] ?? 'tool/panchang_accuracy/cities.json',
      Platform.environment['AUDIT_START'] ?? '2025-12-01',
      Platform.environment['AUDIT_DAYS'] ?? '790',
      Platform.environment['AUDIT_OUT']!,
    ]);
  }, skip: !Platform.environment.containsKey('AUDIT_OUT'),
     timeout: const Timeout(Duration(minutes:40)));
}
