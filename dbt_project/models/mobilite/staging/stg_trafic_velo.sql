{{
  config(materialized = 'view')
}}

SELECT
    compteur_id,
    compteur_nom,
    site_id,
    name                                                      AS nom_site,
    TRY_CAST(sum_counts AS INT)                               AS nb_passages,
    TRY_TO_TIMESTAMP(date, 'YYYY-MM-DDTHH24:MI:SS')          AS date_comptage,
    DATE(TRY_TO_TIMESTAMP(date, 'YYYY-MM-DDTHH24:MI:SS'))     AS date_jour,
    TRY_TO_DATE(date_installation, 'YYYY-MM-DD')              AS date_installation,
    SPLIT_PART(coordonnees_geographiques, ',', 1)::FLOAT      AS latitude,
    SPLIT_PART(coordonnees_geographiques, ',', 2)::FLOAT      AS longitude,
    mois_annee_comptage,
    _loaded_at,
    _file_name
FROM {{ source('bronze_mobilite', 'RAW_TRAFIC_VELO') }}
WHERE date IS NOT NULL
  AND compteur_id IS NOT NULL
