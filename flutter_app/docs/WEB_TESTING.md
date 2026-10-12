# Testing SongPilot on the Web

## Prerequisites

Install a current stable Flutter SDK and Chrome, then from `flutter_app/`:

```bash
flutter create --platforms=web .
flutter pub get
```

Then run:

```bash
flutter run -d chrome \
  --dart-define=SUPABASE_URL=https://<project-ref>.supabase.co \
  --dart-define=SUPABASE_PUBLISHABLE_KEY=<publishable-key>
```

Use only a publishable/anon client key. Never use a service-role key in Flutter or browser code. Configure the exact localhost URL/port and hosted HTTPS URL in Supabase Authentication > URL Configuration > Redirect URLs. Configure each OAuth provider callback separately.

For database-backed community safety, export and deletion status, first apply the migrations in `supabase/migrations/` to a development project. The request record is not the deletion itself; automatic account deletion is not deployed by this repository package.

Web is suitable for UI, navigation and basic database-flow testing. Microphone permissions, pitch capture, mobile OAuth return handling, native permissions and store builds still need target-device tests.

To create a production web bundle, run `flutter build web` with the same Dart defines; output is in `build/web`. No hosting deployment is configured here.