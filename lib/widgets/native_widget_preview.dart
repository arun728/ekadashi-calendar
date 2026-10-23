import 'dart:convert';
import 'dart:io';
import 'package:flutter/foundation.dart';
import 'package:flutter/gestures.dart';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';

/// Hosts the same Kotlin/XML renderer as installed Android widgets.
class NativeWidgetPreview extends StatefulWidget {
  const NativeWidgetPreview({
    super.key,
    required this.payload,
    required this.upcoming,
    required this.width,
    required this.height,
    required this.now,
    required this.onOpenOccurrence,
    this.live = false,
  });
  final Map<String, dynamic> payload;
  final bool upcoming, live;
  final double width, height;
  final DateTime now;
  final ValueChanged<String> onOpenOccurrence;

  @override
  State<NativeWidgetPreview> createState() => _NativeWidgetPreviewState();
}

class _NativeWidgetPreviewState extends State<NativeWidgetPreview> {
  MethodChannel? _channel;
  Map<String, Object> get _arguments => {
    'payloadJson': jsonEncode(widget.payload),
    'upcoming': widget.upcoming,
    'live': widget.live,
    'width': widget.width,
    'height': widget.height,
    'now': widget.now.toUtc().toIso8601String(),
  };
  @override
  void didUpdateWidget(covariant NativeWidgetPreview oldWidget) {
    super.didUpdateWidget(oldWidget);
    _channel?.invokeMethod<void>('update', _arguments);
  }

  void _created(int id) {
    _channel = MethodChannel('com.ekadashi.widget/preview/$id')
      ..setMethodCallHandler((call) async {
        if (call.method == 'openOccurrence' && call.arguments is String) {
          widget.onOpenOccurrence(call.arguments as String);
        }
      });
  }

  @override
  void dispose() {
    _channel?.setMethodCallHandler(null);
    super.dispose();
  }

  @override
  Widget build(BuildContext context) => SizedBox(
    width: widget.width,
    height: widget.height,
    child: !kIsWeb && Platform.isAndroid
        ? AndroidView(
            viewType: 'com.ekadashi.widget/preview',
            creationParams: _arguments,
            creationParamsCodec: const StandardMessageCodec(),
            onPlatformViewCreated: _created,
            gestureRecognizers: {
              Factory<OneSequenceGestureRecognizer>(
                () => EagerGestureRecognizer(),
              ),
            },
          )
        : const SizedBox.expand(),
  );
}
