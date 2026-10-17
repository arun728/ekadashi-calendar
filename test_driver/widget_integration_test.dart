import 'dart:io';
import 'package:integration_test/integration_test_driver_extended.dart';

Future<void> main() => integrationDriver(
  onScreenshot: (name, bytes, [args]) async {
    final folder = Directory(
      Platform.environment['WIDGET_SCREENSHOT_DIR'] ??
          'build/widget-screenshots',
    );
    await folder.create(recursive: true);
    await File('${folder.path}/$name.png').writeAsBytes(bytes);
    return true;
  },
);
