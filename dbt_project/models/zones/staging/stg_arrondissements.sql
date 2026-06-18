-- Flatten du GeoJSON FeatureCollection : une ligne par arrondissement.
-- Matérialisé en table (pas view) : référentiel statique, pas besoin de
-- reparser la géométrie à chaque requête.
{{
  config(materialized = 'table')
}}

SELECT
    feature.value:properties:c_ar::INT           AS arrondissement_code,
    feature.value:properties:c_arinsee::VARCHAR  AS code_insee,
    feature.value:properties:l_aroff::VARCHAR    AS nom_arrondissement,
    feature.value:properties:surface::FLOAT      AS surface_m2,
    feature.value:properties:geom_x_y:lat::FLOAT AS centroid_lat,
    feature.value:properties:geom_x_y:lon::FLOAT AS centroid_lon,
    TO_GEOGRAPHY(feature.value:geometry)          AS geometry
FROM {{ source('bronze_zones', 'RAW_ARRONDISSEMENTS_PARIS') }},
LATERAL FLATTEN(input => raw_geojson:features) AS feature
