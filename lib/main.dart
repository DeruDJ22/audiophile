import 'dart:async';
import 'package:flutter/material.dart';
import 'ffi/kuroakai_bindings.dart';
import 'services/file_picker_service.dart';
import 'services/app_link_service.dart';

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
      theme: ThemeData.dark().copyWith(
        scaffoldBackgroundColor: const Color(0xFF0B0C10),
        colorScheme: const ColorScheme.dark(
          primary: Color(0xFFE50914), // Ruby Red Accent
          secondary: Color(0xFFFF2E63),
          surface: Color(0xFF1F2833),
        ),
        appBarTheme: const AppBarTheme(
          backgroundColor: Color(0xFF0B0C10),
          elevation: 0,
        ),
      ),
      home: AudioPlayerScreen(initialArgs: initialArgs),
    );
  }
}

class AudioPlayerScreen extends StatefulWidget {
  final List<String> initialArgs;

  const AudioPlayerScreen({super.key, required this.initialArgs});

  @override
  State<AudioPlayerScreen> createState() => _AudioPlayerScreenState();
}

class _AudioPlayerScreenState extends State<AudioPlayerScreen> {
  final _bindings = KuroakaiAudioBindings();
  late AppLinkService _appLinkService;
  Timer? _statusTimer;

  String? _currentFilePath;
  KuroakaiAudioStatus _status = KuroakaiAudioStatus(
    state: 0,
    currentPosition: 0,
    duration: 0,
    sampleRate: 0,
    channels: 2,
    bitDepth: 16,
    volume: 1.0,
    codecName: 'N/A',
  );

  bool _isEngineInitialized = false;
  String _statusMessage = 'Engine ready';

  @override
  void initState() {
    super.initState();
    _initEngine();
    
    _appLinkService = AppLinkService(
      onAudioFileOpened: (filePath) {
        _playAudioFile(filePath);
      },
    );
    _appLinkService.init(widget.initialArgs);

    // Poll engine status at 10Hz for smooth timeline UI updating
    _statusTimer = Timer.periodic(const Duration(milliseconds: 100), (timer) {
      if (_isEngineInitialized) {
        setState(() {
          _status = _bindings.getStatus();
        });
      }
    });
  }

  void _initEngine() {
    try {
      final res = _bindings.initEngine();
      if (res == 0) {
        setState(() {
          _isEngineInitialized = true;
          _statusMessage = 'WASAPI Exclusive / Oboe Bit-Perfect Engine Online';
        });
      } else {
        setState(() {
          _statusMessage = 'Failed to init engine code: $res';
        });
      }
    } catch (e) {
      setState(() {
        _statusMessage = 'Native Library Error: $e';
      });
    }
  }

  void _playAudioFile(String path) {
    try {
      final res = _bindings.playFile(path);
      if (res == 0) {
        setState(() {
          _currentFilePath = path;
          _statusMessage = 'Playing: ${path.split(RegExp(r'[/\\]')).last}';
        });
      } else {
        setState(() {
          _statusMessage = 'Playback error code: $res';
        });
      }
    } catch (e) {
      setState(() {
        _statusMessage = 'FFI Exception: $e';
      });
    }
  }

  Future<void> _pickAndPlayFile() async {
    try {
      final path = await FilePickerService.pickAudioFile();
      if (path != null) {
        _playAudioFile(path);
      }
    } catch (e) {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text('File Pick Error: $e')),
      );
    }
  }

  @override
  void dispose() {
    _statusTimer?.cancel();
    _appLinkService.dispose();
    _bindings.cleanup();
    super.dispose();
  }

  String _formatDuration(double seconds) {
    final duration = Duration(seconds: seconds.toInt());
    final mins = duration.inMinutes;
    final secs = duration.inSeconds % 60;
    return '${mins.toString().padLeft(2, '0')}:${secs.toString().padLeft(2, '0')}';
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      body: SafeArea(
        child: Padding(
          padding: const EdgeInsets.symmetric(horizontal: 24.0, vertical: 16.0),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.center,
            children: [
              // Header & Logo Branding
              Row(
                mainAxisAlignment: MainAxisAlignment.spaceBetween,
                children: [
                  Row(
                    children: [
                      Image.asset(
                        'assets/logo.png',
                        height: 36,
                        errorBuilder: (ctx, err, stack) => const Icon(
                          Icons.album,
                          color: Color(0xFFE50914),
                          size: 32,
                        ),
                      ),
                      const SizedBox(width: 12),
                      const Text(
                        'KUROAKAI',
                        style: TextStyle(
                          fontSize: 20,
                          fontWeight: FontWeight.bold,
                          letterSpacing: 3,
                          color: Colors.white,
                        ),
                      ),
                    ],
                  ),
                  Container(
                    padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 4),
                    decoration: BoxDecoration(
                      color: const Color(0xFFE50914).withOpacity(0.15),
                      borderRadius: BorderRadius.circular(12),
                      border: Border.all(color: const Color(0xFFE50914)),
                    ),
                    child: const Text(
                      'BIT-PERFECT',
                      style: TextStyle(
                        fontSize: 10,
                        fontWeight: FontWeight.bold,
                        color: Color(0xFFE50914),
                        letterSpacing: 1.5,
                      ),
                    ),
                  ),
                ],
              ),
              const SizedBox(height: 40),

              // Album Art / Visualizer Placeholder
              Expanded(
                child: Center(
                  child: Container(
                    width: 260,
                    height: 260,
                    decoration: BoxDecoration(
                      shape: BoxShape.circle,
                      gradient: RadialGradient(
                        colors: [
                          const Color(0xFFE50914).withOpacity(0.3),
                          const Color(0xFF1F2833),
                          const Color(0xFF0B0C10),
                        ],
                        radius: 0.85,
                      ),
                      boxShadow: [
                        BoxShadow(
                          color: const Color(0xFFE50914).withOpacity(0.25),
                          blurRadius: 30,
                          spreadRadius: 5,
                        ),
                      ],
                    ),
                    child: Center(
                      child: Column(
                        mainAxisAlignment: MainAxisAlignment.center,
                        children: [
                          Icon(
                            _status.isPlaying ? Icons.graphic_eq : Icons.music_note,
                            size: 64,
                            color: const Color(0xFFE50914),
                          ),
                          const SizedBox(height: 12),
                          Text(
                            _status.codecName.toUpperCase(),
                            style: const TextStyle(
                              color: Colors.white70,
                              fontWeight: FontWeight.w600,
                              letterSpacing: 2,
                            ),
                          ),
                        ],
                      ),
                    ),
                  ),
                ),
              ),

              // Audio Format Specs Badge
              Container(
                padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
                decoration: BoxDecoration(
                  color: const Color(0xFF1F2833),
                  borderRadius: BorderRadius.circular(20),
                ),
                child: Text(
                  _status.formattedFormatInfo,
                  style: const TextStyle(
                    color: Colors.white70,
                    fontSize: 12,
                    fontFamily: 'monospace',
                  ),
                ),
              ),
              const SizedBox(height: 16),

              // Track Title & File Path
              Text(
                _currentFilePath != null
                    ? _currentFilePath!.split(RegExp(r'[/\\]')).last
                    : 'No Track Loaded',
                style: const TextStyle(
                  fontSize: 18,
                  fontWeight: FontWeight.w600,
                  color: Colors.white,
                ),
                textAlign: TextAlign.center,
                maxLines: 1,
                overflow: TextOverflow.ellipsis,
              ),
              const SizedBox(height: 4),
              Text(
                _statusMessage,
                style: const TextStyle(fontSize: 12, color: Colors.white38),
                textAlign: TextAlign.center,
                maxLines: 1,
              ),
              const SizedBox(height: 24),

              // Timeline Progress Slider
              Column(
                children: [
                  SliderTheme(
                    data: SliderTheme.of(context).copyWith(
                      activeTrackColor: const Color(0xFFE50914),
                      inactiveTrackColor: Colors.white12,
                      thumbColor: const Color(0xFFE50914),
                      trackHeight: 3,
                    ),
                    child: Slider(
                      min: 0,
                      max: _status.duration > 0 ? _status.duration : 1,
                      value: _status.currentPosition.clamp(
                          0, _status.duration > 0 ? _status.duration : 1),
                      onChanged: (val) {
                        _bindings.seek(val);
                      },
                    ),
                  ),
                  Padding(
                    padding: const EdgeInsets.symmetric(horizontal: 8.0),
                    child: Row(
                      mainAxisAlignment: MainAxisAlignment.spaceBetween,
                      children: [
                        Text(
                          _formatDuration(_status.currentPosition),
                          style: const TextStyle(fontSize: 11, color: Colors.white54),
                        ),
                        Text(
                          _formatDuration(_status.duration),
                          style: const TextStyle(fontSize: 11, color: Colors.white54),
                        ),
                      ],
                    ),
                  ),
                ],
              ),
              const SizedBox(height: 16),

              // Transport Controls (Play / Pause / Stop / Browse)
              Row(
                mainAxisAlignment: MainAxisAlignment.spaceEvenly,
                children: [
                  IconButton(
                    iconSize: 28,
                    icon: const Icon(Icons.folder_open, color: Colors.white70),
                    onPressed: _pickAndPlayFile,
                    tooltip: 'Browse Local Audio',
                  ),
                  IconButton(
                    iconSize: 36,
                    icon: const Icon(Icons.stop_rounded, color: Colors.white70),
                    onPressed: () {
                      _bindings.stop();
                    },
                    tooltip: 'Stop',
                  ),
                  Container(
                    decoration: const BoxDecoration(
                      shape: BoxShape.circle,
                      color: Color(0xFFE50914),
                    ),
                    child: IconButton(
                      iconSize: 42,
                      icon: Icon(
                        _status.isPlaying ? Icons.pause_rounded : Icons.play_arrow_rounded,
                        color: Colors.white,
                      ),
                      onPressed: () {
                        if (_status.isPlaying) {
                          _bindings.pause();
                        } else if (_status.isPaused) {
                          _bindings.resume();
                        } else if (_currentFilePath != null) {
                          _playAudioFile(_currentFilePath!);
                        } else {
                          _pickAndPlayFile();
                        }
                      },
                    ),
                  ),
                  IconButton(
                    iconSize: 28,
                    icon: Icon(
                      _status.volume == 0 ? Icons.volume_off : Icons.volume_up,
                      color: Colors.white70,
                    ),
                    onPressed: () {
                      _bindings.setVolume(_status.volume == 0 ? 1.0 : 0.0);
                    },
                  ),
                ],
              ),
              const SizedBox(height: 16),
            ],
          ),
        ),
      ),
    );
  }
}
