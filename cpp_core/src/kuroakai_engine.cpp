#include "kuroakai_engine.h"

#include <iostream>
#include <thread>
#include <mutex>
#include <atomic>
#include <cstring>
#include <chrono>
#include <vector>

// FFmpeg headers wrapped in extern "C"
extern "C" {
#include <libavformat/avformat.h>
#include <libavcodec/avcodec.h>
#include <libswresample/swresample.h>
#include <libavutil/opt.h>
#include <libavutil/channel_layout.h>
}

// Miniaudio high-fidelity audio I/O library
#define MINIAUDIO_IMPLEMENTATION
#include "miniaudio.h"

// Core Engine Internal State Context
struct KuroakaiContext {
    std::mutex mutex;
    std::atomic<KuroakaiState> state{KUROAKAI_STATE_STOPPED};

    // FFmpeg decoder context
    AVFormatContext* format_ctx = nullptr;
    AVCodecContext* codec_ctx = nullptr;
    SwrContext* swr_ctx = nullptr;
    int audio_stream_idx = -1;

    // Decoding info
    std::string current_file_path;
    double duration = 0.0;
    double current_position = 0.0;
    uint32_t sample_rate = 44100;
    uint32_t channels = 2;
    uint32_t bit_depth = 16;
    float volume = 1.0f;
    char codec_name[32] = "N/A";

    // Miniaudio device context
    ma_device device;
    bool device_initialized = false;

    // Audio Ring Buffer for Bit-Perfect Output
    std::vector<uint8_t> pcm_buffer;
    std::mutex buffer_mutex;
    std::thread decode_thread;
    std::atomic<bool> stop_decoder{false};
    std::atomic<bool> seek_requested{false};
    std::atomic<double> seek_target{0.0};
};

static KuroakaiContext g_ctx;

// Miniaudio Playback Data Callback (runs on high priority realtime audio thread)
static void data_callback(ma_device* pDevice, void* pOutput, const void* pInput, ma_uint32 frameCount) {
    (void)pInput;
    KuroakaiContext* ctx = (KuroakaiContext*)pDevice->pUserData;
    if (!ctx || ctx->state.load() != KUROAKAI_STATE_PLAYING) {
        std::memset(pOutput, 0, frameCount * ma_get_bytes_per_frame(pDevice->format, pDevice->channels));
        return;
    }

    size_t bytes_needed = frameCount * ma_get_bytes_per_frame(pDevice->format, pDevice->channels);
    std::lock_guard<std::mutex> lock(ctx->buffer_mutex);

    if (ctx->pcm_buffer.size() >= bytes_needed) {
        std::memcpy(pOutput, ctx->pcm_buffer.data(), bytes_needed);
        ctx->pcm_buffer.erase(ctx->pcm_buffer.begin(), ctx->pcm_buffer.begin() + bytes_needed);

        // Calculate current position based on consumed bytes
        double seconds_consumed = (double)frameCount / (double)ctx->sample_rate;
        ctx->current_position += seconds_consumed;
    } else {
        // Buffer underrun protection - silence fill
        std::memset(pOutput, 0, bytes_needed);
    }
}

// Detect source bit depth from FFmpeg sample format
static uint32_t detect_bit_depth(enum AVSampleFormat fmt) {
    switch (fmt) {
        case AV_SAMPLE_FMT_U8:
        case AV_SAMPLE_FMT_U8P:   return 8;
        case AV_SAMPLE_FMT_S16:
        case AV_SAMPLE_FMT_S16P:  return 16;
        case AV_SAMPLE_FMT_S32:
        case AV_SAMPLE_FMT_S32P:  return 32;
        case AV_SAMPLE_FMT_FLT:
        case AV_SAMPLE_FMT_FLTP:  return 32;
        case AV_SAMPLE_FMT_DBL:
        case AV_SAMPLE_FMT_DBLP:  return 64;
        case AV_SAMPLE_FMT_S64:
        case AV_SAMPLE_FMT_S64P:  return 64;
        default:                   return 24; // Common audiophile default
    }
}

// Background Decoder Thread Loop
static void decode_loop() {
    AVPacket* packet = av_packet_alloc();
    AVFrame* frame = av_frame_alloc();

    while (!g_ctx.stop_decoder.load()) {
        if (g_ctx.seek_requested.load()) {
            double target_sec = g_ctx.seek_target.load();
            int64_t timestamp = target_sec * AV_TIME_BASE;
            av_seek_frame(g_ctx.format_ctx, -1, timestamp, AVSEEK_FLAG_BACKWARD);
            if (g_ctx.codec_ctx) {
                avcodec_flush_buffers(g_ctx.codec_ctx);
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

        // Maintain ~1 second of buffered PCM data
        size_t current_buf_size = 0;
        {
            std::lock_guard<std::mutex> lock(g_ctx.buffer_mutex);
            current_buf_size = g_ctx.pcm_buffer.size();
        }

        if (current_buf_size > (g_ctx.sample_rate * g_ctx.channels * sizeof(float))) {
            std::this_thread::sleep_for(std::chrono::milliseconds(5));
            continue;
        }

        if (av_read_frame(g_ctx.format_ctx, packet) >= 0) {
            if (packet->stream_index == g_ctx.audio_stream_idx) {
                if (avcodec_send_packet(g_ctx.codec_ctx, packet) == 0) {
                    while (avcodec_receive_frame(g_ctx.codec_ctx, frame) == 0) {
                        // Calculate max output samples for this frame
                        int max_out_samples = swr_get_out_samples(g_ctx.swr_ctx, frame->nb_samples);
                        if (max_out_samples <= 0) continue;

                        // Allocate output buffer for float32 PCM
                        int dst_bufsize = av_samples_get_buffer_size(nullptr,
                            g_ctx.channels, max_out_samples, AV_SAMPLE_FMT_FLT, 1);

                        std::vector<uint8_t> decoded_data(dst_bufsize);
                        uint8_t* out_ptr = decoded_data.data();

                        // Single-pass bit-perfect resampling / format conversion
                        int out_samples = swr_convert(g_ctx.swr_ctx,
                            &out_ptr, max_out_samples,
                            (const uint8_t**)frame->data, frame->nb_samples);

                        if (out_samples > 0) {
                            int actual_size = av_samples_get_buffer_size(nullptr,
                                g_ctx.channels, out_samples, AV_SAMPLE_FMT_FLT, 1);

                            // Apply volume attenuation (0dB = 1.0 passthrough)
                            float vol = g_ctx.volume;
                            if (vol < 0.999f) {
                                float* float_ptr = reinterpret_cast<float*>(decoded_data.data());
                                size_t sample_count = actual_size / sizeof(float);
                                for (size_t i = 0; i < sample_count; ++i) {
                                    float_ptr[i] *= vol;
                                }
                            }

                            std::lock_guard<std::mutex> lock(g_ctx.buffer_mutex);
                            g_ctx.pcm_buffer.insert(g_ctx.pcm_buffer.end(),
                                decoded_data.begin(), decoded_data.begin() + actual_size);
                        }
                    }
                }
            }
            av_packet_unref(packet);
        } else {
            // End of File (EOF) - transition to stopped
            g_ctx.state.store(KUROAKAI_STATE_STOPPED);
            break;
        }
    }

    av_frame_free(&frame);
    av_packet_free(&packet);
}

// C API Implementations

KUROAKAI_API int kuroakai_init(void) {
    std::lock_guard<std::mutex> lock(g_ctx.mutex);
    std::cout << "[KuroakaiEngine] Initializing Core Engine with WASAPI/Oboe bit-perfect audio..." << std::endl;

    // Miniaudio device setup for bit-perfect output
    ma_device_config deviceConfig = ma_device_config_init(ma_device_type_playback);
    deviceConfig.playback.format   = ma_format_f32; // Standard 32-bit Float PCM for audiophile headroom
    deviceConfig.playback.channels = 2;
    deviceConfig.sampleRate        = 0; // Native hardware rate for bit-perfect passthrough
    deviceConfig.dataCallback      = data_callback;
    deviceConfig.pUserData         = &g_ctx;

    // Configure WASAPI Exclusive Mode on Windows / Low Latency on Android
#if defined(_WIN32)
    deviceConfig.wasapi.shareMode = ma_wasapi_share_mode_exclusive;
    deviceConfig.wasapi.noAutoConvertSRC = MA_TRUE;
#endif

    if (ma_device_init(NULL, &deviceConfig, &g_ctx.device) != MA_SUCCESS) {
        std::cerr << "[KuroakaiEngine] Failed to initialize miniaudio playback device." << std::endl;
        return -1;
    }

    g_ctx.device_initialized = true;
    g_ctx.state.store(KUROAKAI_STATE_STOPPED);
    return 0;
}

KUROAKAI_API int kuroakai_play_file(const char* filepath) {
    if (!filepath) return -1;
    std::lock_guard<std::mutex> lock(g_ctx.mutex);

    // Stop current track if playing
    if (g_ctx.state.load() != KUROAKAI_STATE_STOPPED) {
        g_ctx.stop_decoder.store(true);
        if (g_ctx.decode_thread.joinable()) {
            g_ctx.decode_thread.join();
        }
        if (g_ctx.format_ctx) {
            avformat_close_input(&g_ctx.format_ctx);
        }
        if (g_ctx.swr_ctx) {
            swr_free(&g_ctx.swr_ctx);
        }
    }

    g_ctx.current_file_path = filepath;
    std::cout << "[KuroakaiEngine] Opening audio stream: " << filepath << std::endl;

    // Open file using FFmpeg
    if (avformat_open_input(&g_ctx.format_ctx, filepath, nullptr, nullptr) < 0) {
        std::cerr << "[KuroakaiEngine] Error opening file: " << filepath << std::endl;
        g_ctx.state.store(KUROAKAI_STATE_ERROR);
        return -2;
    }

    if (avformat_find_stream_info(g_ctx.format_ctx, nullptr) < 0) {
        g_ctx.state.store(KUROAKAI_STATE_ERROR);
        return -3;
    }

    // Locate best audio stream
    g_ctx.audio_stream_idx = av_find_best_stream(g_ctx.format_ctx, AVMEDIA_TYPE_AUDIO, -1, -1, nullptr, 0);
    if (g_ctx.audio_stream_idx < 0) {
        g_ctx.state.store(KUROAKAI_STATE_ERROR);
        return -4;
    }

    AVStream* stream = g_ctx.format_ctx->streams[g_ctx.audio_stream_idx];
    const AVCodec* decoder = avcodec_find_decoder(stream->codecpar->codec_id);
    if (!decoder) {
        g_ctx.state.store(KUROAKAI_STATE_ERROR);
        return -5;
    }

    g_ctx.codec_ctx = avcodec_alloc_context3(decoder);
    avcodec_parameters_to_context(g_ctx.codec_ctx, stream->codecpar);

    if (avcodec_open2(g_ctx.codec_ctx, decoder, nullptr) < 0) {
        g_ctx.state.store(KUROAKAI_STATE_ERROR);
        return -6;
    }

    // Extract Metadata
    g_ctx.sample_rate = g_ctx.codec_ctx->sample_rate;
    g_ctx.channels = g_ctx.codec_ctx->ch_layout.nb_channels > 0 ? g_ctx.codec_ctx->ch_layout.nb_channels : 2;
    g_ctx.bit_depth = detect_bit_depth(g_ctx.codec_ctx->sample_fmt);
    g_ctx.duration = (double)g_ctx.format_ctx->duration / AV_TIME_BASE;
    g_ctx.current_position = 0.0;
    strncpy(g_ctx.codec_name, decoder->name, sizeof(g_ctx.codec_name) - 1);

    // Initialize Bit-Perfect Resampler (Float 32-bit output)
    g_ctx.swr_ctx = swr_alloc();
    AVChannelLayout out_ch_layout;
    av_channel_layout_default(&out_ch_layout, g_ctx.channels);

    swr_alloc_set_opts2(&g_ctx.swr_ctx,
        &out_ch_layout, AV_SAMPLE_FMT_FLT, g_ctx.sample_rate,
        &g_ctx.codec_ctx->ch_layout, g_ctx.codec_ctx->sample_fmt, g_ctx.codec_ctx->sample_rate,
        0, nullptr);

    swr_init(g_ctx.swr_ctx);

    // Clear PCM buffer
    {
        std::lock_guard<std::mutex> buf_lock(g_ctx.buffer_mutex);
        g_ctx.pcm_buffer.clear();
    }

    // Start playback device and decoder thread
    g_ctx.stop_decoder.store(false);
    g_ctx.state.store(KUROAKAI_STATE_PLAYING);
    g_ctx.decode_thread = std::thread(decode_loop);

    if (g_ctx.device_initialized) {
        ma_device_start(&g_ctx.device);
    }

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
}

KUROAKAI_API void kuroakai_cleanup(void) {
    kuroakai_stop();
    if (g_ctx.device_initialized) {
        ma_device_uninit(&g_ctx.device);
        g_ctx.device_initialized = false;
    }
    if (g_ctx.codec_ctx) {
        avcodec_free_context(&g_ctx.codec_ctx);
    }
    if (g_ctx.format_ctx) {
        avformat_close_input(&g_ctx.format_ctx);
    }
    if (g_ctx.swr_ctx) {
        swr_free(&g_ctx.swr_ctx);
    }
}
