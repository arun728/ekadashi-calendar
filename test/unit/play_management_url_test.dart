import 'package:ekadashi_calendar/services/play_billing_service.dart';
import 'package:ekadashi_calendar/services/premium_service.dart';
import 'package:flutter_test/flutter_test.dart';

/// Manage subscription (Settings > Purchases and the plans page). On the M52
/// (27 Nov 2026) a free user's tap opened Google Play's page for the old
/// combined ekadashi_premium subscription: "We couldn't find your
/// subscription". Without a subscription it opens Google Play's list.
void main() {
  test('without a subscription it opens Google Play subscriptions list', () {
    expect(
      PlayBillingService.managementUrl(null).toString(),
      'https://play.google.com/store/account/subscriptions',
    );
  });

  test('with a subscription it opens that subscription in Google Play', () {
    expect(
      PlayBillingService.managementUrl(
        PremiumService.monthlySubscriptionId,
      ).toString(),
      'https://play.google.com/store/account/subscriptions'
      '?package=com.applausestudios.ekadashi_calendar'
      '&sku=${PremiumService.monthlySubscriptionId}',
    );
  });
}
