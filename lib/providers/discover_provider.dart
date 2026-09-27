import 'package:flutter/material.dart';

import '../models/discover_track.dart';
import '../services/music_source/music_source_provider.dart';
import '../services/music_source/archive_org_provider.dart';
import '../services/music_source/jamendo_provider.dart';
import '../services/music_source/url_import_provider.dart';

/// Search state for the Discover screen.
/// Aggregates results from all registered MusicSourceProviders.
class DiscoverProvider extends ChangeNotifier {
  final List<MusicSourceProvider> _sources = [
    ArchiveOrgProvider(),
    JamendoProvider(),
  ];
  final UrlImportProvider _urlImporter = UrlImportProvider();

  List<DiscoverTrack> _results = [];
  bool _isLoading = false;
  String? _errorMessage;
  String _lastQuery = '';
  String _activeSourceFilter = 'All'; // 'All', 'Archive.org', 'Jamendo'

  List<DiscoverTrack> get results => _filteredResults;
  bool get isLoading => _isLoading;
  String? get errorMessage => _errorMessage;
  String get lastQuery => _lastQuery;
  String get activeSourceFilter => _activeSourceFilter;
  List<String> get availableSources => ['All', ..._sources.map((s) => s.sourceName)];

  List<DiscoverTrack> get _filteredResults {
    if (_activeSourceFilter == 'All') return _results;
    return _results.where((t) => t.source == _activeSourceFilter).toList();
  }

  void setSourceFilter(String source) {
    _activeSourceFilter = source;
    notifyListeners();
  }

  /// Search all registered sources concurrently
  Future<void> search(String query) async {
    if (query.trim().isEmpty) return;

    _lastQuery = query;
    _isLoading = true;
    _errorMessage = null;
    _results = [];
    notifyListeners();

    try {
      final futures = _sources.map((s) => s.search(query).catchError((e) {
            // Individual source failure shouldn't kill the whole search
            debugPrint('Source ${s.sourceName} error: $e');
            return <DiscoverTrack>[];
          }));

      final allResults = await Future.wait(futures);
      _results = allResults.expand((list) => list).toList();

      if (_results.isEmpty) {
        _errorMessage = 'No results found for "$query"';
      }
    } catch (e) {
      _errorMessage = 'Search failed: ${e.toString()}';
    } finally {
      _isLoading = false;
      notifyListeners();
    }
  }

  /// Import a track from a direct URL
  Future<DiscoverTrack?> importFromUrl(String url) async {
    _isLoading = true;
    _errorMessage = null;
    notifyListeners();

    try {
      final track = await _urlImporter.importUrl(url);
      if (track != null) {
        _results.insert(0, track);
      } else {
        _errorMessage = 'Could not import audio from this URL. Make sure it points to a valid audio file.';
      }
      return track;
    } catch (e) {
      _errorMessage = 'Import failed: ${e.toString()}';
      return null;
    } finally {
      _isLoading = false;
      notifyListeners();
    }
  }

  void clearResults() {
    _results = [];
    _errorMessage = null;
    _lastQuery = '';
    notifyListeners();
  }
}
