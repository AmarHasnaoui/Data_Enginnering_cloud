-- Aucune date de mesure ne doit être dans le futur : signale un bug de
-- parsing de date (ex : mauvais format TO_TIMESTAMP_NTZ) en amont.
SELECT 'dm_air_quality_daily' AS source_model, date_mesure AS bad_date
FROM {{ ref('dm_air_quality_daily') }}
WHERE date_mesure > CURRENT_DATE()

UNION ALL

SELECT 'dm_velo_daily', date_jour
FROM {{ ref('dm_velo_daily') }}
WHERE date_jour > CURRENT_DATE()

UNION ALL

SELECT 'dm_trafic_routier_daily', date_jour
FROM {{ ref('dm_trafic_routier_daily') }}
WHERE date_jour > CURRENT_DATE()

UNION ALL

SELECT 'dm_smartcity_kpi_daily', date_jour
FROM {{ ref('dm_smartcity_kpi_daily') }}
WHERE date_jour > CURRENT_DATE()
