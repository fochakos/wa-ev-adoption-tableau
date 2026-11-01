# Washington State EV Adoption Dashboard (Tableau)

An interactive Tableau dashboard of the **299,353 electric vehicles** registered in Washington State, built from official Department of Licensing records joined with state population estimates. It answers four questions: how many EVs there are, where adoption is highest per person, which brands lead, and how the fleet has grown by model year.

### [▶ Open the live dashboard on Tableau Public](https://public.tableau.com/app/profile/fred.ochako/viz/WashingtonEVAdoption2026/WashingtonEVAdoption)

[![Washington EV Adoption dashboard](https://public.tableau.com/static/images/Wa/WashingtonEVAdoption2026/WashingtonEVAdoption/1.png)](https://public.tableau.com/app/profile/fred.ochako/viz/WashingtonEVAdoption2026/WashingtonEVAdoption)

## Key findings

1. **Washington has 36.6 EVs per 1,000 residents,** and **81%** of them are fully electric rather than plug-in hybrids.
2. **Adoption splits along the Cascades.** Western Washington has **42.6 EVs per 1,000 residents**; Eastern Washington has **14.7**, about a third of the rate.
3. **Per person, the leader isn't King County.** **San Juan County** (74.4 per 1,000) is ahead of King (59.4) and Jefferson (49.1). Garfield County is lowest at 3.5. Raw counts would hide this: King alone holds 48% of all EVs.
4. **Tesla dominates, but its share is falling.** Tesla is **41%** of all EVs, and the Model Y alone is 22%. Among model years 2020–2025, Tesla's share fell from 56% to 26% as the number of brands roughly doubled (20 → 39).
5. **Model year 2023 is the peak,** with 61,000 vehicles still registered. The plug-in hybrid share rose in 2024 (22% vs. 12% in 2023).

## What the dashboard shows

| Element | What it shows | Tableau technique |
|---|---|---|
| Headline tiles | Total EVs, EVs per 1,000 residents, fully electric share | Calculated fields, custom number formats |
| County map | EVs per 1,000 residents, with counts in the tooltip | Filled map, **level-of-detail (LOD) expression** |
| Top 10 makes | Registered vehicles by brand | Top-N filter, sorted bars |
| By model year | Fully electric vs. plug-in hybrid, 2011–2026 | Stacked bars, discrete date dimension |

**Per-capita calculation.** The Tableau source has one row per county × model year × make × model, so population repeats on many rows. A plain `SUM` would count it many times. The LOD expression takes each county's population once:

```
SUM([Vehicles]) / SUM({FIXED [County] : MIN([County Population])}) * 1000
```

This gives the correct rate for a single county on the map and for the whole state in the headline tile (36.6).

## Data

| Source | What | License |
|---|---|---|
| [Electric Vehicle Population Data](https://data.wa.gov/Transportation/Electric-Vehicle-Population-Data/f6w7-q2d2), WA Department of Licensing | One row per registered BEV/PHEV, as of 30 Sept 2026 (300,142 rows) | ODbL |
| [April 1 Population by County](https://data.wa.gov/d/nde6-xvwf), WA Office of Financial Management | 2026 population estimate for each of the 39 counties | data.wa.gov open data |

## Cleaning and modeling (SQL)

All cleaning is in [`sql/clean.sql`](sql/clean.sql), run with DuckDB:

| Issue found | Fix |
|---|---|
| 0.3% of records are owners living outside Washington | Kept WA registrations only (299,353) |
| Electric range is recorded as **0** when it hasn't been researched (most BEVs from model year 2021 onward, 66% of rows) | Converted to missing, so averages aren't dragged to zero; range is left off the dashboard |
| Population file lists Pierce County as `Pierce?` (a footnote marker), so Pierce initially failed to join (25,169 vehicles) | Stripped non-letter characters before joining; all rows now match |
| Location stored as text, e.g. `POINT (-122.37 47.74)` | Parsed into numeric latitude and longitude |
| Overlapping utility territories listed in one field (`A|B||C`) | Kept the first listed utility, and noted it isn't reliable for analysis |
| Long eligibility labels | Mapped to short categories |

The SQL writes three files to `data/clean/`:
- `wa_ev_tableau.csv`: 12,687 rows aggregated for Tableau (vehicle totals match the row-level data exactly).
- `wa_ev_by_county.csv`: one row per county with per-capita rates.
- `wa_ev_registrations.csv`: the full row-level table (not committed because of its size).

Headline numbers are reproduced in SQL in [`sql/insights.sql`](sql/insights.sql), so the dashboard can be checked against an independent calculation.

## How to reproduce

```bash
pip install duckdb pandas
python src/get_data.py    # downloads both sources into data/raw/
python src/clean.py       # writes data/clean/*.csv
python src/insights.py    # prints the headline numbers
```

Then connect Tableau (Public or Desktop) to `data/clean/wa_ev_tableau.csv`, or open the live workbook above and download it.

## Limitations

- **A snapshot, not sales history.** The data lists vehicles registered today. "Model year" counts surviving vehicles, so older years are understated (cars scrapped or moved out of state), and the 2026 model year is still in progress.
- **Where the owner lives, not where the car is driven.** Locations are ZIP-code centres of the registered owner's address.
- **No income or charger data,** so the east–west gap is described but not explained. Joining household income and public charging stations by county would be the next step.

## Project structure

```
├── sql/
│   ├── clean.sql        # cleaning, joins and the Tableau source
│   └── insights.sql     # headline numbers, checked against the dashboard
├── src/
│   ├── get_data.py      # downloads both sources
│   ├── clean.py         # runs clean.sql, writes data/clean/
│   └── insights.py      # prints the insight queries
└── data/
    ├── raw/             # downloaded sources (not committed)
    └── clean/           # Tableau-ready files
```

## Tools

Tableau Public · SQL (DuckDB) · Python
