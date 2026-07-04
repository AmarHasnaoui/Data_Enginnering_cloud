-- Référentiel des arrondissements parisiens : chargement one-shot, pas de Snowpipe.
-- Le GeoJSON source (FeatureCollection) n'est pas un array à la racine, donc
-- STRIP_OUTER_ARRAY ne s'applique pas : on charge le JSON entier dans une seule
-- ligne VARIANT, puis FLATTEN sur raw_geojson:features dans le staging dbt.
--
-- Mise à jour manuelle :
--   1. Télécharger https://opendata.paris.fr/api/explore/v2.1/catalog/datasets/arrondissements/exports/geojson
--   2. Uploader vers s3://s3-projet-efrei/bronze/zones_administratives/arrondissements_paris.geojson
--   3. Le COPY INTO ci-dessous se déclenche automatiquement au prochain run du pipeline DDL
--      (et ne rechargera pas le même fichier deux fois — historique de charge Snowflake)

USE DATABASE BRONZE;
USE SCHEMA ZONES_ADMINISTRATIVES;

CREATE TABLE IF NOT EXISTS RAW_ARRONDISSEMENTS_PARIS
(
    raw_geojson   VARIANT,
    _file_name    VARCHAR(500),
    _loaded_at    TIMESTAMP_NTZ DEFAULT CURRENT_TIMESTAMP()
);

CREATE STAGE IF NOT EXISTS stage_bronze_zones
  URL                 = 's3://s3-projet-efrei/bronze/zones_administratives/'
  STORAGE_INTEGRATION = s3_integration
  FILE_FORMAT         = (TYPE = JSON);

COPY INTO RAW_ARRONDISSEMENTS_PARIS (raw_geojson, _file_name)
FROM (
    SELECT $1, METADATA$FILENAME
    FROM @stage_bronze_zones
)
ON_ERROR = 'CONTINUE';
