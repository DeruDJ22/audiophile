import 'dart:convert';
import 'package:http/http.dart' as http;

import '../../config/api_config.dart';
import '../../models/discover_track.dart';
import 'music_source_provider.dart';

/// Jamendo music provider.
/// Uses the free Jamendo API tier for Creative Commons licensed music.
/// Requires JAMENDO_CLIENT_ID set in .env file.
class JamendoProvider extends MusicSourceProvider {
  static const String _baseUrl = 'https://api.jamendo.com/v3.0';

  @override
  String get sourceName => 'Jamendo';

  @override
  String get sourceIcon => 'jamendo';

  @override
  Future<List<DiscoverTrack>> search(String query, {int limit = 30}) async {
    if (!ApiConfig.hasJamendoKey) {
      // Silently return empty if no API key configured
      return [];
    }

    try {
      final uri = Uri.parse('$_baseUrl/tracks/').replace(queryParameters: {
        'client_id': ApiConfig.jamendoClientId,
        'format': 'json',
        'search': query,
        'limit': limit.toString(),
        'include': 'musicinfo+licenses+stats',
        'audioformat': 'mp32', // high quality MP3
        'order': 'popularity_total',
      });

      final response = await http.get(uri).timeout(const Duration(seconds: 15));

      if (response.statusCode != 200) {
        throw Exception('Jamendo API returned ${response.statusCode}');
      }

      final json = jsonDecode(response.body);
      final results = json['results'] as List<dynamic>? ?? [];

      return results.map((track) {
        final durationSec = track['duration'] as int? ?? 0;
        final audioUrl = track['audio'] as String? ?? '';
        final audioDownload = track['audiodownload'] as String? ?? '';
        final licenseUrl = track['license_ccurl']?.toString() ?? '';

        return DiscoverTrack(
          id: 'jamendo_${track['id']}',
          title: track['name']?.toString() ?? 'Untitled',
          artist: track['artist_name']?.toString() ?? 'Unknown Artist',
          source: sourceName,
          thumbnailUrl: track['album_image']?.toString(),
          streamUrl: audioUrl.isNotEmpty ? audioUrl : audioDownload,
          downloadUrl: audioDownload.isNotEmpty ? audioDownload : null,
          duration: Duration(seconds: durationSec),
          format: 'MP3',
          bitrate: 320, // Jamendo mp32 format
          license: _parseLicense(licenseUrl),
          sourcePageUrl: track['shareurl']?.toString(),
          canDownload: audioDownload.isNotEmpty,
        );
      }).toList();
    } catch (e) {
      throw Exception('Jamendo search failed: $e');
    }
  }

  String _parseLicense(String url) {
    if (url.contains('by-nc-sa')) return 'CC BY-NC-SA';
    if (url.contains('by-nc-nd')) return 'CC BY-NC-ND';
    if (url.contains('by-nc')) return 'CC BY-NC';
    if (url.contains('by-sa')) return 'CC BY-SA';
    if (url.contains('by-nd')) return 'CC BY-ND';
    if (url.contains('by')) return 'CC BY';
    return 'CC License';
  }
}
