"""Download the two public source files into data/raw/.

- EV registrations: Washington State Department of Licensing, via data.wa.gov (f6w7-q2d2)
- County population: WA Office of Financial Management, April 1 estimates (nde6-xvwf)

Usage (from the project root):
    python src/get_data.py
"""
import csv
import json
import urllib.request
from pathlib import Path

ROOT = Path(__file__).resolve().parents[1]
RAW = ROOT / "data" / "raw"

EV_URL = "https://data.wa.gov/api/views/f6w7-q2d2/rows.csv?accessType=DOWNLOAD"
POP_URL = "https://data.wa.gov/resource/nde6-xvwf.json?$select=county_name,pop_2026&$limit=100"


def main() -> None:
    RAW.mkdir(parents=True, exist_ok=True)

    print("Downloading EV registrations (~70 MB)...")
    urllib.request.urlretrieve(EV_URL, RAW / "Electric_Vehicle_Population_Data.csv")

    print("Downloading county population...")
    with urllib.request.urlopen(POP_URL) as resp:
        rows = json.load(resp)
    with open(RAW / "wa_county_population_2026.csv", "w", newline="", encoding="utf-8") as f:
        writer = csv.writer(f)
        writer.writerow(["county", "population_2026"])
        for r in sorted(rows, key=lambda r: r["county_name"]):
            writer.writerow([r["county_name"], r["pop_2026"]])
    print(f"Saved to {RAW}")


if __name__ == "__main__":
    main()
