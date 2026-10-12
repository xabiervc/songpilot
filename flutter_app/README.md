# SongPilot — Flutter App

Cross-platform SongPilot songwriting and musician-collaboration app. The repository contains a Flutter client and a Python core engine.

## Project structure

- `lib/` — Flutter application, services, models and screens.
- `test/` — Dart unit tests.
- `docs/` — development, CI and release guides.
- `assets/icons/` — launcher icon source images.

## Configure Supabase

Do not commit project keys. Provide your Supabase project URL and publishable (anon) key at run time using Dart defines.

```bash
cd flutter_app
flutter pub get
flutter run -d chrome \
  --dart-define=SUPABASE_URL=https://<project-ref>.supabase.co \
  --dart-define=SUPABASE_PUBLISHABLE_KEY=<publishable-key>
```

For a web build, run `flutter build web` with the same two `--dart-define` values. Flutter outputs static deployment files under `build/web`.

In Supabase Dashboard, add each development and deployment URL to **Authentication > URL Configuration > Redirect URLs**. For local web testing, allow the exact localhost URL/port Flutter uses (for example `http://localhost:7357/**` only if that is the actual port); configure the production HTTPS origin separately. OAuth providers must also be enabled and have their provider-side callback URLs configured.

See [`docs/WEB_TESTING.md`](docs/WEB_TESTING.md) for the complete setup and test limitations.

## Run checks

```bash
cd flutter_app
flutter analyze
flutter test
```

For microphone/pitch detection, OAuth behavior, permissions, and release builds, also test on physical Android and iOS devices; web testing does not replace device testing.
