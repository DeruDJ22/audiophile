import 'package:flutter/material.dart';
import 'package:provider/provider.dart';

import '../config/theme.dart';
import '../providers/audio_provider.dart';

/// 5-band parametric equalizer screen with presets.
class EqualizerScreen extends StatelessWidget {
  const EqualizerScreen({super.key});

  static const _bands = ['60 Hz', '230 Hz', '910 Hz', '4 kHz', '14 kHz'];
  static const _presets = [
    'Direct Bit-Perfect',
    'Bass Boost',
    'Vocal Enhancement',
    'Treble Boost'
  ];

  @override
  Widget build(BuildContext context) {
    return Consumer<AudioProvider>(
      builder: (context, audio, _) {
        return Container(
          color: KuroakaiTheme.background,
          padding: const EdgeInsets.all(20),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              const Text('Audiophile Equalizer',
                  style: TextStyle(
                      color: KuroakaiTheme.textPrimary,
                      fontSize: 24,
                      fontWeight: FontWeight.bold)),
              const Text('5-Band Parametric Sound Tuning & Presets',
                  style: TextStyle(
                      color: KuroakaiTheme.textSecondary, fontSize: 13)),
              const SizedBox(height: 20),

              // Presets row
              SizedBox(
                height: 40,
                child: ListView.builder(
                  scrollDirection: Axis.horizontal,
                  itemCount: _presets.length,
                  itemBuilder: (ctx, idx) {
                    final preset = _presets[idx];
                    final isSel = audio.activeEqPreset == preset;
                    return Padding(
                      padding: const EdgeInsets.only(right: 8.0),
                      child: ChoiceChip(
                        label: Text(preset),
                        selected: isSel,
                        selectedColor: KuroakaiTheme.primary,
                        backgroundColor: KuroakaiTheme.card,
                        labelStyle: TextStyle(
                            color: isSel
                                ? Colors.white
                                : KuroakaiTheme.textSecondary,
                            fontWeight: isSel
                                ? FontWeight.bold
                                : FontWeight.normal),
                        onSelected: (sel) {
                          if (sel) audio.updateEqPreset(preset);
                        },
                      ),
                    );
                  },
                ),
              ),
              const SizedBox(height: 30),

              // EQ Sliders
              Expanded(
                child: Container(
                  padding: const EdgeInsets.all(20),
                  decoration: KuroakaiTheme.cardDecoration,
                  child: Row(
                    mainAxisAlignment: MainAxisAlignment.spaceAround,
                    children: List.generate(5, (idx) {
                      return Column(
                        children: [
                          Text(
                            '${audio.eqValues[idx] > 0 ? '+' : ''}${audio.eqValues[idx].toInt()} dB',
                            style: const TextStyle(
                                color: KuroakaiTheme.secondary,
                                fontWeight: FontWeight.bold,
                                fontSize: 12),
                          ),
                          const SizedBox(height: 12),
                          Expanded(
                            child: RotatedBox(
                              quarterTurns: 3,
                              child: Slider(
                                value: audio.eqValues[idx],
                                min: -12.0,
                                max: 12.0,
                                onChanged: (val) =>
                                    audio.updateEqBand(idx, val),
                              ),
                            ),
                          ),
                          const SizedBox(height: 12),
                          Text(_bands[idx],
                              style: const TextStyle(
                                  color: KuroakaiTheme.textSecondary,
                                  fontSize: 12,
                                  fontWeight: FontWeight.bold)),
                        ],
                      );
                    }),
                  ),
                ),
              ),
            ],
          ),
        );
      },
    );
  }
}
