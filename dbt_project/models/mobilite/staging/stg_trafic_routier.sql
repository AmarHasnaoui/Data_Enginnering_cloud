{{
  config(materialized = 'view')
}}

SELECT
    iu_ac                                                             AS arc_id,
    libelle                                                           AS libelle_arc,
    TRY_TO_TIMESTAMP(t_1h, 'YYYY-MM-DDTHH24:MI:SS')                 AS comptage_datetime,
    DATE(TRY_TO_TIMESTAMP(t_1h, 'YYYY-MM-DDTHH24:MI:SS'))           AS date_jour,
    TRY_CAST(q AS FLOAT)                                             AS debit_horaire,
    TRY_CAST(k AS FLOAT)                                             AS taux_occupation,
    etat_trafic,
    iu_nd_amont                                                       AS noeud_amont_id,
    libelle_nd_amont,
    iu_nd_aval                                                        AS noeud_aval_id,
    libelle_nd_aval,
    etat_barre,
    SPLIT_PART(geo_point_2d, ',', 1)::FLOAT                         AS latitude,
    SPLIT_PART(geo_point_2d, ',', 2)::FLOAT                         AS longitude,
    _loaded_at,
    _file_name
FROM {{ source('bronze_mobilite', 'RAW_TRAFIC_ROUTIER') }}
WHERE t_1h IS NOT NULL
  AND iu_ac IS NOT NULL
