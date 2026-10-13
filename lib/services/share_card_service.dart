import 'dart:io';
import 'dart:typed_data';
import 'dart:ui' as ui;
import 'package:flutter/material.dart';
import 'package:flutter/rendering.dart';
import 'package:gal/gal.dart';
import 'package:path_provider/path_provider.dart';
import 'package:share_plus/share_plus.dart';

/// Result status of saving an image to the device gallery
enum GallerySaveStatus {
  success,
  permissionDenied,
  failure,
}

/// Detailed result of saving an image to the device gallery
class GallerySaveResult {
  final GallerySaveStatus status;
  final String? errorMessage;

  const GallerySaveResult({required this.status, this.errorMessage});

  factory GallerySaveResult.success() =>
      const GallerySaveResult(status: GallerySaveStatus.success);

  factory GallerySaveResult.permissionDenied([String? message]) =>
      GallerySaveResult(status: GallerySaveStatus.permissionDenied, errorMessage: message);

  factory GallerySaveResult.failure([String? message]) =>
      GallerySaveResult(status: GallerySaveStatus.failure, errorMessage: message);

  bool get isSuccess => status == GallerySaveStatus.success;
  bool get isPermissionDenied => status == GallerySaveStatus.permissionDenied;
  bool get isFailure => status == GallerySaveStatus.failure;
}

/// Available visual themes for the shareable Ekadashi cards (Exclusive Divine Teal/Green theme)
enum CardDesignTheme {
  divineTeal,
}

extension CardDesignThemeExtension on CardDesignTheme {
  String get id => 'divine_teal';

  String get translationKey => 'design_divine_teal';

  List<Color> get gradientColors => const [
        Color(0xFF00332A),
        Color(0xFF002922),
        Color(0xFF00221C),
      ];

  Color get accentColor => const Color(0xFF80CBC4);

  Color get cardBorderColor => const Color(0xFF00A19B).withOpacity(0.75);
}

/// Service to handle rendering, caching, saving, and sharing of Ekadashi cards
class ShareCardService {
  static final ShareCardService _instance = ShareCardService._internal();
  factory ShareCardService() => _instance;
  ShareCardService._internal();

  /// Captures a widget bounded by [boundaryKey] as PNG image bytes.
  Future<Uint8List?> captureBoundaryAsPng(
    GlobalKey boundaryKey, {
    double pixelRatio = 3.0,
  }) async {
    try {
      final boundary = boundaryKey.currentContext?.findRenderObject() as RenderRepaintBoundary?;
      if (boundary == null) {
        debugPrint('⚠️ RenderRepaintBoundary not found for key: $boundaryKey');
        return null;
      }

      // Wait if boundary is still painting
      if (boundary.debugNeedsPaint) {
        await Future.delayed(const Duration(milliseconds: 50));
      }

      final ui.Image image = await boundary.toImage(pixelRatio: pixelRatio);
      final ByteData? byteData = await image.toByteData(format: ui.ImageByteFormat.png);
      if (byteData == null) return null;

      return byteData.buffer.asUint8List();
    } catch (e) {
      debugPrint('⚠️ Error capturing widget to image: $e');
      return null;
    }
  }

  /// Cleans up previously generated temporary card files from the cache directory.
  Future<void> cleanTemporaryCardFiles() async {
    try {
      final tempDir = await getTemporaryDirectory();
      if (tempDir.existsSync()) {
        final files = tempDir.listSync();
        for (final entity in files) {
          if (entity is File) {
            final name = entity.uri.pathSegments.isNotEmpty
                ? entity.uri.pathSegments.last.toLowerCase()
                : entity.path.toLowerCase();
            if (name.startsWith('ekadashi_') && name.endsWith('.png')) {
              try {
                await entity.delete();
              } catch (_) {}
            }
          }
        }
      }
    } catch (e) {
      debugPrint('⚠️ Error cleaning temporary card files: $e');
    }
  }

  /// Writes captured PNG bytes to a local temporary file for sharing.
  Future<File?> saveImageToTemp(Uint8List bytes, {String? filename}) async {
    try {
      await cleanTemporaryCardFiles();
      final tempDir = await getTemporaryDirectory();
      final ext = (filename != null && filename.toLowerCase().endsWith('.png')) ? '' : '.png';
      final base = filename ?? 'ekadashi_card_${DateTime.now().millisecondsSinceEpoch}';
      final name = '$base$ext';
      final file = File('${tempDir.path}/$name');
      await file.writeAsBytes(bytes);
      return file;
    } catch (e) {
      debugPrint('⚠️ Error writing image to temporary file: $e');
      return null;
    }
  }

  /// Saves the card image to the user's public Photos / Gallery.
  /// On Android, saves to Pictures/Ekadashi Calendar using MediaStore.
  /// On iOS, saves to the Photos app library.
  /// Does NOT save to app documents or cache directory.
  Future<GallerySaveResult> saveImageToGallery(
    Uint8List bytes, {
    String? filename,
    String album = 'Ekadashi Calendar',
    @visibleForTesting Future<void> Function(Uint8List bytes, {String? album, String name})? customSaver,
  }) async {
    try {
      final name = filename ?? 'ekadashi_card_${DateTime.now().millisecondsSinceEpoch}';

      if (customSaver != null) {
        await customSaver(bytes, album: album, name: name);
        return GallerySaveResult.success();
      }

      // First try saving with the dedicated album
      try {
        await Gal.putImageBytes(bytes, album: album, name: name);
        return GallerySaveResult.success();
      } on GalException catch (e) {
        if (e.type == GalExceptionType.accessDenied) {
          // On some systems, album creation requires full access while saving to root requires only add.
          try {
            await Gal.putImageBytes(bytes, name: name);
            return GallerySaveResult.success();
          } on GalException catch (e2) {
            if (e2.type == GalExceptionType.accessDenied) {
              return GallerySaveResult.permissionDenied(e2.type.message);
            }
            return GallerySaveResult.failure(e2.type.message);
          }
        }
        return GallerySaveResult.failure(e.type.message);
      }
    } on GalException catch (e) {
      if (e.type == GalExceptionType.accessDenied) {
        return GallerySaveResult.permissionDenied(e.type.message);
      }
      return GallerySaveResult.failure(e.type.message);
    } catch (e) {
      debugPrint('⚠️ Error saving image to gallery: $e');
      return GallerySaveResult.failure(e.toString());
    }
  }

  /// Legacy wrapper for saving image to gallery.
  /// Returns a non-null string ('gallery') on success, or null on failure.
  Future<String?> saveImageToDevice(Uint8List bytes, {String? filename}) async {
    final result = await saveImageToGallery(bytes, filename: filename);
    return result.isSuccess ? 'gallery' : null;
  }

  /// Official Google Play Store download URL for Ekadashi Calendar
  static const String officialDownloadUrl =
      'https://play.google.com/store/apps/details?id=com.applausestudios.ekadashi_calendar';

  /// Official hosted landing page URL featuring the expandable download interaction
  static const String landingPageUrl =
      'https://sakthivel-rajendhran.github.io/ekadashi-calendar/download.html';

  /// Instance getter for official download url
  String get downloadUrl => officialDownloadUrl;

  /// Instance getter for official landing page url
  String get landingUrl => landingPageUrl;

  /// Default share message without emojis containing app description and expandable download link
  static const String defaultShareMessage =
      'Ekadashi Calendar\n\n'
      'Check Ekadashi dates, fasting timings, Parana windows, and spiritual significance.\n\n'
      '[Download the app]($landingPageUrl)';

  /// Instance getter for default share message
  String get shareMessage => defaultShareMessage;

  /// Shares the card image via the native system share sheet.
  /// Accompanying text presents the app description followed by a rich Download App call to action.
  /// Falls back to text sharing if image creation fails.
  Future<bool> shareCard({
    required Uint8List? imageBytes,
    String? shareText,
    String? subject,
    Rect? sharePositionOrigin,
    String? filename,
  }) async {
    try {
      final textToShare = (shareText != null && shareText.trim().isNotEmpty)
          ? shareText.trim()
          : defaultShareMessage;

      if (imageBytes != null && imageBytes.isNotEmpty) {
        final tempFile = await saveImageToTemp(imageBytes, filename: filename);
        if (tempFile != null) {
          final xFile = XFile(tempFile.path, mimeType: 'image/png');
          await Share.shareXFiles(
            [xFile],
            text: textToShare,
            subject: subject,
            sharePositionOrigin: sharePositionOrigin,
          );
          return true;
        }
      }

      // Fallback to text share
      await Share.share(
        textToShare,
        subject: subject,
        sharePositionOrigin: sharePositionOrigin,
      );
      return true;
    } catch (e) {
      debugPrint('⚠️ Error sharing card: $e');
      return false;
    }
  }

  /// Generates the accompanying text for the card share.
  /// Formats the app description followed by a rich-text Download App call to action.
  String buildShareSummary({
    String? ekadashiName,
    String? dateFormatted,
    String? traditionName,
    String? fastingStart,
    String? paranaWindow,
    String? locationName,
    String? spiritualMessage,
  }) {
    return defaultShareMessage;
  }
}
