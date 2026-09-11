# Supabase setup for SongPilot

The Flutter app expects a Supabase project with the schema from
`supabase/migrations/20260911210000_init.sql`. One-time setup:

## 1. Create the project

1. Go to https://supabase.com and sign in.
2. Create a new project (choose region + database password).
3. Wait for provisioning to finish.

## 2. Apply the schema

1. In the Supabase dashboard, open **SQL Editor** -> **New query**.
2. Paste the full contents of `supabase/migrations/20260911210000_init.sql`.
3. Run it. You should now have four tables: `profiles`, `songs`,
   `song_sections`, `collab_requests`, all with row-level security enabled.

## 3. Enable email auth

Authentication -> Providers -> Email should already be on. Optional: disable
"Confirm email" during development so sign-ups log in immediately.

## 4. Get your credentials

Project Settings -> API:
- Project URL (e.g. https://xyzcompany.supabase.co)
- publishable key (the `anon` / public key — safe to embed in the app)

## 5. Configure the app

In `flutter_app/lib/main.dart`, replace:

```dart
const supabaseUrl = 'https://YOUR_PROJECT.supabase.co';
const supabasePublishableKey = 'YOUR_ANON_KEY';
```

with your real values.

## 6. What this gives you

| Feature | Table | Who can do what (RLS) |
|---|---|---|
| Profile + collab preferences | `profiles` | Everyone can read; owners write their own row. Auto-created on sign-up via trigger. |
| Saved songs | `songs` | Owner full control; `public`/`collab_open` songs discoverable. |
| Song sections/chords | `song_sections` | Follows parent song visibility; owner manages. |
| Collaboration requests | `collab_requests` | Participants read; requester creates; recipient responds. |

Next planned slices: tab/audio input UI, suggestion engine per-section
storage, collaboration discovery screen, Pro gating with RevenueCat.
