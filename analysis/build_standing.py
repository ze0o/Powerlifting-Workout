"""
Meet Prep Log · build the "where you stand" tables from real competition results.

Downloads the OpenIPF dataset (IPF-affiliated meets, public domain, from OpenPowerlifting),
keeps full-power (SBD) results from the last few years, and computes the 1st–99th percentile
of total, GL points, DOTS, squat, bench and deadlift for every sex × division × IPF weight class
(plus "all classes"). The rows are uploaded to the competition_percentiles table, which the app
reads to show "top X% of classic men −105 kg".

Setup (on your computer, not in the app)
  pip install pandas numpy sqlalchemy "psycopg[binary]" requests
  export DATABASE_URL="postgresql+psycopg://postgres.<ref>:<password>@<host>:5432/postgres"
  python analysis/build_standing.py               # last 3 years
  python analysis/build_standing.py --years 5     # or a wider window
  python analysis/build_standing.py --csv path/to/openipf.csv --dry-run   # use a local file, don't upload

Re-run it every few months to refresh the numbers. Keep DATABASE_URL secret.
"""
import argparse
import io
import os
import zipfile
from datetime import date, timedelta

import numpy as np
import pandas as pd

URL = "https://openpowerlifting.gitlab.io/opl-csv/files/openipf-latest.zip"
MEN = [59, 66, 74, 83, 93, 105, 120]
WOMEN = [47, 52, 57, 63, 69, 76, 84]
COLS = ["Name", "Sex", "Event", "Equipment", "BodyweightKg", "Best3SquatKg", "Best3BenchKg",
        "Best3DeadliftKg", "TotalKg", "Place", "Dots", "Goodlift", "Date"]
GL = {  # IPF GL coefficients (A, B, C)
    ("male", "classic"): (1199.72839, 1025.18162, 0.00921),
    ("male", "equipped"): (1236.25115, 1449.21864, 0.01644),
    ("female", "classic"): (610.32796, 1045.59282, 0.03048),
    ("female", "equipped"): (758.63878, 949.31382, 0.02435),
}


def load(csv_path: str | None) -> pd.DataFrame:
    if csv_path:
        return pd.read_csv(csv_path, usecols=lambda c: c in COLS, low_memory=False)
    import requests

    print(f"Downloading {URL} ...")
    r = requests.get(URL, timeout=600)
    r.raise_for_status()
    with zipfile.ZipFile(io.BytesIO(r.content)) as z:
        name = next(n for n in z.namelist() if n.endswith(".csv"))
        with z.open(name) as f:
            return pd.read_csv(f, usecols=lambda c: c in COLS, low_memory=False)


def ipf_class(bw: float, female: bool) -> str:
    limits = WOMEN if female else MEN
    for lim in limits:
        if bw <= lim:
            return str(lim)
    return f"{limits[-1]}+"


def build(df: pd.DataFrame, years: int) -> tuple[pd.DataFrame, str]:
    since = (date.today() - timedelta(days=365 * years)).isoformat()
    df = df[(df.Event == "SBD") & df.Sex.isin(["M", "F"]) & df.Equipment.isin(["Raw", "Single-ply"])]
    df = df[pd.to_numeric(df.Place, errors="coerce").notna()]  # drop DQ, DD, NS, guest lifters
    df = df[(df.Date >= since) & (df.TotalKg > 0) & (df.BodyweightKg > 0)].copy()
    df["sex"] = np.where(df.Sex == "F", "female", "male")
    df["equipment"] = np.where(df.Equipment == "Raw", "classic", "equipped")
    df["weight_class"] = [ipf_class(b, s == "female") for b, s in zip(df.BodyweightKg, df.sex)]
    if "Goodlift" not in df or df.Goodlift.isna().all():
        df["Goodlift"] = np.nan
    missing = df.Goodlift.isna()
    if missing.any():
        a = df.loc[missing].apply(lambda r: GL[(r.sex, r.equipment)], axis=1, result_type="expand")
        df.loc[missing, "Goodlift"] = df.loc[missing, "TotalKg"] * 100 / (a[0] - a[1] * np.exp(-a[2] * df.loc[missing, "BodyweightKg"]))
    metrics = {"total": "TotalKg", "gl": "Goodlift", "dots": "Dots", "squat": "Best3SquatKg",
               "bench": "Best3BenchKg", "deadlift": "Best3DeadliftKg"}
    source = f"OpenIPF results since {since} (openpowerlifting.org, public domain)"
    rows = []
    for (sex, eq), g in df.groupby(["sex", "equipment"]):
        for cls in ["all", *sorted(g.weight_class.unique(), key=lambda c: (c.endswith("+"), float(c.rstrip("+"))))]:
            part = g if cls == "all" else g[g.weight_class == cls]
            for metric, col in metrics.items():
                if col not in part:
                    continue
                # One value per lifter (their best), so frequent competitors don't dominate.
                best = part[part[col] > 0].groupby("Name")[col].max().dropna()
                if len(best) < 50:
                    continue
                cuts = np.percentile(best.values, np.arange(1, 100)).round(2).tolist()
                rows.append({"sex": sex, "equipment": eq, "weight_class": cls, "metric": metric,
                             "n": int(len(best)), "p": cuts, "source": source})
    return pd.DataFrame(rows), source


def upload(rows: pd.DataFrame) -> None:
    from sqlalchemy import create_engine, text

    engine = create_engine(os.environ["DATABASE_URL"])
    sql = text("""
        insert into public.competition_percentiles (sex, equipment, weight_class, metric, n, p, source, built_at)
        values (:sex, :equipment, :weight_class, :metric, :n, :p, :source, now())
        on conflict (sex, equipment, weight_class, metric)
        do update set n = excluded.n, p = excluded.p, source = excluded.source, built_at = now()
    """)
    with engine.begin() as con:
        con.execute(sql, rows.to_dict("records"))
    print(f"Uploaded {len(rows)} rows to competition_percentiles.")


def main() -> None:
    ap = argparse.ArgumentParser()
    ap.add_argument("--years", type=int, default=3)
    ap.add_argument("--csv", help="use a local OpenIPF CSV instead of downloading")
    ap.add_argument("--dry-run", action="store_true", help="print a summary, don't upload")
    args = ap.parse_args()

    rows, source = build(load(args.csv), args.years)
    if rows.empty:
        raise SystemExit("No rows built. Check the data file.")
    print(source)
    show = rows[(rows.metric == "gl")][["sex", "equipment", "weight_class", "n"]].copy()
    show["median_gl"] = rows[rows.metric == "gl"].p.map(lambda p: p[49])
    print(show.to_string(index=False))
    if not args.dry_run:
        upload(rows)


if __name__ == "__main__":
    main()
