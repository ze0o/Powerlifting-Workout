-- Meet Prep Log · coach mode (already applied to the meet-prep-log project)
--
-- A coach turns on coaching and gets a 6-character code. An athlete enters the code,
-- which links them; either side can remove the link. While linked, the coach can read
-- the athlete's profile and latest snapshot, comment on workouts, and send programs
-- that the athlete accepts or declines.

-- ---------- coach profile ----------

alter table public.profiles
  add column if not exists is_coach boolean not null default false,
  add column if not exists coach_code text unique;

-- ---------- links ----------

create table public.coach_links (
  id uuid primary key default gen_random_uuid(),
  coach_id uuid not null references auth.users(id) on delete cascade,
  athlete_id uuid not null references auth.users(id) on delete cascade,
  created_at timestamptz not null default now(),
  unique (coach_id, athlete_id),
  check (coach_id <> athlete_id)
);
create index coach_links_athlete_idx on public.coach_links (athlete_id);

alter table public.coach_links enable row level security;

-- Both sides can see and remove their links. Links are only created by connect_coach().
create policy "see own links" on public.coach_links for select to authenticated
  using (coach_id = (select auth.uid()) or athlete_id = (select auth.uid()));
create policy "remove own links" on public.coach_links for delete to authenticated
  using (coach_id = (select auth.uid()) or athlete_id = (select auth.uid()));

-- True when the signed-in user coaches this athlete.
create or replace function public.is_coach_of(athlete uuid)
returns boolean
language sql
stable
security invoker
set search_path = ''
as $$
  select exists (
    select 1 from public.coach_links l
    where l.coach_id = (select auth.uid()) and l.athlete_id = athlete
  );
$$;

-- True when the signed-in user and this user are linked either way.
create or replace function public.is_linked(other uuid)
returns boolean
language sql
stable
security invoker
set search_path = ''
as $$
  select exists (
    select 1 from public.coach_links l
    where (l.coach_id = (select auth.uid()) and l.athlete_id = other)
       or (l.athlete_id = (select auth.uid()) and l.coach_id = other)
  );
$$;

-- ---------- what a linked coach can read ----------

create policy "linked profiles" on public.profiles for select to authenticated
  using (public.is_linked(id));

create policy "coach reads athlete snapshot" on public.app_snapshots for select to authenticated
  using (public.is_coach_of(user_id));

-- ---------- comments on workouts ----------

create table public.coach_comments (
  id uuid primary key default gen_random_uuid(),
  athlete_id uuid not null references auth.users(id) on delete cascade,
  author_id uuid not null references auth.users(id) on delete cascade,
  program_id text not null,
  workout_id text not null,
  body text not null check (char_length(btrim(body)) between 1 and 2000),
  created_at timestamptz not null default now(),
  read_at timestamptz
);
create index coach_comments_workout_idx on public.coach_comments (athlete_id, program_id, workout_id, created_at);
create index coach_comments_unread_idx on public.coach_comments (athlete_id) where read_at is null;

alter table public.coach_comments enable row level security;

-- The athlete and their coaches can read and write comments on the athlete's workouts.
create policy "read comments" on public.coach_comments for select to authenticated
  using (athlete_id = (select auth.uid()) or public.is_coach_of(athlete_id));
create policy "write comments" on public.coach_comments for insert to authenticated
  with check (
    author_id = (select auth.uid())
    and (athlete_id = (select auth.uid()) or public.is_coach_of(athlete_id))
    and read_at is null
  );
create policy "delete own comments" on public.coach_comments for delete to authenticated
  using (author_id = (select auth.uid()));
-- Only read_at can change, and only on comments someone else wrote.
create policy "mark comments read" on public.coach_comments for update to authenticated
  using ((athlete_id = (select auth.uid()) or public.is_coach_of(athlete_id)) and author_id <> (select auth.uid()))
  with check ((athlete_id = (select auth.uid()) or public.is_coach_of(athlete_id)) and author_id <> (select auth.uid()));
revoke update on public.coach_comments from anon, authenticated;
grant update (read_at) on public.coach_comments to authenticated;

-- ---------- programs sent by a coach ----------

create table public.program_assignments (
  id uuid primary key default gen_random_uuid(),
  coach_id uuid not null references auth.users(id) on delete cascade,
  athlete_id uuid not null references auth.users(id) on delete cascade,
  program jsonb not null,
  note text not null default '' check (char_length(note) <= 2000),
  status text not null default 'sent' check (status in ('sent', 'accepted', 'declined')),
  created_at timestamptz not null default now(),
  responded_at timestamptz
);
create index program_assignments_athlete_idx on public.program_assignments (athlete_id, status);
create index program_assignments_coach_idx on public.program_assignments (coach_id);

alter table public.program_assignments enable row level security;

create policy "see own assignments" on public.program_assignments for select to authenticated
  using (coach_id = (select auth.uid()) or athlete_id = (select auth.uid()));
create policy "coach sends to linked athlete" on public.program_assignments for insert to authenticated
  with check (coach_id = (select auth.uid()) and public.is_coach_of(athlete_id) and status = 'sent' and responded_at is null);
create policy "coach withdraws unanswered" on public.program_assignments for delete to authenticated
  using (coach_id = (select auth.uid()) and status = 'sent');
-- The athlete answers; only status and responded_at can change.
create policy "athlete answers" on public.program_assignments for update to authenticated
  using (athlete_id = (select auth.uid()))
  with check (athlete_id = (select auth.uid()) and status in ('accepted', 'declined'));
revoke update on public.program_assignments from anon, authenticated;
grant update (status, responded_at) on public.program_assignments to authenticated;

-- ---------- functions the app calls ----------

-- Turns on coaching and returns the coach code (made once, then kept).
create or replace function public.enable_coaching()
returns text
language plpgsql
security invoker
set search_path = ''
as $$
declare
  uid uuid := auth.uid();
  alphabet constant text := 'ABCDEFGHJKLMNPQRSTUVWXYZ23456789';
  new_code text;
  existing text;
  i int;
begin
  if uid is null then
    raise exception 'Sign in first';
  end if;
  insert into public.profiles (id) values (uid) on conflict (id) do nothing;
  select coach_code into existing from public.profiles where id = uid;
  if existing is not null then
    update public.profiles set is_coach = true where id = uid;
    return existing;
  end if;
  loop
    new_code := '';
    for i in 1..6 loop
      new_code := new_code || substr(alphabet, 1 + floor(random() * length(alphabet))::int, 1);
    end loop;
    begin
      update public.profiles set is_coach = true, coach_code = new_code where id = uid;
      return new_code;
    exception when unique_violation then
      -- someone already has this code; try another
    end;
  end loop;
end;
$$;

-- Links the signed-in athlete to the coach who owns this code. Returns the link id.
create or replace function public.connect_coach(code text)
returns uuid
language plpgsql
security definer
set search_path = ''
as $$
declare
  uid uuid := auth.uid();
  coach uuid;
  link uuid;
begin
  if uid is null then
    raise exception 'Sign in first';
  end if;
  select p.id into coach from public.profiles p
  where p.coach_code = upper(btrim(code)) and p.is_coach;
  if coach is null then
    raise exception using errcode = 'P0002', message = 'No coach has that code';
  end if;
  if coach = uid then
    raise exception using errcode = '22023', message = 'That is your own coach code';
  end if;
  insert into public.coach_links (coach_id, athlete_id) values (coach, uid)
  on conflict (coach_id, athlete_id) do update set coach_id = excluded.coach_id
  returning id into link;
  return link;
end;
$$;

revoke execute on function public.enable_coaching() from public, anon;
revoke execute on function public.connect_coach(text) from public, anon;
grant execute on function public.enable_coaching() to authenticated;
grant execute on function public.connect_coach(text) to authenticated;

-- ---------- one row per link, with names (row level security applies) ----------

create view public.v_coach_links
with (security_invoker = true)
as
select
  l.id,
  l.coach_id,
  l.athlete_id,
  l.created_at,
  c.display_name as coach_name,
  a.display_name as athlete_name,
  a.sex as athlete_sex,
  a.division as athlete_division,
  a.weight_class as athlete_class,
  s.synced_at as athlete_synced_at
from public.coach_links l
left join public.profiles c on c.id = l.coach_id
left join public.profiles a on a.id = l.athlete_id
left join public.app_snapshots s on s.user_id = l.athlete_id;
