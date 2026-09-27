import 'package:http/http.dart' as http;

import '../../models/discover_track.dart';

/// URL Import provider.
/// Validates and imports audio from direct URLs pasted by the user.
class UrlImportProvider {
  static const _audioContentTypes = [
    'audio/',
    'application/ogg',
    'application/x-flac',
  ];

  /// Validate and create a DiscoverTrack from a direct audio URL
  Future<DiscoverTrack?> importUrl(String url) async {
    try {
      final uri = Uri.parse(url);
      if (!uri.hasScheme || (!uri.scheme.startsWith('http'))) {
        return null;
      }

      // HEAD request to validate content type
      final response = await http.head(uri).timeout(const Duration(seconds: 10));

      if (response.statusCode != 200) {
        return null;
      }

      final contentType = response.headers['content-type']?.toLowerCase() ?? '';
      final isAudio = _audioContentTypes.any((type) => contentType.contains(type));

      if (!isAudio) {
        return null;
      }

      // Extract filename from URL
      final pathSegments = uri.pathSegments;
      final fileName = pathSegments.isNotEmpty
          ? Uri.decodeComponent(pathSegments.last)
          : 'Imported Track';
      final title = fileName.replaceAll(RegExp(r'\.[^.]+$'), '');
      final extension = fileName.contains('.')
          ? fileName.split('.').last.toUpperCase()
          : _formatFromContentType(contentType);

      return DiscoverTrack(
        id: 'import_${DateTime.now().millisecondsSinceEpoch}',
        title: title,
        artist: uri.host,
        source: 'Imported',
        thumbnailUrl: null,
        streamUrl: url,
        downloadUrl: url,
        format: extension,
        license: 'User Imported',
        sourcePageUrl: url,
        canDownload: true,
      );
    } catch (e) {
      return null;
    }
  }

  String _formatFromContentType(String contentType) {
    if (contentType.contains('flac')) return 'FLAC';
    if (contentType.contains('wav')) return 'WAV';
    if (contentType.contains('ogg')) return 'OGG';
    if (contentType.contains('aac')) return 'AAC';
    if (contentType.contains('mp3') || contentType.contains('mpeg')) return 'MP3';
    return 'AUDIO';
  }
}
