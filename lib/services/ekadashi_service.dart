import 'dart:convert';
import 'package:flutter/services.dart';

class EkadashiDate {
  final String id;
  final String name;
  final DateTime date;
  final String fastStartTime;
  final String fastBreakTime;
  final String description;
  final String story;
  final String fastingRules;
  final String benefits; // Added Benefits

  EkadashiDate({
    required this.id,
    required this.name,
    required this.date,
    required this.fastStartTime,
    required this.fastBreakTime,
    required this.description,
    this.story = '',
    this.fastingRules = '',
    this.benefits = '', // Added Default
  });

  factory EkadashiDate.fromJson(Map<String, dynamic> json) {
    return EkadashiDate(
      id: json['id'].toString(),
      name: json['name'] ?? '',
      date: DateTime.parse(json['date']),
      fastStartTime: json['fastStartTime'] ?? '',
      fastBreakTime: json['fastBreakTime'] ?? '',
      description: json['description'] ?? '',
      story: json['story'] ?? 'Story details coming soon...',
      fastingRules: json['fastingRules'] ?? 'Standard Ekadashi fasting rules apply.',
      benefits: json['benefits'] ?? 'Grants spiritual merit and purifies the heart.', // Added Parsing
    );
  }
}

class EkadashiService {
  Future<List<EkadashiDate>> getUpcomingEkadashis({String languageCode = 'en'}) async {
    try {
      final String path = 'assets/ekadashi_data_$languageCode.json';
      final String response = await rootBundle.loadString(path);
      final List<dynamic> data = json.decode(response);
      return data.map((json) => EkadashiDate.fromJson(json)).toList();
    } catch (e) {
      // Fallback to English if file not found or error
      if (languageCode != 'en') {
         return getUpcomingEkadashis(languageCode: 'en');
      }
      return [];
    }
  }
}