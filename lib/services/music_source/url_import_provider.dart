import 'dart:convert';
import 'package:http/http.dart' as http;
import 'package:youtube_explode_dart/youtube_explode_dart.dart';

import '../../models/discover_track.dart';

/// URL Import provider with multi-platform resolution support.
///
/// Supports importing from:
/// 1. YouTube & YouTube Music (extracts direct high-bitrate audio stream)
/// 2. Spotify (extracts track metadata & cover art, resolves audio via YouTube audio stream)
/// 3. Apple Music (extracts track metadata & artwork, resolves audio via YouTube audio stream)
/// 4. SoundCloud (extracts metadata via oEmbed, resolves audio stream)
/// 5. Direct audio streams (MP3, FLAC, WAV, OGG, AAC, M4A, HLS/M3U8)
class UrlImportProvider {
  static const _crawlerUserAgent =
      'facebookexternalhit/1.1 (+http://www.facebook.com/externalhit_uatext.php)';

  static const _audioContentTypes = [
    'audio/',
    'application/ogg',
    'application/x-flac',
    'application/vnd.apple.mpegurl',
    'application/x-mpegurl',
  ];

  /// Import audio from a URL, automatically detecting platform
  Future<DiscoverTrack?> importUrl(String rawUrl) async {
    final url = rawUrl.trim();
    if (url.isEmpty) return null;

    final uri = Uri.tryParse(url);
    if (uri == null || !uri.hasScheme || !uri.scheme.startsWith('http')) {
      return null;
    }

    final host = uri.host.toLowerCase();

    // 1. YouTube & YouTube Music
    if (_isYouTube(host, uri)) {
      return await _importYouTube(url, uri);
    }

    // 2. Spotify
    if (_isSpotify(host)) {
      return await _importSpotify(url, uri);
    }

    // 3. Apple Music
    if (_isAppleMusic(host)) {
      return await _importAppleMusic(url, uri);
    }

    // 4. SoundCloud
    if (_isSoundCloud(host)) {
      return await _importSoundCloud(url, uri);
    }

    // 5. Direct Audio Stream / File URL
    return await _importDirectAudio(url, uri);
  }

  // ─── Platform Matchers ───

  bool _isYouTube(String host, Uri uri) {
    return host.contains('youtube.com') ||
        host.contains('youtu.be') ||
        host.contains('music.youtube.com');
  }

  bool _isSpotify(String host) {
    return host.contains('spotify.com') || host.contains('spotify.link');
  }

  bool _isAppleMusic(String host) {
    return host.contains('music.apple.com');
  }

  bool _isSoundCloud(String host) {
    return host.contains('soundcloud.com');
  }

  // ─── YouTube / YouTube Music ───

  Future<DiscoverTrack?> _importYouTube(String url, Uri uri) async {
    final yt = YoutubeExplode();
    try {
      final video = await yt.videos.get(url);
      final manifest = await yt.videos.streamsClient.getManifest(video.id);
      final audioOnly = manifest.audioOnly;
      if (audioOnly.isEmpty) return null;

      final bestAudio = audioOnly.withHighestBitrate();

      return DiscoverTrack(
        id: 'yt_${video.id.value}',
        title: video.title,
        artist: video.author,
        source: 'YouTube',
        thumbnailUrl: video.thumbnails.highResUrl,
        streamUrl: bestAudio.url.toString(),
        downloadUrl: bestAudio.url.toString(),
        duration: video.duration,
        format: bestAudio.container.name.toUpperCase(),
        bitrate: bestAudio.bitrate.kiloBitsPerSecond.round(),
        license: 'YouTube Stream',
        sourcePageUrl: url,
        canDownload: true,
      );
    } catch (_) {
      return null;
    } finally {
      yt.close();
    }
  }

  // ─── Spotify ───

  Future<DiscoverTrack?> _importSpotify(String url, Uri uri) async {
    String title = 'Spotify Track';
    String artist = 'Spotify Artist';
    String? thumbnailUrl;
    Duration? duration;

    // 1. Fetch metadata from Spotify oEmbed endpoint
    try {
      final oEmbedUri = Uri.parse(
          'https://open.spotify.com/oembed?url=${Uri.encodeComponent(url)}');
      final res = await http.get(oEmbedUri).timeout(const Duration(seconds: 8));
      if (res.statusCode == 200) {
        final data = jsonDecode(res.body) as Map<String, dynamic>;
        final oEmbedTitle = (data['title'] as String? ?? '').trim();
        if (oEmbedTitle.isNotEmpty) {
          title = oEmbedTitle;
        }
        thumbnailUrl = data['thumbnail_url'] as String?;
      }
    } catch (_) {}

    // 2. Fetch page HTML with crawler User-Agent to extract precise artist & duration
    try {
      final pageRes = await http.get(uri, headers: {
        'User-Agent': _crawlerUserAgent,
        'Accept-Language': 'en-US,en;q=0.9',
      }).timeout(const Duration(seconds: 8));

      if (pageRes.statusCode == 200) {
        final body = pageRes.body;

        // og:title
        final ogTitleMatch = RegExp(
                r'<meta\s+(?:property|name)="og:title"\s+content="([^"]+)"',
                caseSensitive: false)
            .firstMatch(body);
        if (ogTitleMatch != null) {
          title = _unescapeHtml(ogTitleMatch.group(1)!);
        }

        // music:musician_description (human readable name like "Rick Astley")
        final artistMatch = RegExp(
                r'<meta\s+(?:property|name)="music:musician_description"\s+content="([^"]+)"',
                caseSensitive: false)
            .firstMatch(body);
        if (artistMatch != null &&
            !artistMatch.group(1)!.startsWith('http')) {
          artist = _unescapeHtml(artistMatch.group(1)!);
        } else {
          // Fallback from og:description: "Artist · Album · Song · Year"
          final descMatch = RegExp(
                  r'<meta\s+(?:property|name)="og:description"\s+content="([^"]+)"',
                  caseSensitive: false)
              .firstMatch(body);
          if (descMatch != null) {
            final desc = _unescapeHtml(descMatch.group(1)!);
            final parts = desc.split(RegExp(r'\s*[·•]\s*'));
            if (parts.isNotEmpty && parts.first.isNotEmpty) {
              artist = parts.first.trim();
            }
          }
        }

        // music:duration (seconds)
        final durMatch = RegExp(
                r'<meta\s+(?:property|name)="music:duration"\s+content="([0-9]+)"',
                caseSensitive: false)
            .firstMatch(body);
        if (durMatch != null) {
          final seconds = int.tryParse(durMatch.group(1)!);
          if (seconds != null) {
            duration = Duration(seconds: seconds);
          }
        }
      }
    } catch (_) {}

    // 3. Resolve audio stream from YouTube
    final resolvedAudio = await _resolveAudioStream('$title $artist');
    if (resolvedAudio == null) return null;

    return DiscoverTrack(
      id: 'spotify_${DateTime.now().millisecondsSinceEpoch}',
      title: title,
      artist: artist,
      source: 'Spotify',
      thumbnailUrl: thumbnailUrl ?? resolvedAudio.thumbnailUrl,
      streamUrl: resolvedAudio.streamUrl,
      downloadUrl: resolvedAudio.streamUrl,
      duration: duration ?? resolvedAudio.duration,
      format: resolvedAudio.format,
      bitrate: resolvedAudio.bitrate,
      license: 'Spotify Metadata • Streamed via YT Audio',
      sourcePageUrl: url,
      canDownload: true,
    );
  }

  // ─── Apple Music ───

  Future<DiscoverTrack?> _importAppleMusic(String url, Uri uri) async {
    String title = 'Apple Music Track';
    String artist = 'Apple Music';
    String? thumbnailUrl;

    try {
      final pageRes = await http.get(uri, headers: {
        'User-Agent': _crawlerUserAgent,
        'Accept-Language': 'en-US,en;q=0.9',
      }).timeout(const Duration(seconds: 10));

      if (pageRes.statusCode == 200) {
        final body = pageRes.body;

        // apple:title or og:title
        final appleTitleMatch = RegExp(
                r'<meta\s+(?:property|name)="apple:title"\s+content="([^"]+)"',
                caseSensitive: false)
            .firstMatch(body);
        if (appleTitleMatch != null) {
          title = _unescapeHtml(appleTitleMatch.group(1)!);
        }

        final ogTitleMatch = RegExp(
                r'<meta\s+(?:property|name)="og:title"\s+content="([^"]+)"',
                caseSensitive: false)
            .firstMatch(body);
        if (ogTitleMatch != null) {
          final full = _unescapeHtml(ogTitleMatch.group(1)!);
          // e.g. "Blinding Lights by The Weeknd on Apple Music"
          if (full.contains(' by ')) {
            final parts = full.split(' by ');
            if (appleTitleMatch == null) {
              title = parts.first.trim();
            }
            final rest = parts.sublist(1).join(' by ');
            artist = rest
                .split(RegExp(r'\s+on\s+Apple', caseSensitive: false))
                .first
                .trim();
          }
        }

        // og:image
        final imageMatch = RegExp(
                r'<meta\s+(?:property|name)="og:image"\s+content="([^"]+)"',
                caseSensitive: false)
            .firstMatch(body);
        if (imageMatch != null) {
          thumbnailUrl = imageMatch.group(1);
        }
      }
    } catch (_) {}

    // Resolve audio stream from YouTube
    final resolvedAudio = await _resolveAudioStream('$title $artist');
    if (resolvedAudio == null) return null;

    return DiscoverTrack(
      id: 'apple_${DateTime.now().millisecondsSinceEpoch}',
      title: title,
      artist: artist,
      source: 'Apple Music',
      thumbnailUrl: thumbnailUrl ?? resolvedAudio.thumbnailUrl,
      streamUrl: resolvedAudio.streamUrl,
      downloadUrl: resolvedAudio.streamUrl,
      duration: resolvedAudio.duration,
      format: resolvedAudio.format,
      bitrate: resolvedAudio.bitrate,
      license: 'Apple Music Metadata • Streamed via YT Audio',
      sourcePageUrl: url,
      canDownload: true,
    );
  }

  // ─── SoundCloud ───

  Future<DiscoverTrack?> _importSoundCloud(String url, Uri uri) async {
    String title = 'SoundCloud Track';
    String artist = 'SoundCloud Artist';
    String? thumbnailUrl;

    try {
      final oEmbedUri = Uri.parse(
          'https://soundcloud.com/oembed?format=json&url=${Uri.encodeComponent(url)}');
      final res = await http.get(oEmbedUri).timeout(const Duration(seconds: 8));
      if (res.statusCode == 200) {
        final data = jsonDecode(res.body) as Map<String, dynamic>;
        title = (data['title'] as String? ?? title).trim();
        artist = (data['author_name'] as String? ?? artist).trim();
        thumbnailUrl = data['thumbnail_url'] as String?;
      }
    } catch (_) {}

    final resolvedAudio = await _resolveAudioStream('$title $artist');
    if (resolvedAudio == null) return null;

    return DiscoverTrack(
      id: 'soundcloud_${DateTime.now().millisecondsSinceEpoch}',
      title: title,
      artist: artist,
      source: 'SoundCloud',
      thumbnailUrl: thumbnailUrl ?? resolvedAudio.thumbnailUrl,
      streamUrl: resolvedAudio.streamUrl,
      downloadUrl: resolvedAudio.streamUrl,
      duration: resolvedAudio.duration,
      format: resolvedAudio.format,
      bitrate: resolvedAudio.bitrate,
      license: 'SoundCloud Metadata • Streamed via YT Audio',
      sourcePageUrl: url,
      canDownload: true,
    );
  }

  // ─── Direct Audio Stream ───

  Future<DiscoverTrack?> _importDirectAudio(String url, Uri uri) async {
    try {
      // 1. Check known audio extensions first
      final path = uri.path.toLowerCase();
      final hasAudioExt = path.endsWith('.mp3') ||
          path.endsWith('.flac') ||
          path.endsWith('.wav') ||
          path.endsWith('.ogg') ||
          path.endsWith('.m4a') ||
          path.endsWith('.aac') ||
          path.endsWith('.m3u8') ||
          path.endsWith('.opus');

      String contentType = '';

      if (!hasAudioExt) {
        // Perform HEAD request to check content type
        try {
          final headRes =
              await http.head(uri).timeout(const Duration(seconds: 8));
          if (headRes.statusCode == 200) {
            contentType =
                headRes.headers['content-type']?.toLowerCase() ?? '';
          }
        } catch (_) {}

        final isAudio =
            _audioContentTypes.any((type) => contentType.contains(type));
        if (!isAudio) {
          return null;
        }
      }

      // Extract filename from URL
      final pathSegments = uri.pathSegments;
      final fileName = pathSegments.isNotEmpty
          ? Uri.decodeComponent(pathSegments.last)
          : 'Imported Audio';
      final cleanTitle = fileName.replaceAll(RegExp(r'\.[^.]+$'), '');
      final extension = fileName.contains('.')
          ? fileName.split('.').last.toUpperCase()
          : _formatFromContentType(contentType);

      return DiscoverTrack(
        id: 'import_${DateTime.now().millisecondsSinceEpoch}',
        title: cleanTitle.isEmpty ? 'Direct Audio Stream' : cleanTitle,
        artist: uri.host,
        source: 'Imported',
        thumbnailUrl: null,
        streamUrl: url,
        downloadUrl: url,
        format: extension,
        license: 'Direct Stream URL',
        sourcePageUrl: url,
        canDownload: true,
      );
    } catch (_) {
      return null;
    }
  }

  // ─── Audio Stream Resolver via YouTube ───

  Future<_ResolvedAudio?> _resolveAudioStream(String query) async {
    final yt = YoutubeExplode();
    try {
      final searchResults = await yt.search.search('$query audio');
      if (searchResults.isEmpty) return null;

      final match = searchResults.first;
      final manifest = await yt.videos.streamsClient.getManifest(match.id);
      final audioOnly = manifest.audioOnly;
      if (audioOnly.isEmpty) return null;

      final bestAudio = audioOnly.withHighestBitrate();

      return _ResolvedAudio(
        streamUrl: bestAudio.url.toString(),
        thumbnailUrl: match.thumbnails.highResUrl,
        duration: match.duration,
        format: bestAudio.container.name.toUpperCase(),
        bitrate: bestAudio.bitrate.kiloBitsPerSecond.round(),
      );
    } catch (_) {
      return null;
    } finally {
      yt.close();
    }
  }

  String _formatFromContentType(String contentType) {
    if (contentType.contains('flac')) return 'FLAC';
    if (contentType.contains('wav')) return 'WAV';
    if (contentType.contains('ogg')) return 'OGG';
    if (contentType.contains('aac')) return 'AAC';
    if (contentType.contains('m4a')) return 'M4A';
    if (contentType.contains('mpegurl') || contentType.contains('m3u8')) {
      return 'HLS';
    }
    if (contentType.contains('mp3') || contentType.contains('mpeg')) {
      return 'MP3';
    }
    return 'AUDIO';
  }

  String _unescapeHtml(String input) {
    return input
        .replaceAll('&amp;', '&')
        .replaceAll('&lt;', '<')
        .replaceAll('&gt;', '>')
        .replaceAll('&quot;', '"')
        .replaceAll('&#39;', "'")
        .replaceAll('&apos;', "'")
        .replaceAll('&#x27;', "'")
        .replaceAll('&nbsp;', ' ')
        .trim();
  }
}

class _ResolvedAudio {
  final String streamUrl;
  final String? thumbnailUrl;
  final Duration? duration;
  final String format;
  final int bitrate;

  const _ResolvedAudio({
    required this.streamUrl,
    this.thumbnailUrl,
    this.duration,
    required this.format,
    required this.bitrate,
  });
}
