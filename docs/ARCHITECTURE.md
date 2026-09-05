# SongPilot — Planned Architecture

This document describes the target architecture for the full SongPilot app.
Only the core engine (this repo's `songpilot_core/`) is implemented and
verified so far.

## Layers

1. **Core engine (this repo)** — Python reference implementation of music
   theory utilities and the suggestion engine. Deterministic, rule-based,
   fully unit tested.
2. **Mobile app (planned)** — Flutter app for Android and iOS.
3. **Backend (planned)** — Supabase (Postgres + Auth + Realtime) for user
   accounts, song projects, and collaboration requests.
4. **Monetization (planned)** — RevenueCat for Free vs Pro subscription
   gating.

## Why the core engine is Python and not Dart

This environment can execute and verify Python unit tests directly. Dart/
Flutter widget and integration tests require a mobile build toolchain that
isn't available here, so porting this logic to Dart is a follow-up
implementation step, using this repo as the verified reference.

## Data model

- `UserProfile`, `SongProject`, `SongSection`, `CollaborationRequest` — see
  `songpilot_core/models.py`.

## Suggestion engine design

Rule-based rather than ML-based, for deterministic and fully testable
behavior. Each progression template declares its roman-numeral sequence,
mode (major/minor), style, mood, and a plain-language explanation.
`suggest_next()` matches exact style+mood first, then falls back to
same-style, then same-mode, then any available template.
