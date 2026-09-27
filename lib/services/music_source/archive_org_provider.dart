import 'dart:convert';
import 'package:http/http.dart' as http;

import '../../models/discover_track.dart';
import 'music_source_provider.dart';

/// Archive.org (Internet Archive) provider.
/// Uses the public Advanced Search API — no API key required.
/// Focuses on Live Music Archive and Creative Commons audio collections.
class ArchiveOrgProvider extends MusicSourceProvider {
  static const String _baseSearchUrl = 'https://archive.org/advancedsearch.php';
  static const String _metadataUrl = 'https://archive.org/metadata';
  static const String _downloadUrl = 'https://archive.org/download';

  @override
  String get sourceName => 'Archive.org';

  @override
  String get sourceIcon => 'archive';

  @override
  Future<List<DiscoverTrack>> search(String query, {int limit = 30}) async {
    try {
      final uri = Uri.parse(_baseSearchUrl).replace(queryParameters: {
        'q': '$query AND mediatype:audio',
        'fl[]': 'identifier,title,creator,description,date,downloads,avg_rating',
        'sort[]': 'downloads desc',
        'rows': limit.toString(),
        'page': '1',
        'output': 'json',
      });

      final response = await http.get(uri).timeout(const Duration(seconds: 15));

      if (response.statusCode != 200) {
        throw Exception('Archive.org API returned ${response.statusCode}');
      }

      final json = jsonDecode(response.body);
      final docs = json['response']?['docs'] as List<dynamic>? ?? [];

      // Fetch metadata for each item to get actual audio files
      final tracks = <DiscoverTrack>[];
      
      // Limit concurrent metadata fetches to avoid overwhelming the API
      final batch = docs.take(limit);
      for (final doc in batch) {
        final identifier = doc['identifier'] as String?;
        if (identifier == null) continue;

        try {
          final itemTracks = await _getItemTracks(
            identifier: identifier,
            itemTitle: doc['title']?.toString() ?? identifier,
            creator: doc['creator']?.toString() ?? 'Unknown Artist',
          );
          tracks.addAll(itemTracks);
        } catch (_) {
          // Skip items that fail metadata fetch
          continue;
        }

        // Stop if we have enough tracks
        if (tracks.length >= limit) break;
      }

      return tracks.take(limit).toList();
    } catch (e) {
      throw Exception('Archive.org search failed: $e');
    }
  }

  /// Fetch metadata for a specific item to extract streamable audio files
  Future<List<DiscoverTrack>> _getItemTracks({
    required String identifier,
    required String itemTitle,
    required String creator,
  }) async {
    final uri = Uri.parse('$_metadataUrl/$identifier');
    final response = await http.get(uri).timeout(const Duration(seconds: 10));

    if (response.statusCode != 200) return [];

    final json = jsonDecode(response.body);
    final files = json['files'] as List<dynamic>? ?? [];
    final metadata = json['metadata'] as Map<String, dynamic>? ?? {};

    // Get thumbnail URL
    final thumbnailUrl = 'https://archive.org/services/img/$identifier';

    // Filter for audio files only
    final audioExtensions = ['.mp3', '.flac', '.ogg', '.wav', '.aac', '.m4a'];
    final audioFiles = files.where((f) {
      final name = (f['name'] as String? ?? '').toLowerCase();
      return audioExtensions.any((ext) => name.endsWith(ext));
    }).toList();

    // Prefer lossless formats
    audioFiles.sort((a, b) {
      final nameA = (a['name'] as String).toLowerCase();
      final nameB = (b['name'] as String).toLowerCase();
      final aIsLossless = nameA.endsWith('.flac') || nameA.endsWith('.wav');
      final bIsLossless = nameB.endsWith('.flac') || nameB.endsWith('.wav');
      if (aIsLossless && !bIsLossless) return -1;
      if (!aIsLossless && bIsLossless) return 1;
      return 0;
    });

    final licenseUrl = metadata['licenseurl']?.toString() ?? '';
    final license = _parseLicense(licenseUrl);

    return audioFiles.take(5).map((f) {
      final fileName = f['name'] as String;
      final title = f['title']?.toString() ?? 
                     fileName.replaceAll(RegExp(r'\.[^.]+$'), '');
      final durationStr = f['length']?.toString();
      final format = fileName.split('.').last.toUpperCase();
      final bitrateStr = f['bitrate']?.toString();

      Duration? duration;
      if (durationStr != null) {
        final seconds = double.tryParse(durationStr);
        if (seconds != null) {
          duration = Duration(seconds: seconds.toInt());
        }
      }

      return DiscoverTrack(
        id: '${identifier}_$fileName',
        title: title,
        artist: f['creator']?.toString() ?? creator,
        source: sourceName,
        thumbnailUrl: thumbnailUrl,
        streamUrl: '$_downloadUrl/$identifier/$fileName',
        downloadUrl: '$_downloadUrl/$identifier/$fileName',
        duration: duration,
        format: format,
        bitrate: bitrateStr != null ? int.tryParse(bitrateStr) : null,
        license: license,
        sourcePageUrl: 'https://archive.org/details/$identifier',
        canDownload: true,
      );
    }).toList();
  }

  String _parseLicense(String url) {
    if (url.contains('publicdomain')) return 'Public Domain';
    if (url.contains('by-nc-sa')) return 'CC BY-NC-SA';
    if (url.contains('by-nc-nd')) return 'CC BY-NC-ND';
    if (url.contains('by-nc')) return 'CC BY-NC';
    if (url.contains('by-sa')) return 'CC BY-SA';
    if (url.contains('by-nd')) return 'CC BY-ND';
    if (url.contains('by')) return 'CC BY';
    if (url.isEmpty) return 'Public Domain'; // Archive.org defaults
    return 'Open License';
  }
}
