-- KPI journalier par arrondissement : croise qualité de l'air, trafic routier
-- et trafic vélo (compteurs) pour comparer les zones entre elles.
-- ratio_mobilite_verte : part du vélo dans le total vélo + véhicules routiers
-- (proxy de mobilité douce, pas de l'usage Vélib réel — voir note dans int_velo_zoned).
{{
  config(
    materialized     = 'incremental',
    unique_key       = ['arrondissement_code', 'date_jour'],
    on_schema_change = 'sync_all_columns'
  )
}}

WITH air AS (
    SELECT
        arrondissement_code,
        date_jour,
        AVG(CASE WHEN polluant = 'NO2'   THEN valeur_moyenne END) AS no2_moyen,
        AVG(CASE WHEN polluant = 'PM10'  THEN valeur_moyenne END) AS pm10_moyen,
        AVG(CASE WHEN polluant = 'PM2.5' THEN valeur_moyenne END) AS pm25_moyen,
        AVG(valeur_moyenne)                                       AS pollution_indice_moyen
    FROM {{ ref('int_air_quality_zoned') }}
    {% if is_incremental() %}
    WHERE date_jour > (SELECT MAX(date_jour) FROM {{ this }})
    {% endif %}
    GROUP BY arrondissement_code, date_jour
),

trafic AS (
    SELECT
        arrondissement_code,
        date_jour,
        AVG(debit_moyen)           AS debit_routier_moyen,
        AVG(taux_occupation_moyen) AS taux_occupation_moyen,
        SUM(nb_heures_bloque)      AS total_heures_bloque
    FROM {{ ref('int_trafic_zoned') }}
    {% if is_incremental() %}
    WHERE date_jour > (SELECT MAX(date_jour) FROM {{ this }})
    {% endif %}
    GROUP BY arrondissement_code, date_jour
),

velo AS (
    SELECT
        arrondissement_code,
        date_jour,
        SUM(total_passages_jour)    AS total_velos,
        COUNT(DISTINCT compteur_id) AS nb_compteurs_actifs
    FROM {{ ref('int_velo_zoned') }}
    {% if is_incremental() %}
    WHERE date_jour > (SELECT MAX(date_jour) FROM {{ this }})
    {% endif %}
    GROUP BY arrondissement_code, date_jour
),

spine AS (
    SELECT arrondissement_code, date_jour FROM air
    UNION
    SELECT arrondissement_code, date_jour FROM trafic
    UNION
    SELECT arrondissement_code, date_jour FROM velo
)

SELECT
    s.arrondissement_code,
    z.nom_arrondissement,
    s.date_jour,
    air.no2_moyen,
    air.pm10_moyen,
    air.pm25_moyen,
    air.pollution_indice_moyen,
    trafic.debit_routier_moyen,
    trafic.taux_occupation_moyen,
    trafic.total_heures_bloque,
    velo.total_velos,
    velo.nb_compteurs_actifs,
    CASE
        WHEN (COALESCE(velo.total_velos, 0) + COALESCE(trafic.debit_routier_moyen, 0)) > 0
        THEN COALESCE(velo.total_velos, 0)
             / (COALESCE(velo.total_velos, 0) + COALESCE(trafic.debit_routier_moyen, 0))
        ELSE NULL
    END AS ratio_mobilite_verte,
    CURRENT_TIMESTAMP() AS updated_at
FROM spine AS s
LEFT JOIN {{ ref('stg_arrondissements') }} AS z ON s.arrondissement_code = z.arrondissement_code
LEFT JOIN air    ON s.arrondissement_code = air.arrondissement_code    AND s.date_jour = air.date_jour
LEFT JOIN trafic ON s.arrondissement_code = trafic.arrondissement_code AND s.date_jour = trafic.date_jour
LEFT JOIN velo   ON s.arrondissement_code = velo.arrondissement_code   AND s.date_jour = velo.date_jour
