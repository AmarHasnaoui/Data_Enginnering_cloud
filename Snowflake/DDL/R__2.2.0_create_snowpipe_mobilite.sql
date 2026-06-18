USE DATABASE BRONZE;
USE SCHEMA MOBILITE;

-- Snowpipe trafic vélo (CSV)
CREATE OR REPLACE PIPE PIPE_TRAFIC_VELO
  AUTO_INGEST = TRUE
AS
COPY INTO BRONZE.MOBILITE.RAW_TRAFIC_VELO
(
    compteur_id, compteur_nom, site_id, name, sum_counts, date, date_installation,
    lien_photo_site, coordonnees_geographiques, counter, photos, test_lien_vers_photo,
    id_photo_1, url_sites, type_image, mois_annee_comptage, _file_name
)
FROM (
    SELECT
        $1::VARCHAR, $2::VARCHAR, $3::VARCHAR, $4::VARCHAR, $5::VARCHAR,
        $6::VARCHAR, $7::VARCHAR, $8::VARCHAR, $9::VARCHAR, $10::VARCHAR,
        $11::VARCHAR, $12::VARCHAR, $13::VARCHAR, $14::VARCHAR, $15::VARCHAR,
        $16::VARCHAR,
        METADATA$FILENAME
    FROM @BRONZE.MOBILITE.stage_bronze_mobilite/velo_counts/
)
FILE_FORMAT = (FORMAT_NAME = BRONZE.MOBILITE.my_csv_format)
ON_ERROR    = 'CONTINUE';

-- Snowpipe trafic routier (CSV)
CREATE OR REPLACE PIPE PIPE_TRAFIC_ROUTIER
  AUTO_INGEST = TRUE
AS
COPY INTO BRONZE.MOBILITE.RAW_TRAFIC_ROUTIER
(
    iu_ac, libelle, t_1h, k, q, etat_trafic, iu_nd_amont, libelle_nd_amont,
    iu_nd_aval, libelle_nd_aval, etat_barre, date_debut, date_fin,
    geo_point_2d, geo_shape, _file_name
)
FROM (
    SELECT
        $1::VARCHAR, $2::VARCHAR, $3::VARCHAR, $4::VARCHAR, $5::VARCHAR,
        $6::VARCHAR, $7::VARCHAR, $8::VARCHAR, $9::VARCHAR, $10::VARCHAR,
        $11::VARCHAR, $12::VARCHAR, $13::VARCHAR, $14::VARCHAR, $15::VARCHAR,
        METADATA$FILENAME
    FROM @BRONZE.MOBILITE.stage_bronze_mobilite/traffic_counts/
)
FILE_FORMAT = (FORMAT_NAME = BRONZE.MOBILITE.my_csv_format)
ON_ERROR    = 'CONTINUE';

-- Vélib realtime reste dans DynamoDB uniquement, pas de pipe Snowflake
DROP PIPE IF EXISTS PIPE_VELIB_REALTIME;

-- Snowpipe stations Vélib (JSON statique)
CREATE OR REPLACE PIPE PIPE_STATIONS_VELIB
  AUTO_INGEST = TRUE
AS
COPY INTO BRONZE.MOBILITE.RAW_STATIONS_VELIB
(
    stationcode, name, capacity, coordonnees_geo_lat, coordonnees_geo_lon,
    nom_arrondissement_communes, code_insee_commune, _file_name
)
FROM (
    SELECT
        $1:stationcode::VARCHAR,
        $1:name::VARCHAR,
        $1:capacity::VARCHAR,
        $1:coordonnees_geo.lat::VARCHAR,
        $1:coordonnees_geo.lon::VARCHAR,
        $1:nom_arrondissement_communes::VARCHAR,
        $1:code_insee_commune::VARCHAR,
        METADATA$FILENAME
    FROM @BRONZE.MOBILITE.stage_bronze_mobilite/stations/
)
FILE_FORMAT = (TYPE = JSON, STRIP_OUTER_ARRAY = TRUE)
ON_ERROR    = 'CONTINUE';
