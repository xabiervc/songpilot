# Testing SongPilot on the Web

## Prerequisites

Install a current stable Flutter SDK and Chrome, then from `flutter_app/`:

```bash
flutter create --platforms=web .
flutter pub get
```

The `flutter create` command adds the web host project files to this Flutter app. Review generated changes before committing them. Then start Chrome:

```bash
flutter run -d chrome \
  --dart-define=SUPABASE_URL=https://<project-ref>.supabase.co \
  --dart-define=SUPABASE_PUBLISHABLE_KEY=<publishable-key>
```

Use the Supabase publishable/anon client key only. Never put a service-role key in Flutter, browser code, repository files, or `--dart-define` values.

## Supabase Auth redirects

In Supabase Dashboard, open **Authentication > URL Configuration** and configure the Site URL and allowed Redirect URLs. Add the exact localhost origin/port printed by Flutter for development, and add the HTTPS origin used by a hosted build. Do not broadly allow arbitrary origins in production.

For Google or Apple OAuth, also configure each provider in Supabase and set its authorized callback URL at the provider. Test returning to the app after login, logout and browser refresh. Password sign-in can be tested without OAuth provider setup, provided the Supabase project is configured and reachable.

## What web testing is good for

- Layout, navigation and responsive UI.
- Email/password flow and database reads/writes against a development Supabase project.
- Project editor, collaboration screens and general interaction.

Use test accounts and non-production data. Avoid testing against real user data.

## What still needs device testing

- Microphone permission prompts, audio capture and pitch detection may behave differently by browser and operating system.
- iOS/Android OAuth return-to-app behavior, native permissions, signing and app-store builds must be tested on their target platforms.
- Do not treat a successful browser run as proof that mobile release builds work.

## Build for static hosting

```bash
flutter build web \
  --dart-define=SUPABASE_URL=https://<project-ref>.supabase.co \
  --dart-define=SUPABASE_PUBLISHABLE_KEY=<publishable-key>
```

Deploy `build/web` to an HTTPS static host only after configuring its exact origin in Supabase Auth redirects. This change does not configure a hosting provider or publish the app.