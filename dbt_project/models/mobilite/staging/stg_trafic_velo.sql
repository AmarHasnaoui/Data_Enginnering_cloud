-- Dédup par jour : si la Lambda est relancée plusieurs fois pour la même date,
-- on ne garde que les lignes du dernier chargement (_loaded_at max) de ce jour.
{{
  config(materialized = 'view')
}}

WITH latest_load_per_day AS (
    SELECT
        DATE(TRY_TO_TIMESTAMP(date, 'YYYY-MM-DDTHH24:MI:SS')) AS day,
        MAX(_loaded_at) AS max_loaded_at
    FROM {{ source('bronze_mobilite', 'RAW_TRAFIC_VELO') }}
    WHERE date IS NOT NULL
    GROUP BY day
)

SELECT
    raw.compteur_id,
    raw.compteur_nom,
    raw.site_id,
    raw.name                                                      AS nom_site,
    TRY_CAST(raw.sum_counts AS INT)                               AS nb_passages,
    TRY_TO_TIMESTAMP(raw.date, 'YYYY-MM-DDTHH24:MI:SS')          AS date_comptage,
    DATE(TRY_TO_TIMESTAMP(raw.date, 'YYYY-MM-DDTHH24:MI:SS'))     AS date_jour,
    TRY_TO_DATE(raw.date_installation, 'YYYY-MM-DD')              AS date_installation,
    SPLIT_PART(raw.coordonnees_geographiques, ',', 1)::FLOAT      AS latitude,
    SPLIT_PART(raw.coordonnees_geographiques, ',', 2)::FLOAT      AS longitude,
    raw.mois_annee_comptage,
    raw._loaded_at,
    raw._file_name
FROM {{ source('bronze_mobilite', 'RAW_TRAFIC_VELO') }} AS raw
JOIN latest_load_per_day AS ll
  ON DATE(TRY_TO_TIMESTAMP(raw.date, 'YYYY-MM-DDTHH24:MI:SS')) = ll.day
 AND raw._loaded_at = ll.max_loaded_at
WHERE raw.date IS NOT NULL
  AND raw.compteur_id IS NOT NULL
