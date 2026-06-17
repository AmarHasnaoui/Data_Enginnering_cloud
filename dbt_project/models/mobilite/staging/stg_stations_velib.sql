{{
  config(materialized = 'view')
}}

SELECT
    stationcode,
    name                                    AS nom_station,
    TRY_CAST(capacity AS INT)               AS capacite,
    TRY_CAST(coordonnees_geo_lat AS FLOAT)  AS latitude,
    TRY_CAST(coordonnees_geo_lon AS FLOAT)  AS longitude,
    nom_arrondissement_communes,
    code_insee_commune,
    _loaded_at
FROM {{ source('bronze_mobilite', 'RAW_STATIONS_VELIB') }}
WHERE stationcode IS NOT NULL
QUALIFY ROW_NUMBER() OVER (PARTITION BY stationcode ORDER BY _loaded_at DESC) = 1
