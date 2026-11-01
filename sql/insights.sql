-- Headline numbers for the README and the dashboard's KPI tiles.
-- Run after clean.sql (python src/insights.py).

-- 1. Statewide totals
SELECT
    COUNT(*)                                                        AS total_evs,
    ROUND(100.0 * AVG(CASE WHEN ev_type = 'BEV' THEN 1 ELSE 0 END), 1) AS bev_share_pct,
    ROUND(1000.0 * COUNT(*) / (SELECT SUM(population_2026) FROM county_pop), 1) AS evs_per_1000_residents,
    COUNT(DISTINCT make)                                            AS makes,
    COUNT(DISTINCT model)                                           AS models
FROM ev;

-- 2. Registrations by model year and type (model years 2011+)
SELECT model_year, ev_type, COUNT(*) AS evs
FROM ev
WHERE model_year BETWEEN 2011 AND 2026
GROUP BY 1, 2
ORDER BY 1, 2;

-- 3. Top 10 makes with share of all EVs and running share
SELECT
    make,
    COUNT(*)                                                      AS evs,
    ROUND(100.0 * COUNT(*) / SUM(COUNT(*)) OVER (), 1)            AS share_pct,
    ROUND(100.0 * SUM(COUNT(*)) OVER (ORDER BY COUNT(*) DESC
          ROWS BETWEEN UNBOUNDED PRECEDING AND CURRENT ROW)
          / SUM(COUNT(*)) OVER (), 1)                             AS cumulative_pct
FROM ev
GROUP BY make
ORDER BY evs DESC
LIMIT 10;

-- 4. Top 10 models
SELECT make || ' ' || model AS vehicle, ev_type, COUNT(*) AS evs,
       ROUND(100.0 * COUNT(*) / SUM(COUNT(*)) OVER (), 1) AS share_pct
FROM ev
GROUP BY 1, 2
ORDER BY evs DESC
LIMIT 10;

-- 5. Tesla's share by model year: is the market diversifying?
SELECT model_year,
       COUNT(*) AS evs,
       ROUND(100.0 * AVG(CASE WHEN make = 'Tesla' THEN 1 ELSE 0 END), 1) AS tesla_share_pct,
       COUNT(DISTINCT make) AS makes
FROM ev
WHERE model_year BETWEEN 2015 AND 2026
GROUP BY 1
ORDER BY 1;

-- 6. West vs. east of the Cascades (per 1,000 residents)
WITH region AS (
    SELECT county, evs, population_2026,
           CASE WHEN county IN ('Clallam','Clark','Cowlitz','Grays Harbor','Island','Jefferson','King',
                                'Kitsap','Lewis','Mason','Pacific','Pierce','San Juan','Skagit','Skamania',
                                'Snohomish','Thurston','Wahkiakum','Whatcom')
                THEN 'Western WA' ELSE 'Eastern WA' END AS region
    FROM county_summary
)
SELECT region, SUM(evs) AS evs, SUM(population_2026) AS population,
       ROUND(1000.0 * SUM(evs) / SUM(population_2026), 1) AS evs_per_1000
FROM region
GROUP BY region;
