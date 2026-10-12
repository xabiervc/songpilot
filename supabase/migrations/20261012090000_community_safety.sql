-- Community safety primitives: user blocks and content reports.
-- RLS limits end users to their own records. Moderation review requires a
-- separate trusted server-side workflow; no moderator privileges are granted.

create table if not exists public.user_blocks (
  blocker_id uuid not null references auth.users(id) on delete cascade,
  blocked_id uuid not null references auth.users(id) on delete cascade,
  created_at timestamptz not null default now(),
  primary key (blocker_id, blocked_id),
  constraint user_blocks_no_self check (blocker_id <> blocked_id)
);

alter table public.user_blocks enable row level security;

create policy "Users can view their own blocks"
  on public.user_blocks for select
  using (auth.uid() = blocker_id);

create policy "Users can block another account"
  on public.user_blocks for insert
  with check (auth.uid() = blocker_id and auth.uid() <> blocked_id);

create policy "Users can unblock accounts"
  on public.user_blocks for delete
  using (auth.uid() = blocker_id);

create table if not exists public.content_reports (
  id uuid primary key default gen_random_uuid(),
  reporter_id uuid not null references auth.users(id) on delete cascade,
  reported_user_id uuid references auth.users(id) on delete set null,
  song_id uuid references public.songs(id) on delete set null,
  reason text not null check (char_length(trim(reason)) between 3 and 500),
  status text not null default 'pending'
    check (status in ('pending', 'reviewing', 'resolved', 'dismissed')),
  created_at timestamptz not null default now(),
  constraint content_reports_target check (reported_user_id is not null or song_id is not null)
);

create index if not exists content_reports_status_created_idx
  on public.content_reports(status, created_at);
create index if not exists content_reports_reporter_idx
  on public.content_reports(reporter_id, created_at desc);

alter table public.content_reports enable row level security;

create policy "Users can view their own reports"
  on public.content_reports for select
  using (auth.uid() = reporter_id);

create policy "Authenticated users can report content"
  on public.content_reports for insert
  with check (
    auth.uid() = reporter_id
    and char_length(trim(reason)) between 3 and 500
    and (reported_user_id is not null or song_id is not null)
  );
