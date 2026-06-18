-- Export Gold (marts Silver dm_*) vers S3 rapatriement RDS Postgres côté AWS
-- via l'extension native aws_s3 (voir infra_aws/lambda_rds_import).
-- Chaque fichier est écrit à un chemin fixe (overwrite quotidien)

USE DATABASE SILVER;
USE SCHEMA TRANSFORMATION;

USE ROLE TRANSFORM_ROLE;

CREATE OR REPLACE FILE FORMAT my_csv_export_format
  TYPE                          = CSV
  FIELD_DELIMITER               = ','
  FIELD_OPTIONALLY_ENCLOSED_BY  = '"'
  EMPTY_FIELD_AS_NULL           = TRUE
  COMPRESSION                   = NONE
  NULL_IF                       = ('\\N');

USE ROLE GITHUB_ROLE;
-- s3_integration (créée en R__1.1.4) n'autorisait que bronze/ : on étend son
-- périmètre à gold_export/ plutôt que créer une 2e storage integration.
ALTER STORAGE INTEGRATION s3_integration
  SET STORAGE_ALLOWED_LOCATIONS = (
    's3://s3-projet-efrei/bronze/',
    's3://s3-projet-efrei/gold_export/'
  );

CREATE STAGE IF NOT EXISTS stage_gold_export
  URL                 = 's3://s3-projet-efrei/gold_export/'
  STORAGE_INTEGRATION = s3_integration
  FILE_FORMAT         = my_csv_export_format;

USE ROLE TRANSFORM_ROLE;

CREATE OR REPLACE FILE FORMAT my_csv_export_format
  TYPE                          = CSV
  FIELD_DELIMITER               = ','
  FIELD_OPTIONALLY_ENCLOSED_BY  = '"'
  EMPTY_FIELD_AS_NULL           = TRUE
  COMPRESSION                   = NONE
  NULL_IF                       = ('\\N');

CREATE OR REPLACE PROCEDURE SP_EXPORT_GOLD_TO_S3()
RETURNS STRING
LANGUAGE SQL
AS
$$
BEGIN
  COPY INTO @stage_gold_export/dm_air_quality_daily.csv
    FROM SILVER.AIR_QUALITY.DM_AIR_QUALITY_DAILY
    FILE_FORMAT = (FORMAT_NAME = my_csv_export_format)
    OVERWRITE = TRUE SINGLE = TRUE HEADER = TRUE;

  COPY INTO @stage_gold_export/dm_alertes_pollution.csv
    FROM SILVER.AIR_QUALITY.DM_ALERTES_POLLUTION
    FILE_FORMAT = (FORMAT_NAME = my_csv_export_format)
    OVERWRITE = TRUE SINGLE = TRUE HEADER = TRUE;

  COPY INTO @stage_gold_export/dm_velo_daily.csv
    FROM SILVER.MOBILITE.DM_VELO_DAILY
    FILE_FORMAT = (FORMAT_NAME = my_csv_export_format)
    OVERWRITE = TRUE SINGLE = TRUE HEADER = TRUE;

  COPY INTO @stage_gold_export/dm_trafic_routier_daily.csv
    FROM SILVER.MOBILITE.DM_TRAFIC_ROUTIER_DAILY
    FILE_FORMAT = (FORMAT_NAME = my_csv_export_format)
    OVERWRITE = TRUE SINGLE = TRUE HEADER = TRUE;

  COPY INTO @stage_gold_export/dm_smartcity_kpi_daily.csv
    FROM SILVER.SMARTCITY.DM_SMARTCITY_KPI_DAILY
    FILE_FORMAT = (FORMAT_NAME = my_csv_export_format)
    OVERWRITE = TRUE SINGLE = TRUE HEADER = TRUE;

  COPY INTO @stage_gold_export/dm_zone_kpi_daily.csv
    FROM SILVER.ZONES_ADMINISTRATIVES.DM_ZONE_KPI_DAILY
    FILE_FORMAT = (FORMAT_NAME = my_csv_export_format)
    OVERWRITE = TRUE SINGLE = TRUE HEADER = TRUE;

  COPY INTO @stage_gold_export/ref_arrondissements.csv
    FROM (
        SELECT * EXCLUDE (geometry), TO_VARCHAR(ST_ASGEOJSON(geometry)) AS geometry
        FROM SILVER.ZONES_ADMINISTRATIVES.STG_ARRONDISSEMENTS
    )
    FILE_FORMAT = (FORMAT_NAME = my_csv_export_format)
    OVERWRITE = TRUE SINGLE = TRUE HEADER = TRUE;

  RETURN 'OK';
END;
$$;

CREATE OR REPLACE TASK TASK_EXPORT_GOLD_TO_S3
  WAREHOUSE = TRANSFORM_WH
  AFTER SILVER.TRANSFORMATION.TASK_RUN_DBT_ALL
AS
  CALL SP_EXPORT_GOLD_TO_S3();

-- Ordre obligatoire : Snowflake exige que les tasks enfants soient résumées
-- avant la task racine d'un DAG.
ALTER TASK TASK_EXPORT_GOLD_TO_S3 RESUME;
ALTER TASK TASK_RUN_DBT_ALL RESUME;

USE ROLE GITHUB_ROLE;