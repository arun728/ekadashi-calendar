import 'dart:convert';
import 'dart:io';
import 'package:flutter_test/flutter_test.dart';

void main() {
  test(
    'StoreKit distinguishes the subscription display names without changing product IDs',
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
      expect(
        {
          for (final p in products)
            p['productID']: (p['localizations'] as List).first['displayName'],
        },
        {
          'ekadashi_premium_monthly': 'Ekadashi Premium - Monthly',
          'ekadashi_premium_yearly': 'Ekadashi Premium - Yearly',
          'ekadashi_premium_lifetime': 'Ekadashi Premium',
        },
      );
    },
  );
}
