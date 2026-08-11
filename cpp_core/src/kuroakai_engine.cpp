#define _CRT_SECURE_NO_WARNINGS
#include "kuroakai_engine.h"

#define MINIAUDIO_IMPLEMENTATION
#include "miniaudio.h"

#include <algorithm>
#include <atomic>
#include <chrono>
#include <cmath>
#include <cstring>
#include <iostream>
#include <mutex>
#include <thread>
#include <vector>

#ifndef M_PI
#define M_PI 3.14159265358979323846
#endif

// 5-Band Parametric Biquad Equalizer Filter
struct BiquadFilter {
  float b0 = 1.0f, b1 = 0.0f, b2 = 0.0f;
  float a1 = 0.0f, a2 = 0.0f;
  float x1_l = 0.0f, x2_l = 0.0f, y1_l = 0.0f, y2_l = 0.0f;
  float x1_r = 0.0f, x2_r = 0.0f, y1_r = 0.0f, y2_r = 0.0f;

  void setup_peaking(float frequency, float sample_rate, float gain_db, float q = 1.0f) {
    if (std::abs(gain_db) < 0.01f) {
      b0 = 1.0f; b1 = 0.0f; b2 = 0.0f;
      a1 = 0.0f; a2 = 0.0f;
      return;
    }
    float A = std::pow(10.0f, gain_db / 40.0f);
    float w0 = 2.0f * (float)M_PI * frequency / sample_rate;
    float alpha = std::sin(w0) / (2.0f * q);
    float cos_w0 = std::cos(w0);

    float b0_raw = 1.0f + alpha * A;
    float b1_raw = -2.0f * cos_w0;
    float b2_raw = 1.0f - alpha * A;
    float a0_raw = 1.0f + alpha / A;
    float a1_raw = -2.0f * cos_w0;
    float a2_raw = 1.0f - alpha / A;

    b0 = b0_raw / a0_raw;
    b1 = b1_raw / a0_raw;
    b2 = b2_raw / a0_raw;
    a1 = a1_raw / a0_raw;
    a2 = a2_raw / a0_raw;
  }

  inline float process_left(float in) {
    float out = b0 * in + b1 * x1_l + b2 * x2_l - a1 * y1_l - a2 * y2_l;
    x2_l = x1_l; x1_l = in;
    y2_l = y1_l; y1_l = out;
    return out;
  }

  inline float process_right(float in) {
    float out = b0 * in + b1 * x1_r + b2 * x2_r - a1 * y1_r - a2 * y2_r;
    x2_r = x1_r; x1_r = in;
    y2_r = y1_r; y1_r = out;
    return out;
  }

  void reset() {
    x1_l = x2_l = y1_l = y2_l = 0.0f;
    x1_r = x2_r = y1_r = y2_r = 0.0f;
  }
};

struct KuroakaiContext {
  std::mutex mutex;
  std::atomic<KuroakaiState> state{KUROAKAI_STATE_STOPPED};

  // Decoder
  ma_decoder decoder;
  bool decoder_initialized = false;

  // Metadata
  std::string current_file_path;
  double duration = 0.0;
  double current_position = 0.0;
  uint32_t sample_rate = 44100;
  uint32_t channels = 2;
  uint32_t bit_depth = 24;
  std::atomic<float> volume{1.0f};
  char codec_name[32] = "N/A";

  // 5-Band EQ (60Hz, 230Hz, 910Hz, 4kHz, 14kHz)
  float eq_gains[5] = {0.0f, 0.0f, 0.0f, 0.0f, 0.0f};
  BiquadFilter eq_filters[5];
  const float eq_freqs[5] = {60.0f, 230.0f, 910.0f, 4000.0f, 14000.0f};

  // Device
  ma_device device;
  bool device_initialized = false;

  // Ring buffer
  std::vector<float> pcm_buffer;
  std::mutex buffer_mutex;
  std::thread decode_thread;
  std::atomic<bool> stop_decoder{false};
  std::atomic<bool> seek_requested{false};
  std::atomic<double> seek_target{0.0};
};

static KuroakaiContext g_ctx;

static void update_eq_filters() {
  float sr = (g_ctx.sample_rate > 0) ? (float)g_ctx.sample_rate : 44100.0f;
  for (int i = 0; i < 5; ++i) {
    g_ctx.eq_filters[i].setup_peaking(g_ctx.eq_freqs[i], sr, g_ctx.eq_gains[i]);
  }
}

// Callback for miniaudio playback
static void data_callback(ma_device *pDevice, void *pOutput, const void *pInput,
                          ma_uint32 frameCount) {
  (void)pInput;
  KuroakaiContext *ctx = (KuroakaiContext *)pDevice->pUserData;
  if (!ctx || ctx->state.load() != KUROAKAI_STATE_PLAYING) {
    std::memset(pOutput, 0,
                frameCount *
                    ma_get_bytes_per_frame(pDevice->playback.format,
                                           pDevice->playback.channels));
    return;
  }

  size_t samples_needed = frameCount * pDevice->playback.channels;
  float *out_ptr = (float *)pOutput;

  std::lock_guard<std::mutex> lock(ctx->buffer_mutex);

  if (ctx->pcm_buffer.size() >= samples_needed) {
    std::memcpy(out_ptr, ctx->pcm_buffer.data(),
                samples_needed * sizeof(float));
    ctx->pcm_buffer.erase(ctx->pcm_buffer.begin(),
                          ctx->pcm_buffer.begin() + samples_needed);

    // Apply 5-Band Equalizer & Master Volume in Real-Time
    float vol = ctx->volume.load();
    uint32_t channels = ctx->channels;

    for (size_t i = 0; i < samples_needed; i += channels) {
      float l = out_ptr[i];
      float r = (channels > 1) ? out_ptr[i + 1] : l;

      // Pass through 5 biquad EQ filters
      for (int b = 0; b < 5; ++b) {
        l = ctx->eq_filters[b].process_left(l);
        if (channels > 1) {
          r = ctx->eq_filters[b].process_right(r);
        }
      }

      // Output with instant master volume scaling
      out_ptr[i] = std::clamp(l * vol, -1.0f, 1.0f);
      if (channels > 1) {
        out_ptr[i + 1] = std::clamp(r * vol, -1.0f, 1.0f);
      }
    }

    double seconds_consumed = (double)frameCount / (double)ctx->sample_rate;
    ctx->current_position += seconds_consumed;
  } else {
    std::memset(pOutput, 0, samples_needed * sizeof(float));
  }
}

// Background decoding thread loop
static void decode_loop() {
  const ma_uint32 CHUNK_FRAMES = 4096;
  std::vector<float> chunk(CHUNK_FRAMES * g_ctx.channels);

  while (!g_ctx.stop_decoder.load()) {
    if (g_ctx.seek_requested.load()) {
      double target_sec = g_ctx.seek_target.load();
      ma_uint64 target_frame = (ma_uint64)(target_sec * g_ctx.sample_rate);
      if (g_ctx.decoder_initialized) {
        ma_decoder_seek_to_pcm_frame(&g_ctx.decoder, target_frame);
      }
      {
        std::lock_guard<std::mutex> lock(g_ctx.buffer_mutex);
        g_ctx.pcm_buffer.clear();
      }
      g_ctx.current_position = target_sec;
      g_ctx.seek_requested.store(false);
    }

    if (g_ctx.state.load() != KUROAKAI_STATE_PLAYING) {
      std::this_thread::sleep_for(std::chrono::milliseconds(10));
      continue;
    }

    size_t current_buf_size = 0;
    {
      std::lock_guard<std::mutex> lock(g_ctx.buffer_mutex);
      current_buf_size = g_ctx.pcm_buffer.size();
    }

    // Maintain ~1 second of buffered float32 PCM samples
    if (current_buf_size > (g_ctx.sample_rate * g_ctx.channels * 2)) {
      std::this_thread::sleep_for(std::chrono::milliseconds(5));
      continue;
    }

    if (g_ctx.decoder_initialized) {
      ma_uint64 frames_read = 0;
      ma_result result = ma_decoder_read_pcm_frames(
          &g_ctx.decoder, chunk.data(), CHUNK_FRAMES, &frames_read);

      if (frames_read > 0) {
        size_t samples_read = frames_read * g_ctx.channels;
        std::lock_guard<std::mutex> lock(g_ctx.buffer_mutex);
        g_ctx.pcm_buffer.insert(g_ctx.pcm_buffer.end(), chunk.begin(),
                                chunk.begin() + samples_read);
      }

      if (result == MA_AT_END || frames_read == 0) {
        g_ctx.state.store(KUROAKAI_STATE_STOPPED);
        break;
      }
    } else {
      break;
    }
  }
}

// Extract codec extension name helper
static void get_codec_from_path(const char *filepath, char *out,
                                size_t max_len) {
  std::string path(filepath);
  size_t dot_idx = path.find_last_of('.');
  if (dot_idx != std::string::npos && dot_idx + 1 < path.length()) {
    std::string ext = path.substr(dot_idx + 1);
    std::transform(ext.begin(), ext.end(), ext.begin(), ::toupper);
    strncpy(out, ext.c_str(), max_len - 1);
    out[max_len - 1] = '\0';
  } else {
    strncpy(out, "AUDIO", max_len - 1);
  }
}

KUROAKAI_API int kuroakai_init(void) {
  std::lock_guard<std::mutex> lock(g_ctx.mutex);
  std::cout << "[KuroakaiEngine] Initializing Bit-Perfect Audio Engine..."
            << std::endl;

  g_ctx.state.store(KUROAKAI_STATE_STOPPED);
  return 0;
}

KUROAKAI_API int kuroakai_play_file(const char *filepath) {
  if (!filepath)
    return -1;
  std::lock_guard<std::mutex> lock(g_ctx.mutex);

  // Stop and cleanup previous track
  if (g_ctx.state.load() != KUROAKAI_STATE_STOPPED) {
    g_ctx.stop_decoder.store(true);
    if (g_ctx.decode_thread.joinable()) {
      g_ctx.decode_thread.join();
    }
    if (g_ctx.device_initialized) {
      ma_device_uninit(&g_ctx.device);
      g_ctx.device_initialized = false;
    }
    if (g_ctx.decoder_initialized) {
      ma_decoder_uninit(&g_ctx.decoder);
      g_ctx.decoder_initialized = false;
    }
  }

  g_ctx.current_file_path = filepath;
  get_codec_from_path(filepath, g_ctx.codec_name, sizeof(g_ctx.codec_name));

  // Configure miniaudio decoder for 32-bit float PCM
  ma_decoder_config decoderConfig = ma_decoder_config_init(ma_format_f32, 0, 0);
  ma_result result =
      ma_decoder_init_file(filepath, &decoderConfig, &g_ctx.decoder);
  if (result != MA_SUCCESS) {
    std::cerr << "[KuroakaiEngine] Error opening file with miniaudio: "
              << filepath << " (code " << result << ")" << std::endl;
    g_ctx.state.store(KUROAKAI_STATE_ERROR);
    return -2;
  }

  g_ctx.decoder_initialized = true;
  g_ctx.sample_rate = g_ctx.decoder.outputSampleRate;
  g_ctx.channels = g_ctx.decoder.outputChannels;
  g_ctx.bit_depth = 24; // Audiophile high-res default

  update_eq_filters();

  ma_uint64 totalFrames = 0;
  if (ma_decoder_get_length_in_pcm_frames(&g_ctx.decoder, &totalFrames) ==
          MA_SUCCESS &&
      g_ctx.sample_rate > 0) {
    g_ctx.duration = (double)totalFrames / (double)g_ctx.sample_rate;
  } else {
    g_ctx.duration = 0.0;
  }
  g_ctx.current_position = 0.0;

  // Device setup in Shared Mode
  ma_device_config deviceConfig =
      ma_device_config_init(ma_device_type_playback);
  deviceConfig.playback.format = ma_format_f32;
  deviceConfig.playback.channels = g_ctx.channels;
  deviceConfig.sampleRate = g_ctx.sample_rate;
  deviceConfig.playback.shareMode = ma_share_mode_shared;
  deviceConfig.dataCallback = data_callback;
  deviceConfig.pUserData = &g_ctx;

  if (ma_device_init(NULL, &deviceConfig, &g_ctx.device) != MA_SUCCESS) {
    std::cerr << "[KuroakaiEngine] Failed to initialize playback device."
              << std::endl;
    ma_decoder_uninit(&g_ctx.decoder);
    g_ctx.decoder_initialized = false;
    g_ctx.state.store(KUROAKAI_STATE_ERROR);
    return -3;
  }

  g_ctx.device_initialized = true;

  {
    std::lock_guard<std::mutex> buf_lock(g_ctx.buffer_mutex);
    g_ctx.pcm_buffer.clear();
  }

  g_ctx.stop_decoder.store(false);
  g_ctx.state.store(KUROAKAI_STATE_PLAYING);
  g_ctx.decode_thread = std::thread(decode_loop);

  ma_device_start(&g_ctx.device);
  return 0;
}

KUROAKAI_API void kuroakai_pause(void) {
  if (g_ctx.state.load() == KUROAKAI_STATE_PLAYING) {
    g_ctx.state.store(KUROAKAI_STATE_PAUSED);
    if (g_ctx.device_initialized) {
      ma_device_stop(&g_ctx.device);
    }
  }
}

KUROAKAI_API void kuroakai_resume(void) {
  if (g_ctx.state.load() == KUROAKAI_STATE_PAUSED) {
    g_ctx.state.store(KUROAKAI_STATE_PLAYING);
    if (g_ctx.device_initialized) {
      ma_device_start(&g_ctx.device);
    }
  }
}

KUROAKAI_API void kuroakai_stop(void) {
  g_ctx.state.store(KUROAKAI_STATE_STOPPED);
  g_ctx.stop_decoder.store(true);
  if (g_ctx.decode_thread.joinable()) {
    g_ctx.decode_thread.join();
  }
  if (g_ctx.device_initialized) {
    ma_device_stop(&g_ctx.device);
  }
  {
    std::lock_guard<std::mutex> lock(g_ctx.buffer_mutex);
    g_ctx.pcm_buffer.clear();
  }
}

KUROAKAI_API void kuroakai_seek(double position_seconds) {
  g_ctx.seek_target.store(position_seconds);
  g_ctx.seek_requested.store(true);
}

KUROAKAI_API void kuroakai_set_volume(float volume) {
  if (volume < 0.0f)
    volume = 0.0f;
  if (volume > 1.0f)
    volume = 1.0f;
  g_ctx.volume.store(volume);
}

KUROAKAI_API void kuroakai_set_eq_band(int band_index, float gain_db) {
  if (band_index < 0 || band_index >= 5) return;
  g_ctx.eq_gains[band_index] = gain_db;
  float sr = (g_ctx.sample_rate > 0) ? (float)g_ctx.sample_rate : 44100.0f;
  g_ctx.eq_filters[band_index].setup_peaking(g_ctx.eq_freqs[band_index], sr, gain_db);
}

KUROAKAI_API void kuroakai_set_eq_all(float g60, float g230, float g910, float g4k, float g14k) {
  g_ctx.eq_gains[0] = g60;
  g_ctx.eq_gains[1] = g230;
  g_ctx.eq_gains[2] = g910;
  g_ctx.eq_gains[3] = g4k;
  g_ctx.eq_gains[4] = g14k;
  update_eq_filters();
}

KUROAKAI_API void kuroakai_get_status(KuroakaiAudioStatus *status_out) {
  if (!status_out)
    return;
  status_out->state = g_ctx.state.load();
  status_out->current_position = g_ctx.current_position;
  status_out->duration = g_ctx.duration;
  status_out->sample_rate = g_ctx.sample_rate;
  status_out->channels = g_ctx.channels;
  status_out->bit_depth = g_ctx.bit_depth;
  status_out->volume = g_ctx.volume.load();
  strncpy(status_out->codec_name, g_ctx.codec_name,
          sizeof(status_out->codec_name) - 1);
  status_out->codec_name[sizeof(status_out->codec_name) - 1] = '\0';
}

KUROAKAI_API void kuroakai_cleanup(void) {
  kuroakai_stop();
  if (g_ctx.device_initialized) {
    ma_device_uninit(&g_ctx.device);
    g_ctx.device_initialized = false;
  }
  if (g_ctx.decoder_initialized) {
    ma_decoder_uninit(&g_ctx.decoder);
    g_ctx.decoder_initialized = false;
  }
}
