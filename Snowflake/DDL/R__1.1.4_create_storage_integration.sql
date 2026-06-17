USE DATABASE BRONZE;
USE SCHEMA AIR_QUALITY;

CREATE OR REPLACE STORAGE INTEGRATION s3_integration
  TYPE                      = EXTERNAL_STAGE
  STORAGE_PROVIDER          = S3
  ENABLED                   = TRUE
  STORAGE_AWS_ROLE_ARN      = 'arn:aws:iam::221996521946:role/projet-efrei-role'
  STORAGE_ALLOWED_LOCATIONS = ('s3://s3-projet-efrei/bronze/');

CREATE OR REPLACE STAGE stage_bronze
  URL                 = 's3://s3-projet-efrei/bronze/'
  STORAGE_INTEGRATION = s3_integration
  FILE_FORMAT         = my_csv_format;

