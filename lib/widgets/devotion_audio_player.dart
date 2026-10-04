import 'devotion_theme.dart';
import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import '../services/devotion_audio_service.dart';
import '../services/language_service.dart';
import '../services/premium_service.dart';
import '../screens/premium_screen.dart';

Future<void> audioAction(
  BuildContext context,
  Future<void> Function() action,
) async {
  try {
    await action();
  } catch (_) {
    if (context.mounted) {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text(
            context.read<LanguageService>().translate('library_audio_error'),
          ),
        ),
      );
    }
  }
}

class DevotionMiniPlayer extends StatelessWidget {
  const DevotionMiniPlayer({super.key});
  @override
  Widget build(BuildContext context) {
    final audio = context.watch<DevotionAudioService>();
    final lang = context.watch<LanguageService>();
    if (audio.current == null) return const SizedBox.shrink();
    return SafeArea(
      top: false,
      bottom: false,
      child: Card(
        margin: const EdgeInsets.symmetric(horizontal: 16),
        child: ListTile(
          key: const Key('devotion_mini_player'),
          title: Text(
            lang.translate(audio.current!.titleKey),
            maxLines: 1,
            overflow: TextOverflow.ellipsis,
          ),
          onTap: () => Navigator.push(
            context,
            MaterialPageRoute<void>(
              builder: (_) =>
                  const DevotionTheme(child: DevotionPlayerScreen()),
            ),
          ),
          trailing: Wrap(
            children: [
              IconButton(
                tooltip: lang.translate(
                  audio.playing ? 'library_pause' : 'library_play',
                ),
                icon: Icon(audio.playing ? Icons.pause : Icons.play_arrow),
                onPressed: () => audioAction(context, audio.toggle),
              ),
              IconButton(
                tooltip: lang.translate('library_stop'),
                icon: const Icon(Icons.close),
                onPressed: () => audioAction(context, () async {
                  await audio.stop();
                  audio.dismiss();
                }),
              ),
            ],
          ),
        ),
      ),
    );
  }
}

class DevotionPlayerScreen extends StatelessWidget {
  const DevotionPlayerScreen({super.key});
  @override
  Widget build(BuildContext context) {
    final audio = context.watch<DevotionAudioService>();
    final lang = context.watch<LanguageService>();
    final paid = context.watch<PremiumService>().isPremium;
    bool unlock() {
      if (paid) return true;
      openPremium(context);
      return false;
    }

    final max = audio.duration.inMilliseconds.toDouble();
    final position = audio.position.inMilliseconds
        .toDouble()
        .clamp(0, max)
        .toDouble();
    return Scaffold(
      appBar: AppBar(title: Text(lang.translate('library_player'))),
      body: ListView(
        padding: const EdgeInsets.all(24),
        children: [
          if (audio.current != null)
            Text(
              lang.translate(audio.current!.titleKey),
              style: Theme.of(context).textTheme.headlineSmall,
            ),
          Slider(
            value: position,
            max: max > 0 ? max : 1,
            onChanged: max > 0
                ? (v) => audioAction(
                    context,
                    () => audio.seek(Duration(milliseconds: v.toInt())),
                  )
                : null,
          ),
          Text(
            '${audio.position.inMinutes}:${(audio.position.inSeconds % 60).toString().padLeft(2, '0')} / ${audio.duration.inMinutes}:${(audio.duration.inSeconds % 60).toString().padLeft(2, '0')}',
          ),
          FilledButton.icon(
            onPressed: () => audioAction(context, audio.toggle),
            icon: Icon(audio.playing ? Icons.pause : Icons.play_arrow),
            label: Text(
              lang.translate(audio.playing ? 'library_pause' : 'library_play'),
            ),
          ),
          const SizedBox(height: 12),
          Text('${lang.translate('library_repeat')}: ${audio.remaining}'),
          Wrap(
            spacing: 8,
            children: [
              for (final repetitions in [1, 3, 9, 27, 108])
                OutlinedButton(
                  onPressed: () => audioAction(context, () async {
                    if (unlock()) await audio.setRepeat(repetitions);
                  }),
                  child: Text('$repetitions'),
                ),
            ],
          ),
          Text(lang.translate('library_sleep')),
          Wrap(
            spacing: 8,
            children: [
              for (final minutes in [5, 15, 30, 60])
                OutlinedButton(
                  onPressed: () {
                    if (unlock()) audio.sleepAfter(Duration(minutes: minutes));
                  },
                  child: Text('$minutes'),
                ),
            ],
          ),
          const SizedBox(height: 16),
          Text(
            lang.translate('library_playlist'),
            style: Theme.of(context).textTheme.titleLarge,
          ),
          if (audio.playlist.isEmpty)
            Text(lang.translate('library_no_playlist')),
          for (var i = 0; i < audio.playlist.length; i++)
            ListTile(
              title: Text(lang.translate(audio.playlist[i].titleKey)),
              trailing: IconButton(
                tooltip: lang.translate('practice_delete'),
                icon: const Icon(Icons.delete_outline),
                onPressed: () => audio.removeFromPlaylist(i),
              ),
            ),
          if (audio.current != null) ...[
            const Divider(),
            Text(audio.current!.attribution),
            Text(audio.current!.license),
          ],
          if (audio.error != null) Text(lang.translate(audio.error!)),
        ],
      ),
    );
  }
}
