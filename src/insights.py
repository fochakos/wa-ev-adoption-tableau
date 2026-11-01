"""Rebuild the clean tables and print the headline queries in sql/insights.sql.

Usage (from the project root):
    python src/insights.py
"""
import os
import re
from pathlib import Path

import duckdb

ROOT = Path(__file__).resolve().parents[1]


def main() -> None:
    os.chdir(ROOT)
    con = duckdb.connect()
    con.execute((ROOT / "sql" / "clean.sql").read_text(encoding="utf-8"))
    sql = (ROOT / "sql" / "insights.sql").read_text(encoding="utf-8")
    # Each query starts with a numbered comment such as "-- 1. Statewide totals"
    parts = re.split(r"^-- (\d+\..*)$", sql, flags=re.MULTILINE)
    for title, query in zip(parts[1::2], parts[2::2]):
        print(f"\n=== {title.strip()} ===")
        print(con.execute(query).df().to_string(index=False))


if __name__ == "__main__":
    main()
