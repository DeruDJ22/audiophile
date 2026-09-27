import 'package:flutter/material.dart';
import 'package:cached_network_image/cached_network_image.dart';

import '../config/theme.dart';
import '../models/discover_track.dart';
import 'source_badge.dart';

/// Card widget for displaying a track from external Discover sources.
/// Shows thumbnail, title, artist, duration, source badge, format info,
/// and action buttons for streaming and downloading.
class DiscoverTrackCard extends StatelessWidget {
  final DiscoverTrack track;
  final VoidCallback onStream;
  final VoidCallback? onDownload;
  final bool isDownloading;
  final double downloadProgress;

  const DiscoverTrackCard({
    super.key,
    required this.track,
    required this.onStream,
    this.onDownload,
    this.isDownloading = false,
    this.downloadProgress = 0.0,
  });

  @override
  Widget build(BuildContext context) {
    return Container(
      margin: const EdgeInsets.only(bottom: 10),
      decoration: BoxDecoration(
        color: KuroakaiTheme.surface,
        borderRadius: BorderRadius.circular(12),
        border: Border.all(color: KuroakaiTheme.border),
      ),
      child: Material(
        color: Colors.transparent,
        child: InkWell(
          borderRadius: BorderRadius.circular(12),
          onTap: onStream,
          child: Padding(
            padding: const EdgeInsets.all(12),
            child: Row(
              children: [
                // Thumbnail
                _buildThumbnail(),
                const SizedBox(width: 14),

                // Track Info
                Expanded(child: _buildTrackInfo()),

                // Actions
                _buildActions(),
              ],
            ),
          ),
        ),
      ),
    );
  }

  Widget _buildThumbnail() {
    return ClipRRect(
      borderRadius: BorderRadius.circular(8),
      child: Container(
        width: 56,
        height: 56,
        color: KuroakaiTheme.card,
        child: track.thumbnailUrl != null
            ? CachedNetworkImage(
                imageUrl: track.thumbnailUrl!,
                fit: BoxFit.cover,
                placeholder: (_, __) => const Center(
                  child: Icon(Icons.music_note_rounded, color: KuroakaiTheme.textTertiary, size: 24),
                ),
                errorWidget: (_, __, ___) => const Center(
                  child: Icon(Icons.album_rounded, color: KuroakaiTheme.primary, size: 28),
                ),
              )
            : const Center(
                child: Icon(Icons.link_rounded, color: KuroakaiTheme.primary, size: 28),
              ),
      ),
    );
  }

  Widget _buildTrackInfo() {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        // Title
        Text(
          track.title,
          maxLines: 1,
          overflow: TextOverflow.ellipsis,
          style: const TextStyle(
            color: KuroakaiTheme.textPrimary,
            fontWeight: FontWeight.w600,
            fontSize: 14,
          ),
        ),
        const SizedBox(height: 4),

        // Artist
        Text(
          track.artist,
          maxLines: 1,
          overflow: TextOverflow.ellipsis,
          style: const TextStyle(
            color: KuroakaiTheme.textSecondary,
            fontSize: 12,
          ),
        ),
        const SizedBox(height: 6),

        // Bottom row: badge, duration, format
        Row(
          children: [
            SourceBadge(source: track.source),
            const SizedBox(width: 8),
            Text(
              track.formattedDuration,
              style: const TextStyle(
                color: KuroakaiTheme.textTertiary,
                fontSize: 11,
              ),
            ),
            const SizedBox(width: 8),
            if (track.format != null)
              Container(
                padding: const EdgeInsets.symmetric(horizontal: 5, vertical: 1),
                decoration: BoxDecoration(
                  color: KuroakaiTheme.primary.withValues(alpha: 0.15),
                  borderRadius: BorderRadius.circular(4),
                ),
                child: Text(
                  track.qualityLabel,
                  style: const TextStyle(
                    color: KuroakaiTheme.secondary,
                    fontSize: 10,
                    fontWeight: FontWeight.bold,
                  ),
                ),
              ),
          ],
        ),
      ],
    );
  }

  Widget _buildActions() {
    return Row(
      mainAxisSize: MainAxisSize.min,
      children: [
        // Stream / Play button
        IconButton(
          icon: const Icon(
            Icons.play_circle_fill_rounded,
            color: KuroakaiTheme.primary,
            size: 36,
          ),
          tooltip: 'Stream',
          onPressed: onStream,
        ),

        // Download button
        if (track.canDownload)
          isDownloading
              ? SizedBox(
                  width: 36,
                  height: 36,
                  child: Stack(
                    alignment: Alignment.center,
                    children: [
                      CircularProgressIndicator(
                        value: downloadProgress > 0 ? downloadProgress : null,
                        strokeWidth: 2.5,
                        valueColor: const AlwaysStoppedAnimation(KuroakaiTheme.primary),
                        backgroundColor: KuroakaiTheme.border,
                      ),
                      Text(
                        '${(downloadProgress * 100).toInt()}%',
                        style: const TextStyle(
                          color: KuroakaiTheme.textSecondary,
                          fontSize: 8,
                          fontWeight: FontWeight.bold,
                        ),
                      ),
                    ],
                  ),
                )
              : IconButton(
                  icon: const Icon(
                    Icons.download_rounded,
                    color: KuroakaiTheme.textSecondary,
                    size: 24,
                  ),
                  tooltip: 'Download to Library',
                  onPressed: onDownload,
                ),
      ],
    );
  }
}
