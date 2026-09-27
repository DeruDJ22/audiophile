import 'dart:io';
import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import 'package:flutter_dotenv/flutter_dotenv.dart';

import 'config/theme.dart';
import 'providers/audio_provider.dart';
import 'providers/library_provider.dart';
import 'providers/discover_provider.dart';
import 'screens/app_shell.dart';
import 'services/app_link_service.dart';

void main(List<String> args) async {
  WidgetsFlutterBinding.ensureInitialized();

  // Load .env for API keys (Jamendo, etc.)
  await dotenv.load(fileName: '.env').catchError((_) {
    // .env file not found — continue without API keys
  });

  runApp(KuroakaiAudioApp(initialArgs: args));
}

class KuroakaiAudioApp extends StatelessWidget {
  final List<String> initialArgs;

  const KuroakaiAudioApp({super.key, required this.initialArgs});

  @override
  Widget build(BuildContext context) {
    return MultiProvider(
      providers: [
        ChangeNotifierProvider(create: (_) => AudioProvider()),
        ChangeNotifierProvider(create: (_) => LibraryProvider()),
        ChangeNotifierProvider(create: (_) => DiscoverProvider()),
      ],
      child: MaterialApp(
        title: 'KuroakaiAudio',
        debugShowCheckedModeBanner: false,
        themeMode: ThemeMode.dark,
        darkTheme: KuroakaiTheme.darkTheme,
        home: _AppInitializer(initialArgs: initialArgs),
      ),
    );
  }
}

/// Handles app link service initialization and provides the shell.
class _AppInitializer extends StatefulWidget {
  final List<String> initialArgs;

  const _AppInitializer({required this.initialArgs});

  @override
  State<_AppInitializer> createState() => _AppInitializerState();
}

class _AppInitializerState extends State<_AppInitializer> {
  late AppLinkService _appLinkService;

  @override
  void initState() {
    super.initState();
    _setupAppLinks();
  }

  void _setupAppLinks() {
    _appLinkService = AppLinkService(onAudioFileOpened: (filePath) {
      if (mounted && File(filePath).existsSync()) {
        final audio = context.read<AudioProvider>();
        final library = context.read<LibraryProvider>();
        audio.playFile(filePath);
        library.addToLibrary(filePath);
      }
    });
    _appLinkService.init(widget.initialArgs);
  }

  @override
  void dispose() {
    _appLinkService.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return AppShell(initialArgs: widget.initialArgs);
  }
}
