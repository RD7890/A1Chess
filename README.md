# A1 Chess

A premium, open-source chess app for Android and iOS — built on the powerful [Lichess](https://lichess.org) platform.

**Package:** `com.ryzix.rdchess`

---

## Features

- ♟ Play online against millions of players worldwide
- 🤖 Challenge Stockfish (the world's strongest chess engine) at any level
- 📊 Deep game analysis with engine evaluation
- 🎯 Puzzles & tactics training — thousands updated daily
- 📖 Opening explorer with comprehensive databases
- 🏆 Tournaments — join or create your own
- 🎓 Study tools & interactive lessons
- 🌐 Supports all Lichess time controls: Bullet, Blitz, Rapid, Classical, Correspondence
- 🔔 Push notifications for game events and challenges
- 🌙 Dark mode & theming support
- 📡 Offline puzzle solving

---

## Getting Started

### Prerequisites

- [Flutter SDK](https://flutter.dev/docs/get-started/install) (see `pubspec.yaml` for required version)
- Android Studio / Xcode for device targets

### Setup

```bash
# Clone the repo
git clone https://github.com/RD7890/A1Chess.git
cd A1Chess

# Install dependencies
flutter pub get

# Run code generation
dart run build_runner build

# Start development watcher
dart run build_runner watch
```

### Run the App

```bash
# Run on all available devices
flutter run -d all

# Run on a specific device
flutter run -d <device-id>
```

### Run Tests

```bash
dart run build_runner build
flutter test
```

---

## Project Structure

```
lib/           # Main Dart source code
assets/        # Images, fonts, and static assets
android/       # Android-specific configuration
ios/           # iOS-specific configuration
test/          # Unit and widget tests
docs/          # Developer documentation
```

---

## Configuration

| Setting | Value |
|---|---|
| Android Package | `com.ryzix.rdchess` |
| iOS Bundle ID | `com.ryzix.rdchess` |
| Flutter app name | `a1_chess` |

---

## Contributing

Contributions are welcome! Please read [CONTRIBUTING.md](./CONTRIBUTING.md) before submitting a PR.

---

## Versioning

This project follows semantic versioning. The `pubspec.yaml` version field contains both the semantic version and the build number (e.g. `1.0.0+100`).

---

## License

This project is licensed under the terms in [LICENSE](./LICENSE). Original work by the [Lichess](https://lichess.org) team — used and modified under open-source license.

---

## Acknowledgements

Built on the incredible open-source work of the [Lichess organization](https://github.com/lichess-org). Special thanks to all contributors.
