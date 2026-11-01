-- Clean the WA EV registration data into one tidy table for Tableau.
-- Run from the project root with: python src/clean.py

CREATE OR REPLACE TABLE raw_ev AS
SELECT *
FROM read_csv('data/raw/Electric_Vehicle_Population_Data.csv',
              header = true, all_varchar = true, quote = '"', escape = '"');

CREATE OR REPLACE TABLE county_pop AS
SELECT
    -- The source marks one county with a footnote character ('Pierce?'): keep letters and spaces only
    TRIM(REGEXP_REPLACE(county, '[^A-Za-z ]', '', 'g')) AS county,
    CAST(population_2026 AS INTEGER)                    AS population_2026
FROM read_csv('data/raw/wa_county_population_2026.csv', header = true);

CREATE OR REPLACE TABLE ev AS
SELECT
    r."DOL Vehicle ID"                                       AS vehicle_id,
    r.County                                                 AS county,
    'Washington'                                             AS state,   -- lets Tableau geocode counties
    r.City                                                   AS city,
    r."Postal Code"                                          AS zip_code,
    CAST(r."Model Year" AS INTEGER)                          AS model_year,
    -- 'TESLA' -> 'Tesla'; keep short brand acronyms upper case
    CASE WHEN LENGTH(r.Make) <= 3 THEN r.Make
         ELSE UPPER(LEFT(r.Make, 1)) || LOWER(SUBSTR(r.Make, 2)) END AS make,
    r.Model                                                  AS model,
    CASE WHEN r."Electric Vehicle Type" LIKE 'Battery%' THEN 'BEV' ELSE 'PHEV' END AS ev_type,
    CASE r."Clean Alternative Fuel Vehicle (CAFV) Eligibility"
        WHEN 'Clean Alternative Fuel Vehicle Eligible'                       THEN 'Eligible'
        WHEN 'Not eligible due to low battery range'                         THEN 'Not eligible (low range)'
        ELSE 'Unknown (range not researched)'
    END                                                      AS cafv_eligibility,
    -- The state records 0 when range hasn't been researched (most BEVs from 2021 on): treat as missing
    NULLIF(TRY_CAST(r."Electric Range" AS INTEGER), 0)        AS electric_range_miles,
    TRY_CAST(r."Legislative District" AS INTEGER)            AS legislative_district,
    -- First listed utility; overlapping territories are separated by | or ||
    TRIM(SPLIT_PART(SPLIT_PART(r."Electric Utility", '||', 1), '|', 1)) AS electric_utility,
    -- 'POINT (-122.37 47.74)' -> longitude, latitude (centre of the ZIP code)
    TRY_CAST(REGEXP_EXTRACT(r."Vehicle Location", 'POINT \(([-0-9.]+) ', 1) AS DOUBLE) AS longitude,
    TRY_CAST(REGEXP_EXTRACT(r."Vehicle Location", ' ([-0-9.]+)\)', 1) AS DOUBLE)       AS latitude,
    p.population_2026                                        AS county_population
FROM raw_ev AS r
LEFT JOIN county_pop AS p
    ON p.county = r.County
WHERE r.State = 'WA'          -- 0.3% of records are owners living in other states
  AND r.County IS NOT NULL;


-- Tableau source: one row per county x model year x make x model x type, with a vehicle count.
-- About 10x smaller than the row-level file and enough for every chart on the dashboard.
CREATE OR REPLACE TABLE tableau_source AS
SELECT
    county,
    state,
    model_year,
    make,
    model,
    ev_type,
    cafv_eligibility,
    MIN(county_population) AS county_population,
    COUNT(*)               AS vehicles
FROM ev
GROUP BY county, state, model_year, make, model, ev_type, cafv_eligibility
ORDER BY county, model_year, make, model;


-- One row per county: the per-capita view the map uses.
CREATE OR REPLACE TABLE county_summary AS
SELECT
    county,
    COUNT(*)                                                    AS evs,
    MIN(county_population)                                      AS population_2026,
    ROUND(1000.0 * COUNT(*) / MIN(county_population), 1)        AS evs_per_1000_residents,
    ROUND(100.0 * AVG(CASE WHEN ev_type = 'BEV' THEN 1 ELSE 0 END), 1) AS bev_share_pct,
    ROUND(100.0 * AVG(CASE WHEN make = 'Tesla' THEN 1 ELSE 0 END), 1)  AS tesla_share_pct,
    ROUND(100.0 * AVG(CASE WHEN model_year >= 2024 THEN 1 ELSE 0 END), 1) AS model_year_2024_plus_pct
FROM ev
GROUP BY county
ORDER BY evs_per_1000_residents DESC;
