# SongPilot — Flutter App

Cross-platform (Android + iOS) app shell for **SongPilot**, an AI-assisted
songwriting companion. This complements the [songpilot core engine
repo](https://github.com/xabiervc/songpilot), whose Python logic was
compiled and unit-tested directly; the logic here is ported to Dart with
matching tests, but relies on CI (see below) for actual verification.

## Important: verification status

- `lib/core/` (music theory + suggestion engine) — Dart port of the
  verified Python `songpilot_core` package. Logic mirrors it exactly.
- `test/` — Dart unit tests mirroring the 53 Python tests.
- **These have not been compiled or run in the environment that wrote
  them** — there is no Flutter/Dart SDK available there. The included
  GitHub Actions workflow (`.github/workflows/flutter-ci.yml`) runs
  `flutter analyze` and `flutter test` automatically on every push, which
  is the first real verification this code gets. Check the **Actions**
  tab after pushing to confirm it's green before trusting it further.

## Project structure

```
flutter_app/
├── lib/
│   ├── main.dart              # App entry, routing, Supabase init
│   ├── core/
│   │   ├── music_theory.dart      # chord parsing, scales, roman numerals
│   │   └── suggestion_engine.dart # rule-based suggestion engine
│   ├── models/
│   │   └── models.dart            # UserProfile, SongProject, etc.
│   └── screens/
│       ├── auth_screen.dart
│       ├── home_screen.dart
│       ├── editor_screen.dart     # wired to the suggestion engine
│       ├── collab_screen.dart
│       └── profile_screen.dart
├── test/
│   ├── music_theory_test.dart
│   ├── suggestion_engine_test.dart
│   └── models_test.dart
├── docs/CI_SETUP.md           # how to get signed App Store/Play builds
├── pubspec.yaml
└── analysis_options.yaml
```

(The CI workflow itself lives at the repo root: `.github/workflows/flutter-ci.yml`,
since GitHub Actions only reads workflows from that exact path.)

## Before you run this

1. Install the Flutter SDK locally, or open this repo in an environment
   that has it (Codemagic, GitHub Codespaces with Flutter, etc.).
2. Create a Supabase project and replace `supabaseUrl` / `supabaseAnonKey`
   placeholders in `lib/main.dart`.
3. Run:
   ```bash
   flutter pub get
   flutter analyze
   flutter test
   flutter run
   ```
4. Push to GitHub — the CI workflow will build Android + iOS automatically.

## What's still missing (by design, for a first pass)

- Supabase table schema (`profiles`, `songs`, `sections`,
  `collaboration_requests`) — not yet created; screens have TODOs marking
  where real queries go.
- Audio playback (synth/high-quality sample toggle).
- Tab/chord-palette input UI (currently text input only).
- RevenueCat Free/Pro gating.
- Real Spotify integration for artist-influence suggestions.

See the core engine repo's `docs/ARCHITECTURE.md` for the full planned
architecture and roadmap.
