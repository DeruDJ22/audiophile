#ifndef KUROAKAI_ENGINE_H
#define KUROAKAI_ENGINE_H

#include <stdint.h>
#include <stdbool.h>

#if defined(_WIN32) || defined(__CYGWIN__)
  #if defined(KUROAKAI_EXPORTS)
    #define KUROAKAI_API __declspec(dllexport)
  #else
    #define KUROAKAI_API __declspec(dllimport)
  #endif
#else
  #if __GNUC__ >= 4
    #define KUROAKAI_API __attribute__((visibility("default")))
  #else
    #define KUROAKAI_API
  #endif
#endif

#ifdef __cplusplus
extern "C" {
#endif

/**
 * Engine Playback State
 */
typedef enum {
    KUROAKAI_STATE_STOPPED = 0,
    KUROAKAI_STATE_PLAYING = 1,
    KUROAKAI_STATE_PAUSED = 2,
    KUROAKAI_STATE_ERROR = 3
} KuroakaiState;

/**
 * Audiophile Track Status Metadata
 */
typedef struct {
    int state;                // KuroakaiState enum
    double current_position;  // Position in seconds
    double duration;          // Total duration in seconds
    uint32_t sample_rate;     // Sample rate in Hz (e.g. 44100, 96000, 192000, 2822400 for DSD)
    uint32_t channels;        // Number of audio channels (e.g. 2 for stereo)
    uint32_t bit_depth;       // Bit depth (e.g. 16, 24, 32, 1 for DSD)
    float volume;             // Volume multiplier 0.0 - 1.0
    char codec_name[32];      // Decoded codec string (e.g. "flac", "dsd_lsbf", "mp3")
} KuroakaiAudioStatus;

/**
 * Initialize the Kuroakai Core Audio Engine.
 * Configures WASAPI Exclusive Mode (Windows) / Oboe AAudio Low Latency (Android)
 * and initializes FFmpeg network/codecs.
 * 
 * @return 0 on success, non-zero error code on failure.
 */
KUROAKAI_API int kuroakai_init(void);

/**
 * Open and start playing an audio file path (FLAC, MP3, DSD/DSF/DFF, WAV, AAC, etc.)
 * 
 * @param filepath UTF-8 absolute path to local audio file
 * @return 0 on success, non-zero error code on failure.
 */
KUROAKAI_API int kuroakai_play_file(const char* filepath);

/**
 * Pause active audio playback.
 */
KUROAKAI_API void kuroakai_pause(void);

/**
 * Resume audio playback from paused state.
 */
KUROAKAI_API void kuroakai_resume(void);

/**
 * Stop playback and close open audio decoder stream.
 */
KUROAKAI_API void kuroakai_stop(void);

/**
 * Seek playback position to specified timestamp in seconds.
 * 
 * @param position_seconds Target timestamp in seconds
 */
KUROAKAI_API void kuroakai_seek(double position_seconds);

/**
 * Set master output volume.
 * 
 * @param volume Value between 0.0 (mute) and 1.0 (max volume, 0dB gain)
 */
KUROAKAI_API void kuroakai_set_volume(float volume);

/**
 * Query current playback status, bit depth, sample rate, and position.
 * 
 * @param status_out Pointer to KuroakaiAudioStatus structure to fill
 */
KUROAKAI_API void kuroakai_get_status(KuroakaiAudioStatus* status_out);

/**
 * Shutdown audio engine, stop output streams, and release FFmpeg / miniaudio resources.
 */
KUROAKAI_API void kuroakai_cleanup(void);

#ifdef __cplusplus
}
#endif

#endif // KUROAKAI_ENGINE_H
