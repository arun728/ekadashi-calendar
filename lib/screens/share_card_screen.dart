import 'dart:io';
import 'dart:typed_data';
import 'dart:ui' as ui;

import 'package:flutter/material.dart';
import 'package:flutter/rendering.dart';
import 'package:gal/gal.dart';
import 'package:path_provider/path_provider.dart';
import 'package:provider/provider.dart';
import 'package:share_plus/share_plus.dart';

import '../l10n/app_language.dart';
import '../services/app_links.dart';
import '../services/ekadashi_service.dart';
import '../services/ekadashi_settings.dart';
import '../services/language_service.dart';
import 'widgets/ekadashi_share_card.dart';
import '../widgets/app_icons.dart';
import '../widgets/ios_style.dart';

/// Opens the share card of [event] (Home's share button, Details).
Future<void> openShareCard(BuildContext context, EkadashiDate event) =>
    showAppSheet<void>(context, builder: (_) => ShareCardScreen(event: event));

/// Preview of an Ekadashi share card with Share (the image and a message
/// with the Play Store link) and Save to Gallery (ShareCardSheet.swift).
/// Free: no paywall.
class ShareCardScreen extends StatefulWidget {
  const ShareCardScreen({super.key, required this.event});

  final EkadashiDate event;

  @override
  State<ShareCardScreen> createState() => _ShareCardScreenState();
}

class _ShareCardScreenState extends State<ShareCardScreen> {
  final _boundary = GlobalKey();
  String? _status;
  bool _busy = false;

  String get _language =>
      context.read<LanguageService>().currentLocale.languageCode;

  /// The card as a PNG at three times its size.
  Future<Uint8List?> _capture() async {
    final boundary =
        _boundary.currentContext?.findRenderObject() as RenderRepaintBoundary?;
    if (boundary == null) return null;
    final image = await boundary.toImage(pixelRatio: 3);
    final data = await image.toByteData(format: ui.ImageByteFormat.png);
    return data?.buffer.asUint8List();
  }

  String get _fileName =>
      'ekadashi_${widget.event.occurrenceUid.replaceAll(':', '_')}';

  Future<void> _share() async {
    setState(() => _busy = true);
    try {
      final bytes = await _capture();
      final message = AppLinks.shareCardMessage(
        AppStrings.translateWithArgs('share_card_message', _language, [
          widget.event.name,
          AppStrings.fullDate(widget.event.date, _language),
        ]),
      );
      if (bytes == null) {
        await Share.share(message);
        return;
      }
      final file = File(
        '${(await getTemporaryDirectory()).path}/$_fileName.png',
      );
      await file.writeAsBytes(bytes);
      await Share.shareXFiles([
        XFile(file.path, mimeType: 'image/png'),
      ], text: message);
    } catch (e) {
      debugPrint('Share card: $e');
    } finally {
      if (mounted) setState(() => _busy = false);
    }
  }

  /// Adds the card to the gallery (Pictures/Ekadashi Calendar).
  Future<void> _save() async {
    setState(() {
      _busy = true;
      _status = null;
    });
    String key;
    try {
      final bytes = await _capture();
      if (bytes == null) throw StateError('no image');
      if (!await Gal.hasAccess(toAlbum: true)) {
        await Gal.requestAccess(toAlbum: true);
      }
      await Gal.putImageBytes(
        bytes,
        album: 'Ekadashi Calendar',
        name: _fileName,
      );
      key = 'share_card_saved';
    } on GalException catch (e) {
      key = e.type == GalExceptionType.accessDenied
          ? 'share_card_photos_denied'
          : 'share_card_save_failed';
    } catch (_) {
      key = 'share_card_save_failed';
    }
    if (mounted) {
      setState(() {
        _busy = false;
        _status = AppStrings.translate(key, _language);
      });
    }
  }

  @override
  Widget build(BuildContext context) {
    final lang = context.watch<LanguageService>();
    final language = lang.currentLocale.languageCode;
    final settings = context.watch<EkadashiSettings?>();
    final content = ShareCardContent.of(
      widget.event,
      language: language,
      tradition: lang.translate(
        settings?.traditionNameKey ?? EkadashiSettings.traditionKeyFor(null),
      ),
    );
    const teal = Color(0xFF00A19B);
    return Scaffold(
      appBar: PreferredSize(
        preferredSize: const Size.fromHeight(56),
        child: SheetBar(
          title: lang.translate('share_card_title'),
          leading: BarTextButton(
            label: lang.translate('cancel'),
            onPressed: () => Navigator.of(context).maybePop(),
          ),
        ),
      ),
      body: SafeArea(
        child: SingleChildScrollView(
          padding: const EdgeInsets.all(20),
          child: Column(
            children: [
              // The card keeps its 360 width; a narrower screen scales it.
              FittedBox(
                fit: BoxFit.scaleDown,
                child: DecoratedBox(
                  decoration: BoxDecoration(
                    borderRadius: BorderRadius.circular(24),
                    boxShadow: [
                      BoxShadow(
                        color: Colors.black.withValues(alpha: 0.35),
                        blurRadius: 14,
                        offset: const Offset(0, 6),
                      ),
                    ],
                  ),
                  child: RepaintBoundary(
                    key: _boundary,
                    child: EkadashiShareCard(
                      key: const Key('share_card_preview'),
                      content: content,
                    ),
                  ),
                ),
              ),
              const SizedBox(height: 20),
              Row(
                children: [
                  Expanded(
                    child: OutlinedButton.icon(
                      key: const Key('share_card_save'),
                      onPressed: _busy ? null : _save,
                      style: OutlinedButton.styleFrom(
                        foregroundColor: teal,
                        padding: const EdgeInsets.symmetric(vertical: 14),
                      ),
                      icon: const Icon(AppIcons.save),
                      label: Text(lang.translate('share_card_save')),
                    ),
                  ),
                  const SizedBox(width: 10),
                  Expanded(
                    child: FilledButton.icon(
                      key: const Key('share_card_share'),
                      onPressed: _busy ? null : _share,
                      style: FilledButton.styleFrom(
                        backgroundColor: teal,
                        padding: const EdgeInsets.symmetric(vertical: 14),
                      ),
                      icon: const Icon(AppIcons.share),
                      label: Text(lang.translate('share')),
                    ),
                  ),
                ],
              ),
              if (_status != null) ...[
                const SizedBox(height: 12),
                Text(
                  _status!,
                  key: const Key('share_card_status'),
                  textAlign: TextAlign.center,
                  style: TextStyle(color: Colors.grey.shade500, fontSize: 13),
                ),
              ],
            ],
          ),
        ),
      ),
    );
  }
}
