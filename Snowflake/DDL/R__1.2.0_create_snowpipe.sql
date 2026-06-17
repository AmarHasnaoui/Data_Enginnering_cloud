USE DATABASE BRONZE;
USE SCHEMA AIR_QUALITY;

-- Snowpipe air quality : auto-ingest dès qu'un fichier arrive dans bronze/air_quality/
CREATE OR REPLACE PIPE PIPE_AIR_QUALITY
  AUTO_INGEST = TRUE
AS
COPY INTO BRONZE.AIR_QUALITY.RAW_AIR_QUALITY
(
    date_debut, date_fin, organisme, code_zas, zas, code_site, nom_site,
    type_implantation, polluant, type_influence, discriminant, reglementaire,
    type_evaluation, procedure_mesure, type_valeur, valeur, valeur_brute,
    unite_mesure, taux_saisie, couverture_temporelle, couverture_donnees,
    code_qualite, validite, _file_name
)
FROM (
    SELECT
        $1::VARCHAR, $2::VARCHAR, $3::VARCHAR, $4::VARCHAR, $5::VARCHAR,
        $6::VARCHAR, $7::VARCHAR, $8::VARCHAR, $9::VARCHAR, $10::VARCHAR,
        $11::VARCHAR, $12::VARCHAR, $13::VARCHAR, $14::VARCHAR, $15::VARCHAR,
        $16::VARCHAR, $17::VARCHAR, $18::VARCHAR, $19::VARCHAR, $20::VARCHAR,
        $21::VARCHAR, $22::VARCHAR, $23::VARCHAR,
        METADATA$FILENAME
    FROM @stage_bronze/air_quality/
)
FILE_FORMAT = (FORMAT_NAME = my_csv_format)
ON_ERROR    = 'CONTINUE';

-- Snowpipe coordonnées : fichier de référence (rechargé ponctuellement)
CREATE OR REPLACE PIPE PIPE_COORDONNEES
  AUTO_INGEST = TRUE
AS
COPY INTO BRONZE.AIR_QUALITY.RAW_COORDONNEES
(
    code_site, latitude, longitude, _file_name
)
FROM (
    SELECT
        $1::VARCHAR, $2::VARCHAR, $3::VARCHAR,
        METADATA$FILENAME
    FROM @stage_bronze/coordonnees/
)
FILE_FORMAT = (FORMAT_NAME = my_csv_format)
ON_ERROR    = 'CONTINUE';

