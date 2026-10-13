import 'dart:typed_data';
import 'package:flutter/material.dart';
import 'package:intl/intl.dart';
import 'package:provider/provider.dart';
import 'package:gal/gal.dart';
import '../services/ekadashi_service.dart';
import '../services/tradition_service.dart';
import '../services/language_service.dart';
import '../services/native_location_service.dart';
import '../services/native_settings_service.dart';
import '../services/indian_cities_data.dart';
import '../services/share_card_service.dart';
import 'widgets/shareable_ekadashi_card.dart';

/// Screen allowing users to preview and share Ekadashi observance cards
class ShareCardPreviewScreen extends StatefulWidget {
  final EkadashiDate ekadashi;
  final String? timezone;

  const ShareCardPreviewScreen({
    super.key,
    required this.ekadashi,
    this.timezone,
  });

  static const Color tealColor = Color(0xFF00A19B);

  @override
  State<ShareCardPreviewScreen> createState() => _ShareCardPreviewScreenState();
}

class _ShareCardPreviewScreenState extends State<ShareCardPreviewScreen> {
  final GlobalKey _cardKey = GlobalKey();
  final ShareCardService _shareService = ShareCardService();

  static const CardDesignTheme _cardTheme = CardDesignTheme.divineTeal;
  bool _isSharing = false;
  bool _isSaving = false;
  LocationData? _location;

  @override
  void initState() {
    super.initState();
    _loadLocation();
  }

  Future<void> _loadLocation() async {
    final saved = await NativeLocationService().getSavedUserLocation();
    final defaultCity = IndianCitiesData.defaultCity;
    final loc = saved ??
        LocationData(
          latitude: defaultCity.latitude,
          longitude: defaultCity.longitude,
          city: defaultCity.name,
          state: defaultCity.state,
          timezone: defaultCity.timezone,
        );
    if (mounted) {
      setState(() => _location = loc);
    }
  }

  String _generateFileName() {
    final namePart = widget.ekadashi.name
        .replaceAll(RegExp(r'[^a-zA-Z0-9\s]'), '')
        .split(RegExp(r'\s+'))
        .firstWhere(
          (p) => p.isNotEmpty && p.toLowerCase() != 'ekadashi',
          orElse: () => 'Observance',
        );
    final dateStr = DateFormat('yyyy-MM-dd').format(widget.ekadashi.date);
    return 'Ekadashi_${namePart}_$dateStr';
  }

  Future<void> _handleShare() async {
    if (_isSharing) return;
    setState(() => _isSharing = true);

    try {
      // 1. Capture the widget as high-resolution PNG
      final Uint8List? imageBytes = await _shareService.captureBoundaryAsPng(
        _cardKey,
        pixelRatio: 3.0,
      );

      // 2. Prepare accompanying text: app description and Download App call-to-action
      final shareText = _shareService.buildShareSummary();
      final filename = _generateFileName();

      if (!mounted) return;

      // 3. Trigger native share
      final box = context.findRenderObject() as RenderBox?;
      final origin =
          box != null ? box.localToGlobal(Offset.zero) & box.size : null;

      await _shareService.shareCard(
        imageBytes: imageBytes,
        shareText: shareText,
        subject: widget.ekadashi.name,
        sharePositionOrigin: origin,
        filename: filename,
      );
    } catch (e) {
      debugPrint('⚠️ Error in _handleShare: $e');
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text('Sharing error: $e'),
            backgroundColor: Colors.red.shade700,
          ),
        );
      }
    } finally {
      if (mounted) {
        setState(() => _isSharing = false);
      }
    }
  }

  Future<void> _handleSave() async {
    if (_isSaving) return;
    setState(() => _isSaving = true);

    try {
      final lang = Provider.of<LanguageService>(context, listen: false);
      final Uint8List? imageBytes = await _shareService.captureBoundaryAsPng(
        _cardKey,
        pixelRatio: 3.0,
      );

      if (imageBytes == null || imageBytes.isEmpty) {
        throw Exception('Failed to generate image bytes');
      }

      final filename = _generateFileName();
      final result = await _shareService.saveImageToGallery(
        imageBytes,
        filename: filename,
      );

      if (!mounted) return;

      if (result.isSuccess) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Row(
              children: [
                const Icon(Icons.check_circle, color: Colors.white, size: 20),
                const SizedBox(width: 8),
                Expanded(child: Text(lang.translate('gallery_save_success'))),
              ],
            ),
            backgroundColor: ShareCardPreviewScreen.tealColor,
            duration: const Duration(seconds: 3),
          ),
        );
      } else if (result.isPermissionDenied) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text(lang.translate('gallery_permission_denied')),
            backgroundColor: Colors.orange.shade800,
            duration: const Duration(seconds: 6),
            action: SnackBarAction(
              label: lang.translate('open_settings'),
              textColor: Colors.white,
              onPressed: () async {
                try {
                  await NativeSettingsService().openAppSettings();
                } catch (_) {
                  try {
                    await Gal.open();
                  } catch (_) {}
                }
              },
            ),
          ),
        );
      } else {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text(
              result.errorMessage ?? lang.translate('gallery_save_error'),
            ),
            backgroundColor: Colors.red.shade700,
            duration: const Duration(seconds: 4),
          ),
        );
      }
    } catch (e) {
      debugPrint('⚠️ Error in _handleSave: $e');
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text('Save error: $e'),
            backgroundColor: Colors.red.shade700,
          ),
        );
      }
    } finally {
      if (mounted) {
        setState(() => _isSaving = false);
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    final lang = Provider.of<LanguageService>(context);
    final traditionService = Provider.of<TraditionService>(context);

    return Scaffold(
      appBar: AppBar(
        title: Text(
          lang.translate('share_card_title'),
          style: const TextStyle(fontWeight: FontWeight.bold),
        ),
        centerTitle: true,
      ),
      body: SingleChildScrollView(
        padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 16),
        child: Column(
          children: [
            // Card Preview Area (Clean Emerald Green Theme)
            Center(
              child: RepaintBoundary(
                key: _cardKey,
                child: ShareableEkadashiCard(
                  ekadashi: widget.ekadashi,
                  theme: _cardTheme,
                  tradition: traditionService.currentTradition,
                  lang: lang,
                  location: _location,
                ),
              ),
            ),
            const SizedBox(height: 24),

            // Action Buttons (Share & Save)
            Row(
              children: [
                // Save Button
                Expanded(
                  child: OutlinedButton.icon(
                    onPressed: _isSaving || _isSharing ? null : _handleSave,
                    icon: _isSaving
                        ? const SizedBox(
                            width: 16,
                            height: 16,
                            child: CircularProgressIndicator(strokeWidth: 2),
                          )
                        : const Icon(Icons.download_rounded, size: 20),
                    label: Text(lang.translate('save_to_device')),
                    style: OutlinedButton.styleFrom(
                      padding: const EdgeInsets.symmetric(vertical: 14),
                      side: const BorderSide(
                        color: ShareCardPreviewScreen.tealColor,
                      ),
                      foregroundColor: ShareCardPreviewScreen.tealColor,
                      shape: RoundedRectangleBorder(
                        borderRadius: BorderRadius.circular(12),
                      ),
                    ),
                  ),
                ),
                const SizedBox(width: 12),

                // Share Button
                Expanded(
                  flex: 2,
                  child: ElevatedButton.icon(
                    onPressed: _isSharing || _isSaving ? null : _handleShare,
                    icon: _isSharing
                        ? const SizedBox(
                            width: 18,
                            height: 18,
                            child: CircularProgressIndicator(
                              strokeWidth: 2,
                              color: Colors.white,
                            ),
                          )
                        : const Icon(
                            Icons.share_rounded,
                            size: 20,
                            color: Colors.white,
                          ),
                    label: Text(
                      _isSharing
                          ? lang.translate('sharing_card')
                          : lang.translate('share_card'),
                      style: const TextStyle(
                        fontSize: 15,
                        fontWeight: FontWeight.bold,
                        color: Colors.white,
                      ),
                    ),
                    style: ElevatedButton.styleFrom(
                      backgroundColor: ShareCardPreviewScreen.tealColor,
                      padding: const EdgeInsets.symmetric(vertical: 14),
                      shape: RoundedRectangleBorder(
                        borderRadius: BorderRadius.circular(12),
                      ),
                      elevation: 2,
                    ),
                  ),
                ),
              ],
            ),
            const SizedBox(height: 24),
          ],
        ),
      ),
    );
  }
}
