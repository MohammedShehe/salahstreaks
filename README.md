# salahstreaks

A new Flutter project.

## Getting Started

This project is a starting point for a Flutter application.

A few resources to get you started if this is your first Flutter project:

- [Lab: Write your first Flutter app](https://docs.flutter.dev/get-started/codelab)
- [Cookbook: Useful Flutter samples](https://docs.flutter.dev/cookbook)

For help getting started with Flutter development, view the
[online documentation](https://docs.flutter.dev/), which offers tutorials,
samples, guidance on mobile development, and a full API reference.


## 🌍 Ummah Leaderboard (serverless)

Global / weekly / monthly rankings of ibadat points and streaks, user discovery
(search + ⭐ friends), opt-in and offline-first. Runs on your own free Firebase
project with **no custom backend** – see [docs/LEADERBOARD_SETUP.md](docs/LEADERBOARD_SETUP.md)
and [firestore.rules](firestore.rules).

Code: `lib/models/leaderboard_models.dart`, `lib/services/leaderboard_scoring.dart`,
`lib/services/leaderboard_service.dart`, `lib/providers/leaderboard_provider.dart`,
`lib/screens/leaderboard_screen.dart`. Tests: `flutter test`.
