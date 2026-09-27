import 'package:flutter/material.dart';
import 'package:provider/provider.dart';

import '../config/theme.dart';
import '../models/discover_track.dart';
import '../providers/audio_provider.dart';
import '../providers/discover_provider.dart';
import '../providers/library_provider.dart';
import '../services/download_service.dart';
import '../widgets/discover_track_card.dart';

/// Discover screen for browsing and streaming music from legal external sources.
/// Features search bar, source filter chips, results list, and URL import.
class DiscoverScreen extends StatefulWidget {
  const DiscoverScreen({super.key});

  @override
  State<DiscoverScreen> createState() => _DiscoverScreenState();
}

class _DiscoverScreenState extends State<DiscoverScreen> {
  final TextEditingController _searchController = TextEditingController();
  final TextEditingController _urlController = TextEditingController();
  final Map<String, double> _downloadProgress = {};
  final Set<String> _downloading = {};

  @override
  void dispose() {
    _searchController.dispose();
    _urlController.dispose();
    super.dispose();
  }

  void _onSearch(DiscoverProvider discover) {
    final query = _searchController.text.trim();
    if (query.isNotEmpty) {
      discover.search(query);
    }
  }

  Future<void> _onImportUrl(DiscoverProvider discover) async {
    final url = _urlController.text.trim();
    if (url.isEmpty) return;

    final track = await discover.importFromUrl(url);
    if (track != null && mounted) {
      _urlController.clear();
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text('Imported: ${track.title}')),
      );
    }
  }

  Future<void> _onDownload(DiscoverTrack track) async {
    if (_downloading.contains(track.id)) return;

    setState(() {
      _downloading.add(track.id);
      _downloadProgress[track.id] = 0.0;
    });

    final localPath = await DownloadService.downloadTrack(
      track,
      onProgress: (progress) {
        if (mounted) {
          setState(() {
            _downloadProgress[track.id] = progress;
          });
        }
      },
    );

    if (mounted) {
      setState(() {
        _downloading.remove(track.id);
        _downloadProgress.remove(track.id);
      });

      if (localPath != null) {
        // Add to local library
        if (mounted) {
          context.read<LibraryProvider>().addToLibrary(localPath);
          ScaffoldMessenger.of(context).showSnackBar(
            SnackBar(content: Text('Downloaded: ${track.title}')),
          );
        }
      } else {
        if (mounted) {
          ScaffoldMessenger.of(context).showSnackBar(
            const SnackBar(content: Text('Download failed. Please try again.')),
          );
        }
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    return Consumer<DiscoverProvider>(
      builder: (context, discover, _) {
        return Container(
          color: KuroakaiTheme.background,
          padding: const EdgeInsets.all(20),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              // Header
              const Text('Discover',
                  style: TextStyle(
                      color: KuroakaiTheme.textPrimary,
                      fontSize: 24,
                      fontWeight: FontWeight.bold)),
              const Text(
                  'Browse Free & CC-Licensed Music from Legal Sources',
                  style: TextStyle(
                      color: KuroakaiTheme.textSecondary, fontSize: 13)),
              const SizedBox(height: 16),

              // Search bar
              _buildSearchBar(discover),
              const SizedBox(height: 12),

              // URL Import bar
              _buildUrlImportBar(discover),
              const SizedBox(height: 14),

              // Source filter chips
              _buildSourceFilters(discover),
              const SizedBox(height: 16),

              // Results
              Expanded(child: _buildResults(discover)),
            ],
          ),
        );
      },
    );
  }

  Widget _buildSearchBar(DiscoverProvider discover) {
    return Container(
      decoration: BoxDecoration(
        color: KuroakaiTheme.surface,
        borderRadius: BorderRadius.circular(12),
        border: Border.all(color: KuroakaiTheme.border),
      ),
      child: Row(
        children: [
          const SizedBox(width: 14),
          const Icon(Icons.search_rounded,
              color: KuroakaiTheme.textTertiary, size: 22),
          const SizedBox(width: 10),
          Expanded(
            child: TextField(
              controller: _searchController,
              style: const TextStyle(
                  color: KuroakaiTheme.textPrimary, fontSize: 14),
              decoration: const InputDecoration(
                hintText: 'Search Archive.org, Jamendo...',
                hintStyle: TextStyle(color: KuroakaiTheme.textTertiary),
                border: InputBorder.none,
                contentPadding: EdgeInsets.symmetric(vertical: 14),
              ),
              onSubmitted: (_) => _onSearch(discover),
            ),
          ),
          Container(
            margin: const EdgeInsets.all(6),
            child: ElevatedButton(
              style: ElevatedButton.styleFrom(
                backgroundColor: KuroakaiTheme.primary,
                padding:
                    const EdgeInsets.symmetric(horizontal: 20, vertical: 10),
                shape: RoundedRectangleBorder(
                    borderRadius: BorderRadius.circular(8)),
              ),
              onPressed:
                  discover.isLoading ? null : () => _onSearch(discover),
              child: const Text('Search',
                  style: TextStyle(
                      color: Colors.white,
                      fontWeight: FontWeight.bold,
                      fontSize: 13)),
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildUrlImportBar(DiscoverProvider discover) {
    return Container(
      decoration: BoxDecoration(
        color: KuroakaiTheme.surface,
        borderRadius: BorderRadius.circular(12),
        border: Border.all(color: KuroakaiTheme.border),
      ),
      child: Row(
        children: [
          const SizedBox(width: 14),
          const Icon(Icons.link_rounded,
              color: KuroakaiTheme.textTertiary, size: 22),
          const SizedBox(width: 10),
          Expanded(
            child: TextField(
              controller: _urlController,
              style: const TextStyle(
                  color: KuroakaiTheme.textPrimary, fontSize: 14),
              decoration: const InputDecoration(
                hintText: 'Paste direct audio URL to import...',
                hintStyle: TextStyle(color: KuroakaiTheme.textTertiary),
                border: InputBorder.none,
                contentPadding: EdgeInsets.symmetric(vertical: 14),
              ),
              onSubmitted: (_) => _onImportUrl(discover),
            ),
          ),
          Container(
            margin: const EdgeInsets.all(6),
            child: ElevatedButton.icon(
              style: ElevatedButton.styleFrom(
                backgroundColor: KuroakaiTheme.card,
                padding:
                    const EdgeInsets.symmetric(horizontal: 14, vertical: 10),
                shape: RoundedRectangleBorder(
                    borderRadius: BorderRadius.circular(8)),
                side: const BorderSide(color: KuroakaiTheme.border),
              ),
              icon: const Icon(Icons.download_rounded,
                  color: KuroakaiTheme.textSecondary, size: 18),
              label: const Text('Import',
                  style: TextStyle(
                      color: KuroakaiTheme.textSecondary,
                      fontWeight: FontWeight.bold,
                      fontSize: 13)),
              onPressed: discover.isLoading
                  ? null
                  : () => _onImportUrl(discover),
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildSourceFilters(DiscoverProvider discover) {
    return SizedBox(
      height: 36,
      child: ListView.builder(
        scrollDirection: Axis.horizontal,
        itemCount: discover.availableSources.length,
        itemBuilder: (ctx, idx) {
          final source = discover.availableSources[idx];
          final isActive = discover.activeSourceFilter == source;
          return Padding(
            padding: const EdgeInsets.only(right: 8),
            child: ChoiceChip(
              label: Text(source),
              selected: isActive,
              selectedColor: KuroakaiTheme.primary,
              backgroundColor: KuroakaiTheme.card,
              labelStyle: TextStyle(
                color: isActive ? Colors.white : KuroakaiTheme.textSecondary,
                fontWeight:
                    isActive ? FontWeight.bold : FontWeight.normal,
                fontSize: 12,
              ),
              onSelected: (sel) {
                if (sel) discover.setSourceFilter(source);
              },
            ),
          );
        },
      ),
    );
  }

  Widget _buildResults(DiscoverProvider discover) {
    // Loading
    if (discover.isLoading) {
      return const Center(
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            CircularProgressIndicator(color: KuroakaiTheme.primary),
            SizedBox(height: 16),
            Text('Searching external sources...',
                style: TextStyle(
                    color: KuroakaiTheme.textSecondary, fontSize: 13)),
          ],
        ),
      );
    }

    // Error
    if (discover.errorMessage != null && discover.results.isEmpty) {
      return Center(
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            const Icon(Icons.error_outline_rounded,
                size: 56, color: KuroakaiTheme.textTertiary),
            const SizedBox(height: 16),
            Text(discover.errorMessage!,
                textAlign: TextAlign.center,
                style: const TextStyle(
                    color: KuroakaiTheme.textSecondary, fontSize: 14)),
            const SizedBox(height: 16),
            ElevatedButton(
              style: ElevatedButton.styleFrom(
                  backgroundColor: KuroakaiTheme.primary),
              onPressed: () => _onSearch(discover),
              child: const Text('Retry',
                  style: TextStyle(color: Colors.white)),
            ),
          ],
        ),
      );
    }

    // Empty initial state
    if (discover.results.isEmpty && discover.lastQuery.isEmpty) {
      return Center(
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            Icon(Icons.explore_rounded,
                size: 72,
                color: KuroakaiTheme.primary.withValues(alpha: 0.3)),
            const SizedBox(height: 20),
            const Text('Explore Free Music',
                style: TextStyle(
                    color: KuroakaiTheme.textPrimary,
                    fontSize: 20,
                    fontWeight: FontWeight.bold)),
            const SizedBox(height: 8),
            const Padding(
              padding: EdgeInsets.symmetric(horizontal: 40),
              child: Text(
                'Search Archive.org\'s Live Music Archive, Jamendo\'s CC-licensed catalog, or import audio from any URL.',
                textAlign: TextAlign.center,
                style: TextStyle(
                    color: KuroakaiTheme.textTertiary, fontSize: 13),
              ),
            ),
          ],
        ),
      );
    }

    // Results list
    final audio = context.read<AudioProvider>();
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        // Results count
        Padding(
          padding: const EdgeInsets.only(bottom: 10),
          child: Text(
            '${discover.results.length} results for "${discover.lastQuery}"',
            style: const TextStyle(
                color: KuroakaiTheme.textTertiary, fontSize: 12),
          ),
        ),

        Expanded(
          child: ListView.builder(
            itemCount: discover.results.length,
            itemBuilder: (ctx, idx) {
              final track = discover.results[idx];
              return DiscoverTrackCard(
                track: track,
                isDownloading: _downloading.contains(track.id),
                downloadProgress: _downloadProgress[track.id] ?? 0.0,
                onStream: () {
                  audio.playStream(
                    track.streamUrl,
                    title: track.title,
                    artist: track.artist,
                  );
                },
                onDownload: track.canDownload
                    ? () => _onDownload(track)
                    : null,
              );
            },
          ),
        ),
      ],
    );
  }
}
