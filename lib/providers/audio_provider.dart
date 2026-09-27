import 'dart:async';
import 'dart:io';
import 'dart:typed_data';
import 'package:flutter/material.dart';

import '../ffi/kuroakai_bindings.dart';
import '../services/cover_art_service.dart';

/// Central audio playback state manager.
/// Wraps the C++ FFI bindings and exposes reactive state via ChangeNotifier.
class AudioProvider extends ChangeNotifier {
  final KuroakaiAudioBindings _bindings = KuroakaiAudioBindings();
  Timer? _statusTimer;

  // ─── Audio Engine State ───
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
  Uint8List? _currentCoverArt;
  double _localVolume = 1.0;
  bool _isFullPlayerOpen = false;

  // ─── EQ State ───
  List<double> eqValues = [0.0, 0.0, 0.0, 0.0, 0.0];
  String activeEqPreset = 'Direct Bit-Perfect';

  // ─── Shuffle & Repeat ───
  bool _shuffleEnabled = false;
  int _repeatMode = 0; // 0: off, 1: all, 2: one

  // ─── Getters ───
  KuroakaiAudioStatus get audioStatus => _audioStatus;
  KuroakaiAudioBindings get bindings => _bindings;
  String? get currentFilePath => _currentFilePath;
  String get currentTitle => _currentTitle;
  String get currentArtist => _currentArtist;
  Uint8List? get currentCoverArt => _currentCoverArt;
  double get localVolume => _localVolume;
  bool get isFullPlayerOpen => _isFullPlayerOpen;
  bool get hasTrack => _currentFilePath != null;
  bool get isPlaying => _audioStatus.isPlaying;
  bool get isPaused => _audioStatus.isPaused;
  bool get shuffleEnabled => _shuffleEnabled;
  int get repeatMode => _repeatMode;

  void init() {
    _bindings.initEngine();
    _statusTimer = Timer.periodic(const Duration(milliseconds: 250), (_) {
      _audioStatus = _bindings.getStatus();
      notifyListeners();
    });
  }

  /// Play a local file by path
  Future<void> playFile(String path) async {
    final fileName = path.split(Platform.pathSeparator).last;
    final title = fileName.replaceAll(RegExp(r'\.[^.]+$'), '');

    _currentFilePath = path;
    _currentTitle = title;
    _currentArtist = 'Local Lossless File';
    _currentCoverArt = null;
    notifyListeners();

    _bindings.playFile(path);
    _bindings.setVolume(_localVolume);

    // Extract embedded album art
    final artBytes = await CoverArtService.getCoverArt(path);
    if (_currentFilePath == path) {
      _currentCoverArt = artBytes;
      notifyListeners();
    }
  }

  /// Play a remote stream URL (for Discover feature)
  void playStream(String url, {String? title, String? artist, String? thumbnailUrl}) {
    _currentFilePath = url;
    _currentTitle = title ?? 'Streaming Track';
    _currentArtist = artist ?? 'External Source';
    _currentCoverArt = null;
    notifyListeners();

    _bindings.playFile(url);
    _bindings.setVolume(_localVolume);
  }

  void togglePlayPause() {
    if (_audioStatus.isPlaying) {
      _bindings.pause();
    } else if (_audioStatus.isPaused) {
      _bindings.resume();
    } else if (_currentFilePath != null && _currentFilePath!.isNotEmpty) {
      _bindings.playFile(_currentFilePath!);
    }
  }

  void seek(double seconds) => _bindings.seek(seconds);

  void setVolume(double volume) {
    _localVolume = volume;
    _bindings.setVolume(volume);
    notifyListeners();
  }

  void toggleFullPlayer() {
    _isFullPlayerOpen = !_isFullPlayerOpen;
    notifyListeners();
  }

  void openFullPlayer() {
    _isFullPlayerOpen = true;
    notifyListeners();
  }

  void closeFullPlayer() {
    _isFullPlayerOpen = false;
    notifyListeners();
  }

  void toggleShuffle() {
    _shuffleEnabled = !_shuffleEnabled;
    notifyListeners();
  }

  void cycleRepeatMode() {
    _repeatMode = (_repeatMode + 1) % 3;
    notifyListeners();
  }

  // ─── EQ Controls ───
  void updateEqPreset(String preset) {
    activeEqPreset = preset;
    if (preset == 'Direct Bit-Perfect') eqValues = [0, 0, 0, 0, 0];
    if (preset == 'Bass Boost') eqValues = [6, 4, 0, 0, -2];
    if (preset == 'Vocal Enhancement') eqValues = [-2, 2, 5, 3, 0];
    if (preset == 'Treble Boost') eqValues = [-3, 0, 1, 4, 7];
    _bindings.setEqAll(eqValues[0], eqValues[1], eqValues[2], eqValues[3], eqValues[4]);
    notifyListeners();
  }

  void updateEqBand(int bandIndex, double val) {
    eqValues[bandIndex] = val;
    activeEqPreset = 'Custom';
    _bindings.setEqBand(bandIndex, val);
    notifyListeners();
  }

  String formatDuration(double seconds) {
    if (seconds.isNaN || seconds.isInfinite || seconds <= 0) return '00:00';
    final duration = Duration(seconds: seconds.toInt());
    final mins = duration.inMinutes;
    final secs = duration.inSeconds % 60;
    return '${mins.toString().padLeft(2, '0')}:${secs.toString().padLeft(2, '0')}';
  }

  @override
  void dispose() {
    _statusTimer?.cancel();
    _bindings.cleanup();
    super.dispose();
  }
}
