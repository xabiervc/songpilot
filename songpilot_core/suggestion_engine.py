"""Rule-based chord progression suggestion engine.

Given a key, current style/mood, and the last chord played, suggests
several ways to continue a song, each with a short theory explanation.
This is intentionally rule-based (no ML) so behavior is deterministic
and testable.
"""
from dataclasses import dataclass
from typing import List
from .music_theory import get_scale, chord_to_roman, NOTE_NAMES

# Each template declares its own mode because minor-key progressions use
# different roman numerals (i, VI, III, VII) than major-key ones (I, IV, V).
PROGRESSION_TEMPLATES = [
    {
        "romans": ["IV", "V", "I"],
        "mode": "major",
        "style": "rock",
        "mood": "driving",
        "explanation": "Classic rock cadence: subdominant to dominant resolves strongly into the tonic.",
    },
    {
        "romans": ["vi", "IV", "I", "V"],
        "mode": "major",
        "style": "pop",
        "mood": "uplifting",
        "explanation": "Pop staple progression; the vi chord adds a touch of melancholy before resolving.",
    },
    {
        "romans": ["I", "bVII", "IV"],
        "mode": "major",
        "style": "blues",
        "mood": "laidback",
        "explanation": "The flat-VII is borrowed from the mixolydian mode, giving a bluesy, unresolved color.",
    },
    {
        "romans": ["ii", "V", "I"],
        "mode": "major",
        "style": "jazz",
        "mood": "smooth",
        "explanation": "The ii-V-I is the most common jazz cadence, creating strong forward motion to the tonic.",
    },
    {
        "romans": ["i", "VI", "III", "VII"],
        "mode": "minor",
        "style": "indie",
        "mood": "melancholic",
        "explanation": "A minor-key loop popularized in alt-rock; it never fully resolves, keeping emotional tension.",
    },
    {
        "romans": ["V", "vi"],
        "mode": "major",
        "style": "pop",
        "mood": "bittersweet",
        "explanation": "Deceptive cadence: expects resolution to I but lands on vi instead, creating surprise.",
    },
]

ROMAN_TO_MAJOR_DEGREE = {"I": 0, "ii": 1, "iii": 2, "IV": 3, "V": 4, "vi": 5, "vii": 6}
ROMAN_TO_MINOR_DEGREE = {"i": 0, "ii": 1, "III": 2, "iv": 3, "v": 4, "VI": 5, "VII": 6}


class NoSuggestionsError(Exception):
    pass


@dataclass
class Suggestion:
    chords: List[str]
    style: str
    mood: str
    explanation: str


def _roman_to_chord(roman: str, key: str, template_mode: str) -> str:
    """Convert a roman numeral to a concrete chord, using the mode the
    template itself was written in (not necessarily the caller's `mode`)."""
    if roman == "bVII":
        tonic = get_scale(key, template_mode)[0]
        idx = NOTE_NAMES.index(tonic)
        return NOTE_NAMES[(idx + 10) % 12]

    degree_map = ROMAN_TO_MAJOR_DEGREE if template_mode == "major" else ROMAN_TO_MINOR_DEGREE
    if roman not in degree_map:
        raise NoSuggestionsError(f"Unsupported roman numeral '{roman}' for mode '{template_mode}'")
    degree = degree_map[roman]
    scale = get_scale(key, template_mode)
    return scale[degree]


def suggest_next(
    key: str,
    style: str,
    mood: str,
    mode: str = "major",
    limit: int = 5,
) -> List[Suggestion]:
    """Return a list of suggested continuations matching the requested style/mood.

    Falls back to any available template if no exact style+mood match exists,
    so the caller always gets at least one usable suggestion when templates exist.
    The `mode` parameter filters/prioritizes candidates that match the requested
    tonal mode, but each template still converts using its own intrinsic mode.
    """
    if not key or not key.strip():
        raise ValueError("key must not be empty")

    exact = [t for t in PROGRESSION_TEMPLATES if t["style"] == style and t["mood"] == mood]
    same_style = [t for t in PROGRESSION_TEMPLATES if t["style"] == style]
    same_mode = [t for t in PROGRESSION_TEMPLATES if t["mode"] == mode]
    candidates = exact or same_style or same_mode or PROGRESSION_TEMPLATES

    results: List[Suggestion] = []
    for template in candidates[:limit]:
        chords = [_roman_to_chord(r, key, template["mode"]) for r in template["romans"]]
        results.append(
            Suggestion(
                chords=chords,
                style=template["style"],
                mood=template["mood"],
                explanation=template["explanation"],
            )
        )

    if not results:
        raise NoSuggestionsError("No suggestions available for the given parameters")

    return results


def explain_progression(chords: List[str], key: str, mode: str = "major") -> List[str]:
    """Return a roman-numeral + plain-language explanation for a chord sequence."""
    if not chords:
        raise ValueError("chords list must not be empty")

    explanations = []
    for chord in chords:
        roman = chord_to_roman(chord, key, mode)
        explanations.append(f"{chord} -> {roman}")
    return explanations
