import 'package:flutter_test/flutter_test.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:shared_preferences_platform_interface/shared_preferences_platform_interface.dart';
import 'package:ekadashi_calendar/services/content_catalog_service.dart';

class RejectContentStore extends InMemorySharedPreferencesStore {
  RejectContentStore() : super.empty();
  @override
  Future<bool> setValue(String type, String key, Object value) async {
    if (key.endsWith('ec2_downloaded_content_ids')) return false;
    return super.setValue(type, key, value);
  }
}

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();
  test(
    'Failed offline save does not mark content downloaded or report success',
    () async {
      SharedPreferences.setMockInitialValues({});
      final original = SharedPreferencesStorePlatform.instance;
      SharedPreferencesStorePlatform.instance = RejectContentStore();
      addTearDown(() => SharedPreferencesStorePlatform.instance = original);
      final catalog = ContentCatalogService();
      await catalog.initialize();
      expect(await catalog.downloadItem('failed_offline_fixture'), isFalse);
      expect(catalog.isItemDownloaded('failed_offline_fixture'), isFalse);
    },
  );
}
