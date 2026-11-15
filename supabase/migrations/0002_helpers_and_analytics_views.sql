-- Meet Prep Log · helpers and analysis views (already applied to the meet-prep-log project)

-- Text to number without failing on a typo ("102,5" works, "abc" becomes null).
create or replace function public.try_numeric(v text)
returns numeric
language plpgsql
immutable
set search_path = ''
as $$
begin
  if v is null or btrim(v) = '' then return null; end if;
  return replace(btrim(v), ',', '.')::numeric;
exception when others then
  return null;
end;
$$;

-- IPF GL points: total * 100 / (A - B * e^(-C * bodyweight)).
create or replace function public.gl_points(total numeric, bodyweight numeric, female boolean default false, equipped boolean default false)
returns numeric
language sql
immutable
set search_path = ''
as $$
  select case when total is null or bodyweight is null or total <= 0 or bodyweight <= 0 then null else
    round(total * 100 / (
      case when female and equipped then 758.63878 - 949.31382 * exp(-0.02435 * greatest(bodyweight, 40))
           when female then 610.32796 - 1045.59282 * exp(-0.03048 * greatest(bodyweight, 40))
           when equipped then 1236.25115 - 1449.21864 * exp(-0.01644 * greatest(bodyweight, 40))
           else 1199.72839 - 1025.18162 * exp(-0.00921 * greatest(bodyweight, 40)) end), 2)
  end;
$$;

-- Every logged set with its date and estimated 1RM (Epley + reps in reserve from RPE).
create view public.v_sets with (security_invoker = true) as
select
  s.*,
  w.workout_date,
  w.week,
  w.title as workout_title,
  w.bodyweight_kg,
  case
    when s.kg > 0 and s.reps between 1 and 12 and coalesce(s.result, 'good') <> 'missed' then
      case when s.reps + greatest(0, 10 - least(coalesce(s.rpe, 10), 10)) <= 1 then s.kg
           else round(s.kg * (1 + (s.reps + greatest(0, 10 - least(coalesce(s.rpe, 10), 10))) / 30.0), 1)
      end
  end as e1rm,
  case when s.kg > 0 and s.reps > 0 and coalesce(s.result, 'good') <> 'missed' then s.kg * s.reps end as volume_kg
from public.sets s
join public.workouts w
  on w.user_id = s.user_id and w.program_id = s.program_id and w.id = s.workout_id;

-- Weekly progress per competition lift: best e1RM, volume and set count.
create view public.v_weekly_lift_progress with (security_invoker = true) as
select
  user_id,
  lift,
  date_trunc('week', workout_date)::date as week_start,
  max(e1rm) as best_e1rm,
  sum(volume_kg) as volume_kg,
  count(*) as sets
from public.v_sets
where lift is not null and workout_date is not null
group by user_id, lift, date_trunc('week', workout_date);

-- One row per workout: duration, sets, volume, bodyweight, best e1RM per lift.
create view public.v_workout_summary with (security_invoker = true) as
select
  w.user_id, w.program_id, w.id as workout_id, w.workout_date, w.week, w.title,
  w.duration_min, w.completed, w.bodyweight_kg,
  count(s.set_index) as sets_logged,
  sum(s.volume_kg) as volume_kg,
  max(s.e1rm) filter (where s.lift = 'squat') as squat_e1rm,
  max(s.e1rm) filter (where s.lift = 'bench') as bench_e1rm,
  max(s.e1rm) filter (where s.lift = 'deadlift') as deadlift_e1rm
from public.workouts w
left join public.v_sets s
  on s.user_id = w.user_id and s.program_id = w.program_id and s.workout_id = w.id
group by w.user_id, w.program_id, w.id, w.workout_date, w.week, w.title, w.duration_min, w.completed, w.bodyweight_kg;

-- Where each lifter stands now: best e1RM per lift, estimated total and GL points at latest bodyweight.
create view public.v_lifter_standing with (security_invoker = true) as
with best as (
  select user_id,
    max(e1rm) filter (where lift = 'squat') as squat,
    max(e1rm) filter (where lift = 'bench') as bench,
    max(e1rm) filter (where lift = 'deadlift') as deadlift
  from public.v_sets group by user_id
), bw as (
  select distinct on (user_id) user_id, weight_kg, entry_date
  from public.body_entries where weight_kg is not null
  order by user_id, entry_date desc
)
select
  p.id as user_id, p.display_name, p.sex, p.division, p.weight_class,
  b.squat, b.bench, b.deadlift,
  b.squat + b.bench + b.deadlift as est_total,
  bw.weight_kg as latest_bodyweight,
  public.gl_points(b.squat + b.bench + b.deadlift, bw.weight_kg, p.sex = 'female', p.division = 'equipped') as gl_points
from public.profiles p
left join best b on b.user_id = p.id
left join bw on bw.user_id = p.id;
