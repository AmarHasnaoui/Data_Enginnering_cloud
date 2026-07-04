-- Stage et format dédié au schéma MOBILITE
-- Réutilise la Storage Integration s3_integration (account-level, définie dans R__1.1.4)
-- Évite le couplage cross-schema avec BRONZE.AIR_QUALITY
USE DATABASE BRONZE;
USE SCHEMA MOBILITE;

CREATE OR REPLACE FILE FORMAT my_csv_format
  TYPE                          = CSV
  FIELD_DELIMITER               = ';'
  FIELD_OPTIONALLY_ENCLOSED_BY  = '"'
  SKIP_HEADER                   = 1
  EMPTY_FIELD_AS_NULL           = TRUE;

CREATE STAGE IF NOT EXISTS stage_bronze_mobilite
  URL                 = 's3://s3-projet-efrei/bronze/'
  STORAGE_INTEGRATION = s3_integration
  FILE_FORMAT         = my_csv_format;
