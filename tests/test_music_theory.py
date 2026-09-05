import unittest
import sys, os
sys.path.insert(0, os.path.join(os.path.dirname(__file__), ".."))

from songpilot_core.music_theory import (
    parse_chord, normalize_note, get_scale, chord_to_roman,
    detect_key_from_chords, InvalidChordError,
)


class TestNormalizeNote(unittest.TestCase):
    def test_sharp_note_unchanged(self):
        self.assertEqual(normalize_note("C#"), "C#")

    def test_flat_note_converted_to_sharp_equivalent(self):
        self.assertEqual(normalize_note("Db"), "C#")

    def test_invalid_note_raises(self):
        with self.assertRaises(InvalidChordError):
            normalize_note("H")


class TestParseChord(unittest.TestCase):
    def test_simple_major_chord(self):
        root, quality = parse_chord("C")
        self.assertEqual(root, "C")
        self.assertEqual(quality, "maj")

    def test_minor_seventh_chord(self):
        root, quality = parse_chord("Am7")
        self.assertEqual(root, "A")
        self.assertEqual(quality, "m7")

    def test_maj7_with_sharp_root(self):
        root, quality = parse_chord("A#maj7")
        self.assertEqual(root, "A#")
        self.assertEqual(quality, "maj7")

    def test_flat_root_normalized(self):
        root, quality = parse_chord("Dbm")
        self.assertEqual(root, "C#")
        self.assertEqual(quality, "m")

    def test_lowercase_letter_accepted(self):
        root, quality = parse_chord("c")
        self.assertEqual(root, "C")

    def test_empty_string_raises(self):
        with self.assertRaises(InvalidChordError):
            parse_chord("")

    def test_whitespace_only_raises(self):
        with self.assertRaises(InvalidChordError):
            parse_chord("   ")

    def test_invalid_letter_raises(self):
        with self.assertRaises(InvalidChordError):
            parse_chord("H7")


class TestGetScale(unittest.TestCase):
    def test_c_major_scale(self):
        self.assertEqual(get_scale("C", "major"), ["C", "D", "E", "F", "G", "A", "B"])

    def test_a_minor_scale(self):
        self.assertEqual(get_scale("A", "minor"), ["A", "B", "C", "D", "E", "F", "G"])

    def test_e_major_scale(self):
        scale = get_scale("E", "major")
        self.assertEqual(scale, ["E", "F#", "G#", "A", "B", "C#", "D#"])

    def test_scale_with_flat_key_normalized(self):
        self.assertEqual(get_scale("Db", "major"), get_scale("C#", "major"))


class TestChordToRoman(unittest.TestCase):
    def test_tonic_chord(self):
        self.assertEqual(chord_to_roman("C", "C", "major"), "I")

    def test_dominant_chord(self):
        self.assertEqual(chord_to_roman("G", "C", "major"), "V")

    def test_subdominant_chord(self):
        self.assertEqual(chord_to_roman("F", "C", "major"), "IV")

    def test_relative_minor_chord(self):
        self.assertEqual(chord_to_roman("Am", "C", "major"), "vi")

    def test_borrowed_chord_outside_key(self):
        self.assertEqual(chord_to_roman("Db", "C", "major"), "borrowed")

    def test_minor_key_tonic(self):
        self.assertEqual(chord_to_roman("Am", "A", "minor"), "i")


class TestDetectKeyFromChords(unittest.TestCase):
    def test_simple_c_major_progression(self):
        key = detect_key_from_chords(["C", "F", "G", "C"])
        self.assertEqual(key, "C")

    def test_e_major_progression(self):
        key = detect_key_from_chords(["E", "A", "B", "E"])
        self.assertEqual(key, "E")

    def test_empty_list_returns_none(self):
        self.assertIsNone(detect_key_from_chords([]))

    def test_single_chord(self):
        key = detect_key_from_chords(["G"])
        self.assertIsNotNone(key)

    def test_invalid_chord_in_list_raises(self):
        with self.assertRaises(InvalidChordError):
            detect_key_from_chords(["C", "H7"])


if __name__ == "__main__":
    unittest.main()
