-- Meet Prep Log · competition standing (already applied to the meet-prep-log project)
-- Percentile cut points (p1..p99) from public competition results (OpenIPF / OpenPowerlifting, public domain).
-- Everyone can read them; only the project owner writes them (with analysis/build_standing.py).
create table public.competition_percentiles (
  sex text not null check (sex in ('male', 'female')),
  equipment text not null check (equipment in ('classic', 'equipped')),
  weight_class text not null,
  metric text not null check (metric in ('total', 'gl', 'dots', 'squat', 'bench', 'deadlift')),
  n int not null,
  p numeric[] not null,
  source text not null,
  built_at timestamptz not null default now(),
  primary key (sex, equipment, weight_class, metric)
);

alter table public.competition_percentiles enable row level security;

create policy "anyone can read percentiles" on public.competition_percentiles
  for select to anon, authenticated using (true);
