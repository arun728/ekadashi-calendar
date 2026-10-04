import 'package:flutter_test/flutter_test.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:ekadashi_calendar/services/reward_wallet_service.dart';
import 'premium_service_test.dart';

class RewardBackend extends Backend {
  final calls = <Map<String, dynamic>>[];
  bool fail = false;
  @override
  Future<Map<String, dynamic>> record(Map<String, dynamic> body) async {
    calls.add(Map.of(body));
    if (fail) throw StateError('offline');
    return {
      'coins': 10,
      'observances': {
        body['uid']: {'version': 1, 'observed': body['status'] == 'observed'},
      },
    };
  }
}

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();
  setUp(() => SharedPreferences.setMockInitialValues({}));
  test(
    'private by default and retry retains exact mutation identity',
    () async {
      final b = RewardBackend();
      final wallet = RewardWalletService(b);
      await wallet.sync('account', {'ekadashi:2026:01': 'observed'}, 'IST');
      expect(b.calls, isEmpty);
      await wallet.activate('account');
      b.fail = true;
      await wallet.sync('account', {'ekadashi:2026:01': 'observed'}, 'IST');
      final key = b.calls.single['mutationKey'];
      b.fail = false;
      final restarted = RewardWalletService(b);
      await restarted.sync('account', {'ekadashi:2026:01': 'observed'}, 'IST');
      expect(b.calls.last['mutationKey'], key);
    },
  );
  test(
    'deletion correction uses last owned version, not other device snapshot',
    () async {
      final b = RewardBackend();
      final wallet = RewardWalletService(b);
      await wallet.activate('account');
      await wallet.sync('account', {'ekadashi:2026:01': 'observed'}, 'IST');
      await wallet.sync('account', {}, 'IST');
      expect(b.calls.last['status'], 'unrecorded');
      expect(b.calls.last['expectedVersion'], 1);
    },
  );
  test(
    'new device missing data never deletes another device records',
    () async {
      final b = RewardBackend();
      final wallet = RewardWalletService(b);
      await wallet.activate('account');
      await wallet.sync('account', {}, 'IST');
      expect(b.calls, isEmpty);
      await wallet.sync('account', {'ekadashi:2026:01': 'missed'}, 'IST');
      expect(b.calls, isEmpty);
    },
  );
  test('account switch does not replay another account queue', () async {
    final b = RewardBackend();
    final wallet = RewardWalletService(b);
    await wallet.activate('first');
    b.fail = true;
    await wallet.sync('first', {'ekadashi:2026:01': 'observed'}, 'IST');
    b.calls.clear();
    b.fail = false;
    await wallet.sync('second', {}, 'IST');
    expect(b.calls, isEmpty);
  });
}
