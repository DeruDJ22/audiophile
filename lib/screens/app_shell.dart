import 'package:flutter/material.dart';
import 'package:provider/provider.dart';

import '../config/theme.dart';
import '../providers/audio_provider.dart';
import '../providers/library_provider.dart';
import '../services/file_picker_service.dart';
import '../widgets/mini_player.dart';
import 'full_player_screen.dart';
import 'library_screen.dart';
import 'playlists_screen.dart';
import 'discover_screen.dart';
import 'equalizer_screen.dart';
import 'settings_screen.dart';

/// App shell — the root layout widget.
/// Desktop (width >= 700): sidebar navigation on left.
/// Mobile (width < 700): bottom navigation bar.
/// Both show a persistent mini player when a track is playing.
/// Full player overlays the entire screen when opened.
class AppShell extends StatefulWidget {
  final List<String> initialArgs;

  const AppShell({super.key, required this.initialArgs});

  @override
  State<AppShell> createState() => _AppShellState();
}

class _AppShellState extends State<AppShell> {
  int _currentNavIndex = 0;
  // 0: Library, 1: Playlists, 2: Discover, 3: Equalizer, 4: Settings

  @override
  void initState() {
    super.initState();

    // Initialize audio engine
    WidgetsBinding.instance.addPostFrameCallback((_) {
      final audio = context.read<AudioProvider>();
      audio.init();

      final library = context.read<LibraryProvider>();
      library.loadPlaylists();

      // Handle initial file args
      if (widget.initialArgs.isNotEmpty) {
        final possiblePath = widget.initialArgs.first;
        audio.playFile(possiblePath);
        library.addToLibrary(possiblePath);
      }
    });
  }

  Widget _getScreen() {
    switch (_currentNavIndex) {
      case 0:
        return const LibraryScreen();
      case 1:
        return const PlaylistsScreen();
      case 2:
        return const DiscoverScreen();
      case 3:
        return const EqualizerScreen();
      case 4:
        return const SettingsScreen();
      default:
        return const LibraryScreen();
    }
  }

  @override
  Widget build(BuildContext context) {
    final isDesktop = MediaQuery.of(context).size.width >= 700;
    final audio = context.watch<AudioProvider>();

    return Scaffold(
      backgroundColor: KuroakaiTheme.background,
      body: Stack(
        children: [
          // Main layout
          isDesktop ? _buildDesktopLayout() : _buildMobileLayout(),

          // Full player overlay
          if (audio.isFullPlayerOpen)
            const Positioned.fill(
              child: FullPlayerScreen(),
            ),
        ],
      ),
    );
  }

  Widget _buildDesktopLayout() {
    return Column(
      children: [
        Expanded(
          child: Row(
            children: [
              // Sidebar
              _buildDesktopSidebar(),
              // Main content
              Expanded(
                child: AnimatedSwitcher(
                  duration: const Duration(milliseconds: 200),
                  child: _getScreen(),
                ),
              ),
              // Right panel (Now Playing)
              _buildDesktopRightPanel(),
            ],
          ),
        ),
        // Bottom player bar
        _buildDesktopBottomBar(),
      ],
    );
  }

  Widget _buildMobileLayout() {
    return Column(
      children: [
        // Main content
        Expanded(
          child: AnimatedSwitcher(
            duration: const Duration(milliseconds: 200),
            child: _getScreen(),
          ),
        ),

        // Mini player
        const MiniPlayer(),

        // Bottom nav
        BottomNavigationBar(
          currentIndex: _currentNavIndex,
          onTap: (index) => setState(() => _currentNavIndex = index),
          backgroundColor: KuroakaiTheme.surfaceAlt,
          selectedItemColor: KuroakaiTheme.primary,
          unselectedItemColor: KuroakaiTheme.textTertiary,
          type: BottomNavigationBarType.fixed,
          selectedFontSize: 11,
          unselectedFontSize: 10,
          items: const [
            BottomNavigationBarItem(
                icon: Icon(Icons.my_library_music_rounded),
                label: 'Library'),
            BottomNavigationBarItem(
                icon: Icon(Icons.playlist_play_rounded),
                label: 'Playlists'),
            BottomNavigationBarItem(
                icon: Icon(Icons.explore_rounded), label: 'Discover'),
            BottomNavigationBarItem(
                icon: Icon(Icons.graphic_eq_rounded),
                label: 'Equalizer'),
            BottomNavigationBarItem(
                icon: Icon(Icons.settings_rounded), label: 'Settings'),
          ],
        ),
      ],
    );
  }

  // ═══════════════════════════════════════════════════════════
  // DESKTOP SIDEBAR
  // ═══════════════════════════════════════════════════════════
  Widget _buildDesktopSidebar() {
    return Container(
      width: 240,
      color: KuroakaiTheme.surfaceAlt,
      padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 20),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          // Branding
          Row(
            children: [
              Image.asset(
                'assets/logo.png',
                height: 32,
                errorBuilder: (ctx, err, stack) => const Icon(
                    Icons.album,
                    color: KuroakaiTheme.primary,
                    size: 32),
              ),
              const SizedBox(width: 10),
              const Text('Kuroakai',
                  style: TextStyle(
                      color: KuroakaiTheme.textPrimary,
                      fontSize: 20,
                      fontWeight: FontWeight.bold,
                      letterSpacing: 1.1)),
              const SizedBox(width: 4),
              Container(
                padding:
                    const EdgeInsets.symmetric(horizontal: 5, vertical: 2),
                decoration: BoxDecoration(
                  color: KuroakaiTheme.primary,
                  borderRadius: BorderRadius.circular(4),
                ),
                child: const Text('HI-RES',
                    style: TextStyle(
                        color: Colors.white,
                        fontSize: 9,
                        fontWeight: FontWeight.bold)),
              ),
            ],
          ),
          const SizedBox(height: 30),

          // Nav items
          _buildSidebarNavItem(
              0, Icons.my_library_music_rounded, 'Library & Songs'),
          _buildSidebarNavItem(
              1, Icons.playlist_play_rounded, 'Playlists Manager'),
          _buildSidebarNavItem(2, Icons.explore_rounded, 'Discover'),
          _buildSidebarNavItem(
              3, Icons.graphic_eq_rounded, 'Audiophile EQ'),
          _buildSidebarNavItem(
              4, Icons.settings_rounded, 'Settings & Engine'),

          const Padding(
            padding: EdgeInsets.symmetric(vertical: 16.0),
            child: Divider(color: KuroakaiTheme.divider),
          ),

          // Playlists
          Consumer<LibraryProvider>(
            builder: (context, library, _) {
              return Expanded(
                child: Column(
                  children: [
                    Row(
                      mainAxisAlignment: MainAxisAlignment.spaceBetween,
                      children: [
                        const Text('YOUR PLAYLISTS',
                            style: TextStyle(
                                color: KuroakaiTheme.textTertiary,
                                fontSize: 11,
                                fontWeight: FontWeight.bold,
                                letterSpacing: 1.2)),
                        IconButton(
                          icon: const Icon(Icons.add_circle_outline,
                              color: KuroakaiTheme.primary, size: 20),
                          onPressed: () =>
                              _showCreatePlaylistDialog(library),
                          tooltip: 'Create Playlist',
                        ),
                      ],
                    ),
                    Expanded(
                      child: ListView.builder(
                        itemCount: library.playlists.length,
                        itemBuilder: (ctx, idx) {
                          final pl = library.playlists[idx];
                          final isSelected =
                              library.selectedPlaylist?.id == pl.id;
                          return ListTile(
                            dense: true,
                            contentPadding:
                                const EdgeInsets.symmetric(horizontal: 8),
                            leading: Icon(Icons.queue_music_rounded,
                                color: isSelected
                                    ? KuroakaiTheme.primary
                                    : KuroakaiTheme.textSecondary,
                                size: 18),
                            title: Text(pl.name,
                                maxLines: 1,
                                overflow: TextOverflow.ellipsis,
                                style: TextStyle(
                                    color: isSelected
                                        ? KuroakaiTheme.textPrimary
                                        : KuroakaiTheme.textSecondary,
                                    fontWeight: isSelected
                                        ? FontWeight.bold
                                        : FontWeight.normal,
                                    fontSize: 13)),
                            onTap: () {
                              library.selectPlaylist(pl);
                              setState(() => _currentNavIndex = 1);
                            },
                          );
                        },
                      ),
                    ),
                  ],
                ),
              );
            },
          ),

          // Open local file button
          SizedBox(
            width: double.infinity,
            child: ElevatedButton.icon(
              style: ElevatedButton.styleFrom(
                backgroundColor: KuroakaiTheme.primary,
                padding: const EdgeInsets.symmetric(vertical: 12),
                shape: RoundedRectangleBorder(
                    borderRadius: BorderRadius.circular(8)),
              ),
              icon: const Icon(Icons.folder_open_rounded,
                  color: Colors.white, size: 18),
              label: const Text('Open Local File',
                  style: TextStyle(
                      color: Colors.white, fontWeight: FontWeight.bold)),
              onPressed: () async {
                final path = await FilePickerService.pickAudioFile();
                if (path != null && mounted) {
                  final audio = context.read<AudioProvider>();
                  final library = context.read<LibraryProvider>();
                  audio.playFile(path);
                  library.addToLibrary(path);
                }
              },
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildSidebarNavItem(int index, IconData icon, String label) {
    final isSelected = _currentNavIndex == index;
    return InkWell(
      onTap: () => setState(() => _currentNavIndex = index),
      borderRadius: BorderRadius.circular(8),
      child: AnimatedContainer(
        duration: const Duration(milliseconds: 200),
        padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 10),
        margin: const EdgeInsets.only(bottom: 4),
        decoration: BoxDecoration(
          color: isSelected
              ? KuroakaiTheme.primary.withValues(alpha: 0.15)
              : Colors.transparent,
          borderRadius: BorderRadius.circular(8),
          border: isSelected
              ? const Border(
                  left: BorderSide(
                      color: KuroakaiTheme.primary, width: 3))
              : null,
        ),
        child: Row(
          children: [
            Icon(icon,
                color: isSelected
                    ? KuroakaiTheme.primary
                    : KuroakaiTheme.textSecondary,
                size: 20),
            const SizedBox(width: 12),
            Text(label,
                style: TextStyle(
                    color: isSelected
                        ? KuroakaiTheme.textPrimary
                        : KuroakaiTheme.textSecondary,
                    fontWeight: isSelected
                        ? FontWeight.bold
                        : FontWeight.normal,
                    fontSize: 14)),
          ],
        ),
      ),
    );
  }

  void _showCreatePlaylistDialog(LibraryProvider library) {
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

  // ═══════════════════════════════════════════════════════════
  // DESKTOP RIGHT PANEL (Now Playing)
  // ═══════════════════════════════════════════════════════════
  Widget _buildDesktopRightPanel() {
    return Consumer<AudioProvider>(
      builder: (context, audio, _) {
        return Container(
          width: 280,
          color: KuroakaiTheme.surfaceAlt,
          padding: const EdgeInsets.all(20),
          child: Column(
            children: [
              const Text('NOW PLAYING',
                  style: TextStyle(
                      color: KuroakaiTheme.textTertiary,
                      fontSize: 11,
                      fontWeight: FontWeight.bold,
                      letterSpacing: 1.2)),
              const SizedBox(height: 20),

              // Album art (tappable to open full player)
              GestureDetector(
                onTap: audio.hasTrack ? () => audio.openFullPlayer() : null,
                child: Hero(
                  tag: 'album_art_desktop',
                  child: Container(
                    width: 180,
                    height: 180,
                    decoration: BoxDecoration(
                      borderRadius: BorderRadius.circular(16),
                      boxShadow: [
                        BoxShadow(
                          color: KuroakaiTheme.primary.withValues(alpha: 0.25),
                          blurRadius: 20,
                          spreadRadius: 2,
                        ),
                      ],
                    ),
                    child: ClipRRect(
                      borderRadius: BorderRadius.circular(16),
                      child: audio.currentCoverArt != null
                          ? Image.memory(audio.currentCoverArt!,
                              fit: BoxFit.cover)
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
                              child: const Icon(
                                  Icons.music_note_rounded,
                                  color: Colors.white,
                                  size: 48),
                            ),
                    ),
                  ),
                ),
              ),
              const SizedBox(height: 20),

              Text(audio.currentTitle,
                  textAlign: TextAlign.center,
                  maxLines: 2,
                  overflow: TextOverflow.ellipsis,
                  style: const TextStyle(
                      color: KuroakaiTheme.textPrimary,
                      fontSize: 16,
                      fontWeight: FontWeight.bold)),
              const SizedBox(height: 6),
              Text(audio.currentArtist,
                  textAlign: TextAlign.center,
                  style: const TextStyle(
                      color: KuroakaiTheme.textSecondary, fontSize: 13)),
              const SizedBox(height: 24),
              const Divider(color: KuroakaiTheme.divider),
              const SizedBox(height: 16),

              // Specs card
              Container(
                padding: const EdgeInsets.all(14),
                decoration: KuroakaiTheme.cardDecoration,
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    const Row(
                      children: [
                        Icon(Icons.workspace_premium_rounded,
                            color: KuroakaiTheme.warning, size: 18),
                        SizedBox(width: 6),
                        Text('AUDIO SPECIFICATIONS',
                            style: TextStyle(
                                color: KuroakaiTheme.textSecondary,
                                fontSize: 11,
                                fontWeight: FontWeight.bold)),
                      ],
                    ),
                    const SizedBox(height: 12),
                    _buildSpecRow('Decoder Engine', 'Miniaudio C++'),
                    _buildSpecRow(
                        'Codec Format', audio.audioStatus.codecName),
                    _buildSpecRow('Sample Rate',
                        '${(audio.audioStatus.sampleRate / 1000).toStringAsFixed(1)} kHz'),
                    _buildSpecRow('Bit Depth',
                        '${audio.audioStatus.bitDepth}-bit Float'),
                    _buildSpecRow(
                        'Channels',
                        audio.audioStatus.channels == 2
                            ? 'Stereo (2.0)'
                            : 'Mono (1.0)'),
                    _buildSpecRow('Output Mode', 'Shared Direct PCM'),
                  ],
                ),
              ),
            ],
          ),
        );
      },
    );
  }

  Widget _buildSpecRow(String label, String value) {
    return Padding(
      padding: const EdgeInsets.only(bottom: 6.0),
      child: Row(
        mainAxisAlignment: MainAxisAlignment.spaceBetween,
        children: [
          Text(label,
              style: const TextStyle(
                  color: KuroakaiTheme.textTertiary, fontSize: 11)),
          Text(value,
              style: const TextStyle(
                  color: KuroakaiTheme.secondary,
                  fontSize: 11,
                  fontWeight: FontWeight.bold)),
        ],
      ),
    );
  }

  // ═══════════════════════════════════════════════════════════
  // DESKTOP BOTTOM BAR
  // ═══════════════════════════════════════════════════════════
  Widget _buildDesktopBottomBar() {
    return Consumer<AudioProvider>(
      builder: (context, audio, _) {
        return Container(
          height: 96,
          color: KuroakaiTheme.surface,
          padding: const EdgeInsets.symmetric(horizontal: 24, vertical: 8),
          child: Row(
            crossAxisAlignment: CrossAxisAlignment.center,
            children: [
              // Track info
              SizedBox(
                width: 240,
                child: Row(
                  children: [
                    GestureDetector(
                      onTap:
                          audio.hasTrack ? () => audio.openFullPlayer() : null,
                      child: ClipRRect(
                        borderRadius: BorderRadius.circular(8),
                        child: Container(
                          width: 52,
                          height: 52,
                          color: KuroakaiTheme.primary,
                          child: audio.currentCoverArt != null
                              ? Image.memory(audio.currentCoverArt!,
                                  fit: BoxFit.cover)
                              : const Icon(Icons.music_note_rounded,
                                  color: Colors.white, size: 30),
                        ),
                      ),
                    ),
                    const SizedBox(width: 14),
                    Expanded(
                      child: Column(
                        mainAxisAlignment: MainAxisAlignment.center,
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Text(audio.currentTitle,
                              maxLines: 1,
                              overflow: TextOverflow.ellipsis,
                              style: const TextStyle(
                                  color: KuroakaiTheme.textPrimary,
                                  fontWeight: FontWeight.bold,
                                  fontSize: 14)),
                          const SizedBox(height: 4),
                          Text(audio.currentArtist,
                              maxLines: 1,
                              overflow: TextOverflow.ellipsis,
                              style: const TextStyle(
                                  color: KuroakaiTheme.textSecondary,
                                  fontSize: 12)),
                        ],
                      ),
                    ),
                  ],
                ),
              ),

              // Transport controls
              Expanded(
                child: Column(
                  mainAxisAlignment: MainAxisAlignment.center,
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    Row(
                      mainAxisAlignment: MainAxisAlignment.center,
                      children: [
                        IconButton(
                          icon: const Icon(Icons.skip_previous_rounded,
                              color: KuroakaiTheme.textSecondary, size: 24),
                          onPressed: () {},
                        ),
                        const SizedBox(width: 16),
                        IconButton(
                          iconSize: 44,
                          padding: EdgeInsets.zero,
                          constraints: const BoxConstraints(),
                          icon: Icon(
                            audio.isPlaying
                                ? Icons.pause_circle_filled_rounded
                                : Icons.play_circle_fill_rounded,
                            color: KuroakaiTheme.primary,
                          ),
                          onPressed: audio.togglePlayPause,
                        ),
                        const SizedBox(width: 16),
                        IconButton(
                          icon: const Icon(Icons.skip_next_rounded,
                              color: KuroakaiTheme.textSecondary, size: 24),
                          onPressed: () {},
                        ),
                      ],
                    ),
                    const SizedBox(height: 4),
                    Row(
                      children: [
                        SizedBox(
                          width: 45,
                          child: Text(
                            audio.formatDuration(
                                audio.audioStatus.currentPosition),
                            textAlign: TextAlign.right,
                            style: const TextStyle(
                                color: KuroakaiTheme.textSecondary,
                                fontSize: 11,
                                fontWeight: FontWeight.w500),
                          ),
                        ),
                        const SizedBox(width: 10),
                        Expanded(
                          child: SliderTheme(
                            data: SliderTheme.of(context).copyWith(
                              trackHeight: 3.0,
                              thumbShape:
                                  const RoundSliderThumbShape(
                                      enabledThumbRadius: 6.0),
                              overlayShape:
                                  const RoundSliderOverlayShape(
                                      overlayRadius: 12.0),
                            ),
                            child: Slider(
                              value: audio.audioStatus.currentPosition
                                  .clamp(
                                      0.0,
                                      audio.audioStatus.duration > 0
                                          ? audio.audioStatus.duration
                                          : 1.0),
                              max: audio.audioStatus.duration > 0
                                  ? audio.audioStatus.duration
                                  : 1.0,
                              onChanged: (val) => audio.seek(val),
                            ),
                          ),
                        ),
                        const SizedBox(width: 10),
                        SizedBox(
                          width: 45,
                          child: Text(
                            audio.formatDuration(
                                audio.audioStatus.duration),
                            textAlign: TextAlign.left,
                            style: const TextStyle(
                                color: KuroakaiTheme.textSecondary,
                                fontSize: 11,
                                fontWeight: FontWeight.w500),
                          ),
                        ),
                      ],
                    ),
                  ],
                ),
              ),

              // Volume & Format badge
              SizedBox(
                width: 240,
                child: Row(
                  mainAxisAlignment: MainAxisAlignment.end,
                  children: [
                    Container(
                      padding: const EdgeInsets.symmetric(
                          horizontal: 10, vertical: 5),
                      decoration: BoxDecoration(
                        color: KuroakaiTheme.primary.withValues(alpha: 0.2),
                        borderRadius: BorderRadius.circular(6),
                        border: Border.all(color: KuroakaiTheme.primary),
                      ),
                      child: Text(audio.audioStatus.codecName,
                          style: const TextStyle(
                              color: KuroakaiTheme.secondary,
                              fontWeight: FontWeight.bold,
                              fontSize: 11)),
                    ),
                    const SizedBox(width: 14),
                    const Icon(Icons.volume_up_rounded,
                        color: KuroakaiTheme.textSecondary, size: 22),
                    const SizedBox(width: 6),
                    SizedBox(
                      width: 130,
                      child: SliderTheme(
                        data: SliderTheme.of(context).copyWith(
                          trackHeight: 4.0,
                          thumbShape: const RoundSliderThumbShape(
                              enabledThumbRadius: 7.0),
                        ),
                        child: Slider(
                          value: audio.localVolume,
                          min: 0.0,
                          max: 1.0,
                          onChanged: (val) => audio.setVolume(val),
                        ),
                      ),
                    ),
                  ],
                ),
              ),
            ],
          ),
        );
      },
    );
  }
}
