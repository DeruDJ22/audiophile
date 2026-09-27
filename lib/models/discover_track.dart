/// Unified data model for tracks from any external discover source.
/// Used by all MusicSourceProvider implementations.
class DiscoverTrack {
  final String id;
  final String title;
  final String artist;
  final String source; // 'Archive.org', 'Jamendo', 'Imported'
  final String? thumbnailUrl;
  final String streamUrl;
  final String? downloadUrl;
  final Duration? duration;
  final String? format; // 'FLAC', 'MP3', 'OGG', etc.
  final int? bitrate; // in kbps
  final String? license; // 'CC BY', 'CC BY-SA', 'Public Domain', etc.
  final String? sourcePageUrl; // link to original page
  final bool canDownload;

  const DiscoverTrack({
    required this.id,
    required this.title,
    required this.artist,
    required this.source,
    this.thumbnailUrl,
    required this.streamUrl,
    this.downloadUrl,
    this.duration,
    this.format,
    this.bitrate,
    this.license,
    this.sourcePageUrl,
    this.canDownload = true,
  });

  /// Display-friendly duration string
  String get formattedDuration {
    if (duration == null) return '--:--';
    final mins = duration!.inMinutes;
    final secs = duration!.inSeconds % 60;
    return '${mins.toString().padLeft(2, '0')}:${secs.toString().padLeft(2, '0')}';
  }

  /// Display-friendly format/quality string
  String get qualityLabel {
    final parts = <String>[];
    if (format != null) parts.add(format!);
    if (bitrate != null) parts.add('${bitrate}kbps');
    return parts.isEmpty ? 'Unknown' : parts.join(' • ');
  }
}
