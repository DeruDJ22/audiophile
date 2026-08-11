import 'dart:io';
import 'package:file_picker/file_picker.dart';
import 'package:permission_handler/permission_handler.dart';

/// Minimal, robust File Picker Service for Windows and Android (Scoped Storage Compliant)
class FilePickerService {
  /// Supported Audiophile Extensions
  static const List<String> audioExtensions = [
    'flac',
    'dsf',
    'dff',
    'wav',
    'mp3',
    'aac',
    'm4a',
    'alac',
    'ogg',
    'aiff'
  ];

  /// Request appropriate runtime audio storage permission based on OS version
  static Future<bool> requestStoragePermission() async {
    if (Platform.isAndroid) {
      // Android 13 (API 33) and above uses READ_MEDIA_AUDIO for Scoped Storage
      if (await _isAndroid13OrHigher()) {
        final status = await Permission.audio.request();
        return status.isGranted;
      } else {
        // Android 12 and below uses READ_EXTERNAL_STORAGE
        final status = await Permission.storage.request();
        return status.isGranted;
      }
    }
    // Windows does not require runtime storage permission prompt
    return true;
  }

  static Future<bool> _isAndroid13OrHigher() async {
    if (!Platform.isAndroid) return false;
    // Android 13 (API 33+) introduced READ_MEDIA_AUDIO granular permission.
    // We try requesting audio permission — if the OS recognizes it, we're on 13+.
    // On older Android, Permission.audio maps to an undefined permission and returns denied.
    final audioStatus = await Permission.audio.status;
    return audioStatus != PermissionStatus.permanentlyDenied;
  }

  /// Pick single high-fidelity audio track
  static Future<String?> pickAudioFile() async {
    final hasPermission = await requestStoragePermission();
    if (!hasPermission) {
      throw Exception('Permission to read local audio files was denied.');
    }

    final FilePickerResult? result = await FilePicker.platform.pickFiles(
      type: FileType.custom,
      allowedExtensions: audioExtensions,
      allowMultiple: false,
    );

    if (result != null && result.files.single.path != null) {
      return result.files.single.path;
    }
    return null;
  }

  /// Pick multiple high-fidelity audio tracks for playlist creation
  static Future<List<String>> pickMultipleAudioFiles() async {
    final hasPermission = await requestStoragePermission();
    if (!hasPermission) {
      throw Exception('Permission to read local audio files was denied.');
    }

    final FilePickerResult? result = await FilePicker.platform.pickFiles(
      type: FileType.custom,
      allowedExtensions: audioExtensions,
      allowMultiple: true,
    );

    if (result != null) {
      return result.files
          .where((f) => f.path != null)
          .map((f) => f.path!)
          .toList();
    }
    return [];
  }
}
