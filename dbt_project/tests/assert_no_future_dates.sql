-- Aucune date de mesure ne doit être dans le futur.
-- Signale un bug de parsing de date (ex : mauvais format TO_TIMESTAMP_NTZ) en amont.

SELECT 'int_air_quality_idf' AS source_model, date_mesure AS bad_date
FROM {{ ref('int_air_quality_idf') }}
WHERE date_mesure > CURRENT_DATE()

UNION ALL

SELECT 'int_velo_daily', date_jour
FROM {{ ref('int_velo_daily') }}
WHERE date_jour > CURRENT_DATE()

UNION ALL

SELECT 'int_trafic_daily', date_jour
FROM {{ ref('int_trafic_daily') }}
WHERE date_jour > CURRENT_DATE()