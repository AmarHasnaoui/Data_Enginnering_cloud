-- Datamart : référentiel des stations (dernière version connue)
{{
  config(
    materialized = 'table'
  )
}}

SELECT DISTINCT
    code_site,
    MAX(nom_site)          AS nom_site,
    MAX(type_implantation) AS type_implantation,
    MAX(latitude)          AS latitude,
    MAX(longitude)         AS longitude,
    CURRENT_TIMESTAMP()    AS updated_at
FROM {{ ref('int_air_quality_idf') }}
WHERE code_site IS NOT NULL
GROUP BY code_site
