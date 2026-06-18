-- Dédup par jour : si la Lambda est relancée plusieurs fois pour la même date,
-- on ne garde que les lignes du dernier chargement (_loaded_at max) de ce jour.
{{
  config(materialized = 'view')
}}

WITH latest_load_per_day AS (
    SELECT
        DATE(t_1h) AS day,
        MAX(_loaded_at) AS max_loaded_at
    FROM {{ source('bronze_mobilite', 'RAW_TRAFIC_ROUTIER') }}
    WHERE t_1h IS NOT NULL
    GROUP BY day
)

SELECT
    raw.iu_ac                                                             AS arc_id,
    raw.libelle                                                           AS libelle_arc,
    TRY_TO_TIMESTAMP(raw.t_1h)                                           AS comptage_datetime,
    DATE(raw.t_1h)                                                       AS date_jour,
    TRY_CAST(raw.q AS FLOAT)                                             AS debit_horaire,
    TRY_CAST(raw.k AS FLOAT)                                             AS taux_occupation,
    raw.etat_trafic,
    raw.iu_nd_amont                                                       AS noeud_amont_id,
    raw.libelle_nd_amont,
    raw.iu_nd_aval                                                        AS noeud_aval_id,
    raw.libelle_nd_aval,
    raw.etat_barre,
    SPLIT_PART(raw.geo_point_2d, ',', 1)::FLOAT                         AS latitude,
    SPLIT_PART(raw.geo_point_2d, ',', 2)::FLOAT                         AS longitude,
    raw._loaded_at,
    raw._file_name
FROM {{ source('bronze_mobilite', 'RAW_TRAFIC_ROUTIER') }} AS raw
JOIN latest_load_per_day AS ll
  ON DATE(raw.t_1h) = ll.day
 AND raw._loaded_at = ll.max_loaded_at
WHERE raw.t_1h IS NOT NULL
  AND raw.iu_ac IS NOT NULL
