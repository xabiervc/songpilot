import unittest
from datetime import datetime
import sys, os
sys.path.insert(0, os.path.join(os.path.dirname(__file__), ".."))

from songpilot_core.models import (
    UserProfile, SongProject, SongSection, CollaborationRequest,
    SkillLevel, Visibility, SectionType,
)


class TestUserProfile(unittest.TestCase):
    def test_valid_profile(self):
        p = UserProfile(user_id="u1", username="xabi", email="x@example.com")
        self.assertEqual(p.skill_level, SkillLevel.INTERMEDIATE)
        self.assertFalse(p.open_to_collab)

    def test_empty_username_raises(self):
        with self.assertRaises(ValueError):
            UserProfile(user_id="u1", username="   ", email="x@example.com")

    def test_invalid_email_raises(self):
        with self.assertRaises(ValueError):
            UserProfile(user_id="u1", username="xabi", email="not-an-email")

    def test_pro_flag_defaults_false(self):
        p = UserProfile(user_id="u1", username="xabi", email="x@example.com")
        self.assertFalse(p.is_pro)


class TestSongSection(unittest.TestCase):
    def test_valid_section(self):
        s = SongSection(section_type=SectionType.VERSE, key="E", chords=["E", "A"], bar_count=4)
        self.assertEqual(s.bar_count, 4)

    def test_zero_bar_count_raises(self):
        with self.assertRaises(ValueError):
            SongSection(section_type=SectionType.VERSE, key="E", bar_count=0)

    def test_negative_bar_count_raises(self):
        with self.assertRaises(ValueError):
            SongSection(section_type=SectionType.CHORUS, key="E", bar_count=-2)


class TestSongProject(unittest.TestCase):
    def test_valid_project_defaults(self):
        proj = SongProject(project_id="p1", owner_id="u1", title="My Song")
        self.assertEqual(proj.key, "C")
        self.assertEqual(proj.tempo, 120)
        self.assertEqual(proj.visibility, Visibility.PRIVATE)
        self.assertIsInstance(proj.created_at, datetime)

    def test_empty_title_raises(self):
        with self.assertRaises(ValueError):
            SongProject(project_id="p1", owner_id="u1", title="")

    def test_tempo_zero_raises(self):
        with self.assertRaises(ValueError):
            SongProject(project_id="p1", owner_id="u1", title="Song", tempo=0)

    def test_tempo_too_high_raises(self):
        with self.assertRaises(ValueError):
            SongProject(project_id="p1", owner_id="u1", title="Song", tempo=500)

    def test_add_section_and_total_bars(self):
        proj = SongProject(project_id="p1", owner_id="u1", title="Song")
        proj.add_section(SongSection(section_type=SectionType.VERSE, key="C", bar_count=8))
        proj.add_section(SongSection(section_type=SectionType.CHORUS, key="C", bar_count=4))
        self.assertEqual(proj.total_bars(), 12)
        self.assertEqual(len(proj.sections), 2)

    def test_total_bars_empty_project(self):
        proj = SongProject(project_id="p1", owner_id="u1", title="Song")
        self.assertEqual(proj.total_bars(), 0)


class TestCollaborationRequest(unittest.TestCase):
    def test_default_status_pending(self):
        req = CollaborationRequest(request_id="r1", from_user_id="u1", to_user_id="u2", project_id="p1")
        self.assertEqual(req.status, "pending")

    def test_accept_changes_status(self):
        req = CollaborationRequest(request_id="r1", from_user_id="u1", to_user_id="u2", project_id="p1")
        req.accept()
        self.assertEqual(req.status, "accepted")

    def test_decline_changes_status(self):
        req = CollaborationRequest(request_id="r1", from_user_id="u1", to_user_id="u2", project_id="p1")
        req.decline()
        self.assertEqual(req.status, "declined")


if __name__ == "__main__":
    unittest.main()
