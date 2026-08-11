import 'dart:async';
import 'dart:io';
import 'package:flutter/material.dart';

import 'ffi/kuroakai_bindings.dart';
import 'services/app_link_service.dart';
import 'services/file_picker_service.dart';
import 'services/playlist_service.dart';

void main(List<String> args) {
  WidgetsFlutterBinding.ensureInitialized();
  runApp(KuroakaiAudioApp(initialArgs: args));
}

class KuroakaiAudioApp extends StatelessWidget {
  final List<String> initialArgs;

  const KuroakaiAudioApp({super.key, required this.initialArgs});

  @override
  Widget build(BuildContext context) {
    return MaterialApp(
      title: 'KuroakaiAudio',
      debugShowCheckedModeBanner: false,
      themeMode: ThemeMode.dark,
      darkTheme: ThemeData.dark().copyWith(
        scaffoldBackgroundColor: const Color(0xFF0F0F13),
        primaryColor: const Color(0xFFE50914),
        colorScheme: const ColorScheme.dark(
          primary: Color(0xFFE50914),
          secondary: Color(0xFFFF3344),
          surface: Color(0xFF181820),
        ),
        cardColor: const Color(0xFF1E1E28),
        dividerColor: Colors.white12,
        sliderTheme: const SliderThemeData(
          activeTrackColor: Color(0xFFE50914),
          inactiveTrackColor: Colors.white12,
          thumbColor: Color(0xFFFF3344),
          overlayColor: Color(0x33E50914),
          trackHeight: 4.0,
        ),
      ),
      home: MainScreen(initialArgs: initialArgs),
    );
  }
}

class MainScreen extends StatefulWidget {
  final List<String> initialArgs;

  const MainScreen({super.key, required this.initialArgs});

  @override
  State<MainScreen> createState() => _MainScreenState();
}

class _MainScreenState extends State<MainScreen>
    with SingleTickerProviderStateMixin {
  final KuroakaiAudioBindings _bindings = KuroakaiAudioBindings();
  late AppLinkService _appLinkService;
  Timer? _statusTimer;

  // Audio Engine State
  KuroakaiAudioStatus _audioStatus = KuroakaiAudioStatus(
    state: 0,
    currentPosition: 0.0,
    duration: 0.0,
    sampleRate: 44100,
    channels: 2,
    bitDepth: 24,
    volume: 1.0,
    codecName: 'N/A',
  );

  String? _currentFilePath;
  String _currentTitle = 'No Track Selected';
  String _currentArtist = 'Kuroakai Audio Engine';

  // Library & Playlists
  final List<String> _librarySongs = [];
  List<Playlist> _playlists = [];
  Playlist? _selectedPlaylist;

  // Navigation
  int _currentNavIndex = 0; // 0: Library, 1: Playlists, 2: Equalizer, 3: Settings

  // EQ Sliders (60Hz, 230Hz, 910Hz, 4kHz, 14kHz)
  List<double> _eqValues = [0.0, 0.0, 0.0, 0.0, 0.0];
  String _activeEqPreset = 'Direct Bit-Perfect';

  // Animation controller for Vinyl spinning
  late AnimationController _vinylAnimController;

  @override
  void initState() {
    super.initState();
    _vinylAnimController = AnimationController(
      vsync: this,
      duration: const Duration(seconds: 8),
    );

    _initAudioEngine();
    _loadPlaylistsData();
    _handleInitialArgs();
    _setupAppLinks();
  }

  void _initAudioEngine() {
    _bindings.initEngine();
    _statusTimer = Timer.periodic(const Duration(milliseconds: 250), (timer) {
      if (!mounted) return;
      setState(() {
        _audioStatus = _bindings.getStatus();
      });

      // Update vinyl animation based on playback state
      if (_audioStatus.isPlaying) {
        if (!_vinylAnimController.isAnimating) {
          _vinylAnimController.repeat();
        }
      } else {
        if (_vinylAnimController.isAnimating) {
          _vinylAnimController.stop();
        }
      }
    });
  }

  Future<void> _loadPlaylistsData() async {
    final loaded = await PlaylistService.loadPlaylists();
    setState(() {
      _playlists = loaded;
      if (_playlists.isNotEmpty) {
        _selectedPlaylist = _playlists.first;
      }
    });
  }

  void _handleInitialArgs() {
    if (widget.initialArgs.isNotEmpty) {
      final possiblePath = widget.initialArgs.first;
      if (File(possiblePath).existsSync()) {
        _playFile(possiblePath);
      }
    }
  }

  void _setupAppLinks() {
    _appLinkService = AppLinkService(onAudioFileOpened: (filePath) {
      if (mounted && File(filePath).existsSync()) {
        _playFile(filePath);
      }
    });
    _appLinkService.init(widget.initialArgs);
  }

  @override
  void dispose() {
    _statusTimer?.cancel();
    _appLinkService.dispose();
    _vinylAnimController.dispose();
    _bindings.cleanup();
    super.dispose();
  }

  Future<void> _playFile(String path) async {
    final fileName = path.split(Platform.pathSeparator).last;
    setState(() {
      _currentFilePath = path;
      _currentTitle = fileName.replaceAll(RegExp(r'\.[^.]+$'), '');
      _currentArtist = 'Local Lossless File';
      if (!_librarySongs.contains(path)) {
        _librarySongs.insert(0, path);
      }
    });

    _bindings.playFile(path);
  }

  void _onPlayPausePressed() {
    if (_audioStatus.isPlaying) {
      _bindings.pause();
    } else if (_audioStatus.isPaused) {
      _bindings.resume();
    } else {
      // Stopped or Error state
      if (_currentFilePath != null && _currentFilePath!.isNotEmpty) {
        _bindings.playFile(_currentFilePath!);
      } else {
        _pickAndPlayFile();
      }
    }
  }

  Future<void> _pickAndPlayFile() async {
    final path = await FilePickerService.pickAudioFile();
    if (path != null) {
      await _playFile(path);
    }
  }

  Future<void> _pickMultipleSongsForLibrary() async {
    final paths = await FilePickerService.pickMultipleAudioFiles();
    if (paths.isNotEmpty) {
      setState(() {
        for (var p in paths) {
          if (!_librarySongs.contains(p)) {
            _librarySongs.add(p);
          }
        }
      });
      if (_currentFilePath == null) {
        _playFile(paths.first);
      }
    }
  }

  String _formatDuration(double seconds) {
    if (seconds.isNaN || seconds.isInfinite || seconds <= 0) return '00:00';
    final duration = Duration(seconds: seconds.toInt());
    final mins = duration.inMinutes;
    final secs = duration.inSeconds % 60;
    return '${mins.toString().padLeft(2, '0')}:${secs.toString().padLeft(2, '0')}';
  }

  // --- Playlist Actions ---
  void _createNewPlaylist() {
    final controller = TextEditingController();
    showDialog(
      context: context,
      builder: (ctx) => AlertDialog(
        backgroundColor: const Color(0xFF1E1E28),
        title: const Text('Create New Playlist', style: TextStyle(color: Colors.white)),
        content: TextField(
          controller: controller,
          autofocus: true,
          style: const TextStyle(color: Colors.white),
          decoration: const InputDecoration(
            hintText: 'Enter playlist title...',
            hintStyle: TextStyle(color: Colors.white38),
            enabledBorder: UnderlineInputBorder(borderSide: BorderSide(color: Color(0xFFE50914))),
            focusedBorder: UnderlineInputBorder(borderSide: BorderSide(color: Color(0xFFFF3344))),
          ),
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(ctx),
            child: const Text('Cancel', style: TextStyle(color: Colors.white54)),
          ),
          ElevatedButton(
            style: ElevatedButton.styleFrom(backgroundColor: const Color(0xFFE50914)),
            onPressed: () async {
              final name = controller.text.trim();
              if (name.isNotEmpty) {
                final newPl = Playlist(
                  id: 'pl_${DateTime.now().millisecondsSinceEpoch}',
                  name: name,
                  songPaths: [],
                );
                setState(() {
                  _playlists.add(newPl);
                  _selectedPlaylist = newPl;
                });
                await PlaylistService.savePlaylists(_playlists);
                if (ctx.mounted) Navigator.pop(ctx);
              }
            },
            child: const Text('Create', style: TextStyle(color: Colors.white)),
          ),
        ],
      ),
    );
  }

  void _addSongToPlaylist(Playlist playlist) async {
    final paths = await FilePickerService.pickMultipleAudioFiles();
    if (paths.isNotEmpty) {
      setState(() {
        for (var p in paths) {
          if (!playlist.songPaths.contains(p)) {
            playlist.songPaths.add(p);
          }
          if (!_librarySongs.contains(p)) {
            _librarySongs.add(p);
          }
        }
      });
      await PlaylistService.savePlaylists(_playlists);
    }
  }

  void _deletePlaylist(Playlist playlist) async {
    setState(() {
      _playlists.removeWhere((p) => p.id == playlist.id);
      if (_selectedPlaylist?.id == playlist.id) {
        _selectedPlaylist = _playlists.isNotEmpty ? _playlists.first : null;
      }
    });
    await PlaylistService.savePlaylists(_playlists);
  }

  @override
  Widget build(BuildContext context) {
    final isDesktop = MediaQuery.of(context).size.width >= 700;

    return Scaffold(
      body: isDesktop ? _buildDesktopLayout() : _buildMobileLayout(),
    );
  }

  // ===========================================================================
  // DESKTOP SPOTIFY-ENCHANTED AUDIOPHILE DASHBOARD
  // ===========================================================================
  Widget _buildDesktopLayout() {
    return Column(
      children: [
        Expanded(
          child: Row(
            children: [
              // 1. Left Navigation Sidebar
              _buildDesktopSidebar(),
              // 2. Main Content View (Dynamic based on Tab)
              Expanded(child: _buildMainContentView()),
              // 3. Right Audiophile Now Playing Visualizer Panel
              _buildDesktopRightPanel(),
            ],
          ),
        ),
        // 4. Bottom Full-Width Player Bar
        _buildBottomPlayerBar(isDesktop: true),
      ],
    );
  }

  Widget _buildDesktopSidebar() {
    return Container(
      width: 240,
      color: const Color(0xFF14141A),
      padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 20),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          // Branding Logo
          Row(
            children: [
              Image.asset(
                'assets/logo.png',
                height: 32,
                errorBuilder: (ctx, err, stack) => const Icon(
                  Icons.album,
                  color: Color(0xFFE50914),
                  size: 32,
                ),
              ),
              const SizedBox(width: 10),
              const Text(
                'Kuroakai',
                style: TextStyle(
                  color: Colors.white,
                  fontSize: 20,
                  fontWeight: FontWeight.bold,
                  letterSpacing: 1.1,
                ),
              ),
              const SizedBox(width: 4),
              Container(
                padding: const EdgeInsets.symmetric(horizontal: 5, vertical: 2),
                decoration: BoxDecoration(
                  color: const Color(0xFFE50914),
                  borderRadius: BorderRadius.circular(4),
                ),
                child: const Text(
                  'HI-RES',
                  style: TextStyle(color: Colors.white, fontSize: 9, fontWeight: FontWeight.bold),
                ),
              ),
            ],
          ),
          const SizedBox(height: 30),

          // Nav Items
          _buildSidebarNavItem(0, Icons.my_library_music_rounded, 'Library & Songs'),
          _buildSidebarNavItem(1, Icons.playlist_play_rounded, 'Playlists Manager'),
          _buildSidebarNavItem(2, Icons.graphic_eq_rounded, 'Audiophile EQ'),
          _buildSidebarNavItem(3, Icons.settings_rounded, 'Settings & Engine'),

          const Padding(
            padding: EdgeInsets.symmetric(vertical: 16.0),
            child: Divider(color: Colors.white12),
          ),

          // Playlists Header & Add Button
          Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: [
              const Text(
                'YOUR PLAYLISTS',
                style: TextStyle(
                  color: Colors.white38,
                  fontSize: 11,
                  fontWeight: FontWeight.bold,
                  letterSpacing: 1.2,
                ),
              ),
              IconButton(
                icon: const Icon(Icons.add_circle_outline, color: Color(0xFFE50914), size: 20),
                onPressed: _createNewPlaylist,
                tooltip: 'Create Playlist',
              ),
            ],
          ),

          // Playlist Items List
          Expanded(
            child: ListView.builder(
              itemCount: _playlists.length,
              itemBuilder: (ctx, idx) {
                final pl = _playlists[idx];
                final isSelected = _selectedPlaylist?.id == pl.id;
                return ListTile(
                  dense: true,
                  contentPadding: const EdgeInsets.symmetric(horizontal: 8),
                  leading: Icon(
                    Icons.queue_music_rounded,
                    color: isSelected ? const Color(0xFFE50914) : Colors.white54,
                    size: 18,
                  ),
                  title: Text(
                    pl.name,
                    maxLines: 1,
                    overflow: TextOverflow.ellipsis,
                    style: TextStyle(
                      color: isSelected ? Colors.white : Colors.white70,
                      fontWeight: isSelected ? FontWeight.bold : FontWeight.normal,
                      fontSize: 13,
                    ),
                  ),
                  onTap: () {
                    setState(() {
                      _selectedPlaylist = pl;
                      _currentNavIndex = 1;
                    });
                  },
                );
              },
            ),
          ),

          // Pick Local File Button
          SizedBox(
            width: double.infinity,
            child: ElevatedButton.icon(
              style: ElevatedButton.styleFrom(
                backgroundColor: const Color(0xFFE50914),
                padding: const EdgeInsets.symmetric(vertical: 12),
                shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(8)),
              ),
              icon: const Icon(Icons.folder_open_rounded, color: Colors.white, size: 18),
              label: const Text('Open Local File', style: TextStyle(color: Colors.white, fontWeight: FontWeight.bold)),
              onPressed: _pickAndPlayFile,
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
      child: Container(
        padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 10),
        margin: const EdgeInsets.only(bottom: 4),
        decoration: BoxDecoration(
          color: isSelected ? const Color(0xFFE50914).withValues(alpha: 0.15) : Colors.transparent,
          borderRadius: BorderRadius.circular(8),
          border: isSelected ? const Border(left: BorderSide(color: Color(0xFFE50914), width: 3)) : null,
        ),
        child: Row(
          children: [
            Icon(icon, color: isSelected ? const Color(0xFFE50914) : Colors.white54, size: 20),
            const SizedBox(width: 12),
            Text(
              label,
              style: TextStyle(
                color: isSelected ? Colors.white : Colors.white70,
                fontWeight: isSelected ? FontWeight.bold : FontWeight.normal,
                fontSize: 14,
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildDesktopRightPanel() {
    return Container(
      width: 280,
      color: const Color(0xFF14141A),
      padding: const EdgeInsets.all(20),
      child: Column(
        children: [
          const Text(
            'NOW PLAYING',
            style: TextStyle(color: Colors.white38, fontSize: 11, fontWeight: FontWeight.bold, letterSpacing: 1.2),
          ),
          const SizedBox(height: 20),

          // Animated Spinning Vinyl Visualizer
          RotationTransition(
            turns: _vinylAnimController,
            child: Container(
              width: 180,
              height: 180,
              decoration: BoxDecoration(
                shape: BoxShape.circle,
                gradient: const RadialGradient(
                  colors: [Color(0xFF333344), Color(0xFF111115), Color(0xFF000000)],
                  stops: [0.2, 0.7, 1.0],
                ),
                boxShadow: [
                  BoxShadow(
                    color: const Color(0xFFE50914).withValues(alpha: 0.25),
                    blurRadius: 20,
                    spreadRadius: 2,
                  )
                ],
              ),
              child: Center(
                child: Container(
                  width: 60,
                  height: 60,
                  decoration: const BoxDecoration(
                    color: Color(0xFFE50914),
                    shape: BoxShape.circle,
                  ),
                  child: const Center(
                    child: Icon(Icons.music_note_rounded, color: Colors.white, size: 28),
                  ),
                ),
              ),
            ),
          ),
          const SizedBox(height: 20),

          Text(
            _currentTitle,
            textAlign: TextAlign.center,
            maxLines: 2,
            overflow: TextOverflow.ellipsis,
            style: const TextStyle(color: Colors.white, fontSize: 16, fontWeight: FontWeight.bold),
          ),
          const SizedBox(height: 6),
          Text(
            _currentArtist,
            textAlign: TextAlign.center,
            style: const TextStyle(color: Colors.white54, fontSize: 13),
          ),
          const SizedBox(height: 24),
          const Divider(color: Colors.white12),
          const SizedBox(height: 16),

          // Audiophile Specs Card
          Container(
            padding: const EdgeInsets.all(14),
            decoration: BoxDecoration(
              color: const Color(0xFF1E1E28),
              borderRadius: BorderRadius.circular(12),
              border: Border.all(color: Colors.white10),
            ),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                const Row(
                  children: [
                    Icon(Icons.workspace_premium_rounded, color: Color(0xFFFFD700), size: 18),
                    SizedBox(width: 6),
                    Text(
                      'AUDIO SPECIFICATIONS',
                      style: TextStyle(color: Colors.white70, fontSize: 11, fontWeight: FontWeight.bold),
                    ),
                  ],
                ),
                const SizedBox(height: 12),
                _buildSpecRow('Decoder Engine', 'Miniaudio C++'),
                _buildSpecRow('Codec Format', _audioStatus.codecName),
                _buildSpecRow('Sample Rate', '${(_audioStatus.sampleRate / 1000).toStringAsFixed(1)} kHz'),
                _buildSpecRow('Bit Depth', '${_audioStatus.bitDepth}-bit Float'),
                _buildSpecRow('Channels', _audioStatus.channels == 2 ? 'Stereo (2.0)' : 'Mono (1.0)'),
                _buildSpecRow('Output Mode', 'Shared Direct PCM'),
              ],
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildSpecRow(String label, String value) {
    return Padding(
      padding: const EdgeInsets.only(bottom: 6.0),
      child: Row(
        mainAxisAlignment: MainAxisAlignment.spaceBetween,
        children: [
          Text(label, style: const TextStyle(color: Colors.white38, fontSize: 11)),
          Text(value, style: const TextStyle(color: Color(0xFFFF3344), fontSize: 11, fontWeight: FontWeight.bold)),
        ],
      ),
    );
  }

  // ===========================================================================
  // MOBILE NAVIGATION LAYOUT (< 700px Width)
  // ===========================================================================
  Widget _buildMobileLayout() {
    return Column(
      children: [
        // Main Content Area
        Expanded(child: _buildMainContentView()),

        // Mini Player Bar (When Track Selected)
        if (_currentFilePath != null) _buildMiniPlayerBar(),

        // Bottom Navigation Bar (4 Tabs)
        BottomNavigationBar(
          currentIndex: _currentNavIndex,
          onTap: (index) => setState(() => _currentNavIndex = index),
          backgroundColor: const Color(0xFF14141A),
          selectedItemColor: const Color(0xFFE50914),
          unselectedItemColor: Colors.white38,
          type: BottomNavigationBarType.fixed,
          items: const [
            BottomNavigationBarItem(icon: Icon(Icons.my_library_music_rounded), label: 'Library'),
            BottomNavigationBarItem(icon: Icon(Icons.playlist_play_rounded), label: 'Playlists'),
            BottomNavigationBarItem(icon: Icon(Icons.graphic_eq_rounded), label: 'Equalizer'),
            BottomNavigationBarItem(icon: Icon(Icons.settings_rounded), label: 'Settings'),
          ],
        ),
      ],
    );
  }

  Widget _buildMiniPlayerBar() {
    return Container(
      height: 64,
      color: const Color(0xFF1E1E28),
      padding: const EdgeInsets.symmetric(horizontal: 16),
      child: Row(
        children: [
          const Icon(Icons.album_rounded, color: Color(0xFFE50914), size: 36),
          const SizedBox(width: 12),
          Expanded(
            child: Column(
              mainAxisAlignment: MainAxisAlignment.center,
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  _currentTitle,
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis,
                  style: const TextStyle(color: Colors.white, fontWeight: FontWeight.bold, fontSize: 13),
                ),
                Text(
                  '${_audioStatus.codecName} • ${(_audioStatus.sampleRate / 1000).toStringAsFixed(1)} kHz',
                  style: const TextStyle(color: Colors.white54, fontSize: 11),
                ),
              ],
            ),
          ),
          IconButton(
            icon: Icon(
              _audioStatus.isPlaying
                  ? Icons.pause_circle_filled_rounded
                  : Icons.play_circle_fill_rounded,
              color: const Color(0xFFE50914),
              size: 38,
            ),
            onPressed: _onPlayPausePressed,
          ),
        ],
      ),
    );
  }

  // ===========================================================================
  // MAIN DYNAMIC CONTENT VIEWS
  // ===========================================================================
  Widget _buildMainContentView() {
    switch (_currentNavIndex) {
      case 0:
        return _buildLibraryView();
      case 1:
        return _buildPlaylistsView();
      case 2:
        return _buildEqualizerView();
      case 3:
        return _buildSettingsView();
      default:
        return _buildLibraryView();
    }
  }

  // TAB 0: LIBRARY & SONGS
  Widget _buildLibraryView() {
    return Container(
      color: const Color(0xFF0F0F13),
      padding: const EdgeInsets.all(20),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          // Banner & Action Row
          Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: [
              const Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text('Music Library', style: TextStyle(color: Colors.white, fontSize: 24, fontWeight: FontWeight.bold)),
                  Text('Local Lossless Audio Files', style: TextStyle(color: Colors.white54, fontSize: 13)),
                ],
              ),
              ElevatedButton.icon(
                style: ElevatedButton.styleFrom(
                  backgroundColor: const Color(0xFFE50914),
                  padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
                  shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(8)),
                ),
                icon: const Icon(Icons.add_rounded, color: Colors.white),
                label: const Text('Add Songs', style: TextStyle(color: Colors.white, fontWeight: FontWeight.bold)),
                onPressed: _pickMultipleSongsForLibrary,
              ),
            ],
          ),
          const SizedBox(height: 20),

          // Songs Table / List
          Expanded(
            child: _librarySongs.isEmpty
                ? _buildEmptyState(
                    icon: Icons.library_music_rounded,
                    title: 'No Local Songs Added Yet',
                    subtitle: 'Click "Add Songs" or "Open Local File" to browse Hi-Res audio tracks.',
                    actionLabel: 'Select Songs',
                    onAction: _pickMultipleSongsForLibrary,
                  )
                : ListView.builder(
                    itemCount: _librarySongs.length,
                    itemBuilder: (ctx, idx) {
                      final path = _librarySongs[idx];
                      final name = path.split(Platform.pathSeparator).last;
                      final isPlaying = _currentFilePath == path;

                      return Card(
                        color: isPlaying ? const Color(0xFFE50914).withValues(alpha: 0.15) : const Color(0xFF181820),
                        margin: const EdgeInsets.only(bottom: 8),
                        child: ListTile(
                          leading: Icon(
                            isPlaying ? Icons.graphic_eq_rounded : Icons.audio_file_rounded,
                            color: isPlaying ? const Color(0xFFE50914) : Colors.white38,
                          ),
                          title: Text(
                            name,
                            maxLines: 1,
                            overflow: TextOverflow.ellipsis,
                            style: TextStyle(
                              color: isPlaying ? const Color(0xFFFF3344) : Colors.white,
                              fontWeight: isPlaying ? FontWeight.bold : FontWeight.normal,
                            ),
                          ),
                          subtitle: Text(path, maxLines: 1, overflow: TextOverflow.ellipsis, style: const TextStyle(color: Colors.white38, fontSize: 11)),
                          trailing: Row(
                            mainAxisSize: MainAxisSize.min,
                            children: [
                              PopupMenuButton<Playlist>(
                                icon: const Icon(Icons.playlist_add_rounded, color: Colors.white54),
                                tooltip: 'Add to Playlist',
                                color: const Color(0xFF1E1E28),
                                onSelected: (pl) async {
                                  if (!pl.songPaths.contains(path)) {
                                    setState(() => pl.songPaths.add(path));
                                    await PlaylistService.savePlaylists(_playlists);
                                    if (mounted) {
                                      ScaffoldMessenger.of(context).showSnackBar(
                                        SnackBar(content: Text('Added to ${pl.name}')),
                                      );
                                    }
                                  }
                                },
                                itemBuilder: (ctx) => _playlists.map((pl) {
                                  return PopupMenuItem(
                                    value: pl,
                                    child: Text(pl.name, style: const TextStyle(color: Colors.white)),
                                  );
                                }).toList(),
                              ),
                              IconButton(
                                icon: Icon(
                                  isPlaying && _audioStatus.isPlaying
                                      ? Icons.pause_circle_rounded
                                      : Icons.play_circle_rounded,
                                  color: const Color(0xFFE50914),
                                ),
                                onPressed: () => _playFile(path),
                              ),
                            ],
                          ),
                        ),
                      );
                    },
                  ),
          ),
        ],
      ),
    );
  }

  // TAB 1: PLAYLISTS MANAGER
  Widget _buildPlaylistsView() {
    return Container(
      color: const Color(0xFF0F0F13),
      padding: const EdgeInsets.all(20),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          // Header & Create Button
          Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: [
              const Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text('Playlists Manager', style: TextStyle(color: Colors.white, fontSize: 24, fontWeight: FontWeight.bold)),
                  Text('Create, Edit, and Manage Custom Playlists', style: TextStyle(color: Colors.white54, fontSize: 13)),
                ],
              ),
              ElevatedButton.icon(
                style: ElevatedButton.styleFrom(
                  backgroundColor: const Color(0xFFE50914),
                  padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
                  shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(8)),
                ),
                icon: const Icon(Icons.playlist_add_rounded, color: Colors.white),
                label: const Text('New Playlist', style: TextStyle(color: Colors.white, fontWeight: FontWeight.bold)),
                onPressed: _createNewPlaylist,
              ),
            ],
          ),
          const SizedBox(height: 20),

          // Playlists Grid / Selector
          if (_playlists.isEmpty)
            Expanded(
              child: _buildEmptyState(
                icon: Icons.queue_music_rounded,
                title: 'No Playlists Created',
                subtitle: 'Create custom playlists to organize your Hi-Res audio collection.',
                actionLabel: 'Create Playlist',
                onAction: _createNewPlaylist,
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
                      itemCount: _playlists.length,
                      itemBuilder: (ctx, idx) {
                        final pl = _playlists[idx];
                        final isSel = _selectedPlaylist?.id == pl.id;
                        return Padding(
                          padding: const EdgeInsets.only(right: 8.0),
                          child: ChoiceChip(
                            label: Text(pl.name),
                            selected: isSel,
                            selectedColor: const Color(0xFFE50914),
                            backgroundColor: const Color(0xFF1E1E28),
                            labelStyle: TextStyle(color: isSel ? Colors.white : Colors.white70, fontWeight: isSel ? FontWeight.bold : FontWeight.normal),
                            onSelected: (sel) {
                              if (sel) setState(() => _selectedPlaylist = pl);
                            },
                          ),
                        );
                      },
                    ),
                  ),
                  const SizedBox(height: 16),

                  // Selected Playlist Details & Tracks
                  if (_selectedPlaylist != null) ...[
                    Row(
                      mainAxisAlignment: MainAxisAlignment.spaceBetween,
                      children: [
                        Text(
                          '${_selectedPlaylist!.name} (${_selectedPlaylist!.songPaths.length} Songs)',
                          style: const TextStyle(color: Colors.white, fontSize: 16, fontWeight: FontWeight.bold),
                        ),
                        Row(
                          children: [
                            IconButton(
                              icon: const Icon(Icons.library_add_rounded, color: Color(0xFFE50914)),
                              tooltip: 'Add Tracks to Playlist',
                              onPressed: () => _addSongToPlaylist(_selectedPlaylist!),
                            ),
                            IconButton(
                              icon: const Icon(Icons.delete_outline_rounded, color: Colors.white38),
                              tooltip: 'Delete Playlist',
                              onPressed: () => _deletePlaylist(_selectedPlaylist!),
                            ),
                          ],
                        ),
                      ],
                    ),
                    const SizedBox(height: 8),

                    Expanded(
                      child: _selectedPlaylist!.songPaths.isEmpty
                          ? _buildEmptyState(
                              icon: Icons.music_off_rounded,
                              title: 'Playlist is Empty',
                              subtitle: 'Add local audio files to this playlist.',
                              actionLabel: 'Add Songs',
                              onAction: () => _addSongToPlaylist(_selectedPlaylist!),
                            )
                          : ListView.builder(
                              itemCount: _selectedPlaylist!.songPaths.length,
                              itemBuilder: (ctx, idx) {
                                final path = _selectedPlaylist!.songPaths[idx];
                                final name = path.split(Platform.pathSeparator).last;
                                return Card(
                                  color: const Color(0xFF181820),
                                  margin: const EdgeInsets.only(bottom: 6),
                                  child: ListTile(
                                    leading: const Icon(Icons.music_note_rounded, color: Color(0xFFE50914)),
                                    title: Text(name, style: const TextStyle(color: Colors.white)),
                                    subtitle: Text(path, style: const TextStyle(color: Colors.white38, fontSize: 11)),
                                    trailing: IconButton(
                                      icon: const Icon(Icons.remove_circle_outline, color: Colors.white38),
                                      onPressed: () async {
                                        setState(() {
                                          _selectedPlaylist!.songPaths.removeAt(idx);
                                        });
                                        await PlaylistService.savePlaylists(_playlists);
                                      },
                                    ),
                                    onTap: () => _playFile(path),
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
  }

  // TAB 2: AUDIOPHILE EQUALIZER
  Widget _buildEqualizerView() {
    final bands = ['60 Hz', '230 Hz', '910 Hz', '4 kHz', '14 kHz'];
    final presets = ['Direct Bit-Perfect', 'Bass Boost', 'Vocal Enhancement', 'Treble Boost'];

    return Container(
      color: const Color(0xFF0F0F13),
      padding: const EdgeInsets.all(20),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          const Text('Audiophile Equalizer', style: TextStyle(color: Colors.white, fontSize: 24, fontWeight: FontWeight.bold)),
          const Text('5-Band Parametric Sound Tuning & Presets', style: TextStyle(color: Colors.white54, fontSize: 13)),
          const SizedBox(height: 20),

          // Presets row
          SizedBox(
            height: 40,
            child: ListView.builder(
              scrollDirection: Axis.horizontal,
              itemCount: presets.length,
              itemBuilder: (ctx, idx) {
                final preset = presets[idx];
                final isSel = _activeEqPreset == preset;
                return Padding(
                  padding: const EdgeInsets.only(right: 8.0),
                  child: ChoiceChip(
                    label: Text(preset),
                    selected: isSel,
                    selectedColor: const Color(0xFFE50914),
                    backgroundColor: const Color(0xFF1E1E28),
                    labelStyle: TextStyle(color: isSel ? Colors.white : Colors.white70, fontWeight: isSel ? FontWeight.bold : FontWeight.normal),
                    onSelected: (sel) {
                      if (sel) {
                        setState(() {
                          _activeEqPreset = preset;
                          if (preset == 'Direct Bit-Perfect') _eqValues = [0, 0, 0, 0, 0];
                          if (preset == 'Bass Boost') _eqValues = [6, 4, 0, 0, -2];
                          if (preset == 'Vocal Enhancement') _eqValues = [-2, 2, 5, 3, 0];
                          if (preset == 'Treble Boost') _eqValues = [-3, 0, 1, 4, 7];
                        });
                      }
                    },
                  ),
                );
              },
            ),
          ),
          const SizedBox(height: 30),

          // EQ Sliders Vertical Columns
          Expanded(
            child: Container(
              padding: const EdgeInsets.all(20),
              decoration: BoxDecoration(
                color: const Color(0xFF181820),
                borderRadius: BorderRadius.circular(16),
                border: Border.all(color: Colors.white10),
              ),
              child: Row(
                mainAxisAlignment: MainAxisAlignment.spaceAround,
                children: List.generate(5, (idx) {
                  return Column(
                    children: [
                      Text('${_eqValues[idx] > 0 ? '+' : ''}${_eqValues[idx].toInt()} dB', style: const TextStyle(color: Color(0xFFFF3344), fontWeight: FontWeight.bold, fontSize: 12)),
                      const SizedBox(height: 12),
                      Expanded(
                        child: RotatedBox(
                          quarterTurns: 3,
                          child: Slider(
                            value: _eqValues[idx],
                            min: -12.0,
                            max: 12.0,
                            onChanged: (val) {
                              setState(() {
                                _eqValues[idx] = val;
                                _activeEqPreset = 'Custom';
                              });
                            },
                          ),
                        ),
                      ),
                      const SizedBox(height: 12),
                      Text(bands[idx], style: const TextStyle(color: Colors.white54, fontSize: 12, fontWeight: FontWeight.bold)),
                    ],
                  );
                }),
              ),
            ),
          ),
        ],
      ),
    );
  }

  // TAB 3: SETTINGS & AUDIO ENGINE
  Widget _buildSettingsView() {
    return Container(
      color: const Color(0xFF0F0F13),
      padding: const EdgeInsets.all(20),
      child: ListView(
        children: [
          const Text('Engine & Settings', style: TextStyle(color: Colors.white, fontSize: 24, fontWeight: FontWeight.bold)),
          const Text('Kuroakai Audio Core System Information', style: TextStyle(color: Colors.white54, fontSize: 13)),
          const SizedBox(height: 20),

          _buildSettingCard(
            title: 'Native Audio Core',
            subtitle: 'Powered by Miniaudio C++ Single-Header Engine',
            icon: Icons.memory_rounded,
            trailing: const Text('ACTIVE', style: TextStyle(color: Colors.greenAccent, fontWeight: FontWeight.bold)),
          ),
          _buildSettingCard(
            title: 'Audio Output Mode',
            subtitle: 'High-Fidelity Shared PCM Direct Driver',
            icon: Icons.speaker_group_rounded,
            trailing: const Text('32-BIT FLOAT', style: TextStyle(color: Color(0xFFE50914), fontWeight: FontWeight.bold)),
          ),
          _buildSettingCard(
            title: 'Supported Formats',
            subtitle: 'FLAC, DSD (.dsf, .dff), MP3, WAV, AAC, ALAC, AIFF',
            icon: Icons.audio_file_rounded,
            trailing: const Text('LOSSLESS', style: TextStyle(color: Color(0xFFFF3344), fontWeight: FontWeight.bold)),
          ),
          _buildSettingCard(
            title: 'OS Integration',
            subtitle: 'Default File Association for Audio Extensions',
            icon: Icons.integration_instructions_rounded,
            trailing: const Text('CONFIGURED', style: TextStyle(color: Colors.blueAccent, fontWeight: FontWeight.bold)),
          ),
        ],
      ),
    );
  }

  Widget _buildSettingCard({required String title, required String subtitle, required IconData icon, required Widget trailing}) {
    return Card(
      color: const Color(0xFF181820),
      margin: const EdgeInsets.only(bottom: 12),
      child: ListTile(
        leading: Icon(icon, color: const Color(0xFFE50914)),
        title: Text(title, style: const TextStyle(color: Colors.white, fontWeight: FontWeight.bold)),
        subtitle: Text(subtitle, style: const TextStyle(color: Colors.white54, fontSize: 12)),
        trailing: trailing,
      ),
    );
  }

  Widget _buildEmptyState({
    required IconData icon,
    required String title,
    required String subtitle,
    required String actionLabel,
    required VoidCallback onAction,
  }) {
    return Center(
      child: Column(
        mainAxisAlignment: MainAxisAlignment.center,
        children: [
          Icon(icon, size: 64, color: Colors.white24),
          const SizedBox(height: 16),
          Text(title, style: const TextStyle(color: Colors.white, fontSize: 18, fontWeight: FontWeight.bold)),
          const SizedBox(height: 8),
          Padding(
            padding: const EdgeInsets.symmetric(horizontal: 32.0),
            child: Text(subtitle, textAlign: TextAlign.center, style: const TextStyle(color: Colors.white38, fontSize: 13)),
          ),
          const SizedBox(height: 20),
          ElevatedButton(
            style: ElevatedButton.styleFrom(backgroundColor: const Color(0xFFE50914)),
            onPressed: onAction,
            child: Text(actionLabel, style: const TextStyle(color: Colors.white)),
          ),
        ],
      ),
    );
  }

  // ===========================================================================
  // BOTTOM PLAYER BAR (DESKTOP FULL WIDTH)
  // ===========================================================================
  Widget _buildBottomPlayerBar({required bool isDesktop}) {
    return Container(
      height: 90,
      color: const Color(0xFF181820),
      padding: const EdgeInsets.symmetric(horizontal: 20),
      child: Row(
        children: [
          // Track Thumbnail & Title Info
          SizedBox(
            width: 220,
            child: Row(
              children: [
                Container(
                  width: 50,
                  height: 50,
                  decoration: BoxDecoration(
                    color: const Color(0xFFE50914),
                    borderRadius: BorderRadius.circular(8),
                  ),
                  child: const Icon(Icons.music_note_rounded, color: Colors.white, size: 28),
                ),
                const SizedBox(width: 12),
                Expanded(
                  child: Column(
                    mainAxisAlignment: MainAxisAlignment.center,
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        _currentTitle,
                        maxLines: 1,
                        overflow: TextOverflow.ellipsis,
                        style: const TextStyle(color: Colors.white, fontWeight: FontWeight.bold, fontSize: 14),
                      ),
                      const SizedBox(height: 4),
                      Text(
                        _currentArtist,
                        maxLines: 1,
                        overflow: TextOverflow.ellipsis,
                        style: const TextStyle(color: Colors.white54, fontSize: 12),
                      ),
                    ],
                  ),
                ),
              ],
            ),
          ),

          // Central Transport Controls & Scrub Slider
          Expanded(
            child: Column(
              mainAxisAlignment: MainAxisAlignment.center,
              children: [
                // Transport Buttons
                Row(
                  mainAxisAlignment: MainAxisAlignment.center,
                  children: [
                    IconButton(
                      icon: const Icon(Icons.skip_previous_rounded, color: Colors.white70),
                      onPressed: () {
                        if (_librarySongs.isNotEmpty) {
                          _playFile(_librarySongs.first);
                        }
                      },
                    ),
                    const SizedBox(width: 12),
                    IconButton(
                      iconSize: 42,
                      icon: Icon(
                        _audioStatus.isPlaying
                            ? Icons.pause_circle_filled_rounded
                            : Icons.play_circle_fill_rounded,
                        color: const Color(0xFFE50914),
                      ),
                      onPressed: _onPlayPausePressed,
                    ),
                    const SizedBox(width: 12),
                    IconButton(
                      icon: const Icon(Icons.skip_next_rounded, color: Colors.white70),
                      onPressed: () {
                        if (_librarySongs.length > 1) {
                          _playFile(_librarySongs.last);
                        }
                      },
                    ),
                  ],
                ),

                // Scrub Bar Slider & Time
                Row(
                  children: [
                    Text(_formatDuration(_audioStatus.currentPosition), style: const TextStyle(color: Colors.white38, fontSize: 11)),
                    Expanded(
                      child: Slider(
                        value: _audioStatus.currentPosition.clamp(0.0, _audioStatus.duration > 0 ? _audioStatus.duration : 1.0),
                        max: _audioStatus.duration > 0 ? _audioStatus.duration : 1.0,
                        onChanged: (val) {
                          _bindings.seek(val);
                        },
                      ),
                    ),
                    Text(_formatDuration(_audioStatus.duration), style: const TextStyle(color: Colors.white38, fontSize: 11)),
                  ],
                ),
              ],
            ),
          ),

          // Volume & Audio Format Badge
          SizedBox(
            width: 220,
            child: Row(
              mainAxisAlignment: MainAxisAlignment.end,
              children: [
                Container(
                  padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
                  decoration: BoxDecoration(
                    color: const Color(0xFFE50914).withValues(alpha: 0.2),
                    borderRadius: BorderRadius.circular(6),
                    border: Border.all(color: const Color(0xFFE50914)),
                  ),
                  child: Text(
                    _audioStatus.codecName,
                    style: const TextStyle(color: Color(0xFFFF3344), fontWeight: FontWeight.bold, fontSize: 10),
                  ),
                ),
                const SizedBox(width: 12),
                const Icon(Icons.volume_up_rounded, color: Colors.white54, size: 20),
                SizedBox(
                  width: 90,
                  child: Slider(
                    value: _audioStatus.volume,
                    onChanged: (val) {
                      _bindings.setVolume(val);
                    },
                  ),
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }
}
