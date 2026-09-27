import 'dart:io';
import 'package:http/http.dart' as http;
import 'package:path_provider/path_provider.dart';

import '../models/discover_track.dart';

/// Download manager for saving discovered tracks to the local library.
class DownloadService {
  /// Download a track to the local music directory.
  /// Returns the local file path on success, null on failure.
  static Future<String?> downloadTrack(
    DiscoverTrack track, {
    Function(double progress)? onProgress,
  }) async {
    try {
      final url = track.downloadUrl ?? track.streamUrl;
      if (url.isEmpty) return null;

      // Determine download directory
      final dir = await _getDownloadDirectory();
      
      // Sanitize filename
      final sanitizedTitle = track.title
          .replaceAll(RegExp(r'[<>:"/\\|?*]'), '_')
          .trim();
      final extension = track.format?.toLowerCase() ?? 'mp3';
      final fileName = '$sanitizedTitle.$extension';
      final filePath = '${dir.path}${Platform.pathSeparator}$fileName';

      // Check if already downloaded
      final file = File(filePath);
      if (await file.exists()) {
        return filePath;
      }

      // Download with progress tracking
      final request = http.Request('GET', Uri.parse(url));
      final streamedResponse = await request.send().timeout(
        const Duration(seconds: 120),
      );

      if (streamedResponse.statusCode != 200) {
        return null;
      }

      final totalBytes = streamedResponse.contentLength ?? -1;
      int receivedBytes = 0;
      final sink = file.openWrite();

      await for (final chunk in streamedResponse.stream) {
        sink.add(chunk);
        receivedBytes += chunk.length;
        if (totalBytes > 0 && onProgress != null) {
          onProgress(receivedBytes / totalBytes);
        }
      }

      await sink.flush();
      await sink.close();

      return filePath;
    } catch (e) {
      return null;
    }
  }

  /// Get the directory for storing downloaded music
  static Future<Directory> _getDownloadDirectory() async {
    if (Platform.isWindows) {
      // Use Music folder on Windows
      final userProfile = Platform.environment['USERPROFILE'] ?? '';
      final musicDir = Directory('$userProfile\\Music\\KuroakaiAudio');
      if (!await musicDir.exists()) {
        await musicDir.create(recursive: true);
      }
      return musicDir;
    } else {
      // Android: use app's external storage
      final dirs = await getExternalStorageDirectories(type: StorageDirectory.music);
      final dir = dirs?.first ?? await getApplicationDocumentsDirectory();
      final musicDir = Directory('${dir.path}/KuroakaiAudio');
      if (!await musicDir.exists()) {
        await musicDir.create(recursive: true);
      }
      return musicDir;
    }
  }
}
