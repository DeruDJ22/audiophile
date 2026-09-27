import 'dart:io';
import 'package:flutter/material.dart';
import 'package:provider/provider.dart';

import '../config/theme.dart';
import '../providers/audio_provider.dart';
import '../providers/library_provider.dart';

/// Playlists manager screen — create, edit, delete playlists.
class PlaylistsScreen extends StatelessWidget {
  const PlaylistsScreen({super.key});

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
                      Text('Playlists Manager',
                          style: TextStyle(
                              color: KuroakaiTheme.textPrimary,
                              fontSize: 24,
                              fontWeight: FontWeight.bold)),
                      Text('Create, Edit, and Manage Custom Playlists',
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
                    icon: const Icon(Icons.playlist_add_rounded,
                        color: Colors.white),
                    label: const Text('New Playlist',
                        style: TextStyle(
                            color: Colors.white,
                            fontWeight: FontWeight.bold)),
                    onPressed: () => _showCreatePlaylistDialog(context, library),
                  ),
                ],
              ),
              const SizedBox(height: 20),

              // Content
              if (library.playlists.isEmpty)
                Expanded(
                  child: Center(
                    child: Column(
                      mainAxisAlignment: MainAxisAlignment.center,
                      children: [
                        const Icon(Icons.queue_music_rounded,
                            size: 64, color: Colors.white24),
                        const SizedBox(height: 16),
                        const Text('No Playlists Created',
                            style: TextStyle(
                                color: KuroakaiTheme.textPrimary,
                                fontSize: 18,
                                fontWeight: FontWeight.bold)),
                        const SizedBox(height: 8),
                        const Text(
                            'Create custom playlists to organize your Hi-Res audio collection.',
                            textAlign: TextAlign.center,
                            style: TextStyle(
                                color: KuroakaiTheme.textTertiary,
                                fontSize: 13)),
                        const SizedBox(height: 20),
                        ElevatedButton(
                          style: ElevatedButton.styleFrom(
                              backgroundColor: KuroakaiTheme.primary),
                          onPressed: () =>
                              _showCreatePlaylistDialog(context, library),
                          child: const Text('Create Playlist',
                              style: TextStyle(color: Colors.white)),
                        ),
                      ],
                    ),
                  ),
                )
              else
                Expanded(
                  child: Column(
                    children: [
                      // Playlist selector chips
                      SizedBox(
                        height: 44,
                        child: ListView.builder(
                          scrollDirection: Axis.horizontal,
                          itemCount: library.playlists.length,
                          itemBuilder: (ctx, idx) {
                            final pl = library.playlists[idx];
                            final isSel =
                                library.selectedPlaylist?.id == pl.id;
                            return Padding(
                              padding: const EdgeInsets.only(right: 8.0),
                              child: ChoiceChip(
                                label: Text(pl.name),
                                selected: isSel,
                                selectedColor: KuroakaiTheme.primary,
                                backgroundColor: KuroakaiTheme.card,
                                labelStyle: TextStyle(
                                    color: isSel
                                        ? Colors.white
                                        : KuroakaiTheme.textSecondary,
                                    fontWeight: isSel
                                        ? FontWeight.bold
                                        : FontWeight.normal),
                                onSelected: (sel) {
                                  if (sel) library.selectPlaylist(pl);
                                },
                              ),
                            );
                          },
                        ),
                      ),
                      const SizedBox(height: 16),

                      // Selected playlist
                      if (library.selectedPlaylist != null) ...[
                        Row(
                          mainAxisAlignment:
                              MainAxisAlignment.spaceBetween,
                          children: [
                            Text(
                              '${library.selectedPlaylist!.name} (${library.selectedPlaylist!.songPaths.length} Songs)',
                              style: const TextStyle(
                                  color: KuroakaiTheme.textPrimary,
                                  fontSize: 16,
                                  fontWeight: FontWeight.bold),
                            ),
                            Row(
                              children: [
                                IconButton(
                                  icon: const Icon(
                                      Icons.library_add_rounded,
                                      color: KuroakaiTheme.primary),
                                  tooltip: 'Add Tracks',
                                  onPressed: () => library
                                      .addSongsToPlaylist(
                                          library.selectedPlaylist!),
                                ),
                                IconButton(
                                  icon: const Icon(
                                      Icons.delete_outline_rounded,
                                      color: KuroakaiTheme.textTertiary),
                                  tooltip: 'Delete Playlist',
                                  onPressed: () => library
                                      .deletePlaylist(
                                          library.selectedPlaylist!),
                                ),
                              ],
                            ),
                          ],
                        ),
                        const SizedBox(height: 8),
                        Expanded(
                          child: library
                                  .selectedPlaylist!.songPaths.isEmpty
                              ? Center(
                                  child: Column(
                                    mainAxisAlignment:
                                        MainAxisAlignment.center,
                                    children: [
                                      const Icon(
                                          Icons.music_off_rounded,
                                          size: 48,
                                          color: Colors.white24),
                                      const SizedBox(height: 12),
                                      const Text('Playlist is Empty',
                                          style: TextStyle(
                                              color: KuroakaiTheme
                                                  .textPrimary,
                                              fontSize: 16,
                                              fontWeight:
                                                  FontWeight.bold)),
                                      const SizedBox(height: 16),
                                      ElevatedButton(
                                        style: ElevatedButton
                                            .styleFrom(
                                                backgroundColor:
                                                    KuroakaiTheme
                                                        .primary),
                                        onPressed: () =>
                                            library.addSongsToPlaylist(
                                                library
                                                    .selectedPlaylist!),
                                        child: const Text('Add Songs',
                                            style: TextStyle(
                                                color: Colors.white)),
                                      ),
                                    ],
                                  ),
                                )
                              : ListView.builder(
                                  itemCount: library
                                      .selectedPlaylist!
                                      .songPaths
                                      .length,
                                  itemBuilder: (ctx, idx) {
                                    final path = library
                                        .selectedPlaylist!
                                        .songPaths[idx];
                                    final name = path
                                        .split(
                                            Platform.pathSeparator)
                                        .last;
                                    return Card(
                                      color: KuroakaiTheme.surface,
                                      margin: const EdgeInsets.only(
                                          bottom: 6),
                                      shape: RoundedRectangleBorder(
                                          borderRadius:
                                              BorderRadius.circular(
                                                  10)),
                                      child: ListTile(
                                        leading: const Icon(
                                            Icons
                                                .music_note_rounded,
                                            color: KuroakaiTheme
                                                .primary),
                                        title: Text(name,
                                            style: const TextStyle(
                                                color: KuroakaiTheme
                                                    .textPrimary)),
                                        subtitle: Text(path,
                                            maxLines: 1,
                                            overflow:
                                                TextOverflow
                                                    .ellipsis,
                                            style:
                                                const TextStyle(
                                                    color: KuroakaiTheme
                                                        .textTertiary,
                                                    fontSize: 11)),
                                        trailing: IconButton(
                                          icon: const Icon(
                                              Icons
                                                  .remove_circle_outline,
                                              color: KuroakaiTheme
                                                  .textTertiary),
                                          onPressed: () =>
                                              library
                                                  .removeSongFromPlaylist(
                                                      library
                                                          .selectedPlaylist!,
                                                      idx),
                                        ),
                                        onTap: () =>
                                            audio.playFile(path),
                                      ),
                                    );
                                  },
                                ),
                        ),
                      ],
                    ],
                  ),
                ),
            ],
          ),
        );
      },
    );
  }

  void _showCreatePlaylistDialog(
      BuildContext context, LibraryProvider library) {
    final controller = TextEditingController();
    showDialog(
      context: context,
      builder: (ctx) => AlertDialog(
        backgroundColor: KuroakaiTheme.card,
        title: const Text('Create New Playlist',
            style: TextStyle(color: KuroakaiTheme.textPrimary)),
        content: TextField(
          controller: controller,
          autofocus: true,
          style: const TextStyle(color: KuroakaiTheme.textPrimary),
          decoration: const InputDecoration(
            hintText: 'Enter playlist title...',
            hintStyle: TextStyle(color: KuroakaiTheme.textTertiary),
            enabledBorder: UnderlineInputBorder(
                borderSide: BorderSide(color: KuroakaiTheme.primary)),
            focusedBorder: UnderlineInputBorder(
                borderSide: BorderSide(color: KuroakaiTheme.secondary)),
          ),
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(ctx),
            child: const Text('Cancel',
                style: TextStyle(color: KuroakaiTheme.textSecondary)),
          ),
          ElevatedButton(
            style: ElevatedButton.styleFrom(
                backgroundColor: KuroakaiTheme.primary),
            onPressed: () async {
              final name = controller.text.trim();
              if (name.isNotEmpty) {
                await library.createPlaylist(name);
                if (ctx.mounted) Navigator.pop(ctx);
              }
            },
            child: const Text('Create',
                style: TextStyle(color: Colors.white)),
          ),
        ],
      ),
    );
  }
}
