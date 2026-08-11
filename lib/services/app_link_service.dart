import 'dart:async';
import 'dart:io';
import 'package:app_links/app_links.dart';

/// App Link & OS File Association Handling Service
class AppLinkService {
  final _appLinks = AppLinks();
  StreamSubscription<Uri>? _linkSubscription;

  /// Callback signature when an audio file path is received from OS "Open With"
  final Function(String filePath) onAudioFileOpened;

  AppLinkService({required this.onAudioFileOpened});

  /// Initialize deep link and CLI argument listening
  Future<void> init(List<String> args) async {
    // 1. Windows Command Line Argument Handling (when launched via double-click on .flac / .mp3)
    if (Platform.isWindows && args.isNotEmpty) {
      final potentialFilePath = args.first;
      if (File(potentialFilePath).existsSync()) {
        onAudioFileOpened(potentialFilePath);
        return;
      }
    }

    // 2. Android Intent / App Links Initial Link Handling
    try {
      final initialUri = await _appLinks.getInitialLink();
      if (initialUri != null) {
        _handleIncomingUri(initialUri);
      }
    } catch (e) {
      // Handle initial link error if any
    }

    // 3. Listen for Incoming Links while App is already open in background
    _linkSubscription = _appLinks.uriLinkStream.listen((Uri uri) {
      _handleIncomingUri(uri);
    }, onError: (err) {
      // Handle link stream error
    });
  }

  void _handleIncomingUri(Uri uri) {
    String filePath = uri.toFilePath();
    // On Android SAF, uri may be content:// scheme. Process path accordingly:
    if (uri.scheme == 'file' || uri.scheme == 'content') {
      filePath = uri.path;
    }
    if (filePath.isNotEmpty) {
      onAudioFileOpened(filePath);
    }
  }

  void dispose() {
    _linkSubscription?.cancel();
  }
}
