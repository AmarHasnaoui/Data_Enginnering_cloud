-- Référentiel enrichi des stations Vélib avec disponibilité moyenne journalière
{{
  config(
    materialized = 'incremental',
    unique_key   = ['stationcode', 'date_jour']
  )
}}

SELECT
    s.stationcode,
    s.nom_station,
    s.capacite,
    s.latitude,
    s.longitude,
    s.nom_arrondissement_communes,
    s.code_insee_commune,
    r.date_jour,
    AVG(r.velos_disponibles)    AS velos_dispo_moyen,
    AVG(r.places_disponibles)   AS places_dispo_moyen,
    AVG(r.velos_mecaniques)     AS velos_meca_moyen,
    AVG(r.velos_electriques)    AS velos_elec_moyen,
    COUNT(r.ts_mesure)          AS nb_releves,
    CURRENT_TIMESTAMP()         AS updated_at
FROM {{ ref('stg_stations_velib') }}  AS s
JOIN {{ ref('stg_velib_realtime') }}  AS r ON s.stationcode = r.station_id

{% if is_incremental() %}
WHERE r.date_jour > (SELECT MAX(date_jour) FROM {{ this }})
{% endif %}

GROUP BY s.stationcode, s.nom_station, s.capacite, s.latitude, s.longitude,
         s.nom_arrondissement_communes, s.code_insee_commune, r.date_jour
