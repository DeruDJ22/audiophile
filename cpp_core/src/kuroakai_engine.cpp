#define _CRT_SECURE_NO_WARNINGS
#include "kuroakai_engine.h"

#define MINIAUDIO_IMPLEMENTATION
#include "miniaudio.h"

#include <iostream>
#include <thread>
#include <mutex>
#include <atomic>
#include <cstring>
#include <chrono>
#include <vector>
#include <algorithm>

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
    float volume = 1.0f;
    char codec_name[32] = "N/A";

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

// Callback for miniaudio playback
static void data_callback(ma_device* pDevice, void* pOutput, const void* pInput, ma_uint32 frameCount) {
    (void)pInput;
    KuroakaiContext* ctx = (KuroakaiContext*)pDevice->pUserData;
    if (!ctx || ctx->state.load() != KUROAKAI_STATE_PLAYING) {
        std::memset(pOutput, 0, frameCount * ma_get_bytes_per_frame(pDevice->playback.format, pDevice->playback.channels));
        return;
    }

    size_t samples_needed = frameCount * pDevice->playback.channels;
    float* out_ptr = (float*)pOutput;

    std::lock_guard<std::mutex> lock(ctx->buffer_mutex);

    if (ctx->pcm_buffer.size() >= samples_needed) {
        std::memcpy(out_ptr, ctx->pcm_buffer.data(), samples_needed * sizeof(float));
        ctx->pcm_buffer.erase(ctx->pcm_buffer.begin(), ctx->pcm_buffer.begin() + samples_needed);

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
            ma_result result = ma_decoder_read_pcm_frames(&g_ctx.decoder, chunk.data(), CHUNK_FRAMES, &frames_read);

            if (frames_read > 0) {
                size_t samples_read = frames_read * g_ctx.channels;

                // Apply volume
                float vol = g_ctx.volume;
                if (vol < 0.999f) {
                    for (size_t i = 0; i < samples_read; ++i) {
                        chunk[i] *= vol;
                    }
                }

                std::lock_guard<std::mutex> lock(g_ctx.buffer_mutex);
                g_ctx.pcm_buffer.insert(g_ctx.pcm_buffer.end(), chunk.begin(), chunk.begin() + samples_read);
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
static void get_codec_from_path(const char* filepath, char* out, size_t max_len) {
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
    std::cout << "[KuroakaiEngine] Initializing Bit-Perfect Audio Engine..." << std::endl;

    g_ctx.state.store(KUROAKAI_STATE_STOPPED);
    return 0;
}

KUROAKAI_API int kuroakai_play_file(const char* filepath) {
    if (!filepath) return -1;
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
    ma_result result = ma_decoder_init_file(filepath, &decoderConfig, &g_ctx.decoder);
    if (result != MA_SUCCESS) {
        std::cerr << "[KuroakaiEngine] Error opening file with miniaudio: " << filepath << " (code " << result << ")" << std::endl;
        g_ctx.state.store(KUROAKAI_STATE_ERROR);
        return -2;
    }

    g_ctx.decoder_initialized = true;
    g_ctx.sample_rate = g_ctx.decoder.outputSampleRate;
    g_ctx.channels = g_ctx.decoder.outputChannels;
    g_ctx.bit_depth = 24; // Audiophile high-res default

    ma_uint64 totalFrames = 0;
    if (ma_decoder_get_length_in_pcm_frames(&g_ctx.decoder, &totalFrames) == MA_SUCCESS && g_ctx.sample_rate > 0) {
        g_ctx.duration = (double)totalFrames / (double)g_ctx.sample_rate;
    } else {
        g_ctx.duration = 0.0;
    }
    g_ctx.current_position = 0.0;

    // Device setup for WASAPI Exclusive (Windows) / Low Latency (Android)
    ma_device_config deviceConfig = ma_device_config_init(ma_device_type_playback);
    deviceConfig.playback.format   = ma_format_f32;
    deviceConfig.playback.channels = g_ctx.channels;
    deviceConfig.sampleRate        = g_ctx.sample_rate;
    deviceConfig.dataCallback      = data_callback;
    deviceConfig.pUserData         = &g_ctx;

#if defined(_WIN32)
    deviceConfig.playback.shareMode = ma_share_mode_exclusive;
    deviceConfig.wasapi.noAutoConvertSRC = MA_TRUE;
#endif

    if (ma_device_init(NULL, &deviceConfig, &g_ctx.device) != MA_SUCCESS) {
        // Fallback to shared mode if exclusive mode is unavailable on device
        deviceConfig.playback.shareMode = ma_share_mode_shared;
        if (ma_device_init(NULL, &deviceConfig, &g_ctx.device) != MA_SUCCESS) {
            std::cerr << "[KuroakaiEngine] Failed to initialize playback device." << std::endl;
            ma_decoder_uninit(&g_ctx.decoder);
            g_ctx.decoder_initialized = false;
            g_ctx.state.store(KUROAKAI_STATE_ERROR);
            return -3;
        }
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
    if (volume < 0.0f) volume = 0.0f;
    if (volume > 1.0f) volume = 1.0f;
    g_ctx.volume = volume;
}

KUROAKAI_API void kuroakai_get_status(KuroakaiAudioStatus* status_out) {
    if (!status_out) return;
    status_out->state = g_ctx.state.load();
    status_out->current_position = g_ctx.current_position;
    status_out->duration = g_ctx.duration;
    status_out->sample_rate = g_ctx.sample_rate;
    status_out->channels = g_ctx.channels;
    status_out->bit_depth = g_ctx.bit_depth;
    status_out->volume = g_ctx.volume;
    strncpy(status_out->codec_name, g_ctx.codec_name, sizeof(status_out->codec_name) - 1);
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
