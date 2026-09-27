import 'dart:io';
import 'package:flutter/material.dart';
import 'package:provider/provider.dart';

import '../config/theme.dart';
import '../providers/audio_provider.dart';
import '../providers/library_provider.dart';
import '../services/playlist_service.dart';

/// Local music library screen — displays user's local audio files.
class LibraryScreen extends StatelessWidget {
  const LibraryScreen({super.key});

  @override
  Widget build(BuildContext context) {
    return Consumer2<LibraryProvider, AudioProvider>(
      builder: (context, library, audio, _) {
        return Container(
          color: KuroakaiTheme.background,
          padding: const EdgeInsets.all(20),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              // Header
              Row(
                mainAxisAlignment: MainAxisAlignment.spaceBetween,
                children: [
                  const Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text('Music Library',
                          style: TextStyle(
                              color: KuroakaiTheme.textPrimary,
                              fontSize: 24,
                              fontWeight: FontWeight.bold)),
                      Text('Local Lossless Audio Files',
                          style: TextStyle(
                              color: KuroakaiTheme.textSecondary,
                              fontSize: 13)),
                    ],
                  ),
                  ElevatedButton.icon(
                    style: ElevatedButton.styleFrom(
                      backgroundColor: KuroakaiTheme.primary,
                      padding: const EdgeInsets.symmetric(
                          horizontal: 16, vertical: 12),
                      shape: RoundedRectangleBorder(
                          borderRadius: BorderRadius.circular(8)),
                    ),
                    icon: const Icon(Icons.add_rounded, color: Colors.white),
                    label: const Text('Add Songs',
                        style: TextStyle(
                            color: Colors.white, fontWeight: FontWeight.bold)),
                    onPressed: () async {
                      final paths = await library.pickAndAddSongs();
                      if (paths.isNotEmpty && audio.currentFilePath == null) {
                        audio.playFile(paths.first);
                      }
                    },
                  ),
                ],
              ),
              const SizedBox(height: 20),

              // Song list
              Expanded(
                child: library.librarySongs.isEmpty
                    ? _buildEmptyState(library, audio)
                    : _buildSongList(library, audio),
              ),
            ],
          ),
        );
      },
    );
  }

  Widget _buildEmptyState(LibraryProvider library, AudioProvider audio) {
    return Center(
      child: Column(
        mainAxisAlignment: MainAxisAlignment.center,
        children: [
          const Icon(Icons.library_music_rounded,
              size: 64, color: Colors.white24),
          const SizedBox(height: 16),
          const Text('No Local Songs Added Yet',
              style: TextStyle(
                  color: KuroakaiTheme.textPrimary,
                  fontSize: 18,
                  fontWeight: FontWeight.bold)),
          const SizedBox(height: 8),
          const Padding(
            padding: EdgeInsets.symmetric(horizontal: 32.0),
            child: Text(
                'Click "Add Songs" or "Open Local File" to browse Hi-Res audio tracks.',
                textAlign: TextAlign.center,
                style: TextStyle(
                    color: KuroakaiTheme.textTertiary, fontSize: 13)),
          ),
          const SizedBox(height: 20),
          ElevatedButton(
            style: ElevatedButton.styleFrom(
                backgroundColor: KuroakaiTheme.primary),
            onPressed: () async {
              final paths = await library.pickAndAddSongs();
              if (paths.isNotEmpty) {
                audio.playFile(paths.first);
              }
            },
            child: const Text('Select Songs',
                style: TextStyle(color: Colors.white)),
          ),
        ],
      ),
    );
  }

  Widget _buildSongList(LibraryProvider library, AudioProvider audio) {
    return ListView.builder(
      itemCount: library.librarySongs.length,
      itemBuilder: (ctx, idx) {
        final path = library.librarySongs[idx];
        final name = path.split(Platform.pathSeparator).last;
        final isPlaying = audio.currentFilePath == path;

        return Card(
          color: isPlaying
              ? KuroakaiTheme.primary.withValues(alpha: 0.15)
              : KuroakaiTheme.surface,
          margin: const EdgeInsets.only(bottom: 8),
          shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(10)),
          child: ListTile(
            leading: Icon(
              isPlaying
                  ? Icons.graphic_eq_rounded
                  : Icons.audio_file_rounded,
              color: isPlaying
                  ? KuroakaiTheme.primary
                  : KuroakaiTheme.textTertiary,
            ),
            title: Text(
              name,
              maxLines: 1,
              overflow: TextOverflow.ellipsis,
              style: TextStyle(
                color: isPlaying
                    ? KuroakaiTheme.secondary
                    : KuroakaiTheme.textPrimary,
                fontWeight:
                    isPlaying ? FontWeight.bold : FontWeight.normal,
              ),
            ),
            subtitle: Text(path,
                maxLines: 1,
                overflow: TextOverflow.ellipsis,
                style: const TextStyle(
                    color: KuroakaiTheme.textTertiary, fontSize: 11)),
            trailing: Row(
              mainAxisSize: MainAxisSize.min,
              children: [
                PopupMenuButton<Playlist>(
                  icon: const Icon(Icons.playlist_add_rounded,
                      color: KuroakaiTheme.textSecondary),
                  tooltip: 'Add to Playlist',
                  color: KuroakaiTheme.card,
                  onSelected: (pl) async {
                    await library.addSongToPlaylist(pl, path);
                    if (ctx.mounted) {
                      ScaffoldMessenger.of(ctx).showSnackBar(
                        SnackBar(content: Text('Added to ${pl.name}')),
                      );
                    }
                  },
                  itemBuilder: (ctx) => library.playlists.map((pl) {
                    return PopupMenuItem(
                      value: pl,
                      child: Text(pl.name,
                          style: const TextStyle(
                              color: KuroakaiTheme.textPrimary)),
                    );
                  }).toList(),
                ),
                IconButton(
                  icon: Icon(
                    isPlaying && audio.isPlaying
                        ? Icons.pause_circle_rounded
                        : Icons.play_circle_rounded,
                    color: KuroakaiTheme.primary,
                  ),
                  onPressed: () {
                    audio.playFile(path);
                    library.addToLibrary(path);
                  },
                ),
              ],
            ),
          ),
        );
      },
    );
  }
}
