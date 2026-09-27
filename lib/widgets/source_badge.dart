import 'package:flutter/material.dart';
import '../config/theme.dart';

/// Source badge widget for Discover track cards.
/// Shows the origin of a track: "Archive.org", "Jamendo", or "Imported".
class SourceBadge extends StatelessWidget {
  final String source;

  const SourceBadge({super.key, required this.source});

  Color get _color {
    switch (source) {
      case 'YouTube':
        return const Color(0xFFFF0000); // YouTube Red
      case 'Spotify':
        return const Color(0xFF1DB954); // Spotify Green
      case 'Apple Music':
        return const Color(0xFFFA243C); // Apple Music Red/Pink
      case 'SoundCloud':
        return const Color(0xFFFF5500); // SoundCloud Orange
      case 'Archive.org':
        return const Color(0xFF4A90D9); // blue
      case 'Jamendo':
        return const Color(0xFF4ADE80); // green
      case 'Imported':
        return const Color(0xFFFFD700); // gold
      default:
        return KuroakaiTheme.primary;
    }
  }

  IconData get _icon {
    switch (source) {
      case 'YouTube':
        return Icons.play_circle_fill_rounded;
      case 'Spotify':
        return Icons.graphic_eq_rounded;
      case 'Apple Music':
        return Icons.music_note_rounded;
      case 'SoundCloud':
        return Icons.cloud_rounded;
      case 'Archive.org':
        return Icons.account_balance_rounded;
      case 'Jamendo':
        return Icons.library_music_rounded;
      case 'Imported':
        return Icons.link_rounded;
      default:
        return Icons.album_rounded;
    }
  }

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 3),
      decoration: BoxDecoration(
        color: _color.withValues(alpha: 0.15),
        borderRadius: BorderRadius.circular(6),
        border: Border.all(color: _color.withValues(alpha: 0.4), width: 1),
      ),
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          Icon(_icon, size: 12, color: _color),
          const SizedBox(width: 4),
          Text(
            source,
            style: TextStyle(
              color: _color,
              fontSize: 10,
              fontWeight: FontWeight.bold,
              letterSpacing: 0.5,
            ),
          ),
        ],
      ),
    );
  }
}
