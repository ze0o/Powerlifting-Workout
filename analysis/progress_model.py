"""
Meet Prep Log · progress analysis starter.

Reads every lifter's data from the Supabase Postgres database and:
  1. prints weekly best estimated 1RM per lifter and lift,
  2. fits a simple model that predicts a lifter's e1RM 4 weeks ahead,
  3. projects each lifter's next-4-week e1RM for squat, bench and deadlift.

Setup
  pip install pandas scikit-learn sqlalchemy "psycopg[binary]"
  export DATABASE_URL="postgresql+psycopg://postgres.<ref>:<password>@<host>:5432/postgres"
  (Supabase dashboard → Connect → Session pooler, then change "postgresql://" to "postgresql+psycopg://".)
  python analysis/progress_model.py

The connection uses the database owner role, which can read all lifters (row level
security only limits the app's users). Keep DATABASE_URL secret and out of the app.
"""
import os

import pandas as pd
from sklearn.ensemble import GradientBoostingRegressor
from sklearn.metrics import mean_absolute_error
from sklearn.model_selection import GroupKFold
from sqlalchemy import create_engine

HORIZON_WEEKS = 4

engine = create_engine(os.environ["DATABASE_URL"])

weekly = pd.read_sql(
    """
    select w.user_id, w.lift, w.week_start, w.best_e1rm, w.volume_kg, w.sets,
           p.sex, p.division, p.height_cm
    from public.v_weekly_lift_progress w
    join public.profiles p on p.id = w.user_id
    where w.best_e1rm is not null
    order by w.user_id, w.lift, w.week_start
    """,
    engine,
    parse_dates=["week_start"],
)
body = pd.read_sql(
    "select user_id, entry_date, weight_kg, pbf, smm_kg from public.body_entries where weight_kg is not null",
    engine,
    parse_dates=["entry_date"],
)

print(f"{weekly.user_id.nunique()} lifters, {len(weekly)} lifter-lift-weeks")
if weekly.empty:
    raise SystemExit("No logged competition lifts yet.")

# ---------- features ----------
# Weekly average bodyweight per lifter.
body["week_start"] = body.entry_date.dt.to_period("W-SUN").dt.start_time
bw = body.groupby(["user_id", "week_start"], as_index=False).agg(
    bodyweight=("weight_kg", "mean"), pbf=("pbf", "mean"), smm=("smm_kg", "mean")
)
df = weekly.merge(bw, on=["user_id", "week_start"], how="left").sort_values(["user_id", "lift", "week_start"])
g = df.groupby(["user_id", "lift"], group_keys=False)
df[["bodyweight", "pbf", "smm"]] = g[["bodyweight", "pbf", "smm"]].ffill()
df["weeks_in"] = g.cumcount()
df["e1rm_change_4w"] = df.best_e1rm - g.best_e1rm.shift(4)
df["volume_4w"] = g.volume_kg.transform(lambda s: s.rolling(4, min_periods=1).sum())
df["sets_4w"] = g.sets.transform(lambda s: s.rolling(4, min_periods=1).sum())
df["female"] = (df.sex == "female").astype(int)
df["equipped"] = (df.division == "equipped").astype(int)
df["lift_code"] = df.lift.map({"squat": 0, "bench": 1, "deadlift": 2})

# Target: best e1RM HORIZON_WEEKS later (matched by date, not by row, so gaps don't lie).
future = df[["user_id", "lift", "week_start", "best_e1rm"]].copy()
future["week_start"] = future.week_start - pd.Timedelta(weeks=HORIZON_WEEKS)
df = df.merge(future.rename(columns={"best_e1rm": "target"}), on=["user_id", "lift", "week_start"], how="left")

FEATURES = ["best_e1rm", "weeks_in", "e1rm_change_4w", "volume_4w", "sets_4w",
            "bodyweight", "pbf", "smm", "female", "equipped", "lift_code"]

train = df.dropna(subset=["target"]).copy()
train[FEATURES] = train[FEATURES].fillna(train[FEATURES].median(numeric_only=True))

# ---------- model ----------
if train.user_id.nunique() >= 5:
    model = GradientBoostingRegressor(random_state=0)
    folds = GroupKFold(n_splits=min(5, train.user_id.nunique()))
    errors = []
    for tr, te in folds.split(train, groups=train.user_id):
        model.fit(train.iloc[tr][FEATURES], train.iloc[tr].target)
        errors.append(mean_absolute_error(train.iloc[te].target, model.predict(train.iloc[te][FEATURES])))
    print(f"Cross-validated error (new lifters): ±{sum(errors) / len(errors):.1f} kg on the {HORIZON_WEEKS}-week e1RM")
    model.fit(train[FEATURES], train.target)
    latest = df.sort_values("week_start").groupby(["user_id", "lift"]).tail(1).copy()
    latest[FEATURES] = latest[FEATURES].fillna(train[FEATURES].median(numeric_only=True))
    latest["predicted_e1rm"] = model.predict(latest[FEATURES]).round(1)
else:
    # Too few lifters to learn across people: extend each lifter's own recent trend.
    print("Fewer than 5 lifters with enough history: using each lifter's own trend instead of a model.")
    rows = []
    for (uid, lift), s in df.groupby(["user_id", "lift"]):
        s = s.tail(6)
        weeks = (s.week_start - s.week_start.iloc[0]).dt.days / 7
        slope = 0.0 if len(s) < 2 or weeks.iloc[-1] == 0 else (s.best_e1rm.iloc[-1] - s.best_e1rm.iloc[0]) / weeks.iloc[-1]
        rows.append({"user_id": uid, "lift": lift, "best_e1rm": s.best_e1rm.iloc[-1],
                     "predicted_e1rm": round(s.best_e1rm.iloc[-1] + slope * HORIZON_WEEKS, 1)})
    latest = pd.DataFrame(rows)

print()
print(latest[["user_id", "lift", "best_e1rm", "predicted_e1rm"]].to_string(index=False))
