import unittest
import sys, os
sys.path.insert(0, os.path.join(os.path.dirname(__file__), ".."))

from songpilot_core.suggestion_engine import (
    suggest_next, explain_progression, Suggestion, NoSuggestionsError,
)


class TestSuggestNext(unittest.TestCase):
    def test_exact_style_mood_match_rock_driving(self):
        results = suggest_next(key="C", style="rock", mood="driving")
        self.assertGreaterEqual(len(results), 1)
        self.assertEqual(results[0].style, "rock")
        self.assertEqual(results[0].mood, "driving")
        self.assertIn("cadence", results[0].explanation.lower())

    def test_blues_laidback_progression(self):
        results = suggest_next(key="A", style="blues", mood="laidback")
        self.assertTrue(any(r.style == "blues" for r in results))

    def test_falls_back_to_same_style_different_mood(self):
        results = suggest_next(key="C", style="pop", mood="aggressive")
        self.assertTrue(all(r.style == "pop" for r in results))

    def test_falls_back_to_any_template_for_unknown_style(self):
        results = suggest_next(key="C", style="unknown-style", mood="unknown-mood")
        self.assertGreaterEqual(len(results), 1)

    def test_empty_key_raises(self):
        with self.assertRaises(ValueError):
            suggest_next(key="", style="rock", mood="driving")

    def test_limit_respected(self):
        results = suggest_next(key="C", style="unknown", mood="unknown", limit=2)
        self.assertLessEqual(len(results), 2)

    def test_chords_are_generated_for_each_suggestion(self):
        results = suggest_next(key="G", style="jazz", mood="smooth")
        for r in results:
            self.assertIsInstance(r, Suggestion)
            self.assertGreater(len(r.chords), 0)

    def test_minor_mode_suggestion(self):
        results = suggest_next(key="A", style="indie", mood="melancholic", mode="minor")
        self.assertTrue(any(r.style == "indie" for r in results))
        for r in results:
            self.assertGreater(len(r.chords), 0)


class TestExplainProgression(unittest.TestCase):
    def test_explains_simple_progression(self):
        explanations = explain_progression(["C", "F", "G"], key="C")
        self.assertEqual(len(explanations), 3)
        self.assertIn("I", explanations[0])
        self.assertIn("IV", explanations[1])
        self.assertIn("V", explanations[2])

    def test_empty_chords_raises(self):
        with self.assertRaises(ValueError):
            explain_progression([], key="C")

    def test_borrowed_chord_labelled(self):
        explanations = explain_progression(["Db"], key="C")
        self.assertIn("borrowed", explanations[0])


if __name__ == "__main__":
    unittest.main()
