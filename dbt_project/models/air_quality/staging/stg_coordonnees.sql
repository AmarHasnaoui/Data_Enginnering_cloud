{{
  config(
    materialized = 'view'
  )
}}

SELECT
    code_site,
    TRY_CAST(latitude  AS FLOAT) AS latitude,
    TRY_CAST(longitude AS FLOAT) AS longitude,
    _loaded_at
FROM BRONZE.AIR_QUALITY.RAW_COORDONNEES
WHERE code_site IS NOT NULL
