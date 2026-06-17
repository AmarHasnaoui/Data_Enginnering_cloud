{{
  config(materialized = 'view')
}}

SELECT
    station_id,
    TRY_TO_TIMESTAMP(timestamp_ingestion)   AS ts_mesure,
    DATE(TRY_TO_TIMESTAMP(timestamp_ingestion)) AS date_jour,
    TRY_CAST(num_bikes_available AS INT)    AS velos_disponibles,
    TRY_CAST(num_docks_available AS INT)    AS places_disponibles,
    TRY_CAST(mechanical AS INT)             AS velos_mecaniques,
    TRY_CAST(ebike AS INT)                  AS velos_electriques,
    nom_arrondissement_communes,
    _loaded_at
FROM {{ source('bronze_mobilite', 'RAW_VELIB_REALTIME') }}
WHERE station_id IS NOT NULL
  AND timestamp_ingestion IS NOT NULL
