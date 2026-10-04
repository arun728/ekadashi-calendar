import 'package:flutter_test/flutter_test.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:ekadashi_calendar/services/devotion_learning_service.dart';

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();
  setUp(() => SharedPreferences.setMockInitialValues({}));
  test(
    'premium bookmarks and review schedule survive restart and downgrade',
    () async {
      bool paid = true;
      final now = DateTime(2026, 10, 4, 9);
      final service = DevotionLearningService(
        premium: () => paid,
        clock: () => now,
      );
      await service.initialize();
      await service.bookmark('verse', 0);
      await service.revise('verse');
      expect(service.bookmarked('verse', 0), isTrue);
      expect(service.due('verse'), DateTime(2026, 10, 5));
      paid = false;
      final restored = DevotionLearningService(
        premium: () => paid,
        clock: () => now,
      );
      await restored.initialize();
      expect(restored.bookmarked('verse', 0), isTrue);
      await expectLater(restored.bookmark('verse', 1), throwsStateError);
      service.dispose();
      restored.dispose();
    },
  );
  test(
    'duplicate same-day revision cannot skip spaced practice intervals',
    () async {
      var now = DateTime(2026, 10, 4);
      final service = DevotionLearningService(
        premium: () => true,
        clock: () => now,
      );
      await service.initialize();
      await service.revise('verse');
      await service.revise('verse');
      expect(service.due('verse'), DateTime(2026, 10, 5));
      now = DateTime(2026, 10, 5);
      await service.revise('verse');
      expect(service.due('verse'), DateTime(2026, 10, 8));
      service.dispose();
    },
  );
}
