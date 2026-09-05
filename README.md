# SongPilot — Core Engine

**SongPilot** helps musicians break out of repetitive chord loops by suggesting
theory-backed ways to continue a song, across styles and moods (e.g. rock to
blues and back to rock), with plain-language explanations of *why* each
suggestion works.

## What's in this repository (current state)

This repo currently contains the **core logic layer** of SongPilot. It is
written in Python and is meant to be the reference implementation for:

- Chord parsing and normalization (`songpilot_core/music_theory.py`)
- Key/scale detection from a chord list
- Roman-numeral analysis relative to a key
- A rule-based chord progression suggestion engine with style/mood matching
  and fallback logic (`songpilot_core/suggestion_engine.py`)
- Core data models for users, song projects, sections, and collaboration
  requests (`songpilot_core/models.py`)

All logic here is covered by unit tests (`tests/`), run with the standard
library `unittest` module — no external dependencies required.

## What is NOT yet in this repository

Being transparent about scope: this repo does **not** yet contain the mobile
app itself. Building and verifying a production Flutter/React Native app for
Android and iOS (UI, Supabase backend, authentication, audio playback,
in-app purchases, App Store/Play Store builds) requires toolchains (Xcode,
Android SDK, physical/emulated devices) that cannot be built and verified
inside this environment. This repo is the honest, verified starting point:
the theory/suggestion "brain" of the app, ready to be wrapped by a mobile
front-end (see `docs/ARCHITECTURE.md`).

## Project structure

```
songpilot/
├── songpilot_core/
│   ├── __init__.py
│   ├── models.py            # UserProfile, SongProject, SongSection, CollaborationRequest
│   ├── music_theory.py      # chord parsing, scales, roman numerals, key detection
│   └── suggestion_engine.py # rule-based next-chord / next-section suggestions
├── tests/
│   ├── test_models.py
│   ├── test_music_theory.py
│   └── test_suggestion_engine.py
├── docs/
│   └── ARCHITECTURE.md
├── requirements.txt
└── README.md
```

## Running the tests

```bash
cd songpilot
python -m unittest discover -s tests -v
```

All 53 tests pass as of the last commit (validation edge cases, chord
parsing edge cases, key detection, and suggestion engine fallback logic).

## Example usage

```python
from songpilot_core import suggest_next, explain_progression

suggestions = suggest_next(key="E", style="rock", mood="driving")
for s in suggestions:
    print(s.chords, "-", s.explanation)

print(explain_progression(["C", "F", "G"], key="C"))
```

## Roadmap

1. Flutter mobile app (Android + iOS) wrapping this engine via a REST/local
   binding layer.
2. Supabase backend for accounts, song projects, and collaboration requests.
3. Chord/tab/audio input UI.
4. Free vs Pro gating (RevenueCat).
5. Collaboration/matching features between musicians.

See `docs/ARCHITECTURE.md` for the full planned architecture.
