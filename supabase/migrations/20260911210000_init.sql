-- SongPilot initial schema (001)
-- Creates profiles, songs, song_sections, collab_requests with row-level security.

-- ============================================================================
-- profiles
-- ============================================================================
create table if not exists public.profiles (
  id uuid primary key references auth.users (id) on delete cascade,
  username text,
  email text,
  skill_level text not null default 'intermediate'
    check (skill_level in ('beginner', 'intermediate', 'advanced')),
  instruments text[] not null default '{}',
  genres text[] not null default '{}',
  favourite_artists text[] not null default '{}',
  open_to_collab boolean not null default false,
  looking_for text[] not null default '{}',
  is_pro boolean not null default false,
  created_at timestamptz not null default now(),
  updated_at timestamptz not null default now()
);

alter table public.profiles enable row level security;

create policy "Profiles are viewable by everyone"
  on public.profiles for select
  using (true);

create policy "Users can insert their own profile"
  on public.profiles for insert
  with check (auth.uid() = id);

create policy "Users can update their own profile"
  on public.profiles for update
  using (auth.uid() = id)
  with check (auth.uid() = id);

-- Auto-create a profile row whenever a user signs up.
create or replace function public.handle_new_user()
returns trigger
language plpgsql
security definer
set search_path = public
as $$
begin
  insert into public.profiles (id, username, email)
  values (
    new.id,
    coalesce(new.raw_user_meta_data ->> 'username', split_part(new.email, '@', 1)),
    new.email
  )
  on conflict (id) do nothing;
  return new;
end;
$$;

drop trigger if exists on_auth_user_created on auth.users;
create trigger on_auth_user_created
  after insert on auth.users
  for each row execute function public.handle_new_user();

-- ============================================================================
-- songs
-- ============================================================================
create table if not exists public.songs (
  id uuid primary key default gen_random_uuid(),
  owner_id uuid not null references auth.users (id) on delete cascade,
  title text not null default 'Untitled song',
  key text not null default 'C',
  tempo int not null default 120 check (tempo > 0 and tempo <= 400),
  style text not null default 'rock',
  mood text not null default 'driving',
  instrument text not null default 'guitar',
  visibility text not null default 'private'
    check (visibility in ('private', 'public', 'collab_open')),
  created_at timestamptz not null default now(),
  updated_at timestamptz not null default now()
);

create index if not exists songs_owner_idx on public.songs (owner_id);

alter table public.songs enable row level security;

create policy "Owners see their songs; public and collab_open songs are discoverable"
  on public.songs for select
  using (
    auth.uid() = owner_id
    or visibility in ('public', 'collab_open')
  );

create policy "Owners can insert songs"
  on public.songs for insert
  with check (auth.uid() = owner_id);

create policy "Owners can update their songs"
  on public.songs for update
  using (auth.uid() = owner_id)
  with check (auth.uid() = owner_id);

create policy "Owners can delete their songs"
  on public.songs for delete
  using (auth.uid() = owner_id);

-- ============================================================================
-- song_sections
-- ============================================================================
create table if not exists public.song_sections (
  id uuid primary key default gen_random_uuid(),
  song_id uuid not null references public.songs (id) on delete cascade,
  position int not null default 0,
  section_type text not null default 'verse',
  key text not null default 'C',
  chords text[] not null default '{}',
  bar_count int not null default 4 check (bar_count > 0)
);

create index if not exists song_sections_song_idx on public.song_sections (song_id);

alter table public.song_sections enable row level security;

create policy "Sections are readable when their song is readable"
  on public.song_sections for select
  using (
    exists (
      select 1 from public.songs s
      where s.id = song_sections.song_id
        and (s.owner_id = auth.uid() or s.visibility in ('public', 'collab_open'))
    )
  );

create policy "Song owners manage sections"
  on public.song_sections for all
  using (
    exists (
      select 1 from public.songs s
      where s.id = song_sections.song_id and s.owner_id = auth.uid()
    )
  )
  with check (
    exists (
      select 1 from public.songs s
      where s.id = song_sections.song_id and s.owner_id = auth.uid()
    )
  );

-- ============================================================================
-- collab_requests
-- ============================================================================
create table if not exists public.collab_requests (
  id uuid primary key default gen_random_uuid(),
  from_user uuid not null references auth.users (id) on delete cascade,
  to_user uuid not null references auth.users (id) on delete cascade,
  song_id uuid references public.songs (id) on delete cascade,
  message text not null default '',
  status text not null default 'pending'
    check (status in ('pending', 'accepted', 'declined')),
  created_at timestamptz not null default now()
);

create index if not exists collab_requests_to_user_idx on public.collab_requests (to_user);
create index if not exists collab_requests_from_user_idx on public.collab_requests (from_user);

alter table public.collab_requests enable row level security;

create policy "Requesters and recipients can read their requests"
  on public.collab_requests for select
  using (auth.uid() = from_user or auth.uid() = to_user);

create policy "Only authenticated requesters can create requests"
  on public.collab_requests for insert
  with check (auth.uid() = from_user);

create policy "Only recipients can respond to requests"
  on public.collab_requests for update
  using (auth.uid() = to_user)
  with check (auth.uid() = to_user);
