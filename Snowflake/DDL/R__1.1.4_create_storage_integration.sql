USE DATABASE BRONZE;
USE SCHEMA AIR_QUALITY;

CREATE OR REPLACE STORAGE INTEGRATION s3_integration
  TYPE                      = EXTERNAL_STAGE
  STORAGE_PROVIDER          = S3
  ENABLED                   = TRUE
  STORAGE_AWS_ROLE_ARN      = 'arn:aws:iam::221996521946:role/projet-efrei-role'
  STORAGE_ALLOWED_LOCATIONS = ('s3://s3-projet-efrei/bronze/');

-- Stage unique pointant sur le préfixe bronze/
-- Les sous-chemins (air_quality/, coordonnees/, ...) sont précisés dans chaque Snowpipe
CREATE OR REPLACE STAGE stage_bronze
  URL                 = 's3://s3-projet-efrei/bronze/'
  STORAGE_INTEGRATION = s3_integration
  FILE_FORMAT         = my_csv_format;

-- Après création, récupérer les valeurs suivantes pour la Storage Integration AWS :
-- DESC INTEGRATION s3_integration;
-- => STORAGE_AWS_IAM_USER_ARN  (à ajouter dans le trust policy du rôle AWS)
-- => STORAGE_AWS_EXTERNAL_ID   (à ajouter dans la condition sts:ExternalId)
