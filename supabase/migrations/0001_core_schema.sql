-- Meet Prep Log · core schema (already applied to the meet-prep-log project)
-- One row per lifter, program, workout, logged set and body entry.

create table public.profiles (
  id uuid primary key references auth.users(id) on delete cascade,
  display_name text not null default '',
  sex text not null default 'male' check (sex in ('male', 'female')),
  division text not null default 'classic' check (division in ('classic', 'equipped')),
  weight_class text not null default '105',
  height_cm numeric,
  squat_max numeric,
  bench_max numeric,
  deadlift_max numeric,
  goals jsonb not null default '{}'::jsonb,
  bw_target_low numeric,
  bw_target_high numeric,
  gym jsonb not null default '{}'::jsonb,
  active_program_id text,
  created_at timestamptz not null default now(),
  updated_at timestamptz not null default now()
);

-- Latest full copy of the app's data, used to restore on a new phone.
create table public.app_snapshots (
  user_id uuid primary key references auth.users(id) on delete cascade,
  data jsonb not null,
  app_version text,
  synced_at timestamptz not null default now()
);

create table public.programs (
  user_id uuid not null references auth.users(id) on delete cascade,
  id text not null,
  template_id text,
  name text,
  level text,
  weeks int,
  start_date date,
  is_active boolean not null default false,
  primary key (user_id, id)
);

create table public.workouts (
  user_id uuid not null,
  program_id text not null,
  id text not null,
  week int,
  title text,
  workout_date date,
  duration_min int,
  completed boolean not null default false,
  bodyweight_kg numeric,
  notes text,
  primary key (user_id, program_id, id),
  foreign key (user_id, program_id) references public.programs (user_id, id) on delete cascade
);
create index workouts_user_date_idx on public.workouts (user_id, workout_date);

create table public.sets (
  user_id uuid not null,
  program_id text not null,
  workout_id text not null,
  slot_id text not null,
  set_index int not null,
  exercise_def text,
  exercise_name text,
  lift text check (lift in ('squat', 'bench', 'deadlift')),
  pct_of text,
  label text,
  target_kg numeric,
  kg numeric,
  reps_text text,
  reps int,
  rpe numeric,
  result text check (result in ('good', 'missed')),
  primary key (user_id, program_id, workout_id, slot_id, set_index),
  foreign key (user_id, program_id, workout_id) references public.workouts (user_id, program_id, id) on delete cascade
);
create index sets_user_lift_idx on public.sets (user_id, lift);

create table public.body_entries (
  user_id uuid not null references auth.users(id) on delete cascade,
  entry_date date not null,
  weight_kg numeric,
  smm_kg numeric,
  fat_mass_kg numeric,
  pbf numeric,
  water_l numeric,
  visceral numeric,
  bmr numeric,
  inbody_score numeric,
  waist_cm numeric,
  note text,
  primary key (user_id, entry_date)
);

-- Row level security: every lifter can only see and change their own rows.
alter table public.profiles enable row level security;
alter table public.app_snapshots enable row level security;
alter table public.programs enable row level security;
alter table public.workouts enable row level security;
alter table public.sets enable row level security;
alter table public.body_entries enable row level security;

create policy "own profile" on public.profiles for all to authenticated
  using (id = (select auth.uid())) with check (id = (select auth.uid()));
create policy "own snapshot" on public.app_snapshots for all to authenticated
  using (user_id = (select auth.uid())) with check (user_id = (select auth.uid()));
create policy "own programs" on public.programs for all to authenticated
  using (user_id = (select auth.uid())) with check (user_id = (select auth.uid()));
create policy "own workouts" on public.workouts for all to authenticated
  using (user_id = (select auth.uid())) with check (user_id = (select auth.uid()));
create policy "own sets" on public.sets for all to authenticated
  using (user_id = (select auth.uid())) with check (user_id = (select auth.uid()));
create policy "own body entries" on public.body_entries for all to authenticated
  using (user_id = (select auth.uid())) with check (user_id = (select auth.uid()));

-- Create an empty profile when someone signs up.
create or replace function public.handle_new_user()
returns trigger
language plpgsql
security definer
set search_path = ''
as $$
begin
  insert into public.profiles (id, display_name)
  values (new.id, coalesce(new.raw_user_meta_data ->> 'name', ''))
  on conflict (id) do nothing;
  return new;
end;
$$;
revoke execute on function public.handle_new_user() from public, anon, authenticated;

create trigger on_auth_user_created
  after insert on auth.users
  for each row execute function public.handle_new_user();
