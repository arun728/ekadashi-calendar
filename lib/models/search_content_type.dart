import 'package:flutter/material.dart';

/// Supported content types for Module 19 Global Search.
enum SearchContentType {
  all,
  ekadashi,
  katha,
  mantra,
  food,
  vratInfo,
  festival,
  temple,
  event;

  String get displayName {
    switch (this) {
      case SearchContentType.all:
        return 'All';
      case SearchContentType.ekadashi:
        return 'Ekadashi';
      case SearchContentType.katha:
        return 'Katha';
      case SearchContentType.mantra:
        return 'Mantra';
      case SearchContentType.food:
        return 'Food';
      case SearchContentType.vratInfo:
        return 'Vrat Info';
      case SearchContentType.festival:
        return 'Festival';
      case SearchContentType.temple:
        return 'Temple';
      case SearchContentType.event:
        return 'Event';
    }
  }

  String get typeKey {
    switch (this) {
      case SearchContentType.all:
        return 'ALL';
      case SearchContentType.ekadashi:
        return 'EKADASHI';
      case SearchContentType.katha:
        return 'KATHA';
      case SearchContentType.mantra:
        return 'MANTRA';
      case SearchContentType.food:
        return 'FOOD';
      case SearchContentType.vratInfo:
        return 'VRAT';
      case SearchContentType.festival:
        return 'FESTIVAL';
      case SearchContentType.temple:
        return 'TEMPLE';
      case SearchContentType.event:
        return 'EVENT';
    }
  }

  IconData get icon {
    switch (this) {
      case SearchContentType.all:
        return Icons.auto_awesome;
      case SearchContentType.ekadashi:
        return Icons.calendar_month;
      case SearchContentType.katha:
        return Icons.menu_book;
      case SearchContentType.mantra:
        return Icons.record_voice_over;
      case SearchContentType.food:
        return Icons.restaurant_menu;
      case SearchContentType.vratInfo:
        return Icons.rule;
      case SearchContentType.festival:
        return Icons.celebration;
      case SearchContentType.temple:
        return Icons.temple_hindu;
      case SearchContentType.event:
        return Icons.event;
    }
  }

  Color get color {
    switch (this) {
      case SearchContentType.all:
        return const Color(0xFF00A19B);
      case SearchContentType.ekadashi:
        return const Color(0xFF00A19B); // Teal
      case SearchContentType.katha:
        return const Color(0xFF8B5CF6); // Violet
      case SearchContentType.mantra:
        return const Color(0xFFF59E0B); // Amber / Gold
      case SearchContentType.food:
        return const Color(0xFF10B981); // Emerald Green
      case SearchContentType.vratInfo:
        return const Color(0xFFEC4899); // Rose / Pink
      case SearchContentType.festival:
        return const Color(0xFFF97316); // Orange
      case SearchContentType.temple:
        return const Color(0xFF0284C7); // Sky Blue
      case SearchContentType.event:
        return const Color(0xFF6366F1); // Indigo
    }
  }

  Color get badgeColor => color;

  static SearchContentType fromString(String? value) {
    if (value == null) return SearchContentType.all;
    final lower = value.trim().toLowerCase();
    for (final type in SearchContentType.values) {
      if (type.name.toLowerCase() == lower ||
          type.typeKey.toLowerCase() == lower ||
          type.displayName.toLowerCase() == lower) {
        return type;
      }
    }
    return SearchContentType.all;
  }
}
