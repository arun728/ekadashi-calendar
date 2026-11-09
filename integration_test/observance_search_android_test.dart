import 'package:integration_test/integration_test.dart';

import '../test/widget/unified_search_screen_test.dart' as search_checks;

/// Run the same real-engine Search regressions on an Android emulator.
void main() {
  IntegrationTestWidgetsFlutterBinding.ensureInitialized();
  search_checks.main();
}
