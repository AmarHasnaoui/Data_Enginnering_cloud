-- Join spatial : compteur vélo (trafic, pas Vélib) → arrondissement parisien (ST_CONTAINS).
{{
  config(materialized = 'table')
}}

SELECT
    z.arrondissement_code,
    z.nom_arrondissement,
    v.date_jour,
    v.compteur_id,
    v.total_passages_jour
FROM {{ ref('dm_velo_daily') }} AS v
JOIN {{ ref('stg_arrondissements') }} AS z
  ON ST_CONTAINS(z.geometry, ST_MAKEPOINT(v.longitude, v.latitude))
