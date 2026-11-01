"""Run sql/clean.sql and export the Tableau-ready files to data/clean/.

Usage (from the project root, after get_data.py):
    python src/clean.py
"""
import os
from pathlib import Path

import duckdb

ROOT = Path(__file__).resolve().parents[1]
CLEAN = ROOT / "data" / "clean"


def main() -> None:
    os.chdir(ROOT)  # the SQL uses paths relative to the project root
    CLEAN.mkdir(parents=True, exist_ok=True)
    con = duckdb.connect()
    con.execute((ROOT / "sql" / "clean.sql").read_text(encoding="utf-8"))

    outputs = [
        ("ev", "wa_ev_registrations.csv"),        # one row per vehicle
        ("tableau_source", "wa_ev_tableau.csv"),  # aggregated source for the dashboard
        ("county_summary", "wa_ev_by_county.csv"),
    ]
    for table, filename in outputs:
        out = (CLEAN / filename).as_posix()
        con.execute(f"COPY (SELECT * FROM {table}) TO '{out}' (HEADER, DELIMITER ',')")
        rows = con.execute(f"SELECT COUNT(*) FROM {table}").fetchone()[0]
        print(f"{filename:<28}{rows:>10,} rows")

    unmatched = con.execute(
        "SELECT COUNT(*) FROM ev WHERE county_population IS NULL"
    ).fetchone()[0]
    print(f"Rows without a county population match: {unmatched}")


if __name__ == "__main__":
    main()
