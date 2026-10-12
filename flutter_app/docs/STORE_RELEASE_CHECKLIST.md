# SongPilot Store Release Checklist

This checklist complements, but does not replace, current requirements in the Apple and Google developer consoles and applicable law.

## Before building
- [ ] Enroll in Apple Developer Program and Google Play Console.
- [ ] Decide seller type; complete business verification, tax and banking details as applicable.
- [ ] Set final Android application ID and iOS bundle identifier.
- [ ] Generate native `ios/` and `android/` projects, configure signing, microphone permission descriptions, app names and production settings.
- [ ] Run `flutter pub get`, `dart run flutter_launcher_icons`, `flutter analyze` and `flutter test`.
- [ ] Test microphone permission, pitch capture, OAuth and release builds on physical devices.

## Privacy and safety
- [ ] Replace every `[TODO]` in `PRIVACY_POLICY.md`, obtain appropriate review and publish it at a public HTTPS URL.
- [ ] Set `PRIVACY_POLICY_URL` in the Flutter build and link the policy in both store consoles.
- [ ] Apply all migrations to staging and verify RLS as regular user and moderator.
- [ ] Assign `profiles.account_role = 'moderator'` only to trusted staff through the Supabase SQL editor after identity verification; never add client UI that grants roles.
- [ ] Deploy the account deletion Edge Function with JWT verification and Supabase secrets set server-side. Test with a disposable account including all owned rows and any Storage objects.
- [ ] Define the deletion processing SLA, support notification flow and retention exceptions.
- [ ] Set up a staff process for reviewing reports; the in-app moderation route relies on database RLS and is not a substitute for assigning authorized moderators.
- [ ] Complete Apple App Privacy and Google Data Safety declarations from real data flows; complete age/content and export-compliance questionnaires.

## Store materials
- [ ] App Store icon: 1024 x 1024 PNG without alpha.
- [ ] Google Play icon: 512 x 512 PNG and feature graphic: 1024 x 500.
- [ ] Prepare truthful device screenshots, descriptions, support URL and review credentials.

## Distribution
- [ ] Upload and test signed iOS build in TestFlight and Android App Bundle in internal/closed testing.
- [ ] Complete any current closed-test requirement for new personal Play accounts before production access.
- [ ] Announce launch only after approval from both stores.
