import 'package:flutter/foundation.dart';

import '../services/playlist_service.dart';
import '../services/file_picker_service.dart';

/// Manages local library songs and playlists state.
class LibraryProvider extends ChangeNotifier {
  final List<String> _librarySongs = [];
  List<Playlist> _playlists = [];
  Playlist? _selectedPlaylist;

  List<String> get librarySongs => _librarySongs;
  List<Playlist> get playlists => _playlists;
  Playlist? get selectedPlaylist => _selectedPlaylist;

  /// Load persisted playlists from SharedPreferences
  Future<void> loadPlaylists() async {
    _playlists = await PlaylistService.loadPlaylists();
    if (_playlists.isNotEmpty) {
      _selectedPlaylist = _playlists.first;
    }
    notifyListeners();
  }

  /// Add a song path to the library (deduped)
  void addToLibrary(String path) {
    if (!_librarySongs.contains(path)) {
      _librarySongs.insert(0, path);
      notifyListeners();
    }
  }

  /// Add multiple songs to library
  void addMultipleToLibrary(List<String> paths) {
    bool changed = false;
    for (var p in paths) {
      if (!_librarySongs.contains(p)) {
        _librarySongs.add(p);
        changed = true;
      }
    }
    if (changed) notifyListeners();
  }

  /// Pick and add multiple songs from file system
  Future<List<String>> pickAndAddSongs() async {
    final paths = await FilePickerService.pickMultipleAudioFiles();
    if (paths.isNotEmpty) {
      addMultipleToLibrary(paths);
    }
    return paths;
  }

  void selectPlaylist(Playlist pl) {
    _selectedPlaylist = pl;
    notifyListeners();
  }

  Future<void> createPlaylist(String name) async {
    final newPl = Playlist(
      id: 'pl_${DateTime.now().millisecondsSinceEpoch}',
      name: name,
      songPaths: [],
    );
    _playlists.add(newPl);
    _selectedPlaylist = newPl;
    await PlaylistService.savePlaylists(_playlists);
    notifyListeners();
  }

  Future<void> deletePlaylist(Playlist playlist) async {
    _playlists.removeWhere((p) => p.id == playlist.id);
    if (_selectedPlaylist?.id == playlist.id) {
      _selectedPlaylist = _playlists.isNotEmpty ? _playlists.first : null;
    }
    await PlaylistService.savePlaylists(_playlists);
    notifyListeners();
  }

  Future<void> addSongToPlaylist(Playlist playlist, String path) async {
    if (!playlist.songPaths.contains(path)) {
      playlist.songPaths.add(path);
      if (!_librarySongs.contains(path)) {
        _librarySongs.add(path);
      }
      await PlaylistService.savePlaylists(_playlists);
      notifyListeners();
    }
  }

  Future<void> addSongsToPlaylist(Playlist playlist) async {
    final paths = await FilePickerService.pickMultipleAudioFiles();
    if (paths.isNotEmpty) {
      for (var p in paths) {
        if (!playlist.songPaths.contains(p)) {
          playlist.songPaths.add(p);
        }
        if (!_librarySongs.contains(p)) {
          _librarySongs.add(p);
        }
      }
      await PlaylistService.savePlaylists(_playlists);
      notifyListeners();
    }
  }

  Future<void> removeSongFromPlaylist(Playlist playlist, int index) async {
    playlist.songPaths.removeAt(index);
    await PlaylistService.savePlaylists(_playlists);
    notifyListeners();
  }
}
