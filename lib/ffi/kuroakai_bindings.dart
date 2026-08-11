import 'dart:ffi';
import 'dart:io';
import 'package:ffi/ffi.dart';

/// Dart representation of KuroakaiAudioStatus C Struct
final class KuroakaiAudioStatusStruct extends Struct {
  @Int32()
  external int state;

  @Double()
  external double currentPosition;

  @Double()
  external double duration;

  @Uint32()
  external int sampleRate;

  @Uint32()
  external int channels;

  @Uint32()
  external int bitDepth;

  @Float()
  external double volume;

  @Array(32)
  external Array<Uint8> codecName;
}

/// Helper Dart Class for status feedback
class KuroakaiAudioStatus {
  final int state;
  final double currentPosition;
  final double duration;
  final int sampleRate;
  final int channels;
  final int bitDepth;
  final double volume;
  final String codecName;

  KuroakaiAudioStatus({
    required this.state,
    required this.currentPosition,
    required this.duration,
    required this.sampleRate,
    required this.channels,
    required this.bitDepth,
    required this.volume,
    required this.codecName,
  });

  bool get isPlaying => state == 1;
  bool get isPaused => state == 2;
  bool get isStopped => state == 0;
  bool get isError => state == 3;

  String get formattedSampleRate => '${(sampleRate / 1000).toStringAsFixed(1)} kHz';
  String get formattedFormatInfo => '$codecName • $bitDepth-bit / $formattedSampleRate • ${channels == 2 ? "Stereo" : "Mono"}';
}

/// Native FFI Signature Types
typedef NativeInit = Int32 Function();
typedef DartInit = int Function();

typedef NativePlayFile = Int32 Function(Pointer<Utf8> filepath);
typedef DartPlayFile = int Function(Pointer<Utf8> filepath);

typedef NativeVoid = Void Function();
typedef DartVoid = void Function();

typedef NativeSeek = Void Function(Double position);
typedef DartSeek = void Function(double position);

typedef NativeSetVolume = Void Function(Float volume);
typedef DartSetVolume = void Function(double volume);

typedef NativeGetStatus = Void Function(Pointer<KuroakaiAudioStatusStruct> statusOut);
typedef DartGetStatus = void Function(Pointer<KuroakaiAudioStatusStruct> statusOut);

/// High-Level Dart FFI Bridge for Kuroakai Core Engine
class KuroakaiAudioBindings {
  late DynamicLibrary _lib;

  late DartInit _initEngine;
  late DartPlayFile _playFile;
  late DartVoid _pause;
  late DartVoid _resume;
  late DartVoid _stop;
  late DartSeek _seek;
  late DartSetVolume _setVolume;
  late DartGetStatus _getStatus;
  late DartVoid _cleanup;

  static final KuroakaiAudioBindings _instance = KuroakaiAudioBindings._internal();

  factory KuroakaiAudioBindings() => _instance;

  KuroakaiAudioBindings._internal() {
    _loadLibrary();
    _bindFunctions();
  }

  void _loadLibrary() {
    if (Platform.isWindows) {
      _lib = DynamicLibrary.open('kuroakai_audio.dll');
    } else if (Platform.isAndroid) {
      _lib = DynamicLibrary.open('libkuroakai_audio.so');
    } else if (Platform.isMacOS) {
      _lib = DynamicLibrary.open('libkuroakai_audio.dylib');
    } else if (Platform.isLinux) {
      _lib = DynamicLibrary.open('libkuroakai_audio.so');
    } else {
      throw UnsupportedError('Unsupported platform for Kuroakai Core Engine');
    }
  }

  void _bindFunctions() {
    _initEngine = _lib.lookupFunction<NativeInit, DartInit>('kuroakai_init');
    _playFile = _lib.lookupFunction<NativePlayFile, DartPlayFile>('kuroakai_play_file');
    _pause = _lib.lookupFunction<NativeVoid, DartVoid>('kuroakai_pause');
    _resume = _lib.lookupFunction<NativeVoid, DartVoid>('kuroakai_resume');
    _stop = _lib.lookupFunction<NativeVoid, DartVoid>('kuroakai_stop');
    _seek = _lib.lookupFunction<NativeSeek, DartSeek>('kuroakai_seek');
    _setVolume = _lib.lookupFunction<NativeSetVolume, DartSetVolume>('kuroakai_set_volume');
    _getStatus = _lib.lookupFunction<NativeGetStatus, DartGetStatus>('kuroakai_get_status');
    _cleanup = _lib.lookupFunction<NativeVoid, DartVoid>('kuroakai_cleanup');
  }

  int initEngine() => _initEngine();

  int playFile(String path) {
    final nativePath = path.toNativeUtf8();
    try {
      return _playFile(nativePath);
    } finally {
      calloc.free(nativePath);
    }
  }

  void pause() => _pause();
  void resume() => _resume();
  void stop() => _stop();
  void seek(double seconds) => _seek(seconds);
  void setVolume(double volume) => _setVolume(volume);

  KuroakaiAudioStatus getStatus() {
    final statusPtr = calloc<KuroakaiAudioStatusStruct>();
    try {
      _getStatus(statusPtr);
      final ref = statusPtr.ref;
      
      // Convert native char array to Dart String
      final codecBytes = <int>[];
      for (int i = 0; i < 32; i++) {
        final byte = ref.codecName[i];
        if (byte == 0) break;
        codecBytes.add(byte);
      }
      final codecStr = String.fromCharCodes(codecBytes);

      return KuroakaiAudioStatus(
        state: ref.state,
        currentPosition: ref.currentPosition,
        duration: ref.duration,
        sampleRate: ref.sampleRate,
        channels: ref.channels,
        bitDepth: ref.bitDepth,
        volume: ref.volume,
        codecName: codecStr.isEmpty ? 'PCM' : codecStr,
      );
    } finally {
      calloc.free(statusPtr);
    }
  }

  void cleanup() => _cleanup();
}
