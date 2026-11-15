-- Meet Prep Log · sync function
-- Run this once in the Supabase dashboard: SQL Editor → New query → paste → Run.
-- (0001 and 0002 are already applied to the meet-prep-log project.)
--
-- The app sends its whole JSON (the same format as "Copy backup").
-- This stores the snapshot and rebuilds the lifter's rows for analysis, in one transaction.

create or replace function public.sync_snapshot(payload jsonb, app_version text default null)
returns timestamptz
language plpgsql
security invoker
set search_path = ''
as $$
declare
  uid uuid := auth.uid();
  ts timestamptz := now();
  pr jsonb := coalesce(payload -> 'profile', '{}'::jsonb);
  maxes jsonb := coalesce(pr -> 'maxes', '{}'::jsonb);
  p jsonb;
  w jsonb;
  e jsonb;
  x jsonb;
  t jsonb;
  b jsonb;
  i int;
begin
  if uid is null then
    raise exception 'Sign in before syncing';
  end if;

  insert into public.profiles as pf (id, display_name, sex, division, weight_class, height_cm,
    squat_max, bench_max, deadlift_max, goals, bw_target_low, bw_target_high, gym, active_program_id, updated_at)
  values (uid,
    coalesce(pr ->> 'name', ''),
    case when pr ->> 'sex' = 'female' then 'female' else 'male' end,
    case when pr ->> 'division' = 'equipped' then 'equipped' else 'classic' end,
    coalesce(nullif(pr ->> 'class', ''), '105'),
    public.try_numeric(pr ->> 'height'),
    public.try_numeric(maxes ->> 'squat'),
    public.try_numeric(maxes ->> 'bench'),
    public.try_numeric(maxes ->> 'deadlift'),
    coalesce(pr -> 'goals', '{}'::jsonb),
    public.try_numeric(pr -> 'bwTarget' ->> 0),
    public.try_numeric(pr -> 'bwTarget' ->> 1),
    coalesce(payload -> 'gym', '{}'::jsonb),
    payload ->> 'active',
    ts)
  on conflict (id) do update set
    display_name = excluded.display_name, sex = excluded.sex, division = excluded.division,
    weight_class = excluded.weight_class, height_cm = excluded.height_cm,
    squat_max = excluded.squat_max, bench_max = excluded.bench_max, deadlift_max = excluded.deadlift_max,
    goals = excluded.goals, bw_target_low = excluded.bw_target_low, bw_target_high = excluded.bw_target_high,
    gym = excluded.gym, active_program_id = excluded.active_program_id, updated_at = ts;

  insert into public.app_snapshots (user_id, data, app_version, synced_at)
  values (uid, payload, app_version, ts)
  on conflict (user_id) do update set data = excluded.data, app_version = excluded.app_version, synced_at = ts;

  -- Rebuild this lifter's analysis rows (workouts and sets cascade from programs).
  delete from public.programs where user_id = uid;
  delete from public.body_entries where user_id = uid;

  for p in select value from jsonb_array_elements(coalesce(payload -> 'programs', '[]'::jsonb)) loop
    insert into public.programs (user_id, id, template_id, name, level, weeks, start_date, is_active)
    values (uid, p ->> 'id', p ->> 'template', p ->> 'name', p ->> 'level',
      (public.try_numeric(p ->> 'weeks'))::int,
      case when p ->> 'start' ~ '^\d{4}-\d{2}-\d{2}$' then (p ->> 'start')::date end,
      (p ->> 'id') = (payload ->> 'active'))
    on conflict do nothing;

    for w in select value from jsonb_array_elements(coalesce(p -> 'workouts', '[]'::jsonb)) loop
      insert into public.workouts (user_id, program_id, id, week, title, workout_date, duration_min, completed, bodyweight_kg, notes)
      values (uid, p ->> 'id', w ->> 'id',
        (public.try_numeric(w ->> 'week'))::int,
        w ->> 'title',
        case when w ->> 'date' ~ '^\d{4}-\d{2}-\d{2}$' then (w ->> 'date')::date end,
        (public.try_numeric(w ->> 'dur'))::int,
        coalesce((w ->> 'done')::boolean, false),
        public.try_numeric(w ->> 'bw'),
        coalesce(w ->> 'notes', ''))
      on conflict do nothing;

      for e in select value from jsonb_array_elements(coalesce(w -> 'ex', '[]'::jsonb)) loop
        i := 0;
        for x in select value from jsonb_array_elements(coalesce(e -> 'log', '[]'::jsonb)) loop
          t := e -> 'plan' -> i;
          if coalesce(btrim(x ->> 'w'), '') <> '' or coalesce(btrim(x ->> 'r'), '') <> '' then
            insert into public.sets (user_id, program_id, workout_id, slot_id, set_index, exercise_def, exercise_name,
              lift, pct_of, label, target_kg, kg, reps_text, reps, rpe, result)
            values (uid, p ->> 'id', w ->> 'id', e ->> 'id', i + 1, e ->> 'def', e ->> 'name',
              case when e ->> 'lift' in ('squat', 'bench', 'deadlift') then e ->> 'lift' end,
              e ->> 'pctOf',
              t ->> 'label',
              case when t ? 'kg' then public.try_numeric(t ->> 'kg')
                   when t ? 'pct' and e ->> 'pctOf' is not null
                     then round(public.try_numeric(maxes ->> (e ->> 'pctOf')) * public.try_numeric(t ->> 'pct') / 2.5) * 2.5
              end,
              public.try_numeric(x ->> 'w'),
              x ->> 'r',
              case when btrim(x ->> 'r') ~ '^\d+$' then btrim(x ->> 'r')::int end,
              public.try_numeric(x ->> 'rpe'),
              case x ->> 's' when '1' then 'good' when '2' then 'missed' end)
            on conflict do nothing;
          end if;
          i := i + 1;
        end loop;
      end loop;
    end loop;
  end loop;

  for b in select value from jsonb_array_elements(coalesce(payload -> 'body', '[]'::jsonb)) loop
    if b ->> 'date' ~ '^\d{4}-\d{2}-\d{2}$' then
      insert into public.body_entries (user_id, entry_date, weight_kg, smm_kg, fat_mass_kg, pbf, water_l,
        visceral, bmr, inbody_score, waist_cm, note)
      values (uid, (b ->> 'date')::date, public.try_numeric(b ->> 'weight'), public.try_numeric(b ->> 'smm'),
        public.try_numeric(b ->> 'fat'), public.try_numeric(b ->> 'pbf'), public.try_numeric(b ->> 'water'),
        public.try_numeric(b ->> 'visceral'), public.try_numeric(b ->> 'bmr'), public.try_numeric(b ->> 'score'),
        public.try_numeric(b ->> 'waist'), b ->> 'note')
      on conflict do nothing;
    end if;
  end loop;

  return ts;
end;
$$;

revoke execute on function public.sync_snapshot(jsonb, text) from public, anon;
grant execute on function public.sync_snapshot(jsonb, text) to authenticated;
