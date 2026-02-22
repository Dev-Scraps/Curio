# Curio

Curio is a Flutter app that provides a personalized YouTube player experience with playlist syncing, progress tracking, and offline downloads.

## Features

- **Offline downloads**
  - Download individual videos or playlists for offline playback.
- **Playlist management & sync**
  - Sync playlists and library structure using imported cookies.
- **Progress tracking**
  - Saves viewing progress so you can resume later.
- **Advanced playback**
  - Quality selection, speed controls, Picture-in-Picture (where supported).
- **Customization**
  - Theme mode, accent color, fonts.
- **Multi-language support**
  - Localized UI (ARB-based Flutter localization).

## Tech stack

- **Flutter** (Dart)
- **Riverpod** for state management
- **media_kit** + **audio_service** for playback/background audio
- **Chaquopy (Python on Android)** for `yt-dlp` integration
- **SQLite (sqflite)** for local persistence

## Project structure

- `lib/main.dart`
  - App bootstrap + initialization (MediaKit, AudioService, notifications, yt-dlp bridge)
- `lib/core/services/yt_dlp/`
  - yt-dlp integration layer
- `lib/core/services/content/`
  - Download manager + syncing local downloads
- `lib/core/services/content/sync.dart`
  - Cookie-based account handling and playlist sync

## Getting started

### Prerequisites

- **Flutter SDK** compatible with `environment.sdk: ^3.10.1` (see `pubspec.yaml`).
- **Android Studio** (for Android builds) with a working Android SDK/NDK installation.

If you plan to build the Android app locally:

- **Python 3.11 for Chaquopy**
  - This repo currently references `C:/Python311/python.exe` in `android/app/build.gradle.kts`.
  - If your Python is elsewhere, update that path before building.

### Install dependencies

```bash
flutter pub get
```

### Run

- Android:

```bash
flutter run
```

- Windows (if enabled on your machine):

```bash
flutter run -d windows
```

## Usage

### First-time setup

On first launch, Curio guides you through:

- Theme + font selection
- Download location selection
- Permissions (storage + notifications)
- Account setup for playlist access

### Account / cookies

Curio uses a cookies-based approach for accessing your YouTube library features.

You can:

- Import a `cookies.txt` file
- Import multiple cookie files from a folder
- Use the in-app Google flow (yt-dlp login flow) to fetch cookies

Cookies are stored in the app’s support directory and managed via the in-app account switcher.

### Downloads

- Default Android download location:
  - `/storage/emulated/0/Download/Curio`
- You can set a custom download location in Setup/Settings.

Curio tracks download progress, supports pause/resume, and syncs completed files into the local library.

## Configuration notes

- **yt-dlp channel**
  - The app supports selecting a channel (e.g. Stable) for the yt-dlp integration.
- **PO token**
  - The app supports setting a yt-dlp PO token (stored in app storage) for improved access where needed.

## Build

### Android (APK)

```bash
flutter build apk
```

This project also defines Gradle tasks to copy APK outputs into `build/app/outputs/flutter-apk/`.

### Windows

```bash
flutter build windows
```

## Troubleshooting

- **Build fails due to Python path (Android)**
  - Update `chaquopy { defaultConfig { buildPython = ... } }` in `android/app/build.gradle.kts`.

- **Downloads/playlist sync not working**
  - Re-import cookies, ensure the cookies are valid, and verify network access.

## Known issues / Incomplete

- **Downloads may fail (signature / JS runtime related)**
  - Some YouTube videos require signature deciphering and/or a JavaScript runtime/extraction step.
  - If yt-dlp breaks due to upstream changes, downloads can fail until the embedded yt-dlp version/extractor pipeline is updated.

- **Streaming extractor needs improvement (NewPipe extractor)**
  - Current streaming URL extraction may not be as reliable as NewPipe’s extractor stack.
  - Planned: integrate or port a NewPipe-style extractor approach for more robust streaming.

## Legal

Curio is an open-source client application. You are responsible for how you use it.

- Downloading content may violate YouTube’s Terms of Service depending on your jurisdiction and usage.
- Only download content you have rights/permission to access.

## Contributing

- Fork the repo
- Create a feature branch
- Open a PR with a clear description and screenshots for UI changes

## License

No root project license file is currently included.

If you intend to publish this repository publicly, consider adding a `LICENSE` file (for example MIT/Apache-2.0/GPL-3.0) and ensuring all third-party dependencies are compatible with your chosen license.
#
