# Social login setup (Google / Apple)

The auth screen already calls Supabase OAuth. To enable each provider:

## Google

1. Google Cloud Console -> create an OAuth 2.0 client (Web + Android + iOS).
2. Supabase dashboard -> Authentication -> Providers -> Google -> enable and
   paste Client ID / Secret.
3. Add the generated OAuth client IDs to the platform configs:
   - Android: SHA-1 fingerprint for the app + the web client ID.
   - iOS: the iOS client ID in the Supabase provider settings.

## Apple

1. Apple Developer -> create an App ID with Sign in with Apple enabled.
2. Create a Service ID and Key, configure the Return URLs Supabase gives you.
3. Supabase dashboard -> Authentication -> Providers -> Apple -> paste those.

## Deep link back into the app

OAuth returns via a redirect URL (`io.supabase.songpilot://login-callback/`).
The platform manifest/plist entries for that scheme come from supabase_flutter
docs and should be added to the generated `android/` and `ios/` projects once
you run the app locally (same note as `docs/MIC_SETUP.md` for generated files).