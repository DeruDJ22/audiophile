import 'package:flutter/material.dart';
import 'package:provider/provider.dart';

import '../config/theme.dart';
import '../providers/audio_provider.dart';

/// Full-screen player view with large album art, dynamic gradient background,
/// and complete playback controls (shuffle, repeat, seek, volume).
/// Opened by tapping the mini player. Uses Hero animation for album art.
class FullPlayerScreen extends StatelessWidget {
  const FullPlayerScreen({super.key});

  @override
  Widget build(BuildContext context) {
    return Consumer<AudioProvider>(
      builder: (context, audio, _) {
        // Determine dominant color for gradient
        const dominantColor = KuroakaiTheme.primary;

        return Scaffold(
          backgroundColor: Colors.transparent,
          body: AnimatedContainer(
            duration: const Duration(milliseconds: 600),
            curve: Curves.easeInOut,
            decoration: BoxDecoration(
              gradient: KuroakaiTheme.playerGradient(dominantColor),
            ),
            child: SafeArea(
              child: Column(
                children: [
                  // Top bar: collapse button + title
                  _buildTopBar(context, audio),

                  const Spacer(flex: 1),

                  // Large album art with Hero
                  _buildAlbumArt(audio),

                  const Spacer(flex: 1),

                  // Track info
                  _buildTrackInfo(audio),

                  const SizedBox(height: 30),

                  // Seek bar
                  _buildSeekBar(context, audio),

                  const SizedBox(height: 20),

                  // Transport controls
                  _buildTransportControls(audio),

                  const SizedBox(height: 20),

                  // Volume slider
                  _buildVolumeSlider(audio),

                  const SizedBox(height: 16),

                  // Audio specs badge
                  _buildSpecsBadge(audio),

                  const Spacer(flex: 1),
                ],
              ),
            ),
          ),
        );
      },
    );
  }

  Widget _buildTopBar(BuildContext context, AudioProvider audio) {
    return Padding(
      padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
      child: Row(
        children: [
          IconButton(
            icon: const Icon(Icons.keyboard_arrow_down_rounded,
                color: KuroakaiTheme.textPrimary, size: 32),
            onPressed: () => audio.closeFullPlayer(),
          ),
          const Expanded(
            child: Text(
              'NOW PLAYING',
              textAlign: TextAlign.center,
              style: TextStyle(
                color: KuroakaiTheme.textSecondary,
                fontSize: 12,
                fontWeight: FontWeight.bold,
                letterSpacing: 1.5,
              ),
            ),
          ),
          IconButton(
            icon: const Icon(Icons.more_vert_rounded,
                color: KuroakaiTheme.textSecondary),
            onPressed: () {},
          ),
        ],
      ),
    );
  }

  Widget _buildAlbumArt(AudioProvider audio) {
    return Hero(
      tag: 'album_art',
      child: Container(
        width: 280,
        height: 280,
        decoration: BoxDecoration(
          borderRadius: BorderRadius.circular(16),
          boxShadow: [
            BoxShadow(
              color: KuroakaiTheme.primary.withValues(alpha: 0.3),
              blurRadius: 40,
              spreadRadius: 8,
            ),
          ],
        ),
        child: ClipRRect(
          borderRadius: BorderRadius.circular(16),
          child: audio.currentCoverArt != null
              ? Image.memory(audio.currentCoverArt!, fit: BoxFit.cover)
              : Container(
                  decoration: const BoxDecoration(
                    gradient: LinearGradient(
                      begin: Alignment.topLeft,
                      end: Alignment.bottomRight,
                      colors: [
                        Color(0xFF2D1517),
                        Color(0xFFE50914),
                        Color(0xFF1A0A0B),
                      ],
                    ),
                  ),
                  child: const Icon(Icons.music_note_rounded,
                      color: Colors.white, size: 80),
                ),
        ),
      ),
    );
  }

  Widget _buildTrackInfo(AudioProvider audio) {
    return Padding(
      padding: const EdgeInsets.symmetric(horizontal: 40),
      child: Column(
        children: [
          Text(
            audio.currentTitle,
            textAlign: TextAlign.center,
            maxLines: 2,
            overflow: TextOverflow.ellipsis,
            style: const TextStyle(
              color: KuroakaiTheme.textPrimary,
              fontSize: 22,
              fontWeight: FontWeight.bold,
            ),
          ),
          const SizedBox(height: 6),
          Text(
            audio.currentArtist,
            textAlign: TextAlign.center,
            style: const TextStyle(
              color: KuroakaiTheme.textSecondary,
              fontSize: 15,
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildSeekBar(BuildContext context, AudioProvider audio) {
    final position = audio.audioStatus.currentPosition;
    final duration = audio.audioStatus.duration;

    return Padding(
      padding: const EdgeInsets.symmetric(horizontal: 32),
      child: Column(
        children: [
          SliderTheme(
            data: SliderTheme.of(context).copyWith(
              trackHeight: 4.0,
              thumbShape: const RoundSliderThumbShape(enabledThumbRadius: 7.0),
              overlayShape: const RoundSliderOverlayShape(overlayRadius: 14.0),
              activeTrackColor: KuroakaiTheme.textPrimary,
              inactiveTrackColor: Colors.white24,
              thumbColor: KuroakaiTheme.textPrimary,
              overlayColor: Colors.white24,
            ),
            child: Slider(
              value: position.clamp(0.0, duration > 0 ? duration : 1.0),
              max: duration > 0 ? duration : 1.0,
              onChanged: (val) => audio.seek(val),
            ),
          ),
          Padding(
            padding: const EdgeInsets.symmetric(horizontal: 6),
            child: Row(
              mainAxisAlignment: MainAxisAlignment.spaceBetween,
              children: [
                Text(
                  audio.formatDuration(position),
                  style: const TextStyle(
                    color: KuroakaiTheme.textTertiary,
                    fontSize: 12,
                    fontWeight: FontWeight.w500,
                  ),
                ),
                Text(
                  audio.formatDuration(duration),
                  style: const TextStyle(
                    color: KuroakaiTheme.textTertiary,
                    fontSize: 12,
                    fontWeight: FontWeight.w500,
                  ),
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildTransportControls(AudioProvider audio) {
    return Row(
      mainAxisAlignment: MainAxisAlignment.center,
      children: [
        // Shuffle
        IconButton(
          icon: Icon(
            Icons.shuffle_rounded,
            color: audio.shuffleEnabled
                ? KuroakaiTheme.primary
                : KuroakaiTheme.textSecondary,
            size: 24,
          ),
          onPressed: audio.toggleShuffle,
        ),

        const SizedBox(width: 16),

        // Previous
        IconButton(
          icon: const Icon(Icons.skip_previous_rounded,
              color: KuroakaiTheme.textPrimary, size: 36),
          onPressed: () {},
        ),

        const SizedBox(width: 8),

        // Play/Pause (big)
        Container(
          width: 64,
          height: 64,
          decoration: const BoxDecoration(
            color: KuroakaiTheme.textPrimary,
            shape: BoxShape.circle,
          ),
          child: IconButton(
            iconSize: 36,
            padding: EdgeInsets.zero,
            icon: Icon(
              audio.isPlaying
                  ? Icons.pause_rounded
                  : Icons.play_arrow_rounded,
              color: KuroakaiTheme.background,
            ),
            onPressed: audio.togglePlayPause,
          ),
        ),

        const SizedBox(width: 8),

        // Next
        IconButton(
          icon: const Icon(Icons.skip_next_rounded,
              color: KuroakaiTheme.textPrimary, size: 36),
          onPressed: () {},
        ),

        const SizedBox(width: 16),

        // Repeat
        IconButton(
          icon: Icon(
            audio.repeatMode == 2
                ? Icons.repeat_one_rounded
                : Icons.repeat_rounded,
            color: audio.repeatMode > 0
                ? KuroakaiTheme.primary
                : KuroakaiTheme.textSecondary,
            size: 24,
          ),
          onPressed: audio.cycleRepeatMode,
        ),
      ],
    );
  }

  Widget _buildVolumeSlider(AudioProvider audio) {
    return Padding(
      padding: const EdgeInsets.symmetric(horizontal: 40),
      child: Row(
        children: [
          const Icon(Icons.volume_down_rounded,
              color: KuroakaiTheme.textTertiary, size: 20),
          Expanded(
            child: SliderTheme(
              data: const SliderThemeData(
                trackHeight: 3,
                thumbShape: RoundSliderThumbShape(enabledThumbRadius: 5),
                overlayShape: RoundSliderOverlayShape(overlayRadius: 10),
                activeTrackColor: KuroakaiTheme.textPrimary,
                inactiveTrackColor: Colors.white12,
                thumbColor: KuroakaiTheme.textPrimary,
              ),
              child: Slider(
                value: audio.localVolume,
                min: 0.0,
                max: 1.0,
                onChanged: (val) => audio.setVolume(val),
              ),
            ),
          ),
          const Icon(Icons.volume_up_rounded,
              color: KuroakaiTheme.textTertiary, size: 20),
        ],
      ),
    );
  }

  Widget _buildSpecsBadge(AudioProvider audio) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 6),
      decoration: BoxDecoration(
        color: KuroakaiTheme.primary.withValues(alpha: 0.15),
        borderRadius: BorderRadius.circular(20),
        border: Border.all(color: KuroakaiTheme.primary.withValues(alpha: 0.3)),
      ),
      child: Text(
        audio.audioStatus.formattedFormatInfo,
        style: const TextStyle(
          color: KuroakaiTheme.secondary,
          fontSize: 11,
          fontWeight: FontWeight.bold,
          letterSpacing: 0.5,
        ),
      ),
    );
  }
}
