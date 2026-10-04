import '../widgets/devotion_theme.dart';
import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import '../services/language_service.dart';
import '../services/premium_service.dart';
import '../services/devotion_audio_service.dart';
import '../services/devotion_catalog.dart';
import '../services/devotion_downloads.dart';
import '../services/devotion_learning_service.dart';
import 'premium_screen.dart';

class DevotionLibraryScreen extends StatefulWidget {
  const DevotionLibraryScreen({
    super.key,
    required this.openSearch,
    this.learn = false,
  });
  final VoidCallback openSearch;
  final bool learn;
  @override
  State<DevotionLibraryScreen> createState() => _DevotionLibraryScreenState();
}

class _DevotionLibraryScreenState extends State<DevotionLibraryScreen> {
  late Future<DevotionCatalog> _catalog;
  @override
  void initState() {
    super.initState();
    _catalog = DevotionCatalog.load();
  }

  @override
  Widget build(BuildContext context) {
    final lang = context.watch<LanguageService>();
    return ListView(
      padding: const EdgeInsets.fromLTRB(16, 16, 16, 170),
      children: [
        OutlinedButton.icon(
          key: const Key('library_search'),
          onPressed: widget.openSearch,
          icon: const Icon(Icons.search),
          label: Text(lang.translate('library_search')),
        ),
        const SizedBox(height: 16),
        FutureBuilder<DevotionCatalog>(
          future: _catalog,
          builder: (context, snapshot) {
            if (snapshot.hasError) {
              return TextButton(
                onPressed: () =>
                    setState(() => _catalog = DevotionCatalog.load()),
                child: Text(lang.translate('retry')),
              );
            }
            if (!snapshot.hasData) return const LinearProgressIndicator();
            final catalog = snapshot.data!;
            final listen = Column(
              crossAxisAlignment: CrossAxisAlignment.stretch,
              children: [
                Text(
                  lang.translate('library_listen'),
                  style: Theme.of(context).textTheme.titleLarge,
                ),
                if (catalog.tracks.isEmpty)
                  Text(lang.translate('library_content_pending')),
                for (final track in catalog.tracks)
                  DevotionTrackTile(track: track),
              ],
            );
            final learn = Column(
              crossAxisAlignment: CrossAxisAlignment.stretch,
              children: [
                Text(
                  lang.translate('library_learn'),
                  style: Theme.of(context).textTheme.titleLarge,
                ),
                for (final lesson in catalog.lessons)
                  Card(
                    child: ListTile(
                      title: Text(lang.translate(lesson.titleKey)),
                      trailing: Icon(
                        lesson.premium
                            ? Icons.lock_outline
                            : Icons.arrow_forward,
                      ),
                      onTap: () {
                        if (lesson.premium &&
                            !context.read<PremiumService>().isPremium) {
                          openPremium(context);
                          return;
                        }
                        Navigator.push(
                          context,
                          MaterialPageRoute<void>(
                            builder: (_) => DevotionTheme(
                              child: DevotionLessonScreen(
                                lesson: lesson,
                                catalog: catalog,
                              ),
                            ),
                          ),
                        );
                      },
                    ),
                  ),
              ],
            );
            return Column(
              crossAxisAlignment: CrossAxisAlignment.stretch,
              children: widget.learn
                  ? [learn, const SizedBox(height: 24), listen]
                  : [listen, const SizedBox(height: 24), learn],
            );
          },
        ),
      ],
    );
  }
}

class DevotionTrackTile extends StatefulWidget {
  const DevotionTrackTile({super.key, required this.track});
  final DevotionTrack track;
  @override
  State<DevotionTrackTile> createState() => _DevotionTrackTileState();
}

class _DevotionTrackTileState extends State<DevotionTrackTile> {
  bool _busy = false, _downloaded = false;
  @override
  void initState() {
    super.initState();
    Future.microtask(() async {
      if (!mounted) return;
      final cached = await context.read<DevotionDownloads>().cached(
        widget.track,
      );
      if (mounted) setState(() => _downloaded = cached != null);
    });
  }

  bool unlock() {
    if (context.read<PremiumService>().isPremium) return true;
    openPremium(context);
    return false;
  }

  Future<void> run(Future<void> Function() action) async {
    if (_busy) return;
    setState(() => _busy = true);
    try {
      await action();
    } catch (_) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text(
              context.read<LanguageService>().translate('library_audio_error'),
            ),
          ),
        );
      }
    }
    if (mounted) setState(() => _busy = false);
  }

  @override
  Widget build(BuildContext context) {
    final track = widget.track;
    final lang = context.watch<LanguageService>();
    return Card(
      child: Padding(
        padding: const EdgeInsets.all(12),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            ListTile(
              contentPadding: EdgeInsets.zero,
              title: Text(lang.translate(track.titleKey)),
              subtitle: Text(track.attribution),
              leading: Icon(
                track.premium ? Icons.lock_outline : Icons.music_note,
              ),
              onTap: _busy
                  ? null
                  : () => run(() async {
                      if (track.premium && !unlock()) return;
                      final cached = await context
                          .read<DevotionDownloads>()
                          .cached(track);
                      if (!context.mounted) return;
                      await context.read<DevotionAudioService>().select(
                        cached == null
                            ? track
                            : DevotionTrack(
                                id: track.id,
                                premium: track.premium,
                                cleared: track.cleared,
                                source: cached,
                                sha256: track.sha256,
                                titleKey: track.titleKey,
                                attribution: track.attribution,
                                license: track.license,
                              ),
                      );
                    }),
            ),
            Wrap(
              spacing: 8,
              children: [
                TextButton(
                  onPressed: () => run(() async {
                    if (!unlock()) return;
                    await context.read<DevotionAudioService>().addToPlaylist(
                      track,
                    );
                  }),
                  child: Text(lang.translate('library_add_playlist')),
                ),
                if (track.offlineAllowed && track.source.startsWith('https:'))
                  TextButton(
                    onPressed: _busy
                        ? null
                        : () => run(() async {
                            final downloads = context.read<DevotionDownloads>();
                            if (_downloaded) {
                              await downloads.remove(track);
                              if (mounted) setState(() => _downloaded = false);
                            } else {
                              if (!unlock()) return;
                              await downloads.download(track);
                              if (mounted) setState(() => _downloaded = true);
                            }
                          }),
                    child: Text(
                      lang.translate(
                        _downloaded
                            ? 'library_remove_download'
                            : 'library_download',
                      ),
                    ),
                  ),
              ],
            ),
            if (_busy) const LinearProgressIndicator(),
          ],
        ),
      ),
    );
  }
}

class DevotionLessonScreen extends StatelessWidget {
  const DevotionLessonScreen({
    super.key,
    required this.lesson,
    required this.catalog,
  });
  final DevotionLesson lesson;
  final DevotionCatalog catalog;
  @override
  Widget build(BuildContext context) {
    final lang = context.watch<LanguageService>();
    final learning = context.watch<DevotionLearningService>();
    final audio = context.watch<DevotionAudioService>();
    final paid = context.watch<PremiumService>().isPremium;
    Future<void> action(Future<void> Function() fn) async {
      if (!paid) {
        await openPremium(context);
        return;
      }
      try {
        await fn();
      } catch (_) {
        if (context.mounted) {
          ScaffoldMessenger.of(context).showSnackBar(
            SnackBar(content: Text(lang.translate('practice_error'))),
          );
        }
      }
    }

    return Scaffold(
      appBar: AppBar(title: Text(lang.translate(lesson.titleKey))),
      body: ListView(
        padding: const EdgeInsets.fromLTRB(16, 16, 16, 170),
        children: [
          for (var i = 0; i < lesson.lines.length; i++)
            Builder(
              builder: (context) {
                final line = lesson.lines[i];
                final trackId = line['trackId'] as String?;
                final next = i + 1 < lesson.lines.length
                    ? lesson.lines[i + 1]['startMs'] as int?
                    : null;
                final highlight =
                    trackId != null &&
                    audio.current?.id == trackId &&
                    audio.position.inMilliseconds >=
                        (line['startMs'] as int? ?? 0) &&
                    (next == null || audio.position.inMilliseconds < next);
                return Card(
                  color: highlight
                      ? Theme.of(context).colorScheme.primaryContainer
                      : null,
                  child: Padding(
                    padding: const EdgeInsets.all(16),
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.stretch,
                      children: [
                        Text(
                          line['text'] as String,
                          style: Theme.of(context).textTheme.headlineSmall,
                        ),
                        const SizedBox(height: 8),
                        Text(lang.translate(line['meaningKey'] as String)),
                        if (paid || learning.bookmarked(lesson.id, i))
                          Text(line['transliteration'] as String),
                        Wrap(
                          children: [
                            TextButton(
                              onPressed: () =>
                                  action(() => learning.bookmark(lesson.id, i)),
                              child: Text(lang.translate('library_bookmark')),
                            ),
                            Icon(
                              learning.bookmarked(lesson.id, i)
                                  ? Icons.bookmark
                                  : Icons.bookmark_outline,
                            ),
                            if (!paid)
                              TextButton(
                                onPressed: () => openPremium(context),
                                child: Text(
                                  lang.translate('library_transliteration'),
                                ),
                              ),
                            if (trackId != null)
                              IconButton(
                                tooltip: lang.translate('library_play'),
                                icon: const Icon(Icons.play_arrow),
                                onPressed: () => action(() async {
                                  final track = catalog.tracks.firstWhere(
                                    (t) => t.id == trackId,
                                  );
                                  await audio.select(track);
                                  await audio.seek(
                                    Duration(
                                      milliseconds:
                                          line['startMs'] as int? ?? 0,
                                    ),
                                  );
                                }),
                              ),
                          ],
                        ),
                      ],
                    ),
                  ),
                );
              },
            ),
          if (lesson.lines.every((l) => l['trackId'] == null))
            Text(lang.translate('library_pronunciation_pending')),
          TextButton(
            onPressed: () => action(() => learning.revise(lesson.id)),
            child: Text(lang.translate('library_revision')),
          ),
          if (learning.due(lesson.id) != null)
            Text(
              '${lang.translate('library_due')}: ${MaterialLocalizations.of(context).formatMediumDate(learning.due(lesson.id)!)}',
            ),
        ],
      ),
    );
  }
}
