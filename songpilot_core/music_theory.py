"""Music theory utilities: chord parsing, key/scale handling, roman numerals."""
import re
from typing import List, Tuple, Optional

NOTE_NAMES = ["C", "C#", "D", "D#", "E", "F", "F#", "G", "G#", "A", "A#", "B"]
ENHARMONIC = {"Db": "C#", "Eb": "D#", "Gb": "F#", "Ab": "G#", "Bb": "A#"}

MAJOR_SCALE_STEPS = [0, 2, 4, 5, 7, 9, 11]
MINOR_SCALE_STEPS = [0, 2, 3, 5, 7, 8, 10]

ROMAN_MAJOR = ["I", "ii", "iii", "IV", "V", "vi", "vii"]
ROMAN_MINOR = ["i", "ii", "III", "iv", "v", "VI", "VII"]


class InvalidChordError(ValueError):
    pass


def normalize_note(note: str) -> str:
    note = note.strip()
    if note in ENHARMONIC:
        return ENHARMONIC[note]
    if note not in NOTE_NAMES:
        raise InvalidChordError(f"Unknown note: {note}")
    return note


def parse_chord(chord: str) -> Tuple[str, str]:
    """Parse a chord symbol into (root_note, quality). Raises InvalidChordError on bad input."""
    if not chord or not chord.strip():
        raise InvalidChordError("Empty chord string")

    chord = chord.strip()
    m = re.match(r"^([A-Ga-g])(#|b)?(.*)$", chord)
    if not m:
        raise InvalidChordError(f"Cannot parse chord: {chord}")

    letter, accidental, quality = m.groups()
    root = letter.upper() + (accidental or "")
    root = normalize_note(root)
    quality = quality or "maj"
    if quality == "":
        quality = "maj"
    return root, quality


def get_scale(key: str, mode: str = "major") -> List[str]:
    """Return the 7 notes of a major or minor scale for a given key."""
    root = normalize_note(key)
    root_index = NOTE_NAMES.index(root)
    steps = MAJOR_SCALE_STEPS if mode == "major" else MINOR_SCALE_STEPS
    return [NOTE_NAMES[(root_index + step) % 12] for step in steps]


def chord_to_roman(chord: str, key: str, mode: str = "major") -> str:
    """Convert a chord symbol to a roman numeral relative to a key."""
    root, quality = parse_chord(chord)
    scale = get_scale(key, mode)
    if root not in scale:
        return "borrowed"  # chromatic / borrowed chord relative to the key
    degree = scale.index(root)
    roman_set = ROMAN_MAJOR if mode == "major" else ROMAN_MINOR
    return roman_set[degree]


def detect_key_from_chords(chords: List[str]) -> Optional[str]:
    """Heuristic key detection: score each candidate major key by how many
    chord roots fit its scale, with extra weight given to roots that match
    the candidate's tonic (since songs usually start/end on the tonic).
    Returns None for empty input. Raises InvalidChordError for malformed chords.
    """
    if not chords:
        return None

    roots = [parse_chord(c)[0] for c in chords]

    best_key = None
    best_score = -1
    for candidate in NOTE_NAMES:
        scale = get_scale(candidate, "major")
        score = 0
        for r in roots:
            if r == candidate:
                score += 2  # tonic match weighted more heavily
            elif r in scale:
                score += 1
        if score > best_score:
            best_score = score
            best_key = candidate
    return best_key
