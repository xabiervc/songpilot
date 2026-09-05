"""Core data models for SongPilot."""
from dataclasses import dataclass, field
from datetime import datetime
from typing import List, Optional
from enum import Enum


class SkillLevel(str, Enum):
    BEGINNER = "beginner"
    INTERMEDIATE = "intermediate"
    ADVANCED = "advanced"


class Visibility(str, Enum):
    PRIVATE = "private"
    PUBLIC = "public"
    COLLAB_OPEN = "collab_open"


class SectionType(str, Enum):
    INTRO = "intro"
    VERSE = "verse"
    PRE_CHORUS = "pre_chorus"
    CHORUS = "chorus"
    BRIDGE = "bridge"
    OUTRO = "outro"
    CUSTOM = "custom"


@dataclass
class UserProfile:
    user_id: str
    username: str
    email: str
    skill_level: SkillLevel = SkillLevel.INTERMEDIATE
    instruments: List[str] = field(default_factory=list)
    genres: List[str] = field(default_factory=list)
    favourite_artists: List[str] = field(default_factory=list)
    open_to_collab: bool = False
    looking_for: List[str] = field(default_factory=list)
    is_pro: bool = False

    def __post_init__(self):
        if not self.username or not self.username.strip():
            raise ValueError("username cannot be empty")
        if "@" not in self.email:
            raise ValueError("email must be valid")


@dataclass
class SongSection:
    section_type: SectionType
    key: str
    chords: List[str] = field(default_factory=list)
    bar_count: int = 4

    def __post_init__(self):
        if self.bar_count <= 0:
            raise ValueError("bar_count must be positive")


@dataclass
class SongProject:
    project_id: str
    owner_id: str
    title: str
    key: str = "C"
    tempo: int = 120
    style: str = "rock"
    mood: str = "driving"
    instrument: str = "guitar"
    visibility: Visibility = Visibility.PRIVATE
    sections: List[SongSection] = field(default_factory=list)
    created_at: datetime = field(default_factory=datetime.utcnow)

    def __post_init__(self):
        if not self.title or not self.title.strip():
            raise ValueError("title cannot be empty")
        if self.tempo <= 0 or self.tempo > 400:
            raise ValueError("tempo must be between 1 and 400 bpm")

    def add_section(self, section: SongSection) -> None:
        self.sections.append(section)

    def total_bars(self) -> int:
        return sum(s.bar_count for s in self.sections)


@dataclass
class CollaborationRequest:
    request_id: str
    from_user_id: str
    to_user_id: str
    project_id: str
    message: str = ""
    status: str = "pending"  # pending, accepted, declined

    def accept(self) -> None:
        self.status = "accepted"

    def decline(self) -> None:
        self.status = "declined"
