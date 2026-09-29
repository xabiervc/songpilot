-- Traceable user-initiated deletion requests.
-- Auth identities must be removed from a protected server-side process that uses
-- a service-role key. The mobile client can only create and view its own request.

create table if not exists public.account_deletion_requests (
  id uuid primary key default gen_random_uuid(),
  user_id uuid not null unique references auth.users (id) on delete cascade,
  requested_at timestamptz not null default now(),
  status text not null default 'pending'
    check (status in ('pending', 'processing', 'completed', 'cancelled')),
  note text not null default ''
);

create index if not exists account_deletion_requests_status_idx
  on public.account_deletion_requests (status, requested_at);

alter table public.account_deletion_requests enable row level security;

create policy "Users can view their own deletion request"
  on public.account_deletion_requests for select
  using (auth.uid() = user_id);

create policy "Users can create their own deletion request"
  on public.account_deletion_requests for insert
  with check (auth.uid() = user_id);

create policy "Users can update their own pending deletion request"
  on public.account_deletion_requests for update
  using (auth.uid() = user_id and status = 'pending')
  with check (auth.uid() = user_id and status = 'pending');
