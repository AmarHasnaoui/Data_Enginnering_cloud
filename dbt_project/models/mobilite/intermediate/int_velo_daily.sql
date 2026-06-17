{{
  config(materialized = 'table')
}}

SELECT
    compteur_id,
    compteur_nom,
    site_id,
    nom_site,
    date_jour,
    latitude,
    longitude,
    SUM(nb_passages)    AS total_passages_jour,
    COUNT(*)            AS nb_mesures_horaires,
    MAX(nb_passages)    AS pic_horaire
FROM {{ ref('stg_trafic_velo') }}
WHERE nb_passages IS NOT NULL
GROUP BY compteur_id, compteur_nom, site_id, nom_site, date_jour, latitude, longitude
