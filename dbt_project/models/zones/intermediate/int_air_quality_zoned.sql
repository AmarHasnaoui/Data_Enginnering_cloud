-- Join spatial : station qualité de l'air → arrondissement parisien (ST_CONTAINS).
-- Les stations hors Paris ne matchent aucune zone et sont naturellement exclues
-- (filtrées par l'INNER JOIN) — c'est attendu, elles restent visibles en points
-- individuels côté dashboard, pas agrégées par zone.
-- L'agrégation journalière (valeur_moyenne, valeur_max) est recalculée ici
-- directement depuis int_air_quality_idf (données horaires brutes).
{{
  config(materialized = 'table')
}}

SELECT
    z.arrondissement_code,
    z.nom_arrondissement,
    aq.date_mesure         AS date_jour,
    aq.code_site,
    aq.polluant,
    AVG(aq.valeur)         AS valeur_moyenne,
    MAX(aq.valeur)         AS valeur_max
FROM {{ ref('int_air_quality_idf') }} AS aq
JOIN {{ ref('stg_arrondissements') }} AS z
  ON ST_CONTAINS(z.geometry, ST_MAKEPOINT(aq.longitude, aq.latitude))
WHERE aq.valeur IS NOT NULL
GROUP BY z.arrondissement_code, z.nom_arrondissement,
         aq.date_mesure, aq.code_site, aq.polluant