-- KPI journalier Smart City : croisement qualité de l'air × trafic routier × vélo
-- Valide BC02 "transformer des données provenant de différentes sources"
{{
  config(
    materialized = 'incremental',
    unique_key   = 'date_jour'
  )
}}

WITH air AS (
    SELECT
        date_mesure                    AS date_jour,
        AVG(CASE WHEN polluant = 'NO2'   THEN valeur_moyenne END) AS no2_moyen,
        AVG(CASE WHEN polluant = 'PM10'  THEN valeur_moyenne END) AS pm10_moyen,
        AVG(CASE WHEN polluant = 'PM2.5' THEN valeur_moyenne END) AS pm25_moyen,
        AVG(CASE WHEN polluant = 'O3'    THEN valeur_moyenne END) AS o3_moyen
    FROM {{ ref('dm_air_quality_daily') }}

    {% if is_incremental() %}
    WHERE date_mesure > (SELECT COALESCE(MAX(date_jour), '1970-01-01') FROM {{ this }})
    {% endif %}

    GROUP BY date_mesure
),

alertes AS (
    SELECT
        date_mesure                      AS date_jour,
        COUNT(DISTINCT code_site)        AS nb_stations_alerte
    FROM {{ ref('dm_alertes_pollution') }}

    {% if is_incremental() %}
    WHERE date_mesure > (SELECT COALESCE(MAX(date_jour), '1970-01-01') FROM {{ this }})
    {% endif %}

    GROUP BY date_mesure
),

trafic AS (
    SELECT
        date_jour,
        AVG(debit_moyen)            AS debit_routier_moyen,
        AVG(taux_occupation_moyen)  AS taux_occupation_moyen,
        SUM(nb_heures_bloque)       AS total_heures_bloque,
        COUNT(DISTINCT arc_id)      AS nb_arcs_surveilles
    FROM {{ ref('dm_trafic_routier_daily') }}

    {% if is_incremental() %}
    WHERE date_jour > (SELECT COALESCE(MAX(date_jour), '1970-01-01') FROM {{ this }})
    {% endif %}

    GROUP BY date_jour
),

velo AS (
    SELECT
        date_jour,
        SUM(total_passages_jour)    AS total_velos,
        COUNT(DISTINCT compteur_id) AS nb_compteurs_actifs
    FROM {{ ref('dm_velo_daily') }}

    {% if is_incremental() %}
    WHERE date_jour > (SELECT COALESCE(MAX(date_jour), '1970-01-01') FROM {{ this }})
    {% endif %}

    GROUP BY date_jour
)

SELECT
    COALESCE(air.date_jour, trafic.date_jour, velo.date_jour) AS date_jour,
    air.no2_moyen,
    air.pm10_moyen,
    air.pm25_moyen,
    air.o3_moyen,
    alertes.nb_stations_alerte,
    trafic.debit_routier_moyen,
    trafic.taux_occupation_moyen,
    trafic.total_heures_bloque,
    trafic.nb_arcs_surveilles,
    velo.total_velos,
    velo.nb_compteurs_actifs,
    CURRENT_TIMESTAMP() AS updated_at
FROM air
LEFT JOIN alertes ON air.date_jour  = alertes.date_jour
LEFT JOIN trafic  ON air.date_jour  = trafic.date_jour
LEFT JOIN velo    ON air.date_jour  = velo.date_jour
