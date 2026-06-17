{{
  config(materialized = 'table')
}}

SELECT
    arc_id,
    libelle_arc,
    date_jour,
    latitude,
    longitude,
    AVG(debit_horaire)                                              AS debit_moyen,
    MAX(debit_horaire)                                              AS debit_max,
    AVG(taux_occupation)                                            AS taux_occupation_moyen,
    SUM(CASE WHEN etat_trafic = 'Bloqué'    THEN 1 ELSE 0 END)    AS nb_heures_bloque,
    SUM(CASE WHEN etat_trafic = 'Saturé'    THEN 1 ELSE 0 END)    AS nb_heures_sature,
    SUM(CASE WHEN etat_trafic = 'Dense'     THEN 1 ELSE 0 END)    AS nb_heures_dense,
    SUM(CASE WHEN etat_trafic = 'Fluide'    THEN 1 ELSE 0 END)    AS nb_heures_fluide,
    COUNT(*)                                                        AS nb_mesures
FROM {{ ref('stg_trafic_routier') }}
WHERE comptage_datetime IS NOT NULL
GROUP BY arc_id, libelle_arc, date_jour, latitude, longitude
