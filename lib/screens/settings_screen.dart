import 'package:flutter/material.dart';

import '../config/theme.dart';

/// Settings & audio engine information screen.
class SettingsScreen extends StatelessWidget {
  const SettingsScreen({super.key});

  @override
  Widget build(BuildContext context) {
    return Container(
      color: KuroakaiTheme.background,
      padding: const EdgeInsets.all(20),
      child: ListView(
        children: [
          const Text('Engine & Settings',
              style: TextStyle(
                  color: KuroakaiTheme.textPrimary,
                  fontSize: 24,
                  fontWeight: FontWeight.bold)),
          const Text('Kuroakai Audio Core System Information',
              style: TextStyle(
                  color: KuroakaiTheme.textSecondary, fontSize: 13)),
          const SizedBox(height: 20),
          _buildSettingCard(
            title: 'Native Audio Core',
            subtitle: 'Powered by Miniaudio C++ Single-Header Engine',
            icon: Icons.memory_rounded,
            trailing: const Text('ACTIVE',
                style: TextStyle(
                    color: KuroakaiTheme.success,
                    fontWeight: FontWeight.bold)),
          ),
          _buildSettingCard(
            title: 'Audio Output Mode',
            subtitle: 'High-Fidelity Shared PCM Direct Driver',
            icon: Icons.speaker_group_rounded,
            trailing: const Text('32-BIT FLOAT',
                style: TextStyle(
                    color: KuroakaiTheme.primary,
                    fontWeight: FontWeight.bold)),
          ),
          _buildSettingCard(
            title: 'Supported Formats',
            subtitle: 'FLAC, DSD (.dsf, .dff), MP3, WAV, AAC, ALAC, AIFF',
            icon: Icons.audio_file_rounded,
            trailing: const Text('LOSSLESS',
                style: TextStyle(
                    color: KuroakaiTheme.secondary,
                    fontWeight: FontWeight.bold)),
          ),
          _buildSettingCard(
            title: 'OS Integration',
            subtitle: 'Default File Association for Audio Extensions',
            icon: Icons.integration_instructions_rounded,
            trailing: const Text('CONFIGURED',
                style: TextStyle(
                    color: Colors.blueAccent,
                    fontWeight: FontWeight.bold)),
          ),
          _buildSettingCard(
            title: 'Discover Sources',
            subtitle: 'Archive.org • Jamendo (CC License) • URL Import',
            icon: Icons.explore_rounded,
            trailing: const Text('3 SOURCES',
                style: TextStyle(
                    color: KuroakaiTheme.warning,
                    fontWeight: FontWeight.bold)),
          ),
        ],
      ),
    );
  }

  Widget _buildSettingCard({
    required String title,
    required String subtitle,
    required IconData icon,
    required Widget trailing,
  }) {
    return Card(
      color: KuroakaiTheme.surface,
      margin: const EdgeInsets.only(bottom: 12),
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(10)),
      child: ListTile(
        leading: Icon(icon, color: KuroakaiTheme.primary),
        title: Text(title,
            style: const TextStyle(
                color: KuroakaiTheme.textPrimary,
                fontWeight: FontWeight.bold)),
        subtitle: Text(subtitle,
            style: const TextStyle(
                color: KuroakaiTheme.textSecondary, fontSize: 12)),
        trailing: trailing,
      ),
    );
  }
}
