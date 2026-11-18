import 'dart:async';

import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:provider/provider.dart';

import '../services/language_service.dart';

enum _UpdatePhase { available, downloading, downloaded, failed }

/// App-owned controls for a Play-managed flexible update. The underlying
/// screen stays active while Play downloads the new version.
class PlayUpdateNotice extends StatefulWidget {
  const PlayUpdateNotice({super.key, required this.child});

  final Widget child;

  @override
  State<PlayUpdateNotice> createState() => _PlayUpdateNoticeState();
}

class _PlayUpdateNoticeState extends State<PlayUpdateNotice>
    with WidgetsBindingObserver {
  static const _channel = MethodChannel('com.ekadashi.app_update');
  _UpdatePhase? _phase;
  int? _version;
  int? _dismissedVersion;
  bool _busy = false;
  int _eventRevision = 0;

  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addObserver(this);
    _channel.setMethodCallHandler(_onPlayEvent);
    unawaited(_check());
  }

  @override
  void dispose() {
    _channel.setMethodCallHandler(null);
    WidgetsBinding.instance.removeObserver(this);
    super.dispose();
  }

  @override
  void didChangeAppLifecycleState(AppLifecycleState state) {
    if (state == AppLifecycleState.resumed) unawaited(_check());
  }

  Future<Object?> _onPlayEvent(MethodCall call) async {
    final arguments = call.arguments;
    if (call.method == 'state' && arguments is Map) {
      _eventRevision++;
      _apply(arguments);
    }
    return null;
  }

  Future<void> _check() async {
    final revision = _eventRevision;
    try {
      final status = await _channel.invokeMapMethod<String, Object?>('check');
      if (revision == _eventRevision) _apply(status);
    } on MissingPluginException {
      // Non-Play installations still use the rest of the app.
    } on PlatformException {
      // A transient store error leaves the current screen usable.
    }
  }

  void _apply(Map<Object?, Object?>? status) {
    if (!mounted) return;
    final phase = switch (status?['state']) {
      'available' => _UpdatePhase.available,
      'downloading' => _UpdatePhase.downloading,
      'downloaded' => _UpdatePhase.downloaded,
      'failed' => _UpdatePhase.failed,
      _ => null,
    };
    final code = status?['versionCode'];
    if (phase == _UpdatePhase.available &&
        (_busy || code is! int || code == _dismissedVersion)) {
      return;
    }
    if (phase == null && _busy) return;
    setState(() {
      _phase = phase;
      if (code is int) _version = code;
    });
  }

  void _dismiss() {
    setState(() {
      if (_phase == _UpdatePhase.available) _dismissedVersion = _version;
      _phase = null;
    });
  }

  Future<void> _request({required bool install}) async {
    if (_busy) return;
    setState(() => _busy = true);
    final revision = _eventRevision;
    try {
      final accepted = await _channel.invokeMethod<bool>(
        install ? 'complete' : 'start',
      );
      if (!mounted || revision != _eventRevision) return;
      if (install) {
        if (accepted != true) setState(() => _phase = _UpdatePhase.failed);
      } else if (accepted == true) {
        setState(() => _phase = _UpdatePhase.downloading);
      } else {
        _dismiss();
      }
    } on PlatformException {
      if (mounted) setState(() => _phase = _UpdatePhase.failed);
    } on MissingPluginException {
      if (mounted) _dismiss();
    } finally {
      if (mounted) setState(() => _busy = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    return Column(
      children: [
        if (_phase case final phase?) _notice(context, phase),
        Expanded(
          key: const ValueKey('play_update_content'),
          child: widget.child,
        ),
      ],
    );
  }

  Widget _notice(BuildContext context, _UpdatePhase phase) {
    final lang = context.watch<LanguageService>();
    if (phase == _UpdatePhase.downloading) {
      return Material(
        color: Theme.of(context).colorScheme.surfaceContainer,
        child: Padding(
          padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
          child: Row(
            children: [
              const SizedBox.square(
                dimension: 16,
                child: CircularProgressIndicator(strokeWidth: 2),
              ),
              const SizedBox(width: 12),
              Expanded(child: Text(lang.translate('app_update_downloading'))),
            ],
          ),
        ),
      );
    }
    final message = switch (phase) {
      _UpdatePhase.available => 'app_update_available',
      _UpdatePhase.downloaded => 'app_update_downloaded',
      _UpdatePhase.failed => 'app_update_failed',
      _UpdatePhase.downloading => 'app_update_downloading',
    };
    return MaterialBanner(
      key: const Key('play_update_notice'),
      content: Text(lang.translate(message)),
      actions: [
        if (phase != _UpdatePhase.downloaded)
          TextButton(
            onPressed: _busy ? null : _dismiss,
            child: Text(lang.translate('app_update_later')),
          ),
        if (phase == _UpdatePhase.available)
          TextButton(
            onPressed: _busy ? null : () => _request(install: false),
            child: Text(lang.translate('app_update_now')),
          ),
        if (phase == _UpdatePhase.downloaded)
          TextButton(
            onPressed: _busy ? null : () => _request(install: true),
            child: Text(lang.translate('app_update_restart')),
          ),
      ],
    );
  }
}
