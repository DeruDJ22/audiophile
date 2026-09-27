import '../../models/discover_track.dart';

/// Abstract interface for any legal music source.
/// Implement this to add new sources (e.g., Free Music Archive, SoundCloud CC, etc.)
abstract class MusicSourceProvider {
  /// Human-readable name shown as badge on results
  String get sourceName;

  /// Icon identifier for the source
  String get sourceIcon;

  /// Search for tracks matching the query
  Future<List<DiscoverTrack>> search(String query, {int limit = 30});

  /// Get detailed metadata for a specific track (optional override)
  Future<DiscoverTrack?> getTrackDetails(String trackId) {
    return Future.value(null);
  }
}

