import 'package:flutter/material.dart';
import 'package:share_plus/share_plus.dart';
import '../models/search_content_type.dart';
import '../models/search_result.dart';

/// Unified detail screen for non-Ekadashi search results (Katha, Mantra, Food, Vrat, Festival, Temple, Event).
class SearchDetailScreen extends StatelessWidget {
  final SearchResult result;
  final VoidCallback? onDownload;

  const SearchDetailScreen({
    super.key,
    required this.result,
    this.onDownload,
  });

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final isDark = theme.brightness == Brightness.dark;

    return Scaffold(
      appBar: AppBar(
        title: Text(result.contentType.displayName),
        centerTitle: true,
        actions: [
          IconButton(
            icon: const Icon(Icons.share),
            tooltip: 'Share',
            onPressed: () {
              Share.share('${result.title}\n\n${result.subtitle}\n\n— Via Ekadashi Calendar App');
            },
          ),
        ],
      ),
      body: SingleChildScrollView(
        padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 16),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            // Top Badge & Online/Offline Status
            Row(
              children: [
                Container(
                  padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 4),
                  decoration: BoxDecoration(
                    color: result.contentType.color.withValues(alpha: 0.15),
                    borderRadius: BorderRadius.circular(12),
                    border: Border.all(color: result.contentType.color.withValues(alpha: 0.4)),
                  ),
                  child: Row(
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      Icon(result.contentType.icon, size: 14, color: result.contentType.color),
                      const SizedBox(width: 4),
                      Text(
                        result.contentType.typeKey,
                        style: TextStyle(
                          fontSize: 11,
                          fontWeight: FontWeight.bold,
                          color: result.contentType.color,
                        ),
                      ),
                    ],
                  ),
                ),
                const Spacer(),
                if (result.isOnlineOnly)
                  Container(
                    padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
                    decoration: BoxDecoration(
                      color: Colors.amber.withValues(alpha: 0.15),
                      borderRadius: BorderRadius.circular(10),
                      border: Border.all(color: Colors.amber),
                    ),
                    child: const Text(
                      'ONLINE ONLY',
                      style: TextStyle(fontSize: 10, fontWeight: FontWeight.bold, color: Colors.amber),
                    ),
                  )
                else if (result.isDownloaded)
                  Container(
                    padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
                    decoration: BoxDecoration(
                      color: Colors.green.withValues(alpha: 0.15),
                      borderRadius: BorderRadius.circular(10),
                      border: Border.all(color: Colors.green),
                    ),
                    child: const Row(
                      mainAxisSize: MainAxisSize.min,
                      children: [
                        Icon(Icons.check_circle, size: 12, color: Colors.green),
                        SizedBox(width: 4),
                        Text(
                          'DOWNLOADED',
                          style: TextStyle(fontSize: 10, fontWeight: FontWeight.bold, color: Colors.green),
                        ),
                      ],
                    ),
                  ),
              ],
            ),
            const SizedBox(height: 16),

            // Title
            Text(
              result.title,
              style: const TextStyle(
                fontSize: 24,
                fontWeight: FontWeight.bold,
                height: 1.25,
              ),
            ),
            const SizedBox(height: 8),

            // Date / Location (if present)
            if (result.date != null && result.date!.isNotEmpty) ...[
              Row(
                children: [
                  const Icon(Icons.event, size: 16, color: Colors.grey),
                  const SizedBox(width: 6),
                  Text(
                    result.date!,
                    style: TextStyle(fontSize: 14, color: Colors.grey.shade400),
                  ),
                ],
              ),
              const SizedBox(height: 12),
            ],

            const Divider(height: 24),

            // Download CTA (if online only)
            if (result.isOnlineOnly) ...[
              Container(
                margin: const EdgeInsets.only(bottom: 20),
                padding: const EdgeInsets.all(14),
                decoration: BoxDecoration(
                  color: isDark ? const Color(0xFF1E293B) : Colors.grey.shade100,
                  borderRadius: BorderRadius.circular(12),
                  border: Border.all(color: Colors.amber.withValues(alpha: 0.4)),
                ),
                child: Row(
                  children: [
                    const Icon(Icons.cloud_download, color: Colors.amber, size: 24),
                    const SizedBox(width: 12),
                    const Expanded(
                      child: Text(
                        'This item is currently online only. Download it for offline access.',
                        style: TextStyle(fontSize: 13),
                      ),
                    ),
                    ElevatedButton(
                      onPressed: onDownload,
                      style: ElevatedButton.styleFrom(
                        backgroundColor: Colors.amber,
                        foregroundColor: Colors.black,
                        padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 8),
                      ),
                      child: const Text('Download', style: TextStyle(fontWeight: FontWeight.bold)),
                    ),
                  ],
                ),
              ),
            ],

            // Content Sections
            _buildContentSections(context, result),

            const SizedBox(height: 30),
          ],
        ),
      ),
    );
  }

  Widget _buildContentSections(BuildContext context, SearchResult item) {
    final meta = item.sourceData;
    final isDark = Theme.of(context).brightness == Brightness.dark;

    switch (item.contentType) {
      case SearchContentType.katha:
        final story = meta['full_story'] as String? ?? item.subtitle;
        final source = meta['source'] as String? ?? 'Sacred Scripture';
        return Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            _buildSectionHeader('Sacred Story & History', Icons.menu_book),
            const SizedBox(height: 8),
            Text(story, style: const TextStyle(fontSize: 16, height: 1.6)),
            const SizedBox(height: 16),
            _buildInfoCard('Scriptural Source', source, isDark),
          ],
        );

      case SearchContentType.mantra:
        final sanskrit = meta['sanskrit'] as String? ?? '';
        final transliteration = meta['transliteration'] as String? ?? '';
        final meaning = meta['meaning'] as String? ?? item.subtitle;
        final benefits = meta['benefits'] as String? ?? '';
        final source = meta['source'] as String? ?? '';
        return Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            if (sanskrit.isNotEmpty) ...[
              _buildHighlightBox(sanskrit, isDark),
              const SizedBox(height: 16),
            ],
            if (transliteration.isNotEmpty) ...[
              _buildSectionHeader('Transliteration', Icons.record_voice_over),
              const SizedBox(height: 6),
              Text(transliteration, style: const TextStyle(fontSize: 16, fontStyle: FontStyle.italic, height: 1.5)),
              const SizedBox(height: 16),
            ],
            _buildSectionHeader('Meaning', Icons.translate),
            const SizedBox(height: 6),
            Text(meaning, style: const TextStyle(fontSize: 16, height: 1.5)),
            const SizedBox(height: 16),
            if (benefits.isNotEmpty) ...[
              _buildSectionHeader('Spiritual Benefits', Icons.star),
              const SizedBox(height: 6),
              Text(benefits, style: const TextStyle(fontSize: 15, height: 1.5)),
              const SizedBox(height: 16),
            ],
            if (source.isNotEmpty) _buildInfoCard('Reference', source, isDark),
          ],
        );

      case SearchContentType.food:
        final itemsList = meta['items'] as List<dynamic>?;
        final ingredients = meta['ingredients'] as String?;
        final steps = meta['steps'] as String?;
        final guidelines = meta['guidelines'] as String?;
        final reason = meta['reason'] as String?;
        return Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text(item.subtitle, style: const TextStyle(fontSize: 16, height: 1.5)),
            const SizedBox(height: 16),
            if (itemsList != null) ...[
              _buildSectionHeader('List of Foods', Icons.checklist),
              const SizedBox(height: 8),
              ...itemsList.map((foodItem) => Padding(
                    padding: const EdgeInsets.only(bottom: 8),
                    child: Row(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        const Text('• ', style: TextStyle(fontSize: 16, color: Color(0xFF00A19B), fontWeight: FontWeight.bold)),
                        Expanded(child: Text(foodItem.toString(), style: const TextStyle(fontSize: 15, height: 1.4))),
                      ],
                    ),
                  )),
              const SizedBox(height: 16),
            ],
            if (ingredients != null) ...[
              _buildSectionHeader('Ingredients', Icons.kitchen),
              const SizedBox(height: 6),
              Text(ingredients, style: const TextStyle(fontSize: 15, height: 1.5)),
              const SizedBox(height: 16),
            ],
            if (steps != null) ...[
              _buildSectionHeader('Preparation Steps', Icons.restaurant),
              const SizedBox(height: 6),
              Text(steps, style: const TextStyle(fontSize: 15, height: 1.5)),
              const SizedBox(height: 16),
            ],
            if (guidelines != null) _buildInfoCard('Guideline', guidelines, isDark),
            if (reason != null) _buildInfoCard('Scriptural Reason', reason, isDark),
          ],
        );

      case SearchContentType.vratInfo:
        final keyRules = meta['key_rules'] as List<dynamic>?;
        final stages = meta['stages'] as List<dynamic>?;
        final levels = meta['levels'] as List<dynamic>?;
        final importance = meta['importance'] as String?;
        return Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text(item.subtitle, style: const TextStyle(fontSize: 16, height: 1.5)),
            const SizedBox(height: 16),
            if (keyRules != null) ...[
              _buildSectionHeader('Key Principles', Icons.rule),
              const SizedBox(height: 8),
              ...keyRules.map((rule) => Padding(
                    padding: const EdgeInsets.only(bottom: 8),
                    child: Row(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        const Icon(Icons.check_circle_outline, size: 18, color: Color(0xFF00A19B)),
                        const SizedBox(width: 8),
                        Expanded(child: Text(rule.toString(), style: const TextStyle(fontSize: 15, height: 1.4))),
                      ],
                    ),
                  )),
              const SizedBox(height: 16),
            ],
            if (stages != null) ...[
              _buildSectionHeader('Three-Day Observance', Icons.calendar_view_day),
              const SizedBox(height: 8),
              ...stages.map((stage) => Container(
                    margin: const EdgeInsets.only(bottom: 10),
                    padding: const EdgeInsets.all(12),
                    decoration: BoxDecoration(
                      color: isDark ? const Color(0xFF1E293B) : Colors.grey.shade100,
                      borderRadius: BorderRadius.circular(10),
                    ),
                    child: Text(stage.toString(), style: const TextStyle(fontSize: 14, height: 1.4)),
                  )),
              const SizedBox(height: 16),
            ],
            if (levels != null) ...[
              _buildSectionHeader('Fast Classifications', Icons.layers),
              const SizedBox(height: 8),
              ...levels.map((lvl) => Padding(
                    padding: const EdgeInsets.only(bottom: 8),
                    child: Text(lvl.toString(), style: const TextStyle(fontSize: 15, height: 1.4)),
                  )),
              const SizedBox(height: 16),
            ],
            if (importance != null) _buildInfoCard('Significance', importance, isDark),
          ],
        );

      case SearchContentType.festival:
        final significance = meta['significance'] as String? ?? item.subtitle;
        final rituals = meta['rituals'] as String? ?? '';
        return Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            _buildSectionHeader('Significance', Icons.celebration),
            const SizedBox(height: 8),
            Text(significance, style: const TextStyle(fontSize: 16, height: 1.5)),
            const SizedBox(height: 16),
            if (rituals.isNotEmpty) ...[
              _buildSectionHeader('Celebration Rituals', Icons.wb_sunny),
              const SizedBox(height: 8),
              Text(rituals, style: const TextStyle(fontSize: 15, height: 1.5)),
            ],
          ],
        );

      case SearchContentType.temple:
        final location = meta['location'] as String? ?? '';
        final deity = meta['deity'] as String? ?? '';
        final highlights = meta['highlights'] as String? ?? item.subtitle;
        return Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            if (location.isNotEmpty) ...[
              _buildInfoCard('Location', location, isDark),
              const SizedBox(height: 12),
            ],
            if (deity.isNotEmpty) ...[
              _buildInfoCard('Presiding Deity', deity, isDark),
              const SizedBox(height: 16),
            ],
            _buildSectionHeader('Temple Highlights', Icons.temple_hindu),
            const SizedBox(height: 8),
            Text(highlights, style: const TextStyle(fontSize: 16, height: 1.5)),
          ],
        );

      case SearchContentType.event:
        final location = meta['location'] as String? ?? '';
        final highlights = meta['highlights'] as String? ?? item.subtitle;
        final description = meta['description'] as String? ?? '';
        return Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            if (location.isNotEmpty) ...[
              _buildInfoCard('Location / Route', location, isDark),
              const SizedBox(height: 16),
            ],
            _buildSectionHeader('Event Details', Icons.event),
            const SizedBox(height: 8),
            Text(highlights.isNotEmpty ? highlights : description, style: const TextStyle(fontSize: 16, height: 1.5)),
          ],
        );

      default:
        return Text(item.subtitle, style: const TextStyle(fontSize: 16, height: 1.5));
    }
  }

  Widget _buildSectionHeader(String title, IconData icon) {
    return Row(
      children: [
        Icon(icon, size: 18, color: const Color(0xFF00A19B)),
        const SizedBox(width: 8),
        Text(
          title,
          style: const TextStyle(
            fontSize: 18,
            fontWeight: FontWeight.bold,
            color: Color(0xFF00A19B),
          ),
        ),
      ],
    );
  }

  Widget _buildHighlightBox(String text, bool isDark) {
    return Container(
      width: double.infinity,
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: isDark ? const Color(0xFF131D31) : const Color(0xFFF0FDFA),
        borderRadius: BorderRadius.circular(12),
        border: Border.all(color: const Color(0xFF00A19B).withValues(alpha: 0.3)),
      ),
      child: Text(
        text,
        style: const TextStyle(
          fontSize: 18,
          fontWeight: FontWeight.bold,
          height: 1.5,
          color: Color(0xFF00A19B),
        ),
        textAlign: TextAlign.center,
      ),
    );
  }

  Widget _buildInfoCard(String label, String value, bool isDark) {
    return Container(
      width: double.infinity,
      padding: const EdgeInsets.all(12),
      decoration: BoxDecoration(
        color: isDark ? const Color(0xFF1E293B) : Colors.grey.shade100,
        borderRadius: BorderRadius.circular(10),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(label, style: const TextStyle(fontSize: 12, fontWeight: FontWeight.bold, color: Colors.grey)),
          const SizedBox(height: 2),
          Text(value, style: const TextStyle(fontSize: 14, height: 1.3)),
        ],
      ),
    );
  }
}
