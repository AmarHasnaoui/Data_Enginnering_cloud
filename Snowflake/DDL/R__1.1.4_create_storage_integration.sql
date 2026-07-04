USE DATABASE BRONZE;
USE SCHEMA AIR_QUALITY;

CREATE FILE FORMAT IF NOT EXISTS my_csv_format
  TYPE                          = CSV
  FIELD_DELIMITER               = ';'
  SKIP_HEADER                   = 1
  FIELD_OPTIONALLY_ENCLOSED_BY  = '"'
  EMPTY_FIELD_AS_NULL           = TRUE;

CREATE STORAGE INTEGRATION IF NOT EXISTS s3_integration
  TYPE                      = EXTERNAL_STAGE
  STORAGE_PROVIDER          = S3
  ENABLED                   = TRUE
  STORAGE_AWS_ROLE_ARN      = 'arn:aws:iam::${AWS_ACCOUNT_ID}:role/projet-efrei-role'
  STORAGE_ALLOWED_LOCATIONS = ('s3://s3-projet-efrei/bronze/');

CREATE STAGE IF NOT EXISTS stage_bronze
  URL                 = 's3://s3-projet-efrei/bronze/'
  STORAGE_INTEGRATION = s3_integration
  FILE_FORMAT         = my_csv_format
;

