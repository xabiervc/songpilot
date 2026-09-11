# Microphone permissions for note capture

The in-app mic button (Editor screen) uses the `record` package, which streams
raw PCM16 from the device microphone. Because `android/` and `ios/` are
generated during CI builds, permission declarations are not tracked in git —
add these to your locally generated platform projects before running on a
device.

## Android

In `flutter_app/android/app/src/main/AndroidManifest.xml`, add above
`<application>`:

```xml
<uses-permission android:name="android.permission.RECORD_AUDIO"/>
```

The plugin shows the runtime permission dialog the first time the user taps
the mic button; denial is handled gracefully in the UI (informative snackbar).

## iOS

In `flutter_app/ios/Runner/Info.plist`, add inside `<dict>`:

```xml
<key>NSMicrophoneUsageDescription</key>
<string>SongPilot uses the microphone to detect which notes you play.</string>
```

Without this key iOS will terminate the app on first capture attempt. Both
keys survive local regeneration once added — CI doesn't submit store builds,
so nothing else is needed right now.
