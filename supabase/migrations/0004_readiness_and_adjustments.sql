-- Meet Prep Log · Phase 2 columns (already applied to the meet-prep-log project)
-- Readiness check, today's load scale and RPE-based adjustments, kept for analysis.

alter table public.workouts
  add column if not exists readiness_score int,
  add column if not exists sleep_hours numeric,
  add column if not exists energy int,
  add column if not exists soreness int,
  add column if not exists stress int,
  add column if not exists load_scale numeric not null default 1;

alter table public.programs
  add column if not exists adjustments jsonb not null default '[]'::jsonb;

create or replace view public.v_workout_summary with (security_invoker = true) as
select
  w.user_id, w.program_id, w.id as workout_id, w.workout_date, w.week, w.title,
  w.duration_min, w.completed, w.bodyweight_kg,
  count(s.set_index) as sets_logged,
  sum(s.volume_kg) as volume_kg,
  max(s.e1rm) filter (where s.lift = 'squat') as squat_e1rm,
  max(s.e1rm) filter (where s.lift = 'bench') as bench_e1rm,
  max(s.e1rm) filter (where s.lift = 'deadlift') as deadlift_e1rm,
  w.readiness_score, w.sleep_hours, w.energy, w.soreness, w.stress, w.load_scale,
  avg(s.rpe) filter (where s.lift is not null) as avg_main_rpe
from public.workouts w
left join public.v_sets s
  on s.user_id = w.user_id and s.program_id = w.program_id and s.workout_id = w.id
group by w.user_id, w.program_id, w.id, w.workout_date, w.week, w.title, w.duration_min, w.completed, w.bodyweight_kg,
  w.readiness_score, w.sleep_hours, w.energy, w.soreness, w.stress, w.load_scale;
