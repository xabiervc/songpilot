-- Explicit staff authorization for moderation. New profiles remain regular users.
alter table public.profiles
  add column if not exists account_role text not null default 'user'
  check (account_role in ('user', 'moderator'));

create or replace function public.is_songpilot_moderator()
returns boolean
language sql
stable
security definer
set search_path = public
as $$
  select exists (
    select 1 from public.profiles
    where id = auth.uid() and account_role = 'moderator'
  );
$$;

revoke all on function public.is_songpilot_moderator() from public;
grant execute on function public.is_songpilot_moderator() to authenticated;

create policy "Moderators can view all content reports"
  on public.content_reports for select
  using (public.is_songpilot_moderator());

create policy "Moderators can update report status"
  on public.content_reports for update
  using (public.is_songpilot_moderator())
  with check (public.is_songpilot_moderator());
