-- La somme des heures par état de trafic ne peut pas dépasser 24h dans une journée.
-- Une ligne retournée signale un bug de classification etat_trafic ou d'agrégation.
SELECT
    arc_id,
    date_jour,
    nb_heures_bloque + nb_heures_sature + nb_heures_dense + nb_heures_fluide AS total_heures_classees
FROM {{ ref('dm_trafic_routier_daily') }}
WHERE nb_heures_bloque + nb_heures_sature + nb_heures_dense + nb_heures_fluide > 24
