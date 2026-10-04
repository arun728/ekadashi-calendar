import 'package:flutter_test/flutter_test.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:ekadashi_calendar/services/practice_service.dart';

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();
  setUp(() => SharedPreferences.setMockInitialValues({}));
  test(
    'durable session restores counts and deduplicates replayed input',
    () async {
      final service = PracticeService(premium: () => false);
      await service.initialize();
      await service.start();
      await Future.wait([
        service.increment('tap-a'),
        service.increment('tap-a'),
        service.increment('tap-b'),
      ]);
      expect(service.count, 2);
      final restored = PracticeService(premium: () => false);
      await restored.initialize();
      expect(restored.count, 2);
      expect(restored.running, isTrue);
      await restored.increment('tap-a');
      expect(restored.count, 2);
      service.dispose();
      restored.dispose();
    },
  );
  test(
    'completion is idempotent and basic streak crosses year boundary',
    () async {
      var now = DateTime(2026, 12, 31, 20);
      final service = PracticeService(premium: () => false, clock: () => now);
      await service.initialize();
      await service.start();
      await service.increment('day-one');
      await service.finish();
      await service.finish();
      expect(service.streak, 1);
      now = DateTime(2027, 1, 1, 9);
      await service.start();
      await service.increment('day-two');
      await service.finish();
      expect(service.streak, 2);
      service.dispose();
    },
  );
  test('advanced sessions require current verified premium', () async {
    final service = PracticeService(premium: () => false);
    await service.initialize();
    await expectLater(
      service.start(
        mantra: 'Personal practice',
        goal: 216,
        malaSize: 54,
        haptics: true,
      ),
      throwsStateError,
    );
    expect(service.running, isFalse);
    service.dispose();
  });
  test(
    'failed storage never publishes a count or loses the recoverable session',
    () async {
      String? stored;
      bool fail = false;
      final service = PracticeService(
        premium: () => false,
        read: () async => stored,
        write: (value) async {
          if (fail) return false;
          stored = value;
          return true;
        },
      );
      await service.initialize();
      await service.start();
      fail = true;
      await expectLater(service.increment('first'), throwsStateError);
      expect(service.count, 0);
      fail = false;
      await service.increment('first');
      expect(service.count, 1);
      service.dispose();
    },
  );
  test(
    'downgrade retains goals and history but prevents new advanced sessions',
    () async {
      bool paid = true;
      final service = PracticeService(premium: () => paid);
      await service.initialize();
      await service.saveGoal(mantra: 'My practice', goal: 216, malaSize: 108);
      await service.start(mantra: 'My practice', goal: 216);
      await service.increment('a');
      paid = false;
      await service.finish();
      expect(service.sessions.single['count'], 1);
      expect(service.goals, hasLength(1));
      await expectLater(service.start(mantra: 'My practice'), throwsStateError);
      await service.start();
      expect(service.hasSession, isTrue);
      service.dispose();
    },
  );
  test(
    'free routine quota and durable completion do not touch Vrat or rewards',
    () async {
      final service = PracticeService(premium: () => false);
      await service.initialize();
      const routine = PracticeRoutine(
        id: 'one',
        title: 'Morning',
        steps: ['chant', 'reflect'],
      );
      await service.saveRoutine(routine);
      await expectLater(
        service.saveRoutine(
          const PracticeRoutine(id: 'two', title: 'Evening', steps: ['read']),
        ),
        throwsStateError,
      );
      await service.toggleStep('one', 0);
      expect(service.streak, 0);
      await service.toggleStep('one', 1);
      expect(service.streak, 1);
      final restored = PracticeService(premium: () => false);
      await restored.initialize();
      expect(restored.checked('one', 0), isTrue);
      final preferences = await SharedPreferences.getInstance();
      expect(preferences.getKeys(), {PracticeService.storageKey});
      service.dispose();
      restored.dispose();
    },
  );
  test('editing routine steps invalidates old checkmarks', () async {
    final service = PracticeService(premium: () => false);
    await service.initialize();
    await service.saveRoutine(
      const PracticeRoutine(id: 'r', title: 'Morning', steps: ['chant']),
    );
    await service.toggleStep('r', 0);
    await service.saveRoutine(
      const PracticeRoutine(id: 'r', title: 'Morning', steps: ['read']),
    );
    expect(service.checked('r', 0), isFalse);
    service.dispose();
  });
}
