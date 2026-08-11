import 'dart:convert';
import 'package:shared_preferences/shared_preferences.dart';

class Playlist {
  final String id;
  String name;
  final List<String> songPaths;
  final DateTime createdAt;

  Playlist({
    required this.id,
    required this.name,
    required this.songPaths,
    DateTime? createdAt,
  }) : createdAt = createdAt ?? DateTime.now();

  Map<String, dynamic> toJson() => {
        'id': id,
        'name': name,
        'songPaths': songPaths,
        'createdAt': createdAt.toIso8601String(),
      };

  factory Playlist.fromJson(Map<String, dynamic> json) => Playlist(
        id: json['id'],
        name: json['name'],
        songPaths: List<String>.from(json['songPaths'] ?? []),
        createdAt: json['createdAt'] != null
            ? DateTime.parse(json['createdAt'])
            : DateTime.now(),
      );
}

class PlaylistService {
  static const String _keyPlaylists = 'kuroakai_playlists';

  // Load all playlists from SharedPreferences
  static Future<List<Playlist>> loadPlaylists() async {
    final prefs = await SharedPreferences.getInstance();
    final String? jsonStr = prefs.getString(_keyPlaylists);
    if (jsonStr == null || jsonStr.isEmpty) {
      // Create default "Favorites" and "Hi-Res Master" playlists
      final defaultList = [
        Playlist(
          id: 'fav_01',
          name: '❤️ Favorite Tracklist',
          songPaths: [],
        ),
        Playlist(
          id: 'hires_02',
          name: '🎼 Hi-Res FLAC Master',
          songPaths: [],
        ),
      ];
      await savePlaylists(defaultList);
      return defaultList;
    }

    try {
      final List<dynamic> listJson = jsonDecode(jsonStr);
      return listJson.map((e) => Playlist.fromJson(e)).toList();
    } catch (e) {
      return [];
    }
  }

  // Save all playlists to SharedPreferences
  static Future<void> savePlaylists(List<Playlist> playlists) async {
    final prefs = await SharedPreferences.getInstance();
    final String jsonStr =
        jsonEncode(playlists.map((p) => p.toJson()).toList());
    await prefs.setString(_keyPlaylists, jsonStr);
  }
}
