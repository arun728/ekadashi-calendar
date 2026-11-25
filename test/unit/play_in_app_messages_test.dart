import 'package:ekadashi_calendar/services/play_in_app_messages.dart';
import 'package:flutter/services.dart';
import 'package:flutter_test/flutter_test.dart';

/// Report issue 5 (25 Nov 2026): after a declined renewal Android shows
/// Google Play's own "fix your payment" message (Play in-app messaging), as
/// iOS shows its billing-retry card. A fixed payment re-reads Premium.
void main() {
  TestWidgetsFlutterBinding.ensureInitialized();
  const channel = MethodChannel('com.ekadashi.play_messages');
  final messenger =
      TestDefaultBinaryMessengerBinding.instance.defaultBinaryMessenger;
  tearDown(() => messenger.setMockMethodCallHandler(channel, null));

  Future<(String, int, List<String>)> run(Object? reply) async {
    final calls = <String>[];
    messenger.setMockMethodCallHandler(channel, (call) async {
      calls.add(call.method);
      if (reply is Exception) throw reply;
      return reply;
    });
    var refreshes = 0;
    final messages = PlayInAppMessages(refresh: () async => refreshes++);
    final outcome = await messages.show();
    return (outcome, refreshes, calls);
  }

  test('asks Google Play for its subscription messages', () async {
    final (outcome, refreshes, calls) = await run('none');
    expect(calls, ['showSubscriptionMessages']);
    expect(outcome, 'none');
    expect(refreshes, 0);
  });

  test('a payment fixed from the message re-reads Premium', () async {
    final (outcome, refreshes, _) = await run('updated');
    expect(outcome, 'updated');
    expect(refreshes, 1);
  });

  test('Play errors never reach the user', () async {
    expect((await run(PlatformException(code: 'x'))).$1, 'error');
    expect((await run(null)).$1, 'error');
  });
}
