import 'package:flutter/material.dart';
import 'package:provider/provider.dart';

import '../config/theme.dart';
import '../providers/audio_provider.dart';

/// Persistent mini player bar shown at the bottom when a track is playing.
/// Tappable to expand to full player view.
class MiniPlayer extends StatelessWidget {
  const MiniPlayer({super.key});

  @override
  Widget build(BuildContext context) {
    return Consumer<AudioProvider>(
      builder: (context, audio, _) {
        if (!audio.hasTrack) return const SizedBox.shrink();

        final progress = audio.audioStatus.duration > 0
            ? (audio.audioStatus.currentPosition / audio.audioStatus.duration).clamp(0.0, 1.0)
            : 0.0;

        return GestureDetector(
          onTap: () => audio.openFullPlayer(),
          child: Container(
            height: 66,
            decoration: const BoxDecoration(
              color: KuroakaiTheme.card,
              border: Border(
                top: BorderSide(color: KuroakaiTheme.border, width: 0.5),
              ),
            ),
            child: Column(
              children: [
                // Thin progress bar at top
                LinearProgressIndicator(
                  value: progress,
                  minHeight: 2,
                  backgroundColor: Colors.transparent,
                  valueColor: const AlwaysStoppedAnimation(KuroakaiTheme.primary),
                ),

                // Content row
                Expanded(
                  child: Padding(
                    padding: const EdgeInsets.symmetric(horizontal: 14),
                    child: Row(
                      children: [
                        // Album art with Hero tag for animation
                        Hero(
                          tag: 'album_art',
                          child: ClipRRect(
                            borderRadius: BorderRadius.circular(8),
                            child: Container(
                              width: 44,
                              height: 44,
                              color: KuroakaiTheme.primary,
                              child: audio.currentCoverArt != null
                                  ? Image.memory(audio.currentCoverArt!, fit: BoxFit.cover)
                                  : const Icon(Icons.music_note_rounded,
                                      color: Colors.white, size: 24),
                            ),
                          ),
                        ),
                        const SizedBox(width: 12),

                        // Title & Artist
                        Expanded(
                          child: Column(
                            mainAxisAlignment: MainAxisAlignment.center,
                            crossAxisAlignment: CrossAxisAlignment.start,
                            children: [
                              Text(
                                audio.currentTitle,
                                maxLines: 1,
                                overflow: TextOverflow.ellipsis,
                                style: const TextStyle(
                                  color: KuroakaiTheme.textPrimary,
                                  fontWeight: FontWeight.w600,
                                  fontSize: 13,
                                ),
                              ),
                              const SizedBox(height: 2),
                              Text(
                                '${audio.currentArtist} • ${audio.audioStatus.codecName}',
                                maxLines: 1,
                                overflow: TextOverflow.ellipsis,
                                style: const TextStyle(
                                  color: KuroakaiTheme.textTertiary,
                                  fontSize: 11,
                                ),
                              ),
                            ],
                          ),
                        ),

                        // Play/Pause button
                        IconButton(
                          icon: Icon(
                            audio.isPlaying
                                ? Icons.pause_rounded
                                : Icons.play_arrow_rounded,
                            color: KuroakaiTheme.textPrimary,
                            size: 30,
                          ),
                          onPressed: audio.togglePlayPause,
                        ),

                        // Next track button
                        IconButton(
                          icon: const Icon(
                            Icons.skip_next_rounded,
                            color: KuroakaiTheme.textSecondary,
                            size: 24,
                          ),
                          onPressed: () {}, // placeholder — needs library context
                        ),
                      ],
                    ),
                  ),
                ),
              ],
            ),
          ),
        );
      },
    );
  }
}
