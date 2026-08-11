# Windows File Association Architecture for KuroakaiAudio

To allow double-clicking an audio file (e.g. `.flac`, `.mp3`, `.dsf`, `.wav`) in Windows File Explorer to automatically launch **KuroakaiAudio** and begin playback, two components are required:

---

## 1. Registration via Windows Registry (HKCU / HKLM)

When an installer (such as Inno Setup, WiX, or MSIX) installs KuroakaiAudio, it registers the application under `HKCU\Software\Classes`:

1. **File Extension Key**: Maps `.flac` to ProgID `KuroakaiAudio.flac`.
2. **ProgID Shell Command**: Maps `KuroakaiAudio.flac\shell\open\command` to:
   ```cmd
   "C:\Program Files\KuroakaiAudio\kuroakai_audio.exe" "%1"
   ```
   `"%1"` passes the clicked file's full system path as the first command-line argument to the executable.

---

## 2. Capturing Command Line Arguments in Flutter (Dart)

In `lib/main.dart`, pass `args` from top-level `void main(List<String> args)` to your application widget:

```dart
void main(List<String> args) async {
  WidgetsFlutterBinding.ensureInitialized();
  
  // Pass args directly to AppLinkService or Main UI
  runApp(KuroakaiApp(initialArgs: args));
}
```

In `AppLinkService`, if `args.isNotEmpty`, the app checks `args.first` and immediately invokes `kuroakai_play_file(args.first)` via FFI!
