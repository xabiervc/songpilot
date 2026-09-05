# CI/CD Setup — Getting Real Builds Without Owning a Mac

This project includes `.github/workflows/flutter-ci.yml` (at the repo
root), which runs on GitHub's own cloud servers every time you push to
`main`. This is what actually gives you verified Android and iOS builds —
no local Flutter/Xcode/Android SDK install needed on your machine.

## What happens automatically

1. **Analyze & Test job** (Ubuntu runner) — runs `flutter analyze` and
   `flutter test`. If anything in `lib/` or `test/` doesn't compile or a
   test fails, this job fails and blocks the build jobs. This is the step
   that actually verifies the Dart code compiles and behaves correctly —
   something that could not be verified inside the AI sandbox that wrote
   this code.
2. **Build Android job** (Ubuntu runner) — builds a release APK and
   uploads it as a downloadable workflow artifact.
3. **Build iOS job** (macOS runner) — builds an *unsigned* iOS app bundle.
   GitHub provides real macOS virtual machines for this specific reason:
   iOS builds require Apple's toolchain, which only runs on macOS.

## How to see the results

1. Push this repo to GitHub (or it's already there).
2. Go to the repo's **Actions** tab.
3. Click the latest workflow run to see test results and download the
   Android APK / iOS app bundle from the "Artifacts" section.

## Getting a real, signed build for App Store / Play Store

The CI above proves the app builds and tests pass, but two more steps are
needed for real distribution:

### Android (Play Store)
1. Generate a signing keystore (`keytool -genkey ...`).
2. Add the keystore and passwords as GitHub Actions secrets.
3. Update `android/app/build.gradle` to use the signing config.
4. Change the build step to `flutter build appbundle --release` and upload
   to Google Play Console.

### iOS (App Store)
1. You need an Apple Developer account ($99/year).
2. Create distribution certificates and provisioning profiles in
   [Apple Developer](https://developer.apple.com).
3. Add certificates/profiles as GitHub Actions secrets (base64-encoded).
4. Use a signing step (e.g. `apple-actions/import-codesign-certs`) before
   `flutter build ipa`.
5. Upload via `xcrun altool` or Fastlane to App Store Connect.

Alternatively, a service like **Codemagic** automates most of this signing
complexity with a UI instead of hand-written YAML, and includes 500 free
build minutes/month.

## Why this matters

The Python core engine in `songpilot_core` (separate repo/folder) was
compiled and unit-tested directly by the AI that wrote it, so its 53 tests
are a verified fact. The Dart/Flutter code in this app was written with the
same logic and test coverage, but **could not be compiled or executed**
in that same environment (no Dart/Flutter SDK available). This CI workflow
is what actually closes that gap — the first `git push` to this repo is
the first time this code gets compiled and tested for real.
