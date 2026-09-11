-- Add free-form tablature text to song sections.
alter table public.song_sections
  add column if not exists tabs text not null default '';
