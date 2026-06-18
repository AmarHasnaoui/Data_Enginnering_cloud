-- Join spatial : station qualité de l'air → arrondissement parisien (ST_CONTAINS).
-- Les stations hors Paris ne matchent aucune zone et sont naturellement exclues
-- (filtrées par l'INNER JOIN) — c'est attendu, elles restent visibles en points
-- individuels côté dashboard, pas agrégées par zone.
{{
  config(materialized = 'table')
}}

SELECT
    z.arrondissement_code,
    z.nom_arrondissement,
    aq.date_mesure AS date_jour,
    aq.code_site,
    aq.polluant,
    aq.valeur_moyenne,
    aq.valeur_max
FROM {{ ref('dm_air_quality_daily') }} AS aq
JOIN {{ ref('stg_arrondissements') }} AS z
  ON ST_CONTAINS(z.geometry, ST_MAKEPOINT(aq.longitude, aq.latitude))
