import 'package:flutter/foundation.dart';
import 'package:flutter/services.dart';

/// Google Play's own "fix your payment" message (report issue 5, 25 Nov
/// 2026): after a declined renewal Play shows it over the app, as iOS shows
/// its billing-retry card. Asked for when the app opens and returns to the
/// foreground; Play decides whether there is anything to show. A payment
/// fixed from the message re-reads Premium.
class PlayInAppMessages {
  PlayInAppMessages({required this.refresh, MethodChannel? channel})
    : _channel = channel ?? const MethodChannel('com.ekadashi.play_messages');

  final Future<void> Function() refresh;
  final MethodChannel _channel;

  /// "updated", "none" or "error"; never throws.
  Future<String> show() async {
    String outcome;
    try {
      outcome =
          await _channel.invokeMethod<String>('showSubscriptionMessages') ??
          'error';
    } catch (e) {
      debugPrint('Google Play messages unavailable: $e');
      outcome = 'error';
    }
    debugPrint('Google Play messages: $outcome');
    if (outcome == 'updated') await refresh();
    return outcome;
  }
}
