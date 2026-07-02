-- Join spatial : tronçon de voirie → arrondissement parisien (ST_CONTAINS).
{{
  config(materialized = 'table')
}}

SELECT
    z.arrondissement_code,
    z.nom_arrondissement,
    t.date_jour,
    t.arc_id,
    t.debit_moyen,
    t.taux_occupation_moyen,
    t.nb_heures_bloque
FROM {{ ref('int_trafic_daily') }} AS t
JOIN {{ ref('stg_arrondissements') }} AS z
  ON ST_CONTAINS(z.geometry, ST_MAKEPOINT(t.longitude, t.latitude))
