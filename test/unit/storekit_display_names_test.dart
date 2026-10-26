import 'dart:convert';
import 'dart:io';
import 'package:flutter_test/flutter_test.dart';

void main() {
  test(
    'StoreKit uses the customer-facing Premium name without changing product IDs',
    () {
      final config =
          jsonDecode(
                File(
                  'ios-native/EkadashiCalendar/Resources/Products.storekit',
                ).readAsStringSync(),
              )
              as Map<String, dynamic>;
      final group =
          (config['subscriptionGroups'] as List).single as Map<String, dynamic>;
      expect(group['name'], 'Ekadashi Premium');
      final products = [
        ...config['products'] as List,
        ...group['subscriptions'] as List,
      ];
      for (final p in products) {
        expect(
          (p['localizations'] as List).first['displayName'],
          'Ekadashi Premium',
        );
      }
      expect(products.map((p) => p['productID']).toSet(), {
        'ekadashi_premium_monthly',
        'ekadashi_premium_yearly',
        'ekadashi_premium_lifetime',
      });
    },
  );
}
